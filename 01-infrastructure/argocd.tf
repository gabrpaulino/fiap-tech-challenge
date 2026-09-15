resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"

  values = [yamlencode({
    server = {
      service = { type = "ClusterIP" }
    }
  })]

  wait       = true
  timeout    = 900
  depends_on = [module.eks]
}
