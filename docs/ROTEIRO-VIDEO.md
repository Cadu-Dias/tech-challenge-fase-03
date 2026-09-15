# Roteiro do vídeo de apresentação — Tech Challenge Fase 3 (ToggleMaster)

> Duração alvo: até 20 minutos. Grave a tela mostrando terminal, GitHub, ArgoCD UI e,
> quando fizer sentido, o AWS Console. Fale em primeira pessoa, sem ler o roteiro
> literalmente — use-o como guia de tópicos e tempos.

---

## 0. Abertura (0:00 – 1:00)

- Se apresentar e contextualizar: "Na Fase 2 nós separamos o monolito ToggleMaster em
  5 microsserviços rodando em Kubernetes (EKS), mas toda a infraestrutura foi criada
  manualmente via AWS CLI e o deploy era feito com `kubectl apply` local."
- Objetivo da Fase 3: **Infraestrutura como Código (Terraform)** + **pipelines de CI
  com DevSecOps** + **entrega contínua via GitOps (ArgoCD)**.
- Mostrar rapidamente a estrutura do repositório `tech-challenge-fase-03`
  (`services/`, `infra/`, `gitops/`, `.github/`).

## 1. Arquitetura geral (1:00 – 3:30)

- Abrir o diagrama de arquitetura do `README.md`.
- Explicar o fluxo em alto nível:
  `Dev push -> GitHub Actions (CI) -> ECR -> commit automático no gitops/ -> ArgoCD detecta -> sync no EKS`.
- Citar os componentes AWS provisionados via Terraform: VPC, EKS, 3× RDS Postgres,
  ElastiCache Redis, DynamoDB, SQS, ECR, Secrets Manager, ArgoCD, ingress-nginx.
- Mencionar as restrições do ambiente AWS Academy (sem criação de IAM Role — uso do
  `LabRole` existente; credenciais temporárias) e como isso influenciou o desenho
  (sem IRSA, CI usa secrets de curta duração).

## 2. Infraestrutura como Código — Terraform (3:30 – 8:00)

- Navegar pela pasta `infra/modules/` e comentar rapidamente cada módulo:
  `network`, `eks`, `rds`, `elasticache`, `dynamodb`, `sqs`, `ecr`, `secrets`,
  `argocd`, `ingress_nginx`.
- Mostrar o backend remoto S3 (`infra/backend.hcl`) e explicar por que existe um
  stack `infra/bootstrap` separado (cria o bucket de state antes do resto existir).
- Rodar ao vivo (ou mostrar um trecho já gravado) de:
  ```
  terraform init -backend-config=backend.hcl
  terraform validate
  terraform plan
  ```
- Destacar 2-3 desafios reais encontrados durante o apply (prova de que o ambiente
  foi realmente provisionado, não é só código estático):
  - AMI do node group do EKS precisou ser `AL2023_x86_64_STANDARD` (o tipo padrão
    não é mais suportado no Kubernetes 1.30).
  - Versão do PostgreSQL 16.4 não disponível na conta/região — foi preciso consultar
    `aws rds describe-db-engine-versions` e usar 16.10.
  - Descrições de Security Group precisam ser 100% ASCII (sem acentuação).
- Mostrar os outputs finais do `terraform apply` (endpoints RDS, Redis, URLs do SQS,
  URIs do ECR).

## 3. Segredos e configuração (8:00 – 9:30)

- Explicar o fluxo de segredos: `random_password` (Terraform) -> AWS Secrets Manager
  (`togglemaster/prod/<service>`) -> Kubernetes Secret (namespace `toggle`), tudo via
  provider `kubernetes`, sem nunca versionar segredo em texto puro no git.
- Mostrar rapidamente no AWS Console (Secrets Manager) os segredos criados.
- Comentar o cuidado extra necessário: senha gerada aleatoriamente pode conter
  caracteres especiais (`%`, `/`, etc.) que quebram uma connection string — por isso
  o `DATABASE_URL` usa `urlencode()` na senha.

## 4. GitOps com ArgoCD (9:30 – 13:30)

- Mostrar a pasta `gitops/base/` e `gitops/overlays/prod/` — explicar Kustomize:
  cada serviço tem seu próprio diretório base (Deployment, Service, ConfigMap, HPA),
  e o overlay `prod` compõe tudo, gera os ConfigMaps de schema SQL via
  `configMapGenerator` e injeta as tags de imagem.
- Abrir a UI do ArgoCD (`kubectl port-forward svc/argocd-server -n argocd 8080:443`)
  e mostrar a `Application toggle-master` com status **Synced / Healthy**, a árvore
  de recursos (Deployments, Services, HPAs, Ingress, Jobs de db-init).
- Explicar o desafio de autenticação: o repositório GitOps é **privado**, então foi
  necessário criar um `kubernetes_secret` com label
  `argocd.argoproj.io/secret-type: repository` contendo um token de acesso, via
  Terraform, para o ArgoCD conseguir clonar o repo.
- Explicar os **Jobs de inicialização de schema** (`db-init-auth/flag/targeting`),
  usados como *sync hooks* do ArgoCD (`argocd.argoproj.io/hook: Sync` +
  `hook-delete-policy: HookSucceeded`) para aplicar o SQL a cada sync, contornando a
  imutabilidade de `Jobs` no Kubernetes.
- Rodar `kubectl get all -n toggle` mostrando todos os pods `Running`.

## 5. Pipelines de CI / DevSecOps (13:30 – 17:30)

- Abrir `.github/workflows/` e explicar a estrutura comum a cada serviço:
  1. **build-test** (go vet/build/test ou pytest)
  2. **lint** (golangci-lint ou flake8)
  3. **security** — Trivy (SCA/dependências) + gosec/bandit (SAST), **bloqueante**
  4. **docker** — build, Trivy na imagem, push pro ECR (só em push na `main`)
  5. **gitops-bump** — atualiza a tag da imagem no `gitops/overlays/prod` via
     `kustomize edit set image` e comita com `[skip ci]`
- **Demonstração ao vivo do bloqueio de segurança** (este é o ponto mais importante):
  - Mostrar o PR #1 (`demo/vulnerable-dependency`) onde foi adicionada uma
    dependência com CVE crítica conhecida (`Pillow==8.1.0`) ao `flag-service`.
  - Mostrar os *checks* do PR falhando e bloqueando o merge.
  - Mostrar o commit seguinte removendo a dependência vulnerável e os checks
    ficando verdes.
  - Reforçar: "o pipeline não deixa uma dependência vulnerável chegar à `main`,
    muito menos ser implantada em produção."
- Mostrar o workflow `terraform.yml`: fmt/validate/tfsec em todo PR, `plan` comentado
  automaticamente, e `apply` restrito a `workflow_dispatch` com aprovação de um
  ambiente (`environment: production`).

## 6. Validação ponta a ponta (17:30 – 19:00)

- Pegar o hostname do NLB do ingress-nginx e mostrar chamadas reais:
  - `GET /auth/health` e `/analytics/health` respondendo 200.
  - Uma chamada de negócio real, por exemplo criar uma API key no `auth-service`
    (`POST /auth/admin/keys`) e mostrar a resposta 201 — prova de que a aplicação
    está escrevendo de verdade no RDS.
- Mostrar o HPA (`kubectl get hpa -n toggle`) configurado para `evaluation-service`
  e `analytics-service`.

## 7. Encerramento (19:00 – 20:00)

- Recapitular o que foi entregue: Terraform 100% do zero, CI com DevSecOps
  bloqueante demonstrado na prática, GitOps funcional com ArgoCD.
- Comparar rapidamente com a Fase 2 (tabela do README): manual vs. automatizado.
- Mencionar os próximos passos possíveis (não escopo desta entrega): OIDC
  GitHub->AWS quando IAM não for restrito, `ApplicationSet` multi-ambiente,
  observabilidade (Prometheus/Grafana).
- Agradecer e encerrar.

---

### Checklist rápido antes de gravar

- [ ] Terminal com fonte grande e tema legível
- [ ] `kubectl get pods -n toggle` e `kubectl get application -n argocd` testados
- [ ] UI do ArgoCD acessível via port-forward
- [ ] PR #1 (demo de segurança) aberto no navegador em uma aba
- [ ] AWS Console (Secrets Manager, RDS, EKS) logado em outra aba
- [ ] Terminal com `terraform plan` já rodado uma vez (cache quente) para não
      esperar download de providers ao vivo
