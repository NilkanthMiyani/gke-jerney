# Jerney — GKE Infrastructure (Terraform)

This directory provisions a **GKE Standard cluster** on Google Cloud Platform to run the Jerney 3-tier blog application, using a **flat Terraform layout** (`infra/` without nested modules) and **Terraform Workspaces** for environment isolation. This mirrors the `jerney-aks` / `jerney-eks` siblings.

Resource names below use the per-environment `<cluster>` prefix — `jerney-gke-dev`, `jerney-gke-stg`, or `jerney-gke-prod`. Best practice is to deploy each environment into a separate GCP project for complete isolation.

---

## What This Creates

| Resource | Type | Purpose |
|---|---|---|
| `<cluster>-vpc` | VPC Network | Isolated network for the cluster |
| `<cluster>-subnet` | Subnetwork | Node subnet + secondary ranges for pods/services |
| `<cluster>-router` & `nat` | Cloud Router/NAT | Outbound internet access for private nodes |
| `<cluster>-allow-web` | Firewall Rule | Opens 80/443 to the internet |
| `<cluster>-allow-health-checks` | Firewall Rule | GCP LB health check ranges (35.191.0.0/16, 130.211.0.0/22) |
| `<cluster>-nodes` SA | Service Account | Least-privilege identity for node VMs |
| `<cluster>` | GKE Standard Cluster | Private Cluster (internal IPs only) — single-zone (version pinned via `kubernetes_version`, default `1.35`) |
| `<cluster>-nodes` | Node Pool | Autoscaling node pool — sizing/machine type/Spot per environment (see Cost Strategy) |
| `<cluster>-eso` SA | Service Account | External Secrets Operator — reads GCP Secret Manager (Workload Identity) |
| `jerney-postgres-password` | Secret Manager Secret | PostgreSQL password (seeded by Terraform from tfvars) |
| `jerney-grafana-admin-password` | Secret Manager Secret | Grafana admin password (seeded by Terraform from tfvars) |
| `jerney-alertmanager-smtp-key` | Secret Manager Secret | Alertmanager SMTP key (seeded by Terraform from tfvars) |

> ArgoCD, the External Secrets Operator, and the `gcp-secret-manager` ClusterSecretStore are also created in-cluster by `bootstrap.tf`.

### IP Ranges

| Range | CIDR | Use |
|---|---|---|
| Node subnet | `10.0.0.0/24` | GCE VM IPs for nodes |
| Pod range | `10.100.0.0/14` | Pod IPs (VPC-native) |
| Service range | `10.104.0.0/20` | ClusterIP service IPs |

---

## Cost Strategy (Free Tier)

The **dev** environment is tuned to stay as cheap as possible while still running the full stack:

- **Single-zone cluster** (`us-central1-a`) — regional clusters run 3 control planes, ~3x the cost
- **Spot VMs** on the node pool (`use_spot = true`) — ~70% cheaper than on-demand; GCP can reclaim with 30s notice (acceptable for dev)
- **e2-medium** (2 vCPU, 4 GB), **autoscale 1–3** — minimum practical size for the full observability stack
- **pd-standard disk** — cheapest disk type, vs pd-ssd

Per-environment defaults (all overridable in `terraform.tfvars`):

| Setting | dev | staging | prod |
|---|---|---|---|
| `kubernetes_version` | 1.35 | 1.35 | 1.35 |
| `node_machine_type` | e2-medium | e2-medium | e2-standard-2 |
| `min_node_count` / `max_node_count` | 1 / 3 | 1 / 4 | 2 / 5 |
| `disk_size_gb` | 30 | 30 | 50 |
| `use_spot` | true | false | false |
| `deletion_protection` | false | false | true |

> **Note:** GKE Standard has a cluster management fee of ~$0.10/hr (~$72/month). GCP's $300 free trial credit covers this for several months. If you want zero management fee, GKE Autopilot charges per pod instead.

---

## Project Architecture

```
Internet
    |
    v
+-----------------------------------------------------+
|  GCP (us-central1-a)                                |
|                                                     |
|  +--------------- <cluster>-vpc -----------------+  |
|  |                                               |  |
|  |  GKE Standard Cluster: <cluster> (K8s 1.35)   |  |
|  |  +-------------------------------------------+   |
|  |  |  Private Node Pool (autoscaling)          |   |
|  |  |                                           |   |
|  |  |  Namespace: ingress-nginx                 |   |
|  |  |    nginx controller (L4 LB) :80 :443      |   |
|  |  |  Namespace: cert-manager                  |   |
|  |  |    Let's Encrypt TLS (HTTP-01)            |   |
|  |  |         |                                 |   |
|  |  |  Namespace: jerney                        |   |
|  |  |    frontend (React)                       |   |
|  |  |    backend  (Node.js + /metrics)          |   |
|  |  |    postgresql (Bitnami chart)             |   |
|  |  |                                           |   |
|  |  |  Namespace: argocd                        |   |
|  |  |    ArgoCD  -- watches k8s-gke/apps/       |   |
|  |  |                                           |   |
|  |  |  Namespace: monitoring                    |   |
|  |  |    Prometheus  (scrapes /metrics, 15d)    |   |
|  |  |    Alertmanager (email via Resend SMTP)   |   |
|  |  |    Grafana     (dashboards + Loki)        |   |
|  |  |    Loki + Promtail (log aggregation)      |   |
|  |  |                                           |   |
|  |  |  Namespace: external-secrets              |   |
|  |  |    ESO  --[Workload Identity]-->          |   |
|  |  +-------------------------------------------+   |
|  |                        |                      |  |
|  |              GCP Secret Manager               |  |
|  |              (jerney-eso SA)                  |  |
|  +-----------------------------------------------+  |
|          | (egress via Cloud NAT)                   |
|  Cloud Router + Cloud NAT                           |
+-----------------------------------------------------+
```

---

## Full Deployment Flow

```
1. terraform apply        -- from infra/ (using workspaces):
                             networking.tf    -> VPC, subnet, firewall
                             iam.tf           -> node SA + jerney-eso SA + WI binding
                             secrets.tf       -> seeds Secret Manager from tfvars
                             gke-cluster.tf   -> GKE cluster + node pool
                             bootstrap.tf     -> installs ArgoCD + ESO (Helm),
                                                 ClusterSecretStore, and root-app

2. ArgoCD syncs
   wave 0: ingress-nginx     -- nginx controller (provisions an L4 LoadBalancer)
   wave 0: cert-manager      -- installs cert-manager + CRDs
   wave 1: platform-secrets  -- ExternalSecrets (the ClusterSecretStore is created
                                by Terraform); K8s Secrets appear in jerney + monitoring
   wave 1: prometheus-stack, jerney, signoz
                             -- apps read secrets via existingSecret refs
   wave 2: loki-stack        -- Loki + Promtail (log aggregation)
   wave 2: ingress-apps      -- letsencrypt-prod ClusterIssuer + Ingresses
                                (cert-manager issues Let's Encrypt certs)

3. CircleCI pipeline      -- on every git push to main:
   (on code push)            lint -> sca -> build -> image-scan
                             -> update-manifest (bumps image tag in values.yaml)

4. ArgoCD detects diff    -- polls GitHub every 3min, sees new image tag,
   in values.yaml            triggers rolling update

5. Prometheus scrapes     -- reads pod annotations:
   /metrics                  prometheus.io/scrape: "true"
                             prometheus.io/port: "5000"

6. Grafana shows          -- kube-prometheus-stack dashboards +
   metrics + logs            Loki + Alertmanager data sources

7. Alertmanager emails    -- fires on alert rules defined in prometheus-stack
   on alert                  values.yaml; sends via Resend SMTP (port 587)
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Terraform | ~> 1.5 | `brew install terraform` |
| gcloud CLI | latest | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |
| kubectl | >= 1.28 | `gcloud components install kubectl` |
| helm | >= 3.12 | `brew install helm` |
| argocd CLI | latest | `brew install argocd` |

---

## Usage

### 1. Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
```

### 2. Create the Terraform state bucket

The state bucket is managed by its own small Terraform config in `infra/bootstrap/`
(uses local state intentionally -- it's the prerequisite that makes remote state possible):

```bash
cd infra/bootstrap/

# Set project_id and state_bucket_name in terraform.tfvars, then:
terraform init
terraform apply
```

Copy the output bucket name into the backend block in
`infra/versions.tf` (the `prefix` is automatically managed by Terraform workspaces):
```hcl
backend "gcs" {
  bucket = "<output-bucket-name>"
  prefix = "jerney-gke/state"
}
```

### 3. TLS certificates (automatic via cert-manager)

No manual cert step is needed. The `cert-manager` app (ArgoCD wave 0) plus the
`letsencrypt-prod` ClusterIssuer issue a Let's Encrypt certificate per host
automatically once each Ingress is created and DNS resolves to the nginx LB IP
(HTTP-01 challenge). Certs land as Kubernetes TLS secrets (`jerney-tls`,
`argocd-tls`, `grafana-tls`, `signoz-tls`) and renew on their own.

> Verify after DNS is pointed at the nginx LB:
> `kubectl get certificate -A` — wait until each shows `READY=True`.

### 4. Set your project ID

Pick an environment (e.g. `dev`, `staging`, or `prod`) and
edit its `<env>.tfvars` (copy from `<env>.tfvars.example`):
```hcl
project_id = "your-actual-project-id"
```

### 5. Apply

```bash
cd infra/

terraform init
terraform workspace new dev
terraform workspace select dev

terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

Apply takes ~5-10 minutes (mostly GKE control plane provisioning). Each environment
keeps its own state (separate `prefix` in the GCS backend) and its own cluster.

### 6. Secrets (seeded by Terraform from tfvars)

No manual step is needed. Set the three secret values in `terraform.tfvars`:

```hcl
postgres_password      = "..."
grafana_admin_password = "..."
alertmanager_smtp_key  = "re_..."   # Resend API key
```

`terraform apply` writes them into GCP Secret Manager
(`jerney-postgres-password`, `jerney-grafana-admin-password`,
`jerney-alertmanager-smtp-key`), and ESO syncs them into Kubernetes Secrets.

> These variables are marked `sensitive`, so they are redacted from plan/apply
> output — but, as with any Terraform-managed secret, the values are stored in
> the state file. Keep the state bucket private (it already is). To rotate later,
> update the value in `terraform.tfvars` and re-apply (creates a new secret version).

### 7. Configure kubectl (optional -- for manual inspection)

Copy the command from Terraform output:
```bash
terraform output kubectl_config_command
# -> gcloud container clusters get-credentials jerney-gke-dev --zone us-central1-a --project <your-project>
```

Run it, then verify:
```bash
kubectl get nodes
```

> ArgoCD, ESO, the ClusterSecretStore, and the root app-of-apps are all applied
> automatically by `terraform apply` (the `argocd-bootstrap` module) -- no post-setup script needed.

### 8. Point DNS at the nginx LoadBalancer

Once the `ingress-nginx` app is synced, grab the external IP of its Service and create
A records for each host so cert-manager can complete the HTTP-01 challenge:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Create A records (or a single `*.nilkanthprojects.site` wildcard) pointing at that IP:
`jerney`, `argocd`, `grafana`, `signoz` `.nilkanthprojects.site`. Then watch the certs:

```bash
kubectl get certificate -A   # each should reach READY=True
```

---

## Differences vs terraform-ec2

| | terraform-ec2 | terraform-gke |
|---|---|---|
| Kubernetes | kubeadm (self-managed) | GKE Standard (managed control plane) |
| Nodes | Single EC2 t3.large | Autoscaling node pool (dev: Spot e2-medium 1–3; prod: e2-standard-2 2–5) |
| Control plane | Your responsibility | Google's responsibility |
| Cluster upgrades | Manual kubeadm upgrade | GKE auto-upgrade |
| Setup time | ~20 min (userdata.sh) | ~10 min (terraform apply) |
| Node failure | Manual intervention | GKE auto-repair replaces node |
| Secret management | Manual kubectl create secret | GCP Secret Manager + ESO |
| Cost | ~$50-60/month (t3.large) | ~$15-25/month (spot e2-medium + mgmt fee) |

---

## Tear Down

The nginx ingress controller is a Service of type LoadBalancer, so GKE creates a
forwarding rule + target pool for it. ArgoCD prunes the Service (and its LB) when the
`ingress-nginx` app is deleted; if you destroy Terraform first, delete the app via
ArgoCD (or `kubectl delete svc -n ingress-nginx`) so the LB is released cleanly:

```bash
# Confirm no leftover LB forwarding rules before/after destroy
gcloud compute forwarding-rules list --filter="name:a"
```

Then destroy Terraform-managed resources:

```bash
terraform destroy
```

This deletes the cluster, VPC, firewall rules, service accounts, and Secret Manager secrets.
**Warning:** All workloads and persistent volumes will be deleted.

---

## File Structure

```
infra/
├── bootstrap/            # run first -- creates the GCS bucket for remote state
│   ├── main.tf
│   └── terraform.tfvars
├── networking.tf         # VPC, VPC-native subnet (pods/services ranges), firewall rules
├── gke-cluster.tf        # GKE Standard cluster + managed node pool
├── iam.tf                # node SA + jerney-eso SA, IAM roles, Workload Identity binding
├── secrets.tf            # GCP Secret Manager secrets (map-driven)
├── bootstrap.tf          # ArgoCD + ESO (Helm), gcpsm ClusterSecretStore, root app-of-apps
├── variables.tf          # input variables (dev defaults: spot on, e2-medium)
├── outputs.tf            # cluster endpoint, kubectl command, service accounts
├── locals.tf             # secrets local map
├── providers.tf          # provider configs
├── versions.tf           # backend config
├── dev.tfvars.example
├── staging.tfvars.example
├── prod.tfvars.example
└── README.md             # this file

k8s-gke/
├── apps/
│   ├── base/
│   │   ├── ingress-nginx.yaml      # wave 0 -- nginx ingress controller (L4 LoadBalancer)
│   │   ├── cert-manager.yaml       # wave 0 -- cert-manager (Let's Encrypt TLS)
│   │   ├── platform-secrets.yaml   # wave 1 -- ExternalSecrets (store created by Terraform)
│   │   ├── prometheus-stack.yaml   # wave 1 -- kube-prometheus-stack (multi-source)
│   │   ├── jerney.yaml             # wave 1 -- app Helm chart (incl. nginx Ingress)
│   │   ├── signoz.yaml             # wave 1 -- SigNoz tracing
│   │   ├── loki-stack.yaml         # wave 2 -- Loki + Promtail
│   │   ├── ingress-apps.yaml       # wave 2 -- ClusterIssuer + platform Ingresses
│   │   └── kustomization.yaml
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── jerney-patch.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── jerney-patch.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── jerney-patch.yaml
└── platform/
    ├── external-secrets/
    │   └── external-secrets.yaml      # 3 ExternalSecrets (DB, Grafana, SMTP key)
    ├── prometheus-stack/
    │   └── values.yaml                # Grafana, Alertmanager, Prometheus config
    ├── loki-stack/
    │   └── values.yaml
    └── ingress/
        ├── cluster-issuer.yaml        # letsencrypt-prod ClusterIssuer (HTTP-01)
        └── ingresses.yaml             # argocd + grafana + signoz Ingresses
```
