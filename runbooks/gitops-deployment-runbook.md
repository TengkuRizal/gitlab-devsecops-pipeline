# GitOps Deployment Runbook

## Overview

This runbook documents the GitOps deployment process using ArgoCD in the homelab DevSecOps/SRE platform.

The purpose of this runbook is to define how Kubernetes workloads are deployed, synchronized, verified, and recovered when ArgoCD is used as the continuous delivery controller.

This runbook supports Phase 2 of the homelab implementation, where `demo-nginx` is managed by ArgoCD from Kubernetes manifests stored in Git.

---

## GitOps Principle

GitOps means Git is the source of truth for the desired state of the Kubernetes cluster.

Instead of manually applying manifests with `kubectl apply`, Kubernetes manifests are stored in Git and ArgoCD continuously compares the desired state in Git against the live state in the cluster.

If there is drift, ArgoCD can detect it and optionally reconcile it.

---

## Environment Reference

| Component | Role |
|---|---|
| GitHub Repository | Source of truth for Kubernetes manifests |
| `kubernetes/` directory | Desired state manifests for `demo-nginx` |
| ArgoCD | GitOps controller and deployment reconciler |
| Kubernetes Cluster | Runtime platform |
| `demo` namespace | Target namespace for the demo workload |
| `demo-nginx` | Example workload managed through GitOps |

---

## Repository Paths

| Path | Purpose |
|---|---|
| `kubernetes/namespace.yaml` | Defines the `demo` namespace |
| `kubernetes/deployment.yaml` | Defines the `demo-nginx` deployment |
| `kubernetes/service.yaml` | Defines the `demo-nginx` service |
| `argocd/applications/demo-nginx-app.yaml` | Defines the ArgoCD Application |
| `evidence/phase-2/` | Stores GitOps validation evidence |

---

## GitOps Flow

```text
Developer updates Kubernetes manifest
      ↓
Change committed to Git
      ↓
Change pushed to main branch
      ↓
ArgoCD detects Git revision change
      ↓
ArgoCD compares desired state with live cluster
      ↓
ArgoCD syncs the application
      ↓
Kubernetes applies the desired state
      ↓
Workload health is validated
```

---

## Pre-Deployment Checklist

Before making a GitOps deployment change, verify:

- [ ] ArgoCD pods are running.
- [ ] ArgoCD UI is accessible.
- [ ] `demo-nginx` Application exists.
- [ ] Application is currently `Synced` and `Healthy`.
- [ ] Kubernetes nodes are `Ready`.
- [ ] Current manifest change is reviewed.
- [ ] Rollback method is understood.
- [ ] No secrets are committed into Git.
- [ ] Evidence capture path is ready.

---

## Check ArgoCD Health

Run from `k8master`:

```bash
kubectl get pods -n argocd -o wide
kubectl get svc -n argocd
kubectl get application -n argocd
```

Expected result:

```text
demo-nginx   Synced   Healthy
```

---

## Check Current Application Status

```bash
kubectl get application demo-nginx -n argocd
kubectl get application demo-nginx -n argocd -o yaml
```

Key fields to check:

- `status.sync.status`
- `status.health.status`
- `status.operationState.phase`
- `status.operationState.message`
- `status.summary.images`

Expected values:

```text
sync.status: Synced
health.status: Healthy
operationState.phase: Succeeded
```

---

## Check Current Kubernetes Workload

```bash
kubectl get pods -n demo -o wide
kubectl get svc -n demo
kubectl get deployment demo-nginx -n demo -o wide
kubectl rollout status deployment/demo-nginx -n demo --timeout=300s
```

Expected result:

- `demo-nginx` deployment is available.
- Pods are running and ready.
- Service exists.
- Rollout status is successful.

---

## Deployment Procedure

## 1. Update Desired State in Git

On the Mac repo:

```bash
cd ~/TengkuRizal
```

Edit the required manifest:

```bash
nano kubernetes/deployment.yaml
```

Common GitOps changes:

- Change image tag
- Change replica count
- Add labels or annotations
- Update resource requests and limits
- Update readiness or liveness probes
- Modify service configuration

---

## 2. Validate Manifest Locally

If the Mac has Kubernetes access:

```bash
kubectl apply --dry-run=client -f kubernetes/
```

If validation must be done on `k8master`, copy or test the manifest carefully before committing.

---

## 3. Commit and Push

```bash
git status
git diff --stat
git diff

git add kubernetes/
git commit -m "Update demo-nginx GitOps desired state"
git pull --rebase origin main
git push origin main
```

---

## 4. Trigger ArgoCD Refresh

ArgoCD may detect changes automatically. To force refresh from `k8master`:

```bash
kubectl annotate application demo-nginx -n argocd   argocd.argoproj.io/refresh=hard   --overwrite
```

Wait:

```bash
sleep 20
```

---

## 5. Check ArgoCD Sync Status

```bash
kubectl get application demo-nginx -n argocd
```

Expected:

```text
demo-nginx   Synced   Healthy
```

If the application is `OutOfSync`, sync it:

```bash
kubectl patch application demo-nginx -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

Then check again:

```bash
kubectl get application demo-nginx -n argocd
```

---

## 6. Validate Kubernetes Workload

```bash
kubectl get pods -n demo -o wide
kubectl get svc -n demo
kubectl get deployment demo-nginx -n demo -o wide
kubectl rollout status deployment/demo-nginx -n demo --timeout=300s
```

---

## 7. Validate Application Access

Check the service:

```bash
kubectl get svc demo-nginx -n demo
```

If using NodePort:

```bash
curl -i http://NODE_IP:NODE_PORT
```

Expected result for nginx:

```text
HTTP/1.1 200 OK
```

---

## Evidence Capture

Capture evidence from `k8master`:

```bash
mkdir -p ~/phase-2-evidence

kubectl get application -n argocd > ~/phase-2-evidence/argocd-applications.txt
kubectl get application demo-nginx -n argocd -o yaml > ~/phase-2-evidence/demo-nginx-argocd-application.yaml
kubectl get pods -n argocd -o wide > ~/phase-2-evidence/argocd-pods.txt
kubectl get svc -n argocd > ~/phase-2-evidence/argocd-services.txt
kubectl get pods -n demo -o wide > ~/phase-2-evidence/demo-nginx-pods.txt
kubectl get svc -n demo > ~/phase-2-evidence/demo-nginx-service.txt
kubectl get deployment demo-nginx -n demo -o wide > ~/phase-2-evidence/demo-nginx-deployment.txt
```

Archive:

```bash
tar -czf ~/phase-2-evidence.tar.gz -C ~ phase-2-evidence
```

Copy from Mac:

```bash
cd ~/TengkuRizal

mkdir -p evidence/phase-2

scp k8@10.10.1.70:/home/k8/phase-2-evidence.tar.gz /tmp/phase-2-evidence.tar.gz
tar -xzf /tmp/phase-2-evidence.tar.gz -C /tmp
cp /tmp/phase-2-evidence/* evidence/phase-2/
```

Commit evidence:

```bash
git add evidence/phase-2/
git commit -m "Update phase 2 GitOps evidence"
git pull --rebase origin main
git push origin main
```

---

## Rollback Procedure

GitOps rollback should prefer Git history.

## Method 1: Git Revert

Identify the bad commit:

```bash
git log --oneline --max-count=10
```

Revert the commit:

```bash
git revert BAD_COMMIT_SHA
git push origin main
```

Force ArgoCD refresh:

```bash
kubectl annotate application demo-nginx -n argocd   argocd.argoproj.io/refresh=hard   --overwrite
```

Validate:

```bash
kubectl get application demo-nginx -n argocd
kubectl get pods -n demo -o wide
kubectl rollout status deployment/demo-nginx -n demo --timeout=300s
```

---

## Method 2: Restore Previous Manifest Value

Edit the manifest back to the previous known-good value:

```bash
nano kubernetes/deployment.yaml
```

Commit and push:

```bash
git add kubernetes/deployment.yaml
git commit -m "Rollback demo-nginx desired state"
git pull --rebase origin main
git push origin main
```

Refresh and validate ArgoCD:

```bash
kubectl annotate application demo-nginx -n argocd   argocd.argoproj.io/refresh=hard   --overwrite

kubectl get application demo-nginx -n argocd
```

---

## Emergency Rollback Warning

Avoid manually changing live resources with `kubectl` unless there is an active incident and GitOps reconciliation is understood.

Manual live changes may be reverted by ArgoCD if self-heal is enabled.

If emergency manual action is required, update Git afterward so the desired state matches the recovered state.

---

## Troubleshooting

## Issue: Application Shows Unknown

Check details:

```bash
kubectl describe application demo-nginx -n argocd
```

Check repo-server logs:

```bash
kubectl logs -n argocd deployment/argocd-repo-server --tail=100
```

Common causes:

- Wrong repo URL
- Wrong path
- Missing manifest directory
- GitHub unreachable
- ArgoCD repo cache stale
- Manifest generation error

---

## Issue: Application Shows OutOfSync

Check:

```bash
kubectl get application demo-nginx -n argocd
kubectl describe application demo-nginx -n argocd
```

Possible causes:

- Git desired state changed
- Live cluster changed manually
- ArgoCD has not synced yet

Resolution:

```bash
kubectl patch application demo-nginx -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

---

## Issue: Application Degraded

Check application:

```bash
kubectl describe application demo-nginx -n argocd
```

Check workload:

```bash
kubectl get pods -n demo -o wide
kubectl describe deployment demo-nginx -n demo
kubectl get events -n demo --sort-by=.metadata.creationTimestamp | tail -30
```

Common causes:

- Pod not ready
- Image pull failure
- Readiness probe failure
- Service mismatch
- Resource constraints

---

## Issue: ArgoCD UI Not Accessible

Check service:

```bash
kubectl get svc argocd-server -n argocd
```

Check pods:

```bash
kubectl get pods -n argocd -o wide
```

Test NodePort:

```bash
curl -k -I https://NODE_IP:HTTPS_NODEPORT
```

Common causes:

- Wrong NodePort
- Firewall issue
- Browser certificate warning
- ArgoCD server not ready

---

## Security Notes

Do not commit:

- ArgoCD admin password
- kubeconfig files
- Kubernetes secrets
- Registry credentials
- Private keys
- Tokens
- Real production data

Recommended security improvements:

- Rotate ArgoCD initial admin password
- Delete initial admin secret after password rotation
- Restrict ArgoCD network access
- Use RBAC
- Use private repository credentials securely if needed
- Avoid hardcoded secrets in manifests
- Use External Secrets or Vault integration in future phases

---

## Success Criteria

GitOps deployment is successful when:

- ArgoCD Application is `Synced`
- ArgoCD Application is `Healthy`
- Kubernetes deployment is available
- Pods are running and ready
- Service is reachable
- Git commit represents the desired state
- Evidence is captured
- No manual drift remains

---

## Interview Explanation

This runbook demonstrates how I operate a GitOps deployment model using ArgoCD.

A strong interview explanation:

> In Phase 2, I introduced ArgoCD so that Kubernetes manifests in Git became the source of truth. Instead of relying only on direct `kubectl apply`, ArgoCD continuously compares Git desired state with the live cluster and syncs the application. This gives better auditability, rollback through Git history, drift detection, and operational visibility through sync and health status.

---

## Future Improvements

Recommended improvements:

- Add Kustomize overlays for dev/staging/prod
- Add Helm-based deployment example
- Add ArgoCD RBAC
- Add ArgoCD notifications
- Add ArgoCD monitoring dashboards
- Add Argo Rollouts for canary deployment
- Add image update automation
- Add GitOps-based rollback evidence
- Add private repo credential management
- Add External Secrets or Vault integration

---

## Summary

This GitOps deployment runbook defines how to deploy, validate, troubleshoot, and roll back Kubernetes workloads managed by ArgoCD.

It supports production-style DevOps/SRE maturity by improving deployment control, desired-state management, auditability, rollback readiness, and operational consistency.
