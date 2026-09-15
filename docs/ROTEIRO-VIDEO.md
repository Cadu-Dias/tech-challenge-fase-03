# Roteiro do vídeo de apresentação — Tech Challenge Fase 3 (ToggleMaster)

> Duração alvo: até 20 minutos. Grave a tela mostrando terminal, GitHub, ArgoCD UI e,
> quando fizer sentido, o AWS Console. Fale em primeira pessoa, sem ler o roteiro
> literalmente — use-o como guia de tópicos e tempos.

---

## 0. Abertura (0:00 – 1:00)

- Se apresentar e contextualizar o histórico do projeto: "Na Fase 2 nós separamos o
  monolito ToggleMaster em 5 microsserviços (auth, flag, targeting, evaluation e
  analytics) rodando em Kubernetes/EKS. O problema é que naquela fase toda a
  infraestrutura AWS foi criada **manualmente** via `aws cli`/console, e o deploy dos
  PODs era feito com `kubectl apply -f` direto da minha máquina — nada versionado,
  nada repetível, nada auditável."
- Deixar claro o objetivo desta Fase 3 em uma frase: "transformar aquele processo
  manual em um pipeline automatizado, seguro e rastreável, do commit até o pod
  rodando em produção." Os três pilares que vou mostrar:
  1. **Infraestrutura como Código** — todo o ambiente AWS recriável via Terraform;
  2. **DevSecOps** — pipelines de CI que testam, fazem lint e **bloqueiam** código
     com vulnerabilidades antes de chegar à `main`;
  3. **GitOps** — o ArgoCD observa o repositório e mantém o cluster sempre
     sincronizado com o que está declarado no git, sem `kubectl apply` manual.
- Mostrar a estrutura do repositório `tech-challenge-fase-03` explicando o papel de
  cada pasta: `services/` (código dos 5 microsserviços, herdado da Fase 2),
  `infra/` (Terraform), `gitops/` (manifests Kustomize consumidos pelo ArgoCD) e
  `.github/workflows` + `.github/actions` (pipelines de CI reutilizáveis).

## 1. Arquitetura geral (1:00 – 3:30)

- Abrir o diagrama de arquitetura do `README.md` e narrar o fluxo completo de ponta
  a ponta, apontando cada seta: "um desenvolvedor faz push num serviço → o GitHub
  Actions builda, testa e escaneia a imagem → se tudo passar, publica no ECR e
  **o próprio pipeline** commita a nova tag de imagem no diretório `gitops/` →
  o ArgoCD, rodando dentro do cluster, detecta essa mudança no git e aplica no EKS
  automaticamente — sem ninguém rodar `kubectl apply` manualmente."
- Enumerar os componentes AWS que o Terraform provisiona, explicando o papel de cada
  um brevemente: VPC com subnets públicas/privadas, EKS (o cluster Kubernetes),
  3 instâncias RDS PostgreSQL (uma por serviço com banco próprio: auth, flag,
  targeting), ElastiCache Redis (cache de flags avaliadas), DynamoDB (histórico de
  avaliações do evaluation-service), SQS (fila assíncrona consumida pelo
  analytics-service), ECR (registry das 5 imagens), Secrets Manager (segredos
  gerenciados) e, dentro do cluster, ArgoCD e ingress-nginx.
- Explicar como as restrições do AWS Academy (Learner Lab) moldaram decisões de
  arquitetura: não é possível criar roles/policies IAM customizadas — usamos o
  `LabRole` já existente — e as credenciais são temporárias (expiram em poucas
  horas). Por isso não foi usado OIDC/IRSA (que exigiria criar uma IAM Role de
  confiança para o GitHub Actions); em vez disso, o CI recebe as credenciais via
  GitHub Secrets, renovadas manualmente quando necessário — uma limitação conhecida
  do ambiente de laboratório, não da arquitetura em si.

## 2. Infraestrutura como Código — Terraform (3:30 – 8:00)

- Navegar pela pasta `infra/modules/` e, para cada módulo, dizer em uma frase o que
  ele provisiona e por que existe como módulo separado (reuso e responsabilidade
  única): `network` (VPC/subnets/rotas), `eks` (cluster + node group gerenciado),
  `rds` (as 3 instâncias Postgres), `elasticache` (Redis), `dynamodb`, `sqs`, `ecr`
  (os 5 repositórios de imagem, com `image_tag_mutability = IMMUTABLE` — importante
  mencionar, volta no bloco de CI), `secrets` (Secrets Manager + sincronização para
  K8s Secret), `argocd` (instalação via Helm + a Application inicial) e
  `ingress_nginx` (o controller que expõe os serviços via NLB).
- Mostrar o backend remoto em S3 (`infra/backend.hcl`) e explicar por que existe um
  stack `infra/bootstrap` isolado: o backend S3 precisa existir *antes* de qualquer
  outro recurso, então ele é criado uma única vez, manualmente, fora do fluxo normal
  de CI/CD — depois disso o resto da infraestrutura vive 100% em S3 com locking.
- Rodar ao vivo (ou mostrar um trecho já gravado) o ciclo básico:
  ```
  terraform init -backend-config=backend.hcl
  terraform validate
  terraform plan
  ```
  Se possível, terminar mostrando um `terraform plan` limpo ("No changes"),
  reforçando que o estado real da AWS bate exatamente com o código — não há drift.
- Contar 2-3 desafios reais enfrentados durante o desenvolvimento (isso mostra que a
  infra foi de fato provisionada do zero, testada e ajustada — não é só código
  estático que nunca rodou):
  - A AMI padrão do node group do EKS não era mais suportada na versão do
    Kubernetes usada; foi preciso trocar para `AL2023_x86_64_STANDARD`.
  - A versão do PostgreSQL pedida (16.4) não estava disponível na conta/região;
    tive que consultar `aws rds describe-db-engine-versions` para achar uma versão
    válida (16.10) antes de reaplicar.
  - Descrições de Security Group no provider AWS exigem texto 100% ASCII — um
    acento sem querer no `description` já derruba o `apply`.
  - Já durante a validação final do pipeline, o `terraform plan` também acusou um
    drift entre a versão do Kubernetes declarada no código (1.30) e a versão real
    do cluster (1.31, atualizada em algum momento) — corrigido atualizando a
    variável, evitando um downgrade destrutivo por engano.
- Mostrar os outputs finais do `terraform apply` (endpoints do RDS, endpoint do
  Redis, URLs das filas SQS, URIs dos repositórios ECR) — esses outputs são
  justamente o que alimenta os Secrets e os manifests do GitOps mais à frente.

## 3. Segredos e configuração (8:00 – 9:30)

- Explicar o fluxo completo de um segredo, do nascimento ao uso: o Terraform gera a
  senha do banco com `random_password` (nunca digitada por humano) → grava no AWS
  Secrets Manager sob o caminho `togglemaster/prod/<service>` → e, através do
  provider Kubernetes do próprio Terraform, replica esse valor como um
  `kubernetes_secret` no namespace `toggle`, que é o que o Pod efetivamente monta
  como variável de ambiente. Em nenhum momento o segredo em texto puro passa pelo
  git.
- Mostrar rapidamente no AWS Console (Secrets Manager) os segredos criados, um por
  serviço.
- Contar um detalhe sutil que gerou um bug real: uma senha gerada aleatoriamente
  pode conter caracteres especiais (`%`, `/`, `@`) que são válidos numa senha, mas
  **quebram o parsing** de uma connection string no formato URI (esquema
  `postgres://<usuario>:<senha>@<host>/<db>`) se não forem percent-encoded.
  A correção foi envolver a senha com a função `urlencode()` do Terraform antes
  de montar o `DATABASE_URL` — um lembrete de que "funciona no `plan`" não é o
  mesmo que "funciona em runtime".

## 4. GitOps com ArgoCD (9:30 – 13:30)

- Mostrar a estrutura `gitops/base/` + `gitops/overlays/prod/` e explicar a lógica
  do Kustomize: cada serviço tem seu diretório `base` com Deployment, Service,
  ConfigMap e HPA; o overlay `prod` compõe todos eles num único pacote, injeta as
  tags de imagem corretas e gera os ConfigMaps de schema SQL via
  `configMapGenerator`. É esse overlay que o ArgoCD aponta como fonte da verdade.
- Abrir a UI do ArgoCD (`kubectl port-forward svc/argocd-server -n argocd 8080:443`,
  depois `https://localhost:8080`) e mostrar a `Application toggle-master` com
  status **Synced / Healthy**. Explorar a árvore de recursos ao vivo — Deployments,
  Services, HPAs, Ingress, os Jobs de `db-init` — mostrando visualmente que tudo que
  está rodando no cluster tem uma origem rastreável no git.
- Explicar o desafio de autenticação enfrentado: como o repositório GitOps é
  **privado**, o ArgoCD precisa de credenciais para clonar. A solução foi o
  Terraform criar um `kubernetes_secret` com o label
  `argocd.argoproj.io/secret-type: repository`, contendo um token de acesso —
  provisionado como qualquer outro recurso de infraestrutura, sem passos manuais.
- Explicar os **Jobs de inicialização de schema** (`db-init-auth/flag/targeting`) e
  o problema real que eles resolveram: Kubernetes `Jobs` são imutáveis, então não dá
  simplesmente para reaplicar o mesmo Job a cada sync. A solução foi usá-los como
  *sync hooks* do ArgoCD (`argocd.argoproj.io/hook: Sync` combinado com
  `hook-delete-policy: HookSucceeded`), garantindo que o schema SQL seja aplicado
  de forma idempotente a cada sincronização, sem acumular Jobs órfãos. Vale
  mencionar de passagem que a ordem dos hooks importa: usar `PreSync` aqui causaria
  o Job tentar montar um ConfigMap que ainda não existe, por isso `Sync` foi a
  escolha certa.
- Rodar `kubectl get all -n toggle` mostrando todos os pods `Running` e, se quiser
  reforçar visualmente o "GitOps de verdade", fazer um pequeno teste ao vivo: mudar
  algo trivial em um manifest do `gitops/`, dar `git push`, e mostrar o ArgoCD
  detectando e sincronizando sozinho em segundos, sem nenhum `kubectl apply`.

## 5. Pipelines de CI / DevSecOps (13:30 – 17:30)

- Abrir `.github/workflows/` e explicar a estrutura comum, presente nos 5 workflows
  (um por serviço), destacando que cada estágio só libera o próximo se passar:
  1. **build-test** — compila/roda os testes unitários (`go build`/`go test` para
     auth e evaluation; `pytest` para flag, targeting e analytics).
  2. **lint** — `golangci-lint` ou `flake8`, garantindo padrão de código mínimo.
  3. **security (DevSecOps)** — Trivy (SCA, escaneando dependências do filesystem)
     + gosec/bandit (SAST, analisando o próprio código-fonte em busca de padrões
     inseguros). Esse estágio é **bloqueante**: severidade CRITICAL derruba o
     pipeline.
  4. **docker** — builda a imagem, roda o Trivy de novo (agora contra a imagem
     final, incluindo o SO base) e só faz push para o ECR se o scan passar. Só
     roda em push direto na `main` (não em PRs, já que exige credenciais AWS).
  5. **gitops-bump** — usa `kustomize edit set image` para atualizar a tag da
     imagem recém-publicada em `gitops/overlays/prod/kustomization.yaml` e comita
     de volta no repo com `[skip ci]` (evitando loop infinito de CI). É esse commit
     automático que o ArgoCD detecta e sincroniza.
- **Demonstração ao vivo do bloqueio de segurança** (o ponto alto da apresentação):
  - Mostrar o PR #1 (`demo/vulnerable-dependency`): adicionei de propósito
    `Pillow==8.1.0` ao `flag-service` — uma versão antiga com CVEs CRITICAL
    conhecidas e documentadas.
  - Mostrar os *checks* do PR falhando e o botão de merge bloqueado pelo GitHub.
  - Mostrar o commit seguinte removendo a dependência vulnerável e os checks
    voltando a ficar verdes, liberando o merge.
  - Reforçar a frase-chave: "o pipeline não deixa uma dependência vulnerável
    chegar à `main`, muito menos ser implantada em produção — o bloqueio acontece
    automaticamente, sem depender de revisão manual."
  - Bônus, se der tempo: mencionar que durante o desenvolvimento desse próprio
    pipeline o Trivy pegou **CVEs reais**, não simulados — um `perl-base`
    desatualizado na imagem base Debian dos serviços Python, e uma versão do Go
    (1.21) com uma falha conhecida na validação de certificado TLS
    (`crypto/tls`). Ambos foram corrigidos (upgrade de pacotes do SO na imagem
    Docker e atualização do Go para 1.25) e re-validados pelo próprio CI antes de
    ir para produção — prova de que o gate de segurança funciona também no
    dia a dia, não só na demo.
- Mostrar o workflow `terraform.yml`: `fmt`/`validate`/`tfsec` rodam em todo
  push/PR que toque `infra/`; o `plan` só roda em PR ou via `workflow_dispatch`
  manual; e o `apply` é **restrito a `workflow_dispatch`** com aprovação de um
  ambiente protegido (`environment: production`) — ninguém aplica infraestrutura
  em produção sem uma ação explícita e auditável.

## 6. Validação ponta a ponta (17:30 – 19:00)

- Pegar o hostname do NLB criado pelo ingress-nginx:
  ```
  kubectl get svc -n ingress-nginx ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```
  (no momento desta gravação:
  `aabe2ae784df14e1d80bf3d9ec5d3c4f-ca1d4678986be305.elb.us-east-1.amazonaws.com`)
- Mostrar chamadas reais contra esse hostname, comentando o porquê de cada código
  de resposta (isso prova que não são apenas "pods verdes", e sim uma aplicação
  respondendo corretamente às regras de negócio):
  - `GET /auth/health` e `GET /analytics/health` → `200` (serviços saudáveis).
  - `GET /flags` sem token → `401` (autenticação sendo exigida corretamente).
  - `GET /rules` com verbo errado → `405` (roteamento e validação de método OK).
  - `POST /evaluate` com corpo inválido → `400` (validação de payload funcionando).
  - Uma chamada de negócio real e completa: criar uma API key via
    `POST /auth/admin/keys` usando o `MASTER_KEY` (lido direto do Secret do
    Kubernetes) e mostrar a resposta `201 Created` — prova definitiva de que a
    aplicação está escrevendo de verdade no RDS, não é só um health-check.
- Mostrar o HPA configurado (`kubectl get hpa -n toggle`) para `evaluation-service`
  e `analytics-service`, explicando que eles escalam horizontalmente com base em
  uso de CPU/memória, sem intervenção manual.

## 7. Encerramento (19:00 – 20:00)

- Recapitular o que foi entregue, com números concretos: infraestrutura 100%
  provisionada via Terraform (VPC, EKS, 3 RDS, Redis, DynamoDB, SQS, ECR, Secrets
  Manager), 5 pipelines de CI com estágio de segurança bloqueante demonstrado na
  prática (não só configurado — testado e comprovado com um PR real), e GitOps
  funcional com ArgoCD mantendo o cluster sincronizado automaticamente com o git.
- Comparar rapidamente com a Fase 2 usando a tabela do README: o que era manual
  (provisionamento via CLI, deploy via `kubectl apply`, segredos preenchidos à
  mão, nenhum teste/scan de segurança) agora é automatizado, versionado e
  auditável.
- Mencionar próximos passos possíveis, deixando claro que são melhorias futuras e
  não lacunas da entrega atual: autenticação via OIDC GitHub→AWS (hoje limitada
  pelas restrições de IAM do AWS Academy), `ApplicationSet` do ArgoCD para
  múltiplos ambientes (dev/staging/prod), e observabilidade com
  Prometheus/Grafana.
- Agradecer e encerrar.

---

### Checklist rápido antes de gravar

- [ ] Terminal com fonte grande e tema legível
- [ ] `kubectl config current-context` aponta para `togglemaster-eks` (se não, rode
      `aws eks update-kubeconfig --name togglemaster-eks --region us-east-1`)
- [ ] Credenciais AWS ainda válidas (`aws sts get-caller-identity`) — no AWS
      Academy elas expiram em poucas horas
- [ ] `kubectl get pods -n toggle` e `kubectl get application -n argocd` testados
- [ ] UI do ArgoCD acessível via port-forward
      (`kubectl port-forward svc/argocd-server -n argocd 8080:443`)
- [ ] PR #1 (demo de segurança) aberto no navegador em uma aba
- [ ] AWS Console (Secrets Manager, RDS, EKS) logado em outra aba
- [ ] Terminal com `terraform plan` já rodado uma vez (cache quente) para não
      esperar download de providers ao vivo
- [ ] Hostname do NLB à mão para os testes de endpoint (`kubectl get svc -n
      ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`)
