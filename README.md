# Self-Healing AWS Infrastructure with Chaos Engineering

A production-style, cost-conscious AWS/Kubernetes platform that detects failures, notifies on-call, and automatically remediates them — built end-to-end with Terraform, k3s, Prometheus/Grafana/Alertmanager, AWS Lambda, SSM, and a full CI/CD pipeline to ECR.

This isn't a tutorial clone. It's infrastructure I designed, broke (on purpose and by accident), diagnosed, and fixed — with a real incident history to show for it. See [ARTICLE.md](./ARTICLE.md) *(or link to published post)* for the full write-up of what broke and why.

---

## Table of Contents
- [Architecture](#architecture)
- [Why These Choices](#why-these-choices)
- [Tech Stack](#tech-stack)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Running This Yourself](#running-this-yourself)
- [Chaos Engineering Results](#chaos-engineering-results)
- [Known Limitations](#known-limitations)
- [Cost](#cost)
- [What I'd Do Differently at Scale](#what-id-do-differently-at-scale)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                              AWS (eu-west-1)                        │
│                                                                       │
│   GitHub Actions (OIDC, no static keys)                              │
│        │                                                             │
│        ├─► build image ──► ECR (healthcheck-app, tagged by SHA)      │
│        │                                                             │
│        └─► SSM SendCommand ──► EC2 instance: "kubectl set image"     │
│                                        │                              │
│                                        ▼                              │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  VPC (10.0.0.0/16) — public subnet, no NAT Gateway           │   │
│   │                                                               │   │
│   │   EC2 (t3.medium, 20GB gp3) running k3s                     │   │
│   │   ├── healthcheck-app (2 replicas, Flask, NodePort 30080)    │   │
│   │   ├── Prometheus (NodePort 30320) — scrapes metrics          │   │
│   │   ├── Grafana (NodePort 30310) — dashboards                 │   │
│   │   ├── Alertmanager (NodePort 30330) — routes alerts          │   │
│   │   └── node-exporter / kube-state-metrics                    │   │
│   │                                                               │   │
│   │   Security Group: SSH + K8s API + all NodePorts              │   │
│   │   restricted to operator's IP only                           │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                        │                              │
│              Alertmanager fires ───────┤                              │
│                                        ▼                              │
│              ┌─────────────────────────────────────┐                 │
│              │  Lambda: alert-notifier               │                │
│              │  → publishes to SNS → email            │                │
│              └─────────────────────────────────────┘                 │
│                                        │                              │
│              ┌─────────────────────────────────────┐                 │
│              │  Lambda: alert-remediator              │                │
│              │  → SSM SendCommand → kubectl rollout   │                │
│              │    restart (auto-remediation)          │                │
│              └─────────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────────┘
```

**The detect → notify → remediate loop:**
1. Prometheus scrapes metrics every 15–30s
2. A `PrometheusRule` evaluates `increase(kube_pod_container_status_restarts_total[15m]) > 3` for 5 minutes
3. Alertmanager receives the fired alert and routes it to **two** webhook receivers simultaneously (`continue: true`)
4. **Notifier Lambda** → SNS → email
5. **Remediator Lambda** → SSM → runs `kubectl rollout restart` directly on the node (no inbound ports opened — SSM polls outbound only)

---

## Why These Choices

| Decision | Reasoning |
|---|---|
| **k3s instead of EKS** | EKS control plane costs ~$73/month minimum. k3s is genuinely production-used (edge/IoT), gives real Kubernetes primitives, and runs free-tier-adjacent. Tradeoff: lost EKS's built-in ECR credential provider (see [Known Limitations](#known-limitations)). |
| **No NAT Gateway** | ~$33/month for something unused in a single-node teaching environment. Public subnet + strict security group scoping to one IP instead. |
| **SSM instead of opening the K8s API to Lambda** | Lambda can't reach a security-group-restricted port. Opening 6443 to Lambda's IP ranges is impractical and insecure. SSM's agent polls *outbound* — zero new inbound rules needed. |
| **OIDC instead of static IAM access keys for GitHub Actions** | No long-lived secret sitting in GitHub. Each run gets a token valid ~1 hour, scoped to this exact repo via the `sub` claim condition. |
| **NodePort instead of Ingress/LoadBalancer** | Single-node cluster, no need for the complexity (or in LoadBalancer's case, the cost) of a full ingress layer yet. |
| **Images tagged by git commit SHA, not `latest`** | Any running container can be traced back to the exact commit that built it. |

---

## Tech Stack

**Infrastructure:** Terraform (AWS provider, remote S3 state, native S3 locking)
**Compute:** AWS EC2, k3s (lightweight Kubernetes)
**Containers:** Docker, containerd
**Observability:** Prometheus, Grafana, Alertmanager (via `kube-prometheus-stack` Helm chart)
**Serverless:** AWS Lambda (Python), AWS SNS, AWS SSM
**Registry:** AWS ECR
**CI/CD:** GitHub Actions, OIDC federation
**App:** Python / Flask (minimal, intentionally — infrastructure is the point)

---

## Features

- ✅ Fully declarative infrastructure (zero manual console clicks)
- ✅ Real-time metrics, dashboards, and alerting
- ✅ Automated incident detection and remediation with zero human intervention
- ✅ CI/CD pipeline: commit → build → push to ECR → deploy, fully automated
- ✅ Least-privilege IAM throughout (every role scoped to exactly what it needs)
- ✅ Chaos-tested: crash-loop, CPU exhaustion, and disk-pressure scenarios run deliberately against the live system
- ✅ Cost-conscious by design: destroyable/resumable infra, ~$0–2/day in active use

---

## Repository Structure

```
.
├── providers.tf                  # Terraform/AWS provider config, default tags
├── backend.tf                    # S3 remote state config
├── vpc.tf                        # VPC, subnet, IGW, routing
├── security_groups.tf            # All ingress/egress rules (least-privilege)
├── ec2.tf                        # EC2 instance, SSM IAM role/profile
├── ecr.tf                        # ECR repository
├── sns.tf                        # SNS topic + email subscription
├── lambda.tf                     # Both Lambdas, their IAM roles, Function URLs
├── github-oidc.tf                # OIDC provider + GitHub Actions IAM role
├── variables.tf / outputs.tf
├── terraform.tfvars.example      # Template for required variables
├── lambda/
│   ├── notify.py                 # Alert → SNS
│   └── remediate.py              # Alert → SSM → kubectl rollout restart
├── app.py / Dockerfile / requirements.txt   # Health-check app
├── deployment.yaml / service.yaml           # K8s manifests
├── healthcheck-alerts.yaml       # PrometheusRule (PodCrashLooping)
├── monitoring-values.yaml        # Helm values for kube-prometheus-stack
└── .github/workflows/
    └── build-and-push.yml        # CI/CD: build → ECR → SSM deploy
```

---

## Running This Yourself

**Prerequisites:** AWS CLI configured, Terraform ≥1.5, an SSH key pair, your public IP.

```bash
git clone https://github.com/GeorgeEliWilliams/self-healing-aws-infra.git
cd self-healing-aws-infra

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: your_ip, alerts_email

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

SSH in, set up `kubectl`/Helm, install the monitoring stack, and deploy the app — full step-by-step commands in [ARTICLE.md](./ARTICLE.md).

**Teardown (important — avoid ongoing cost):**
```bash
terraform destroy
```

---

## Chaos Engineering Results

Three deliberate failure scenarios were run against the live system:

1. **Pod crash-loop** — Full pipeline verified: detection → dual notification → automated SSM-triggered restart, all with zero manual intervention. Timeline reconstructed from Prometheus's `for: 5m` window and Kubernetes' exponential backoff curve (~7–9 min total, detect to remediation attempt).
2. **CPU exhaustion** — Confirmed a real gap: pure CPU contention doesn't crash a pod, and the current alerting (restart-count based) doesn't catch it at all. Only visible via Grafana/node-exporter dashboards — a deliberate finding, not an oversight, documented as future work.
3. **Disk pressure** — Discovered a flaw in the original test design (accidentally filled a RAM-backed `tmpfs` instead of the root EBS volume) and a genuine, disruptive side effect: a full small filesystem blocked unrelated shell commands system-wide, a more interesting result than the original intended test.

Full incident timelines and reasoning in [ARTICLE.md](./ARTICLE.md).

---

## Known Limitations

- **k3s lacks EKS's built-in ECR credential provider.** EKS nodes authenticate to ECR automatically via IAM role with no configuration. k3s requires manually maintaining `/etc/rancher/k3s/registries.yaml` with a token that expires every ~12 hours — solved here with a refresh script, not yet automated via cron (documented as a next step).
- **Single-node cluster** — no high availability. A real production deployment would run multi-node k3s/RKE2 or EKS.
- **ECR tag mutability is `MUTABLE`** — chosen for learning simplicity. Production should use `IMMUTABLE` to prevent accidental tag overwrites (mitigated here in practice by always tagging with the git commit SHA).
- **No automated disk-pressure alerting** — the CPU/disk chaos tests exposed real gaps in current alert coverage; only crash-loop detection is implemented.
- **Lambda Function URLs use `authorization_type = "NONE"`** — a deliberate tradeoff since Alertmanager can't sign AWS requests; access control instead relies on the URL being unguessable (128-bit random subdomain) plus scoped resource policies.

---

## Cost

Built to be destroyed/resumed rather than left running:
- **EC2 (t3.medium)**: ~$0.0416/hr → stopped between sessions
- **EBS (20GB gp3)**: ~$1.60/month if left provisioned
- **Lambda, SNS, SSM**: effectively free at this usage volume
- **ECR storage**: pennies for a single small image
- **No NAT Gateway, no Load Balancer, no managed EKS control plane**

Realistic cost for active development: **under $2 for the entire build.**

---

## What I'd Do Differently at Scale

- Multi-node cluster (k3s HA or migrate to EKS) for real redundancy
- `IMMUTABLE` ECR tags as the hard default, not just a convention
- Automated ECR token refresh via cron/systemd timer, baked into `user_data`
- CPU/memory/disk-pressure alerting to close the gaps chaos testing exposed
- Ingress controller instead of per-service NodePorts as the service count grows
- Lambda Function URLs behind IAM auth instead of `NONE`, with a signing-capable caller in front of Alertmanager

---

*Built by George Williams as part of a self-directed DevOps/Cloud portfolio project. No tutorials were cloned in the making of this repository — every bug was real.*
