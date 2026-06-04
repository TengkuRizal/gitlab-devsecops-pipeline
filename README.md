# gitlab-devsecops-pipeline

A production-style DevSecOps CI/CD pipeline built on self-hosted GitLab CE, deploying to a 3-node Kubernetes cluster via GitOps with ArgoCD. Security is enforced at every stage — from secret scanning and SAST through to admission control at the Kubernetes level.

[![Pipeline](https://img.shields.io/badge/GitLab-CI%2FCD-FC6D26?logo=gitlab)](https://gitlab.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Deployment-326CE5?logo=kubernetes)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo)](https://argoproj.github.io)
[![Kyverno](https://img.shields.io/badge/Policy-Kyverno-00B2B2)](https://kyverno.io)
[![Trivy](https://img.shields.io/badge/Trivy-Image%20%26%20Config%20Scan-blue)](https://trivy.dev)

---

## Overview

This project implements a 9-stage DevSecOps pipeline that validates, scans, builds, and deploys a containerised workload to Kubernetes using a GitOps pattern. Security checks are shifted left into the CI/CD workflow, and deployment is enforced through policy-as-code at the admission controller level.

The pipeline runs on self-hosted GitLab CE and GitLab Runner in a segmented homelab environment. ArgoCD manages deployment by watching a GitHub repository for manifest changes — the pipeline updates the image tag in Git, and ArgoCD reconciles the cluster state.

---

## Problem Statement

Traditional CI/CD pipelines focus only on build and deploy. Security is often bolted on after the fact, leading to:

- Secrets committed into repositories
- Vulnerable dependencies entering production
- Insecure Kubernetes manifests
- Container images with known CVEs deployed without scanning
- No supply chain visibility
- No policy enforcement at the cluster level

This project addresses all of these by integrating security gates directly into the delivery pipeline and enforcing policy at every layer.

---

## Architecture

```
Developer Push
      |
GitLab CE (self-hosted)
      |
9-Stage CI/CD Pipeline
      |
      |-- Stage 1: Validate K8s manifests (kubectl dry-run)
      |-- Stage 2: Secret scan (Gitleaks)
      |-- Stage 3: SAST (Semgrep)
      |-- Stage 4: IaC config scan (Trivy)
      |-- Stage 5: Build + push image to GitLab Registry
      |-- Stage 6: Generate SBOM (Syft)
      |-- Stage 7: Image vulnerability scan (Trivy)
      |-- Stage 8: GitOps deploy
      |        |
      |        |-- Update deployment.yaml in GitLab CE repo
      |        |-- Update deployment.yaml in GitHub repo
      |
      ArgoCD detects GitHub change
      |
      Kyverno admission control
      |-- disallow-latest-image-tag (Enforce)
      |-- disallow-privileged-containers (Enforce)
      |-- require-approved-registry (Enforce)
      |
      Kubernetes rolling update
      |
      Stage 9: Verify
               |-- ArgoCD sync status check
               |-- HTTP 200 smoke test
```

---

## Pipeline Stages

| Stage | Tool | Purpose |
|---|---|---|
| validate | kubectl | Dry-run K8s manifest validation before deployment |
| secret-scan | Gitleaks | Detect secrets, tokens, and credentials in source code |
| sast | Semgrep | Static analysis for insecure code patterns |
| config-scan | Trivy | Kubernetes manifest misconfiguration detection |
| build-image | Docker | Build and push image to private GitLab Registry |
| sbom | Syft | Generate Software Bill of Materials (CycloneDX) |
| image-scan | Trivy | CVE scanning of built container image |
| deploy | Git + ArgoCD | Update image tag in Git, ArgoCD reconciles cluster |
| verify | kubectl + curl | Confirm ArgoCD sync, pod health, and HTTP 200 |

---

## GitOps Deployment Flow

This pipeline uses a pull-based GitOps pattern. The CI pipeline does not run `kubectl apply` directly. Instead:

1. Pipeline builds and pushes image with commit SHA tag
2. Pipeline updates `deployment.yaml` with new image tag via `sed`
3. Updated manifest is committed and pushed to GitHub
4. ArgoCD detects the change and syncs the cluster
5. Kyverno validates the deployment at admission time
6. Verify stage confirms sync status and application health

This approach separates CI (build, scan, test) from CD (deploy, reconcile), which is a more reliable and auditable pattern for production environments.

---

## Security Controls

| Control | Tool | Enforcement |
|---|---|---|
| Secret detection | Gitleaks | Pipeline gate — blocks on findings |
| Static code analysis | Semgrep | Pipeline gate |
| IaC misconfiguration | Trivy | Pipeline gate |
| Container CVE scanning | Trivy | Pipeline gate — HIGH and CRITICAL |
| SBOM generation | Syft | CycloneDX format, committed as artifact |
| No latest image tag | Kyverno | Enforce — blocks deployment |
| No privileged containers | Kyverno | Enforce — blocks deployment |
| Approved registry only | Kyverno | Enforce — only GitLab Registry permitted |
| Image tag pinning | CI variable | Commit SHA used as image tag |
| Credential protection | GitLab CI variables | No secrets in code or YAML |

---

## Kubernetes Security Context

All workloads deployed through this pipeline use a hardened security context:

```yaml
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
```

Resource limits, readiness probes, and liveness probes are applied to all containers.

---

## Kyverno Policy Enforcement Evidence

Attempting to deploy an image from an external registry or with a `:latest` tag is blocked at the admission controller:

```
$ kubectl run test --image=nginx:latest -n demo
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/demo/test was blocked due to the following policies
disallow-latest-image-tag:
  require-explicit-image-tag: 'validation failure: Images must use an explicit non-latest tag.'
require-approved-registry:
  only-gitlab-registry: 'validation error: Container images must come from approved
    GitLab Registry 10.10.1.101:5050.'
```

Full evidence: [evidence/kubernetes/kyverno-policy-enforcement.txt](evidence/kubernetes/kyverno-policy-enforcement.txt)

---

## Repository Structure

```
gitlab-devsecops-pipeline/
├── .gitlab-ci.yml                        # 9-stage pipeline definition
├── Dockerfile                            # nginx-unprivileged hardened image
├── k8s/
│   ├── deployment.yaml                   # K8s deployment manifest
│   ├── service.yaml                      # NodePort service
│   ├── namespace.yaml                    # demo namespace
│   └── networkpolicy.yaml               # Network policy
├── evidence/
│   └── kubernetes/
│       ├── deployment-validation.txt     # kubectl output — pods, nodes, ArgoCD
│       └── kyverno-policy-enforcement.txt # Policy block evidence
├── runbooks/
│   ├── deployment-runbook.md            # Standard deployment procedure
│   ├── rollback-runbook.md              # Rollback steps
│   ├── gitops-deployment-runbook.md     # ArgoCD GitOps runbook
│   ├── alert-response-runbook.md        # Alert triage and response
│   └── troubleshooting.md              # Common issues and fixes
└── terraform/                           # Supporting IaC (WIP)
```

---

## Infrastructure

| Component | Address | Role |
|---|---|---|
| GitLab CE | 10.10.1.101 | Source control, CI/CD, container registry |
| GitLab Runner | 10.10.1.21 | Pipeline execution (SOC network) |
| k8master | 10.10.1.70 | Kubernetes control plane |
| k8s-worker-1 | 10.10.2.71 | Worker node (Target network) |
| k8s-worker-2 | 10.10.3.72 | Worker node (Attacker network) |
| ArgoCD | in-cluster | GitOps controller — syncs from GitHub |
| Kyverno | in-cluster | Admission controller — policy enforcement |

The Kubernetes cluster intentionally spans multiple network security zones (SOC, Target, Attacker) to simulate real-world multi-zone cluster design.

---

## Deployment Validation

After pipeline runs, deployment can be validated:

```bash
# Check pods and images
kubectl get pods -n demo -o wide
kubectl get pods -n demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Check ArgoCD sync
kubectl get application demo-nginx -n argocd

# Check rollout
kubectl rollout status deployment/demo-nginx -n demo
```

Expected result:

```
NAME         SYNC STATUS   HEALTH STATUS
demo-nginx   Synced        Healthy
```

---

## Design Decisions and Tradeoffs

**Why GitOps instead of direct kubectl apply?**
Direct kubectl apply in CI creates drift risk — ArgoCD would revert changes not reflected in Git. GitOps ensures Git is the single source of truth and all changes are auditable.

**Why two repo updates in deploy stage?**
ArgoCD is configured to sync from `github.com/TengkuRizal/TengkuRizal` (public). The GitLab CE repo is the source of CI, but GitHub is the source of truth for ArgoCD. Both are updated to keep them in sync.

**Why runner cannot reach worker nodes directly?**
The GitLab Runner sits in the SOC network (10.10.1.0/24). Worker nodes are in the Target and Attacker networks. pfSense firewall segments these zones. The smoke test uses k8master (also in SOC network) as the NodePort access point.

**Why nginx-unprivileged?**
Standard nginx runs as root on port 80. `nginxinc/nginx-unprivileged` runs as UID 101 on port 8080, compatible with `runAsNonRoot: true` and Kyverno's privileged container policy.

**Why Audit mode was changed to Enforce for require-approved-registry?**
The policy was in Audit mode initially — a known gap. After confirming all system namespaces were excluded from the policy scope, it was changed to Enforce to close the supply chain gap.

---

## Operational Runbooks

| Runbook | Purpose |
|---|---|
| [deployment-runbook.md](runbooks/deployment-runbook.md) | Standard deployment and validation |
| [rollback-runbook.md](runbooks/rollback-runbook.md) | Rollback procedure using kubectl and ArgoCD |
| [gitops-deployment-runbook.md](runbooks/gitops-deployment-runbook.md) | ArgoCD sync troubleshooting |
| [alert-response-runbook.md](runbooks/alert-response-runbook.md) | Alert triage and incident response |
| [troubleshooting.md](runbooks/troubleshooting.md) | Common pipeline and cluster issues |

---

## Future Improvements

- Add Cosign image signing for supply chain integrity
- Add Falco runtime security monitoring
- Add manual approval gate before deploy stage
- Add Slack notification for pipeline success and failure
- Add separate environments for staging and production
- Add automated rollback on failed smoke test
- Add SLO definition and error budget alerting
- Enforce Kyverno policy for initContainers and ephemeralContainers

---

## Interview Talking Points

**On the pipeline design:**
This pipeline implements shift-left security — every security check runs before deployment, not after. Gitleaks catches secrets before they reach the registry. Trivy catches CVEs before the image is deployed. Kyverno catches policy violations before pods are scheduled.

**On the GitOps pattern:**
The pipeline does not run kubectl apply directly. It updates the deployment manifest in Git and lets ArgoCD reconcile the cluster state. This means every deployment is auditable, reversible, and consistent with what is in Git.

**On Kyverno enforcement:**
The require-approved-registry policy was initially in Audit mode — a gap I identified and addressed after confirming system namespace exclusions were in place. It is now in Enforce mode, meaning any image not from the internal GitLab registry is blocked at admission time, regardless of how the deployment is triggered.

**On tradeoffs:**
The smoke test uses k8master as the NodePort access point because the GitLab Runner cannot reach worker nodes directly due to network segmentation. In production, I would use an Ingress controller with a load balancer instead of NodePort, which would make the service accessible from a stable address regardless of which node is running the pod.

---

## Author

**Tengku Rizal** — DevSecOps Engineer
Building: GitLab CI/CD · Kubernetes · ArgoCD · Kyverno · Wazuh SIEM · Terraform
Location: Kuala Lumpur, Malaysia
