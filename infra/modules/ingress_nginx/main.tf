############################################
# Módulo ingress_nginx: instala o ingress-nginx
# controller via Helm, expondo um Network Load
# Balancer (NLB) usado pelos dois Ingress do
# GitOps (toggle-ingress-rewrite/passthrough).
############################################

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
  namespace  = kubernetes_namespace.this.metadata[0].name

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # NLB (mais barato/rápido de provisionar no Academy que o Classic ELB
  # default do provider AWS legado).
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
}
