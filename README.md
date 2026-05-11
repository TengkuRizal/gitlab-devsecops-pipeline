# gitlab-devsecops-pipeline

9-stage DevSecOps CI/CD pipeline built on self-hosted GitLab CE, integrating secret scanning, SAST, container scanning, SBOM generation, and automated Kubernetes deployment.

![Pipeline](https://img.shields.io/badge/Pipeline-9%20Stages-brightgreen)
![GitLab](https://img.shields.io/badge/GitLab-CE%20Self--Hosted-FC6D26?logo=gitlab)
![Kubernetes](https://img.shields.io/badge/Deploy-Kubernetes-326CE5?logo=kubernetes)
![Status](https://img.shields.io/badge/Status-Passing-brightgreen)

---

## Pipeline Overview

Every commit to `main` triggers all 9 stages sequentially. A failure in any stage blocks deployment.

<pre>
┌─────────────┐
│  Git Commit │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Stage 1: validate      │  kubectl dry-run on K8s manifests        │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 2: secret-scan   │  Gitleaks — detect hardcoded secrets      │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 3: sast          │  Semgrep — static application analysis    │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 4: config-scan   │  Trivy — K8s manifest misconfiguration    │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 5: build-image   │  Docker build + push to GitLab Registry   │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 6: sbom          │  Syft — CycloneDX SBOM generation         │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 7: image-scan    │  Trivy — HIGH/CRITICAL CVE scan on image  │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 8: deploy        │  kubectl apply to Kubernetes cluster       │
├─────────────────────────┼───────────────────────────────────────────┤
│  Stage 9: verify        │  kubectl status check post-deployment      │
└─────────────────────────┴───────────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│  Production │
└─────────────┘
</pre>

---

## Security Tools

| Stage | Tool | Purpose | Output |
|---|---|---|---|
| secret-scan | Gitleaks | Detect hardcoded secrets, API keys, tokens | `gitleaks-report.json` |
| sast | Semgrep | Static code analysis, insecure patterns | `semgrep-report.json` |
| config-scan | Trivy | K8s manifest security misconfiguration | `trivy-k8s-config-report.json` |
| sbom | Syft | Software Bill of Materials (CycloneDX) | `sbom-cyclonedx.json` |
| image-scan | Trivy | Container image CVE scan (HIGH/CRITICAL) | `trivy-image-report.json` |

---

## Security Hardening

This project goes beyond scanning — the workload itself is hardened before it enters the pipeline.

### Dockerfile — Non-Root + CVE Patching

```dockerfile
FROM nginxinc/nginx-unprivileged:1.28-alpine  # Runs as UID 101, not root
USER root
RUN apk upgrade --no-cache libcrypto3 libssl3  # Patch OpenSSL CVEs at build time
USER 101
```

Standard `nginx:alpine` runs as root. This image uses `nginx-unprivileged` (UID 101) and explicitly patches known OpenSSL CVEs before the image is scanned.

### Kubernetes — CIS Benchmark Controls

| Control | Value | Purpose |
|---|---|---|
| `seccompProfile` | `RuntimeDefault` | Restrict syscalls to safe default |
| `runAsNonRoot` | `true` | Block root container execution |
| `allowPrivilegeEscalation` | `false` | Block setuid/setgid escalation |
| `readOnlyRootFilesystem` | `true` | Prevent runtime filesystem tampering |
| `capabilities.drop` | `ALL` | Remove all Linux capabilities |
| `resources.limits` | CPU + Memory | Prevent resource exhaustion |

emptyDir volumes mount at `/var/cache/nginx`, `/var/run`, `/tmp` — nginx functions normally with a read-only root filesystem.

### NetworkPolicy — Ingress Restriction

Only port 8080 allowed inbound. All other ingress blocked by default.

## Infrastructure

| Component | Detail |
|---|---|
| GitLab CE | Self-hosted, 10.10.1.101 |
| GitLab Runner | Shell executor, 10.10.1.21 |
| Container Registry | GitLab built-in registry |
| Kubernetes | 3-node kubeadm cluster |
| Deploy target | Namespace `demo`, deployment `demo-nginx` |

Runner tools installed directly (shell executor):
- `gitleaks` `/usr/local/bin/gitleaks`
- `semgrep` `/home/runner/.local/bin/semgrep`
- `trivy` `/usr/bin/trivy`
- `syft` `/usr/local/bin/syft`
- `kubectl` `/usr/bin/kubectl`
- `docker` v29.4.3

---

## Artifacts

Every pipeline run produces security artifacts retained for 7 days:

<pre>
pipeline-artifacts/
├── validate-report.txt          # K8s manifest dry-run output
├── gitleaks-report.json         # Secret scan results
├── semgrep-report.json          # SAST findings
├── trivy-k8s-config-report.json # K8s config issues
├── sbom-cyclonedx.json          # Software Bill of Materials
└── trivy-image-report.json      # Container CVE scan results
</pre>

---

## Pipeline Result

<pre>
Pipeline #76 — Passed ✅
Duration   : 48 seconds
Stages     : 9/9 passed
Branch     : main
Runner     : gitrunner (shell executor)
</pre>

---

## Security Design

**Why shell executor over Docker executor?**
All security tools (Gitleaks, Semgrep, Trivy, Syft) are installed directly on the runner. This avoids Docker-in-Docker complexity and reduces attack surface — no privileged containers required.

**Why block on ALL security stages?**
`allow_failure: false` is set on secret-scan, sast, and image-scan. A single HIGH/CRITICAL finding or detected secret stops the pipeline. Security gates are not advisory — they are mandatory.

**Why SBOM?**
CycloneDX SBOM provides a complete inventory of all software components in the container image. This supports vulnerability tracking, license compliance, and supply chain security visibility.

**Why verify stage after deploy?**
Deployment success does not equal workload health. The verify stage confirms pods are running, services are exposed, and the rollout completed — not just that `kubectl apply` returned 0.

---

## Related Projects

| Project | Description |
|---|---|
| [devsecops-homelab](https://github.com/TengkuRizal/devsecops-homelab) | Full homelab architecture |
| [terraform-aws-devsecops](https://github.com/TengkuRizal/terraform-aws-devsecops) | AWS IaC with Checkov scanning |

---

## Author

**Tengku Rizal** — DevSecOps Engineer
Building: GitLab CI/CD · Kubernetes · Wazuh SIEM · Terraform · Security Automation
Location: Kuala Lumpur, Malaysia
