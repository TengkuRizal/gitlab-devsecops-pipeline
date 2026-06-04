# Deployment Runbook

## Overview

This runbook documents the end-to-end deployment process for workloads in the homelab DevSecOps environment. It covers GitLab CI/CD pipeline execution, security gate validation, Kubernetes deployment verification, rollback awareness, and post-deployment monitoring.

The goal of this runbook is to ensure deployments are repeatable, auditable, and aligned with production-style DevOps/SRE practices.

> Note: All IP addresses shown are private homelab addresses and do not expose public infrastructure.

---

## Environment Reference

| Component | Hostname / IP | Role |
|---|---|---|
| GitLab CE | `10.10.1.101` | Source control and CI/CD orchestrator |
| GitLab Runner | `10.10.1.21` | Pipeline executor |
| Kubernetes Master | `k8master` / `10.10.1.70` | Kubernetes control plane |
| Wazuh SIEM | `10.10.1.30` | Security event monitoring |
| Security Onion | `10.10.1.151` | Network traffic analysis |

---

## Deployment Scope

This runbook applies to:

- Application deployment to Kubernetes
- Kubernetes manifest updates
- Container image changes
- GitLab CI/CD pipeline execution
- Security scanning before deployment
- Post-deployment validation
- Basic security monitoring after deployment
- Rollback readiness
- Evidence collection for portfolio and operational review

---

## Pre-Deployment Checklist

Before triggering a pipeline, verify the following:

- [ ] All code changes are committed and pushed to the target branch.
- [ ] GitLab Runner is online and healthy.
- [ ] Kubernetes cluster nodes are in `Ready` state.
- [ ] Required GitLab CI/CD variables are configured.
- [ ] `KUBECONFIG_B64` is available in GitLab project settings.
- [ ] Kubernetes manifests have been reviewed.
- [ ] No secrets are committed into the repository.
- [ ] Wazuh agents on Kubernetes nodes are active.
- [ ] Security Onion is available for network visibility.
- [ ] Rollback method is understood before deployment.
- [ ] Monitoring dashboard is available.
- [ ] Previous stable commit or image tag is known.

---

## Pre-Deployment Validation Commands

### Check Git Status

```bash
git status
git log --oneline --max-count=5
```

Expected result:

```text
nothing to commit, working tree clean
```

### Check Kubernetes Nodes

```bash
kubectl get nodes -o wide
```

Expected result:

```text
All required nodes should be in Ready state.
```

### Check Existing Workloads

```bash
kubectl get pods -A
kubectl get deployment -A
kubectl get svc -A
```

### Check GitLab Runner Status

Run this on the GitLab Runner host:

```bash
sudo gitlab-runner status
```

Expected result:

```text
gitlab-runner: Service is running
```

### Check Kubernetes Manifest Syntax

```bash
kubectl apply --dry-run=client -f kubernetes/
```

Optional server-side validation:

```bash
kubectl apply --dry-run=server -f kubernetes/
```

---

## Pipeline Stages

The CI/CD pipeline should execute multiple validation and security stages before deployment.

| Stage | Tool | Purpose | Failure Action |
|---|---|---|---|
| Validate | kubectl | Validate Kubernetes manifests | Fix manifest syntax or schema issue |
| Secret Scan | Gitleaks | Detect hardcoded secrets, tokens, and credentials | Remove secret, rotate credential, clean Git history if required |
| SAST | Semgrep | Detect insecure code patterns | Fix code and re-run pipeline |
| Config Scan | Trivy Config | Detect Kubernetes misconfiguration | Fix manifest and re-run pipeline |
| Build Image | Docker | Build application container image | Fix Dockerfile or build context |
| Image Scan | Trivy | Detect container image vulnerabilities | Patch base image or dependency |
| Deploy | kubectl | Apply manifests to Kubernetes | Investigate rollout failure |
| Verify | kubectl / curl | Confirm workload health | Rollback if service is unhealthy |

---

## Stage 1: Manifest Validation

### Tool

kubectl

### Purpose

Validate Kubernetes manifests before deployment.

### Command

```bash
kubectl apply --dry-run=client -f kubernetes/
```

### Expected Result

```text
All Kubernetes manifests should pass validation without syntax or schema errors.
```

### Failure Action

If validation fails:

1. Identify the broken manifest.
2. Fix YAML syntax or invalid Kubernetes fields.
3. Re-run dry-run validation.
4. Commit the fix.
5. Re-run the pipeline.

---

## Stage 2: Secret Scanning

### Tool

Gitleaks

### Purpose

Detect hardcoded secrets such as:

- API keys
- Passwords
- Private keys
- Access tokens
- Cloud credentials
- Database credentials
- Webhook tokens

### Failure Condition

Any confirmed exposed secret should block deployment.

### Action If Failed

1. Remove the secret from the code.
2. Rotate the exposed credential immediately.
3. Review Git history to confirm exposure scope.
4. Rewrite Git history only through an approved process if required.
5. Coordinate force-push carefully if history rewrite is needed.
6. Re-run the pipeline after remediation.

---

## Stage 3: Static Application Security Testing

### Tool

Semgrep

### Purpose

Detect insecure code patterns and common security weaknesses.

### Example Checks

- Command injection risk
- Insecure deserialization
- Hardcoded credentials
- Weak cryptography
- Unsafe file handling
- Insecure HTTP usage
- Missing input validation

### Failure Condition

High-severity findings should block deployment.

### Action If Failed

1. Review the finding in pipeline logs.
2. Confirm whether it is a true positive.
3. Fix the affected code.
4. Commit and push the fix.
5. Re-run the pipeline.

---

## Stage 4: Kubernetes Configuration Scanning

### Tool

Trivy Config

### Purpose

Detect Kubernetes misconfigurations before deployment.

### Example Checks

- Privileged containers
- Missing resource limits
- Running as root
- Exposed services
- Missing security context
- Weak pod configuration
- HostPath volume usage
- Insecure capabilities

### Action If Failed

1. Review the misconfiguration.
2. Update the Kubernetes manifest.
3. Re-run the pipeline.
4. Confirm the misconfiguration is resolved.

---

## Stage 5: Container Image Build

### Tool

Docker

### Purpose

Build the application container image before deployment.

### Example Command

```bash
docker build -t REGISTRY/IMAGE_NAME:IMAGE_TAG .
```

### Failure Action

If image build fails:

1. Review Docker build logs.
2. Confirm Dockerfile syntax.
3. Confirm required files exist in the build context.
4. Confirm package repositories are reachable.
5. Rebuild after fixing the issue.

---

## Stage 6: Container Image Scanning

### Tool

Trivy

### Purpose

Scan the container image for operating system and application dependency vulnerabilities.

### Example Command

```bash
trivy image REGISTRY/IMAGE_NAME:IMAGE_TAG
```

### Failure Condition

Critical vulnerabilities should block deployment unless formally accepted as risk.

### Action If Failed

1. Identify affected package or image layer.
2. Update the base image.
3. Patch vulnerable dependencies.
4. Rebuild the image.
5. Re-run the scan.
6. Re-run the pipeline.

---

## Stage 7: Deploy to Kubernetes

### Tool

kubectl

### Authentication Method

The GitLab pipeline uses the `KUBECONFIG_B64` CI/CD variable.

The pipeline decodes the kubeconfig during job execution and uses it to authenticate to the Kubernetes cluster.

### Deployment Command Example

```bash
kubectl apply -f kubernetes/
```

For namespace-specific deployment:

```bash
kubectl apply -f kubernetes/ -n NAMESPACE
```

---

## Deployment Procedure

## 1. Trigger Pipeline

Push changes to the target branch:

```bash
git add .
git commit -m "feat: describe deployment change"
git push origin main
```

Alternatively, trigger manually from GitLab:

```text
GitLab → Project → CI/CD → Pipelines → Run Pipeline
```

---

## 2. Monitor Pipeline Execution

Monitor each stage in GitLab:

```text
GitLab → Project → CI/CD → Pipelines
```

Expected stage duration:

| Stage | Expected Duration |
|---|---|
| Validate | 10–30 seconds |
| Gitleaks | 30 seconds |
| Semgrep | 60–90 seconds |
| Trivy Config | 30–60 seconds |
| Docker Build | 60–180 seconds |
| Trivy Image Scan | 60–120 seconds |
| Kubernetes Deploy | 30–60 seconds |
| Verify | 10–30 seconds |

If any stage fails, stop the deployment and resolve the issue before retrying.

---

## 3. Verify Deployment on Kubernetes

After the pipeline completes successfully, verify from `k8master`.

### Check Pods

```bash
kubectl get pods -n NAMESPACE -o wide
```

Expected result:

```text
Pods should be Running and Ready.
```

### Check Deployment Rollout

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

Expected result:

```text
deployment "DEPLOYMENT_NAME" successfully rolled out
```

### Check Deployment Details

```bash
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

### Check ReplicaSets

```bash
kubectl get rs -n NAMESPACE
```

### Check Recent Events

```bash
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -20
```

---

## 4. Validate Application

### Check Service

```bash
kubectl get svc -n NAMESPACE
```

### Check Endpoints

```bash
kubectl get endpoints -n NAMESPACE
```

Expected result:

```text
Service should have active endpoints.
```

### Port Forward for Local Testing

Use this if there is no Ingress or external endpoint:

```bash
kubectl port-forward svc/SERVICE_NAME 8080:80 -n NAMESPACE
```

Then test from another terminal:

```bash
curl -i http://localhost:8080
```

### Health Check

```bash
curl -i http://APPLICATION_ENDPOINT/health
```

Expected result:

```text
HTTP/1.1 200 OK
```

---

## 5. Validate Logs

Check current logs:

```bash
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
```

If a pod restarted, check previous logs:

```bash
kubectl logs POD_NAME -n NAMESPACE --previous
```

Look for:

- Startup errors
- CrashLoopBackOff
- Image pull errors
- Database connection errors
- Missing environment variables
- Permission errors
- HTTP 5xx errors
- Security warnings

---

## 6. Confirm in Wazuh

Check Wazuh dashboard:

```text
https://10.10.1.30
```

Review:

- Agent status
- Authentication failure alerts
- File integrity alerts
- Suspicious process alerts
- Critical rule-level alerts
- Kubernetes node security events

Expected result:

```text
No critical alerts related to the deployment.
```

---

## 7. Confirm Network Visibility in Security Onion

Check Security Onion if the deployment involves network exposure or traffic flow changes.

Review:

- Zeek logs
- Suricata alerts
- DNS activity
- HTTP activity
- Unusual source or destination traffic

Expected result:

```text
No suspicious network activity caused by the deployment.
```

---

## Post-Deployment Verification

| Check | Command / Location | Expected Result |
|---|---|---|
| Pods running | `kubectl get pods -n NAMESPACE` | All pods are Running |
| Deployment rolled out | `kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE` | Rollout successful |
| No crash loops | `kubectl get pods -n NAMESPACE` | No CrashLoopBackOff |
| Service has endpoints | `kubectl get endpoints -n NAMESPACE` | Endpoints are populated |
| Application reachable | `curl -i http://APPLICATION_ENDPOINT/health` | HTTP 200 |
| Logs clean | `kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE` | No critical errors |
| Wazuh clean | Wazuh dashboard | No critical deployment-related alerts |
| Security Onion clean | Security Onion dashboard | No suspicious traffic |

---

## Rollback Awareness

If the deployment causes service instability, use the rollback runbook.

Common rollback triggers:

- Deployment rollout timeout
- CrashLoopBackOff
- ImagePullBackOff
- Failed health check
- High HTTP 5xx rate
- Critical Wazuh alerts
- Suspicious Security Onion findings
- Broken application functionality
- Unexpected service downtime

Quick Kubernetes rollback:

```bash
kubectl rollout undo deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

---

## Common Deployment Issues

### Issue: ImagePullBackOff

Command:

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Common causes:

- Wrong image name
- Wrong image tag
- Registry authentication issue
- Missing imagePullSecret
- Registry unreachable from node

Action:

```bash
kubectl get secret -n NAMESPACE
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -20
```

---

### Issue: CrashLoopBackOff

Command:

```bash
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

Common causes:

- Application startup failure
- Missing environment variable
- Invalid configuration
- Database unavailable
- Permission issue
- Application port mismatch

Action:

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get configmap -n NAMESPACE
kubectl get secret -n NAMESPACE
```

---

### Issue: Service Not Reachable

Commands:

```bash
kubectl get svc -n NAMESPACE
kubectl get endpoints -n NAMESPACE
kubectl get pods -n NAMESPACE --show-labels
```

Common causes:

- Wrong service selector
- Pod labels do not match service selector
- Target port mismatch
- Pod not ready
- NetworkPolicy blocking traffic

---

### Issue: Rollout Timeout

Commands:

```bash
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -20
```

Common causes:

- Readiness probe failure
- Image pull issue
- Insufficient resources
- Pod scheduling issue
- Persistent volume mount issue

---

### Issue: KUBECONFIG Error in Pipeline

Common symptoms:

```text
error: You must be logged in to the server
error: invalid configuration
certificate signed by unknown authority
```

Possible causes:

- `KUBECONFIG_B64` variable missing
- Kubeconfig encoded incorrectly
- GitLab variable protected but branch is not protected
- Kubernetes certificate issue
- Wrong cluster context

Action:

```bash
echo "$KUBECONFIG_B64" | base64 -d > kubeconfig
export KUBECONFIG=$PWD/kubeconfig
kubectl config get-contexts
kubectl get nodes
```

Do not print kubeconfig content in public logs.

---

## Monitoring After Deployment

Monitor the following after deployment:

- Pod readiness
- Pod restart count
- CPU usage
- Memory usage
- Node health
- HTTP 4xx and 5xx errors
- Application latency
- Wazuh critical alerts
- Security Onion suspicious traffic
- Kubernetes events

Useful commands:

```bash
kubectl get pods -n NAMESPACE -o wide
kubectl top pods -n NAMESPACE
kubectl top nodes
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -20
```

---

## Security Checks After Deployment

Perform basic security validation:

```bash
kubectl get pods -n NAMESPACE -o yaml | grep -i privileged
kubectl get svc -n NAMESPACE
kubectl get secrets -n NAMESPACE
```

Review:

- No unnecessary privileged container.
- No unexpected NodePort exposure.
- No secret value exposed in logs.
- No critical Wazuh alert.
- No suspicious Security Onion alert.

---

## Deployment Success Criteria

Deployment is considered successful when:

- Pipeline completed successfully.
- All required security stages passed.
- Kubernetes rollout completed successfully.
- Pods are running and ready.
- Service has endpoints.
- Health check returns HTTP 200.
- Application logs show no critical errors.
- Wazuh shows no critical deployment-related alerts.
- Security Onion shows no suspicious deployment-related traffic.
- No rollback is required.

---

## Deployment Failure Criteria

Deployment is considered failed when:

- Pipeline fails at required stage.
- Kubernetes rollout times out.
- Pods enter CrashLoopBackOff.
- Pods enter ImagePullBackOff.
- Health check fails.
- Service has no endpoints.
- Application logs show critical errors.
- Wazuh reports critical security alerts.
- Security Onion detects suspicious traffic caused by deployment.
- User-facing functionality is broken.

---

## Rollback Decision Matrix

| Condition | Action |
|---|---|
| Pipeline failed before deployment | Do not deploy |
| Manifest validation failed | Fix manifest and re-run |
| Image scan found critical vulnerabilities | Patch image before deployment |
| Pod CrashLoopBackOff after deployment | Investigate quickly, rollback if service impact |
| Health check failed | Rollback if not resolved quickly |
| Service has no endpoints | Fix selector or rollback |
| Critical security alert triggered | Stop deployment and investigate |
| Suspicious network activity detected | Isolate and investigate |

---

## Deployment Sign-Off Record

Record the following after each successful deployment:

| Field | Value |
|---|---|
| Deployment date |  |
| Deployment time |  |
| Environment | Homelab / Staging / Production-style |
| Commit SHA |  |
| Pipeline ID |  |
| Image tag |  |
| Namespace |  |
| Deployment name |  |
| Deployed by |  |
| Verification completed | Yes / No |
| Rollback required | Yes / No |
| Issues encountered | None / Describe |
| Evidence location |  |

---

## Evidence to Capture

Store sanitized evidence under the `evidence/` directory.

Recommended evidence:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get deployment -A
kubectl get svc -A
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE
curl -i http://APPLICATION_ENDPOINT/health
git log --oneline --max-count=5
```

Suggested evidence files:

```text
evidence/deployment-status.md
evidence/health-check-result.md
evidence/rollout-status.md
evidence/pipeline-result.md
evidence/monitoring-check.md
```

Do not commit:

- Passwords
- Tokens
- Private keys
- Real credentials
- Customer data
- Sensitive screenshots
- Full kubeconfig files

---

## Post-Deployment Review

After deployment, review:

- Did the pipeline pass without manual intervention?
- Were all security gates effective?
- Did deployment complete within expected time?
- Did application health checks pass?
- Were there any Wazuh alerts?
- Were there any Security Onion findings?
- Was rollback required?
- Should documentation be updated?
- Should monitoring or alerting be improved?

---

## Continuous Improvement

Future improvements:

- Add automated smoke testing.
- Add automated rollback trigger.
- Add canary deployment.
- Add blue-green deployment.
- Add ArgoCD GitOps workflow.
- Add Argo Rollouts.
- Add OpenTelemetry tracing.
- Add Loki log aggregation.
- Add SLO-based alerting.
- Add Kyverno or OPA policy-as-code.
- Add SBOM generation using Syft.
- Add image signing using Cosign.

---

## Interview Explanation

This runbook demonstrates that deployment is handled as a controlled operational process, not just a `kubectl apply`.

It shows:

- Git-based deployment discipline
- CI/CD pipeline control
- Security checks before release
- Kubernetes validation
- Monitoring after deployment
- Rollback awareness
- Evidence collection
- Production-style DevOps/SRE thinking

A senior DevOps or SRE engineer should be able to explain not only how deployment works, but also how deployment risk is reduced, how failures are detected, and how service recovery is handled.

---

## Summary

This deployment runbook provides a repeatable and controlled process for deploying workloads into the homelab DevSecOps environment.

It covers:

- Pre-deployment validation
- GitLab CI/CD execution
- Security scanning
- Kubernetes deployment
- Post-deployment verification
- Wazuh security monitoring
- Security Onion network visibility
- Rollback awareness
- Evidence collection
- Continuous improvement

The goal is to demonstrate reliable, secure, and production-style DevOps/SRE operational maturity.
