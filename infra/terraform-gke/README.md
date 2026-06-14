# Jerney — GKE Infrastructure (Terraform)

This directory provisions a **GKE Standard cluster** on Google Cloud Platform to run the Jerney 3-tier blog application.

---

## What This Creates

| Resource | Type | Purpose |
|---|---|---|
| `jerney-gke-vpc` | VPC Network | Isolated network for the cluster |
| `jerney-gke-subnet` | Subnetwork | Node subnet + secondary ranges for pods/services |
| `jerney-gke-allow-web` | Firewall Rule | Opens 80/443 to the internet |
| `jerney-gke-allow-health-checks` | Firewall Rule | GCP LB health check ranges (35.191.0.0/16, 130.211.0.0/22) |
| `jerney-gke-nodes` SA | Service Account | Least-privilege identity for node VMs |
| `jerney-gke` | GKE Standard Cluster | Single-zone managed Kubernetes |
| `jerney-gke-nodes` | Node Pool | Spot e2-medium nodes, autoscales 1–5 |
| `jerney-eso` SA | Service Account | External Secrets Operator — reads GCP Secret Manager |
| `jerney-postgres-password` | Secret Manager Secret | PostgreSQL password (value seeded via gcloud) |
| `jerney-grafana-admin-password` | Secret Manager Secret | Grafana admin password (value seeded via gcloud) |
| `jerney-alertmanager-smtp-key` | Secret Manager Secret | Alertmanager SMTP key (value seeded via gcloud) |

### IP Ranges

| Range | CIDR | Use |
|---|---|---|
| Node subnet | `10.0.0.0/24` | GCE VM IPs for nodes |
| Pod range | `10.100.0.0/14` | Pod IPs (VPC-native) |
| Service range | `10.104.0.0/20` | ClusterIP service IPs |

---

## Cost Strategy (Free Tier)

This config is designed to stay as cheap as possible while still running the full stack:

- **Single-zone cluster** (`us-central1-a`) — regional clusters run 3 control planes, ~3x the cost
- **Spot VMs** on node pool — ~70% cheaper than on-demand; GCP can reclaim with 30s notice (acceptable for dev)
- **e2-medium** (2 vCPU, 4 GB) — minimum practical size for running the full observability stack
- **1 node minimum** — scales to zero when idle; GKE auto-repairs if spot is preempted
- **pd-standard disk** — cheapest disk type, vs pd-ssd

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
|  +--------------- jerney-gke-vpc ----------------+  |
|  |                                               |  |
|  |  GKE Standard Cluster: jerney-gke             |  |
|  |  +-------------------------------------------+   |
|  |  |  Node Pool (Spot e2-medium, 1-5)          |   |
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
+-----------------------------------------------------+
```

---

## Full Deployment Flow

```
1. terraform apply        -- provisions GKE cluster + VPC (main.tf)
                             seeds Secret Manager values from terraform.tfvars
                             creates jerney-eso SA + Workload Identity binding
                             installs ArgoCD via Helm (bootstrap.tf)
                             applies root-app.yaml via kubectl_manifest

2. ArgoCD syncs
   wave 0: external-secrets  -- installs ESO from Helm chart
   wave 0: ingress-nginx     -- nginx controller (provisions an L4 LoadBalancer)
   wave 0: cert-manager      -- installs cert-manager + CRDs
   wave 1: platform-secrets  -- ClusterSecretStore + ExternalSecrets
                                K8s Secrets appear in jerney + monitoring
   wave 1: prometheus-stack, jerney, loki-stack
                             -- apps read secrets via existingSecret refs
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

Copy the output bucket name into the backend block in `infra/terraform-gke/versions.tf`:
```hcl
backend "gcs" {
  bucket = "<output-bucket-name>"
  prefix = "terraform/state"
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

Edit `terraform.tfvars` (copy from `terraform.tfvars.example`):
```hcl
project_id = "your-actual-project-id"
```

### 5. Apply

```bash
cd terraform-gke/

terraform init
terraform plan
terraform apply
```

Apply takes ~5-10 minutes (mostly GKE control plane provisioning).

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
# -> gcloud container clusters get-credentials jerney-gke --zone us-central1-a --project <your-project>
```

Run it, then verify:
```bash
kubectl get nodes
```

> ArgoCD and the root app-of-apps are applied automatically by `terraform apply` via `bootstrap.tf` -- no post-setup script needed.

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
| Nodes | Single EC2 t3.large | Spot e2-medium, autoscales 1-5 |
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
+-- bootstrap/            # run first -- creates the GCS bucket for remote state
|   +-- main.tf           # google_storage_bucket with versioning (local state intentional)
|   +-- terraform.tfvars  # set project_id + state_bucket_name here
|
+-- terraform-gke/        # main cluster config (run after bootstrap)
    +-- versions.tf       # terraform block (~> 1.5), required_providers (google, helm, kubectl)
    +-- main.tf           # VPC, subnet, firewall, GKE cluster + node pool,
    |                     # ESO service account, IAM bindings, Secret Manager secrets
    +-- bootstrap.tf      # ArgoCD Helm release + root app-of-apps (kubectl_manifest)
    +-- variables.tf      # all input variables with descriptions
    +-- outputs.tf        # cluster endpoint, kubectl command, service account
    +-- terraform.tfvars  # your values (set project_id here)
    +-- README.md         # this file

k8s-gke/
+-- apps/
|   +-- root-app.yaml           # ArgoCD App-of-Apps (bootstrapped by Terraform)
|   +-- ingress-nginx.yaml      # wave 0 -- nginx ingress controller (L4 LoadBalancer)
|   +-- cert-manager.yaml       # wave 0 -- cert-manager (Let's Encrypt TLS)
|   +-- external-secrets.yaml   # wave 0 -- installs ESO from Helm chart
|   +-- platform-secrets.yaml   # wave 1 -- ClusterSecretStore + ExternalSecrets
|   +-- prometheus-stack.yaml   # wave 1 -- kube-prometheus-stack (multi-source)
|   +-- jerney.yaml             # wave 1 -- app Helm chart (incl. nginx Ingress)
|   +-- loki-stack.yaml         # wave 1 -- Loki + Promtail
|   +-- ingress-apps.yaml       # wave 2 -- ClusterIssuer + platform Ingresses
+-- platform/
    +-- external-secrets/
    |   +-- cluster-secret-store.yaml  # ClusterSecretStore -> GCP Secret Manager
    |   +-- external-secrets.yaml      # 3 ExternalSecrets (DB, Grafana, SMTP key)
    +-- prometheus-stack/
    |   +-- values.yaml                # Grafana, Alertmanager, Prometheus config
    +-- loki-stack/
    |   +-- values.yaml
    +-- ingress/
        +-- cluster-issuer.yaml        # letsencrypt-prod ClusterIssuer (HTTP-01)
        +-- ingresses.yaml             # argocd + grafana + signoz Ingresses
```
