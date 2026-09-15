############################################
# Módulo argocd: instala o ArgoCD via Helm no
# cluster EKS e registra uma Application que
# sincroniza automaticamente (self-heal + prune)
# os manifestos de gitops/overlays/prod.
############################################

terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
  }
}

# --- Credencial de acesso ao repositório GitOps (privado). O ArgoCD exige
# um Secret com o label `argocd.argoproj.io/secret-type: repository` para
# autenticar via HTTPS+token em repositórios privados. O token nunca é
# commitado: é passado como variável sensível (TF_VAR_gitops_repo_token ou
# -var na hora do apply). ---
resource "kubernetes_secret" "repo_credentials" {
  count = var.gitops_repo_token != "" ? 1 : 0

  metadata {
    name      = "repo-toggle-master-gitops"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.gitops_repo_url
    username = "x-access-token"
    password = var.gitops_repo_token
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Exposto via ClusterIP por padrão; acesso à UI é feito por
  # `kubectl port-forward` (documentado no README) para não depender de um
  # segundo Load Balancer/Ingress no cluster do Academy.
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
}

# --- Application do ArgoCD apontando para o repositório GitOps deste
# monorepo. Sync automático com self-heal (reverte drift manual) e prune
# (remove recursos removidos do Git) — implementa o requisito de GitOps. ---
# --- Application do ArgoCD apontando para o repositório GitOps deste
# monorepo. Sync automático com self-heal (reverte drift manual) e prune
# (remove recursos removidos do Git) — implementa o requisito de GitOps.
#
# Não usamos `kubernetes_manifest` porque ele precisa se conectar ao
# cluster durante o `plan` para validar o schema do CRD Application, o que
# falha no primeiro apply (quando o EKS ainda não existe, endpoint/CA são
# "known after apply"). Em vez disso, geramos o YAML com `local_file` e
# aplicamos via `kubectl apply` num `null_resource` (local-exec), que só
# roda em tempo de apply, quando o cluster já existe. ---
resource "local_file" "toggle_master_app" {
  filename = "${path.module}/.generated/${var.app_name}-application.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = var.app_name
      namespace = var.namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        path           = var.gitops_repo_path
        targetRevision = var.gitops_target_revision
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.destination_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  })
}

resource "null_resource" "apply_argocd_app" {
  triggers = {
    manifest_sha = sha256(local_file.toggle_master_app.content)
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      KCFG="${path.module}/.generated/kubeconfig-${var.cluster_name}"
      aws eks update-kubeconfig --region "${var.aws_region}" --name "${var.cluster_name}" --kubeconfig "$KCFG"
      kubectl --kubeconfig "$KCFG" apply -f "${local_file.toggle_master_app.filename}"
      rm -f "$KCFG"
    EOT
  }

  depends_on = [helm_release.argocd, local_file.toggle_master_app]
}
