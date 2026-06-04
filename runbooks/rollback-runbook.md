# Rollback Runbook

## Overview

This runbook documents the standard rollback process for workloads deployed in the homelab DevSecOps environment.

The purpose of this runbook is to provide a controlled, repeatable, and auditable recovery process when a deployment causes service instability, security risk, failed health checks, or unexpected operational impact.

Rollback is not a sign of failure. In production-style operations, rollback is a reliability control used to restore service quickly and reduce user impact.

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

## Rollback Scope

This runbook applies to rollback scenarios involving:

- Failed Kubernetes deployment
- Failed GitLab CI/CD deployment
- Bad application release
- Broken container image
- Misconfigured Kubernetes manifests
- Failed health check
- Service downtime after deployment
- Security alert triggered after deployment
- Suspicious network activity after deployment
- Accidental configuration change
- Incorrect image tag
- Failed rollout
- Application instability
- Emergency restoration to previous known-good state

---

## Rollback Objectives

The rollback process should achieve the following:

- Restore service availability quickly
- Minimize user-facing impact
- Return the workload to a known-good state
- Preserve evidence for troubleshooting
- Avoid making the incident worse
- Document what happened and what was restored
- Support post-incident review and continuous improvement

---

## Rollback Principles

All rollback actions should follow these principles:

1. Confirm impact before rollback where possible.
2. Do not troubleshoot endlessly during active service impact.
3. Restore service first, investigate root cause after stabilization.
4. Prefer known-good versions over untested emergency fixes.
5. Capture evidence before and after rollback.
6. Avoid manual changes that cannot be tracked.
7. Communicate status clearly.
8. Review the failed deployment after recovery.

---

## Rollback Triggers

Rollback should be considered if any of the following conditions occur.

| Trigger | Example |
|---|---|
| Deployment rollout timeout | `kubectl rollout status` does not complete |
| Pod failure | `CrashLoopBackOff`, `ImagePullBackOff`, `ErrImagePull` |
| Health check failure | `/health` endpoint does not return HTTP 200 |
| Service unavailable | Application endpoint unreachable |
| No service endpoints | Kubernetes service has no active endpoints |
| High error rate | HTTP 5xx increases after deployment |
| Security alert | Wazuh reports critical deployment-related alert |
| Suspicious traffic | Security Onion detects abnormal traffic after release |
| Resource exhaustion | Pod OOMKilled or node resource pressure |
| Broken functionality | Smoke test or manual validation fails |
| Bad configuration | Wrong ConfigMap, Secret, port, selector, or environment variable |

---

## Rollback Decision Matrix

| Condition | Severity | Recommended Action |
|---|---|---|
| Pipeline failed before deployment | Low | Do not rollback; fix pipeline |
| Manifest validation failed before deployment | Low | Do not deploy; fix manifest |
| Deployment applied but pods not ready | Medium | Investigate briefly, rollback if not quickly resolved |
| Health check failed | High | Rollback if service impact is confirmed |
| Application unavailable | Critical | Rollback immediately |
| Critical security alert triggered | Critical | Stop deployment, rollback or isolate workload |
| Suspicious network traffic detected | High | Rollback and investigate |
| Database migration failure | Critical | Stop, assess data risk, follow database rollback process |
| User-facing impact confirmed | Critical | Restore previous known-good state |

---

## Roles and Responsibilities

| Role | Responsibility |
|---|---|
| Deployment Owner | Owns the release and rollback decision |
| DevOps / SRE | Executes rollback and validates service recovery |
| Security Owner | Reviews Wazuh and Security Onion findings |
| Incident Owner | Coordinates incident communication if service impact occurs |
| Reviewer | Reviews failed deployment after recovery |

For a homelab or solo project, one engineer may perform all roles, but the same discipline should still be followed.

---

## Pre-Rollback Checklist

Before executing rollback, confirm the following:

- [ ] Impact has been identified.
- [ ] Current deployment state is captured.
- [ ] Rollback target is known.
- [ ] Previous working revision or image tag is available.
- [ ] Kubernetes context is correct.
- [ ] Namespace is confirmed.
- [ ] Deployment name is confirmed.
- [ ] Recent logs or events are captured.
- [ ] Wazuh and Security Onion are checked if security impact is suspected.
- [ ] Rollback method is selected.
- [ ] Post-rollback validation steps are ready.

---

## Immediate Triage Commands

Run these commands before rollback where time allows.

### Confirm Kubernetes Context

```bash
kubectl config current-context
kubectl get nodes -o wide
```

### Check Pods

```bash
kubectl get pods -n NAMESPACE -o wide
```

### Check Deployment Status

```bash
kubectl get deployment -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

### Check Rollout Status

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=60s
```

### Check Recent Events

```bash
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -30
```

### Check Logs

```bash
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
```

If pods restarted:

```bash
kubectl logs POD_NAME -n NAMESPACE --previous
```

### Check Service and Endpoints

```bash
kubectl get svc -n NAMESPACE
kubectl get endpoints -n NAMESPACE
```

---

## Evidence to Capture Before Rollback

If service impact is not critical, capture evidence before rollback.

```bash
mkdir -p evidence/rollback

kubectl get pods -n NAMESPACE -o wide > evidence/rollback/pre-rollback-pods.txt
kubectl get deployment DEPLOYMENT_NAME -n NAMESPACE -o yaml > evidence/rollback/pre-rollback-deployment.yaml
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE > evidence/rollback/pre-rollback-deployment-describe.txt
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -50 > evidence/rollback/pre-rollback-events.txt
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=200 > evidence/rollback/pre-rollback-logs.txt
```

Do not capture or commit:

- Passwords
- Tokens
- Private keys
- Full kubeconfig files
- Secret values
- Sensitive screenshots
- Customer data

---

## Rollback Method 1: Kubernetes Rollout Undo

Use this method when the previous ReplicaSet revision is available.

### Step 1: Check Rollout History

```bash
kubectl rollout history deployment/DEPLOYMENT_NAME -n NAMESPACE
```

### Step 2: Rollback to Previous Revision

```bash
kubectl rollout undo deployment/DEPLOYMENT_NAME -n NAMESPACE
```

### Step 3: Monitor Rollback

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

### Step 4: Verify Pods

```bash
kubectl get pods -n NAMESPACE -o wide
```

### Step 5: Verify Application Health

```bash
curl -i http://APPLICATION_ENDPOINT/health
```

Expected result:

```text
HTTP/1.1 200 OK
```

---

## Rollback Method 2: Rollback to Specific Kubernetes Revision

Use this method when you know the exact working revision.

### Step 1: View Revision History

```bash
kubectl rollout history deployment/DEPLOYMENT_NAME -n NAMESPACE
```

### Step 2: Inspect a Specific Revision

```bash
kubectl rollout history deployment/DEPLOYMENT_NAME -n NAMESPACE --revision=REVISION_NUMBER
```

### Step 3: Rollback to Known-Good Revision

```bash
kubectl rollout undo deployment/DEPLOYMENT_NAME -n NAMESPACE --to-revision=REVISION_NUMBER
```

### Step 4: Monitor Rollback

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

### Step 5: Confirm ReplicaSet

```bash
kubectl get rs -n NAMESPACE
```

---

## Rollback Method 3: Git Revert Rollback

Use this method when the bad deployment was introduced by a Git commit and the pipeline deploys from the main branch.

### Step 1: Identify Recent Commits

```bash
git log --oneline --max-count=10
```

### Step 2: Revert the Bad Commit

```bash
git revert BAD_COMMIT_SHA
```

### Step 3: Push the Revert Commit

```bash
git push origin main
```

### Step 4: Monitor Pipeline

```text
GitLab → Project → CI/CD → Pipelines
```

### Step 5: Validate Deployment

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
kubectl get pods -n NAMESPACE -o wide
curl -i http://APPLICATION_ENDPOINT/health
```

### Notes

Prefer `git revert` over force-push because it preserves audit history and is safer for shared repositories.

---

## Rollback Method 4: Image Tag Rollback

Use this method when the deployment failed due to a bad container image.

### Step 1: Identify Current Image

```bash
kubectl get deployment DEPLOYMENT_NAME -n NAMESPACE -o jsonpath='{.spec.template.spec.containers[*].image}'
echo
```

### Step 2: Set Previous Known-Good Image

```bash
kubectl set image deployment/DEPLOYMENT_NAME CONTAINER_NAME=REGISTRY/IMAGE_NAME:PREVIOUS_IMAGE_TAG -n NAMESPACE
```

### Step 3: Monitor Rollout

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

### Step 4: Verify

```bash
kubectl get pods -n NAMESPACE -o wide
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
curl -i http://APPLICATION_ENDPOINT/health
```

### Risk

This is fast but may create drift from Git if not followed by a Git commit updating the manifest.

After emergency recovery, update the manifest in Git to match the restored image state.

---

## Rollback Method 5: Kubernetes Manifest Reapply

Use this method when a previous known-good manifest exists.

### Step 1: Checkout Previous Known-Good Commit

```bash
git checkout GOOD_COMMIT_SHA
```

### Step 2: Reapply Manifests

```bash
kubectl apply -f kubernetes/ -n NAMESPACE
```

### Step 3: Monitor Rollout

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

### Step 4: Return to Main Branch

```bash
git checkout main
```

### Recommended Follow-Up

Create a proper revert commit on `main` so the Git repository reflects the restored state.

---

## Rollback Method 6: ConfigMap or Secret Rollback

Use this method when the issue is caused by configuration.

### Step 1: Check Current ConfigMaps and Secrets

```bash
kubectl get configmap -n NAMESPACE
kubectl get secret -n NAMESPACE
```

### Step 2: Check Deployment Environment References

```bash
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

### Step 3: Restore Known-Good Configuration

Apply the known-good configuration from Git:

```bash
kubectl apply -f kubernetes/configmap.yaml -n NAMESPACE
```

If secret values need to be restored, use the approved secure secret management process.

Do not commit secret values into Git.

### Step 4: Restart Deployment

```bash
kubectl rollout restart deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

### Step 5: Validate

```bash
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
curl -i http://APPLICATION_ENDPOINT/health
```

---

## Rollback Method 7: Terraform Rollback

Use this method when the failed change was introduced through Terraform.

### Important Rule

Terraform rollback should not be performed by manually editing the Terraform state unless there is no other safe option.

### Step 1: Identify Bad Infrastructure Commit

```bash
git log --oneline --max-count=10
```

### Step 2: Revert Terraform Code

```bash
git revert BAD_COMMIT_SHA
```

### Step 3: Run Terraform Validation

```bash
cd terraform
terraform fmt -check
terraform init
terraform validate
terraform plan
```

### Step 4: Review Plan Carefully

Confirm the plan only restores the intended infrastructure change.

### Step 5: Apply

```bash
terraform apply
```

### Step 6: Return to Repo Root

```bash
cd ..
```

### Post-Terraform Validation

```bash
kubectl get nodes -o wide
kubectl get pods -A
curl -i http://APPLICATION_ENDPOINT/health
```

---

## Rollback Method 8: Database Rollback Awareness

Database rollback is high-risk and should be treated separately from simple application rollback.

### Before Database Rollback

Confirm:

- Backup exists.
- Restore process is documented.
- Data loss risk is understood.
- Schema change impact is understood.
- Application compatibility is confirmed.
- Stakeholders are informed if real production data is involved.

### Safer Database Release Pattern

Prefer:

- Backward-compatible migrations
- Expand-and-contract migration
- Feature flags
- Non-destructive schema changes
- Restore testing
- Backup verification before migration

### Database Rollback Warning

Do not perform destructive database rollback without validating data integrity and recovery impact.

---

## Post-Rollback Validation

After rollback, perform full validation.

### Check Rollout

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

### Check Pods

```bash
kubectl get pods -n NAMESPACE -o wide
```

### Check Service

```bash
kubectl get svc -n NAMESPACE
kubectl get endpoints -n NAMESPACE
```

### Check Application Health

```bash
curl -i http://APPLICATION_ENDPOINT/health
```

Expected result:

```text
HTTP/1.1 200 OK
```

### Check Logs

```bash
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
```

### Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -30
```

### Check Resource Usage

```bash
kubectl top pods -n NAMESPACE
kubectl top nodes
```

---

## Security Validation After Rollback

After rollback, check Wazuh and Security Onion.

### Wazuh Validation

Open Wazuh dashboard:

```text
https://10.10.1.30
```

Review:

- Critical alerts
- Authentication failures
- File integrity alerts
- Suspicious process execution
- Kubernetes node alerts
- Container-related alerts

Expected result:

```text
No new critical security alert related to the rollback.
```

### Security Onion Validation

Open Security Onion dashboard:

```text
https://10.10.1.151
```

Review:

- Suricata alerts
- Zeek logs
- HTTP activity
- DNS activity
- Unusual east-west traffic
- Unexpected external connections

Expected result:

```text
No suspicious traffic related to the rollback.
```

---

## Post-Rollback Evidence Collection

Capture post-rollback evidence.

```bash
mkdir -p evidence/rollback

kubectl get pods -n NAMESPACE -o wide > evidence/rollback/post-rollback-pods.txt
kubectl get deployment DEPLOYMENT_NAME -n NAMESPACE -o yaml > evidence/rollback/post-rollback-deployment.yaml
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s > evidence/rollback/post-rollback-rollout.txt
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -50 > evidence/rollback/post-rollback-events.txt
curl -i http://APPLICATION_ENDPOINT/health > evidence/rollback/post-rollback-health-check.txt
```

Optional Git evidence:

```bash
git log --oneline --max-count=10 > evidence/rollback/git-history-after-rollback.txt
```

---

## Rollback Success Criteria

Rollback is considered successful when:

- Previous known-good version is restored.
- Kubernetes rollout completes successfully.
- Pods are running and ready.
- Service has active endpoints.
- Application health check returns HTTP 200.
- Application logs show no critical error.
- Wazuh shows no critical rollback-related alert.
- Security Onion shows no suspicious rollback-related traffic.
- User-facing functionality is restored.
- Evidence is captured.
- Follow-up review is planned.

---

## Rollback Failure Criteria

Rollback is considered failed when:

- Rollout timeout continues after rollback.
- Pods remain in `CrashLoopBackOff`.
- Pods remain in `ImagePullBackOff`.
- Service still has no endpoints.
- Health check still fails.
- Application remains unavailable.
- Critical security alerts continue.
- Previous known-good version is unavailable.
- Rollback causes additional infrastructure or data risk.

If rollback fails, escalate immediately and move into incident response.

---

## Common Rollback Issues

### Issue: Rollback Revision Not Found

Command:

```bash
kubectl rollout history deployment/DEPLOYMENT_NAME -n NAMESPACE
```

Possible causes:

- Deployment revision history limit too low
- Deployment recreated instead of updated
- Previous ReplicaSet deleted
- GitOps controller reconciled a different state

Action:

- Use Git revert rollback.
- Use previous image tag rollback.
- Reapply known-good manifests from Git.

---

### Issue: Rollback Completed but Pod Still Failing

Commands:

```bash
kubectl get pods -n NAMESPACE -o wide
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

Possible causes:

- Previous version also depends on broken config
- Shared dependency is down
- Secret or ConfigMap still incorrect
- Database or network issue still exists
- Node-level problem

Action:

- Check ConfigMap and Secret.
- Check service dependencies.
- Check node health.
- Check Wazuh and Security Onion.
- Escalate if service impact continues.

---

### Issue: Git Revert Triggers New Pipeline Failure

Commands:

```bash
git status
git log --oneline --max-count=10
```

Possible causes:

- Merge conflict during revert
- Pipeline syntax issue
- Security scan blocks reverted state
- Kubernetes manifest still invalid
- Protected branch or permission issue

Action:

- Resolve conflict carefully.
- Validate pipeline configuration.
- Re-run failed stage after fix.
- Use Kubernetes rollout undo if urgent.

---

### Issue: Image Tag Rollback Creates Git Drift

Symptom:

```text
Cluster is running a different image than the image declared in Git.
```

Action:

1. Restore service first.
2. Update Git manifest with the restored image tag.
3. Commit and push the corrected state.
4. Confirm pipeline reconciles successfully.

---

### Issue: Rollback Blocked by GitOps Controller

Possible causes:

- ArgoCD or GitOps controller reverts manual rollback
- Desired state in Git still points to bad version

Action:

1. Revert the Git commit first.
2. Let GitOps reconcile the cluster.
3. Avoid manual rollback unless emergency requires it.
4. Sync the application after Git is corrected.

---

## Incident Communication Template

Use this if rollback is part of an incident.

```text
Incident Update

Status:
Mitigating / Rolled Back / Resolved

Impact:
Describe the affected service and user impact.

Start Time:
YYYY-MM-DD HH:MM

Detected By:
Pipeline / Monitoring / Health Check / User Report / Security Alert

Suspected Cause:
Bad deployment / Image issue / Config issue / Infrastructure issue / Unknown

Action Taken:
Rollback initiated to previous known-good version.

Current Status:
Service recovering / Service restored / Further investigation ongoing.

Next Step:
Continue monitoring and perform post-incident review.
```

---

## Rollback Log Template

Record every rollback.

| Field | Value |
|---|---|
| Rollback date |  |
| Rollback time |  |
| Environment | Homelab / Staging / Production-style |
| Namespace |  |
| Deployment name |  |
| Failed commit SHA |  |
| Restored commit SHA |  |
| Failed image tag |  |
| Restored image tag |  |
| Rollback method | Kubernetes undo / Git revert / Image tag / Terraform / Config restore |
| Rollback reason |  |
| Impact |  |
| Duration |  |
| Executed by |  |
| Validation completed | Yes / No |
| Evidence location |  |
| Follow-up required | Yes / No |

---

## Post-Incident Review

After rollback and service recovery, perform a post-incident review.

### Questions to Answer

| Question | Answer |
|---|---|
| What changed? |  |
| What failed? |  |
| When did it fail? |  |
| How was it detected? |  |
| What was the user impact? |  |
| Why did validation not catch it earlier? |  |
| What rollback method was used? |  |
| How long did recovery take? |  |
| What evidence was collected? |  |
| What preventive action is required? |  |

### Preventive Actions

Possible preventive actions:

- Improve automated smoke tests.
- Add stronger readiness probes.
- Add deployment approval gate.
- Add canary release.
- Add blue-green deployment.
- Add automated rollback trigger.
- Add better alerting.
- Improve pipeline validation.
- Improve security scanning policy.
- Improve documentation.
- Improve dependency health checks.

---

## Rollback Anti-Patterns

Avoid these practices:

- Troubleshooting too long while users are impacted.
- Making untracked manual changes during recovery.
- Force-pushing without understanding team impact.
- Rolling back database changes without backup validation.
- Ignoring security alerts after rollback.
- Not capturing evidence.
- Not documenting the rollback.
- Declaring success without health check validation.
- Forgetting to update Git after emergency manual rollback.
- Treating rollback as root cause analysis.

Rollback restores service. Root cause analysis happens after recovery.

---

## Interview Explanation

This runbook demonstrates that rollback is handled as a controlled reliability process.

A senior DevOps or SRE engineer should be able to explain:

- When rollback should be triggered
- How rollback impact is assessed
- How Kubernetes rollout undo works
- When to use Git revert instead of manual rollback
- Why image tag rollback can create drift
- How security monitoring is checked after rollback
- How evidence is captured
- How rollback supports incident response
- How post-incident review improves future reliability

This shows production-minded thinking because the goal is not only to deploy, but also to recover safely when deployment fails.

---

## Summary

This rollback runbook provides a controlled and repeatable process for restoring service after a failed deployment.

It covers:

- Rollback triggers
- Immediate triage
- Evidence capture
- Kubernetes rollback
- Git revert rollback
- Image tag rollback
- Config rollback
- Terraform rollback
- Database rollback awareness
- Post-rollback validation
- Security monitoring
- Incident communication
- Post-incident review
- Continuous improvement

The goal is to minimize service impact, restore reliability quickly, and preserve operational evidence for learning and improvement.
