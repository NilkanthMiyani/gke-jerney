# ==============================================================
# Module: argocd-bootstrap
#
# In-cluster bootstrap, applied by Terraform via the helm + kubectl
# providers (configured in the environment composition and inherited here):
#   1. ArgoCD             (Helm)
#   2. ESO                (Helm — installed by TF so its CRDs exist
#                          before the ClusterSecretStore below)
#   3. ClusterSecretStore (GCP Secret Manager, via the ESO CRD)
#   4. Root App-of-Apps   (ArgoCD then syncs everything else from Git)
#
# The root Application is rendered from gitops_* variables so each
# environment can track its own branch/path without committing   a
# different YAML file per env.
# ==============================================================



# ---- 1. ArgoCD ----
resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    # ArgoCD server runs without TLS — the nginx Ingress + cert-manager terminate TLS.
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "configs.cm.application\\.instanceLabelKey"
    value = "argocd.argoproj.io/instance"
  }
}

# ---- 2. External Secrets Operator ----
# Installed by Terraform (not GitOps) so its CRDs exist before the
# ClusterSecretStore below is applied.
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.eso_chart_version
  namespace        = var.eso_namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  # Workload Identity: bind the ESO k8s ServiceAccount to the GCP service account.
  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = google_service_account.eso.email
  }
}

# ---- 3. ClusterSecretStore (GCP Secret Manager) ----
# Uses a local Helm chart instead of kubernetes_manifest because the Helm
# provider does NOT validate CRDs at plan time — so this works on the very
# first `terraform apply` against a brand-new cluster (the ESO CRDs are
# installed by step 2 above, which runs before this with depends_on).
resource "helm_release" "eso_cluster_secret_store" {
  name      = "eso-cluster-store"
  chart     = "${path.module}/charts/cluster-secret-store"
  namespace = var.eso_namespace

  set {
    name  = "projectID"
    value = var.project_id
  }

  set {
    name  = "storeName"
    value = var.secret_store_name
  }

  depends_on = [helm_release.external_secrets]
}

# ---- 4. Root App-of-Apps (via argocd-apps chart) ----
resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  version          = var.argocd_apps_chart_version
  namespace        = "argocd"
  create_namespace = false

  values = [
    yamlencode({
      applications = {
        platform = {
          namespace = "argocd"
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
          project = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = var.gitops_target_revision
            path           = var.gitops_apps_path
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}
