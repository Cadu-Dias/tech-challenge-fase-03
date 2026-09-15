# TECH Challenge Fase 03 — ToggleMaster: IaC + DevSecOps + GitOps

Continuação do [ToggleMaster Fase 2](https://github.com/Cadu-Dias/tech-challenge-fase-02):
os mesmos 5 microsserviços (auth, flag, targeting, evaluation, analytics), agora com:

1. **Infraestrutura 100% em Terraform** (com backend remoto S3), substituindo o
   provisionamento manual via AWS CLI da Fase 2.
2. **Pipelines de CI com DevSecOps bloqueante** (GitHub Actions).
3. **CD via GitOps com ArgoCD**, substituindo o `kubectl apply` manual.

---

## 📁 Estrutura do repositório

```
.
├── services/                 # os 5 microsserviços (código-fonte + testes + Dockerfile)
│   ├── auth-service/          (Go)
│   ├── flag-service/          (Python/Flask)
│   ├── targeting-service/     (Python/Flask)
│   ├── evaluation-service/    (Go)
│   └── analytics-service/     (Python/Flask, worker)
├── infra/                    # Terraform: toda a infra AWS + instalação do ArgoCD/ingress-nginx
│   ├── bootstrap/              stack separada: bucket S3 do state remoto
│   └── modules/                network, eks, rds, elasticache, dynamodb, sqs, ecr,
│                                secrets, argocd, ingress_nginx
├── gitops/                   # manifestos Kubernetes (Kustomize), sincronizados pelo ArgoCD
│   ├── base/                   um diretório por recurso/serviço
│   └── overlays/prod/          overlay único usado em produção
└── .github/
    ├── workflows/             5 pipelines de CI (um por serviço) + terraform.yml
    └── actions/                composite actions reutilizáveis (trivy scan, gitops-bump)
```

---

## 🏗️ Arquitetura

```
GitHub Actions (CI)                    ArgoCD (CD/GitOps)
────────────────────                   ───────────────────
build → test → lint → security   push   watch gitops/overlays/prod
  → docker build/scan → push ECR ────▶  sync automático (prune + self-heal)
  → bump da tag no gitops/                    │
                                              ▼
                                   ┌─────────────────────────────┐
                     Internet ───▶ │  ingress-nginx + NLB         │
                                   └──────────────┬──────────────┘
        ┌───────────────┬───────────────┬─────────┴─────┬────────────────┐
        ▼               ▼               ▼               ▼                ▼
 ┌────────────┐  ┌────────────┐  ┌─────────────┐  ┌────────────┐  ┌──────────────┐
 │ auth-svc   │  │ flag-svc   │  │ targeting   │  │ evaluation │  │ analytics    │
 └─────┬──────┘  └─────┬──────┘  └──────┬──────┘  └─────┬──────┘  └──────┬───────┘
   ┌───▼───┐       ┌───▼───┐        ┌───▼───┐      ┌────▼────┐      ┌─────▼─────┐
   │  RDS  │       │  RDS  │        │  RDS  │      │ Redis   │      │ DynamoDB  │
   └───────┘       └───────┘        └───────┘      └────┬────┘      └─────▲─────┘
                                                        ▼                │
                                                   ┌─────────┐           │
                                                   │  SQS    │───────────┘
                                                   └─────────┘
```

Todos os recursos AWS (VPC, EKS, RDS, ElastiCache, DynamoDB, SQS, ECR, Secrets Manager)
são criados pelo Terraform em `infra/`. O ArgoCD e o ingress-nginx são instalados pelo
próprio Terraform (provider `helm`), mas os *workloads* dos 5 microsserviços são geridos
via GitOps (a partir de `gitops/overlays/prod`).

---

## ☁️ Restrições do AWS Academy (Learner Lab) que moldaram o desenho

- **Proibido criar IAM Roles/Policies** → EKS (cluster role + node group role) reusam a
  role pré-existente `LabRole` via `data "aws_iam_role" "lab_role"`. Sem IRSA — os pods
  usam as credenciais do nó via IMDS, como na Fase 2.
- **IMDS hop limit** → o launch template do node group define
  `metadata_options.http_put_response_hop_limit = 2` (bug conhecido da Fase 2: com o
  padrão 1, os pods não alcançam o IMDS para pegar as credenciais da `LabRole`).
- **Sem OIDC GitHub→AWS** (exigiria criar uma IAM Role) → os workflows usam as
  credenciais temporárias do Lab guardadas como *secrets* do repositório
  (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`), que precisam ser
  atualizadas a cada nova sessão do Lab (elas expiram em poucas horas).
- **SCP explícita nega `s3:GetBucketObjectLockConfiguration`** — isso quebra o ciclo
  padrão Create+Read do recurso `aws_s3_bucket` usado no bucket do state remoto
  (`infra/bootstrap`). Ver seção *Runbook* abaixo para o workaround.

---

## 🚀 Runbook — provisionando a infraestrutura do zero

### 1. Pré-requisitos

- Terraform >= 1.9, AWS CLI, `kubectl`.
- Credenciais do AWS Academy Learner Lab em `~/.aws/credentials` (perfil `default`).

### 2. Bootstrap do backend remoto (bucket S3 do state)

```bash
cd infra/bootstrap
terraform init
terraform apply
```

> ⚠️ **SCP do Academy**: a primeira `apply` pode falhar com
> `AccessDenied: s3:GetBucketObjectLockConfiguration` durante o *refresh* automático
> pós-criação do `aws_s3_bucket`. O bucket **é criado com sucesso** apesar do erro; o
> Terraform apenas marca o recurso como `(tainted)`. Para completar o restante dos
> recursos (versionamento, criptografia, bloqueio de acesso público) sem disparar a
> mesma leitura proibida:
> ```bash
> terraform untaint aws_s3_bucket.tfstate
> terraform apply -refresh=false -auto-approve
> ```
> Depois disso, **nunca rode `terraform plan`/`apply` normal nesta stack novamente**
> (ela não pode ser atualizada/destruída pela mesma razão); trate-a como *write-once*.

### 3. Stack principal (rede, EKS, dados, ArgoCD, ingress)

```bash
cd infra
cp backend.hcl.example backend.hcl   # ajuste o nome do bucket se necessário
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

Tempo esperado: **25–35 minutos** (EKS ~10-12min, RDS ~5-8min cada, em paralelo).
As credenciais do Lab expiram em poucas horas — se o apply falhar no meio com
`ExpiredToken`/`InvalidClientTokenId`, basta atualizar `~/.aws/credentials` e rodar
`terraform apply tfplan` (ou um novo `plan`) novamente; o state em S3 permite retomar.

Ao final, os outputs trazem: endpoints do RDS/Redis, URL da SQS, URIs do ECR, comando
para configurar o `kubectl` e o comando de `port-forward` da UI do ArgoCD.

### 4. Build e push das imagens (primeira vez, antes do primeiro sync do ArgoCD)

O `ArgoCD Application` já é criado apontando para `gitops/overlays/prod`, mas os
Deployments referenciam a tag `latest` de cada repositório ECR. Rode os 5 workflows de
CI (ou faça manualmente `docker build && docker push`) pelo menos uma vez para publicar
as imagens antes do primeiro sync ficar `Healthy`.

### 5. Validar

```bash
$(terraform output -raw configure_kubectl 2>/dev/null || echo "aws eks update-kubeconfig --region us-east-1 --name togglemaster-eks")
kubectl get pods -n toggle
kubectl get ingress -n toggle
kubectl get svc -n ingress-nginx ingress-nginx-controller   # aguardar o hostname do NLB
```

### 6. Destruir (evitar consumo de créditos do Lab)

```bash
cd infra
terraform destroy
# infra/bootstrap NÃO deve ser destruído por este workflow (mesma SCP); apague o bucket
# manualmente via console/CLI se necessário ao final do curso.
```

---

## 🔐 Segredos

Nenhuma credencial é commitada. O módulo `infra/modules/secrets`:

1. Gera senhas (`random_password`) para os 3 bancos RDS, a `MASTER_KEY` do auth-service
   e a `SERVICE_API_KEY` compartilhada entre os serviços internos.
2. Persiste cada payload em **AWS Secrets Manager** (`togglemaster/<env>/<serviço>`),
   para auditoria/rotação.
3. Materializa os mesmos valores como **Kubernetes Secrets** (`auth-secret`,
   `flag-secret`, `targeting-secret`, `evaluation-secret`) via provider `kubernetes`,
   consumidos pelos Deployments com `envFrom.secretRef` — substituindo os antigos
   `secret.template.yaml` preenchidos manualmente na Fase 2.

Os workflows de CI usam as credenciais do Lab como *secrets* do repositório GitHub
(`Settings → Secrets and variables → Actions`): `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `TF_STATE_BUCKET`.

---

## 🔁 Fluxo de CI/CD (GitOps)

Cada serviço tem seu próprio workflow (`.github/workflows/ci-<serviço>.yml`), disparado
por `pull_request`/`push` filtrado por `paths: services/<serviço>/**`:

1. **build-test** — `go test`/`pytest` com cobertura.
2. **lint** — `golangci-lint` (Go) ou `flake8` (Python).
3. **security** — Trivy *filesystem scan* (SCA/dependências) + `gosec`/`bandit` (SAST).
   Achados `CRITICAL` **bloqueiam** os jobs seguintes.
4. **docker** *(só em push na `main`)* — build da imagem, Trivy *image scan*
   (`CRITICAL` bloqueia o push), login no ECR, push com tag `v1.0.0-<sha7>` + `latest`.
5. **gitops-bump** — `kustomize edit set image` em `gitops/overlays/prod`, commit com
   `[skip ci]` e push na `main`.

O ArgoCD (instalado pelo Terraform, `sync automático` com `prune: true, selfHeal: true`)
detecta o novo commit em `gitops/overlays/prod` e aplica a mudança no cluster — nenhum
`kubectl apply` manual é necessário.

Workflow `terraform.yml`: `fmt`/`validate`/`tfsec`/`plan` em todo PR que toque `infra/`;
`apply` disponível via `workflow_dispatch` (aprovação manual, ambiente `production`).

---

## 🧪 Testes

- **auth-service** / **evaluation-service** (Go): `go test ./... -cover`
  (`key_test.go`, `evaluator_test.go`).
- **flag-service** / **targeting-service** / **analytics-service** (Python):
  `pytest` com mocks de banco (`psycopg2.pool`) e AWS (`boto3.Session`,
  `threading.Thread`), sem dependências externas reais.

```bash
# Go
cd services/auth-service && go test ./... -cover

# Python
cd services/flag-service && pip install -r requirements.txt -r requirements-dev.txt && pytest
```

---

## 📌 O que muda em relação à Fase 2

| Tema | Fase 2 | Fase 3 |
|---|---|---|
| Infraestrutura | AWS CLI manual | Terraform (backend S3, módulos reutilizáveis) |
| Deploy | `kubectl apply -f` manual | ArgoCD (GitOps), sync automático |
| Segredos | `secret.template.yaml` preenchido à mão | Terraform → Secrets Manager → K8s Secret |
| Qualidade | Nenhum teste/lint | Testes unitários + lint bloqueante no CI |
| Segurança | Nenhuma verificação | Trivy (SCA+imagem), gosec, bandit, tfsec bloqueantes |
| Imagens | Push manual (`docker push`) | CI builda, escaneia e publica no ECR |

---

## 🎬 Roteiro do vídeo de apresentação

Ver [`docs/ROTEIRO-VIDEO.md`](docs/ROTEIRO-VIDEO.md) para o roteiro completo
(até 20 minutos) usado na gravação da demonstração.

