# Troubleshooting Runbook

## Overview

This runbook documents common troubleshooting procedures for the homelab DevSecOps environment.

It is designed to help diagnose and resolve issues across:

- GitLab CI/CD pipelines
- GitLab Runner
- Kubernetes workloads
- Docker/container image builds
- Kubernetes deployment rollout
- KUBECONFIG and cluster authentication
- DNS and network connectivity
- Wazuh monitoring
- Security Onion visibility
- Prometheus and Grafana monitoring
- Node resource pressure
- Storage and disk space issues

The purpose of this runbook is to provide repeatable troubleshooting steps that are useful for day-to-day operations, incident response, portfolio evidence, and interview discussion.

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
| Monitoring Namespace | `monitoring` | Prometheus and Grafana stack |
| Demo Namespace | `demo` | Example application workloads |

---

## Troubleshooting Principles

Follow these principles before making changes:

1. Confirm the exact symptom.
2. Identify the affected component.
3. Check recent changes first.
4. Read logs before restarting services.
5. Capture evidence before fixing major issues.
6. Avoid deleting resources unless impact is understood.
7. Fix root cause, not only the symptom.
8. Document the issue, command output, and resolution.
9. Validate service health after every fix.
10. Convert repeated issues into automation or monitoring alerts.

---

## Initial Triage Checklist

Start with these checks when the problem is unclear.

```bash
date
hostname
whoami
pwd
git status
```

Check Kubernetes:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -50
```

Check GitLab Runner host:

```bash
sudo gitlab-runner status
systemctl status gitlab-runner --no-pager
df -h
free -h
```

Check local network:

```bash
ip addr
ip route
resolvectl status
ping -c 4 10.10.1.70
ping -c 4 10.10.1.101
```

---

## Evidence Collection

Before making major changes, collect evidence.

```bash
mkdir -p evidence/troubleshooting

kubectl get nodes -o wide > evidence/troubleshooting/k8s-nodes.txt
kubectl get pods -A -o wide > evidence/troubleshooting/k8s-pods.txt
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -100 > evidence/troubleshooting/k8s-events.txt
df -h > evidence/troubleshooting/disk-usage.txt
free -h > evidence/troubleshooting/memory-usage.txt
git status > evidence/troubleshooting/git-status.txt
git log --oneline --max-count=10 > evidence/troubleshooting/git-history.txt
```

Do not commit:

- Passwords
- Tokens
- Private keys
- Full kubeconfig files
- Secret values
- Sensitive internal screenshots
- Customer data

---

# Section 1: Git and Repository Issues

## Issue 1.1: Git Working Tree Not Clean

### Symptom

```text
nothing added to commit but untracked files present
```

or

```text
modified: runbooks/troubleshooting.md
```

### Diagnosis

```bash
git status
git diff --stat
git diff
```

### Resolution

If changes are intended:

```bash
git add .
git commit -m "docs: update troubleshooting runbook"
git push origin main
```

If changes should be discarded:

```bash
git restore FILE_NAME
```

For untracked files:

```bash
git clean -n
```

Only delete after reviewing:

```bash
git clean -f
```

---

## Issue 1.2: Pushed File Not Showing Correctly on GitHub Raw

### Symptom

Local file shows correct line count, but GitHub raw shows old content.

### Diagnosis

```bash
git rev-parse HEAD
git ls-remote origin main
git show HEAD:runbooks/troubleshooting.md | wc -l

curl -L -s "https://raw.githubusercontent.com/TengkuRizal/TengkuRizal/main/runbooks/troubleshooting.md?cachebust=$(date +%s)" | wc -l
```

### Expected Result

Local HEAD and remote `origin/main` should match.

### Resolution

If raw GitHub is stale, use a cache-busting URL:

```text
https://raw.githubusercontent.com/TengkuRizal/TengkuRizal/main/runbooks/troubleshooting.md?cachebust=1
```

If remote commit does not match local:

```bash
git push origin main
```

---

# Section 2: GitLab CI/CD Issues

## Issue 2.1: Pipeline Fails at Validate Stage

### Symptom

Pipeline fails before deployment during Kubernetes manifest validation.

### Diagnosis

Run locally:

```bash
kubectl apply --dry-run=client -f kubernetes/
```

Server-side validation:

```bash
kubectl apply --dry-run=server -f kubernetes/
```

Check YAML structure:

```bash
find kubernetes -type f -name "*.yaml" -print
```

### Common Causes

- Invalid YAML indentation
- Wrong Kubernetes API version
- Missing required field
- Invalid container port
- Invalid selector or labels
- Wrong namespace reference

### Resolution

Fix the manifest and re-run:

```bash
git add kubernetes/
git commit -m "fix: correct Kubernetes manifest validation issue"
git push origin main
```

---

## Issue 2.2: Pipeline Fails at Gitleaks Secret Scan

### Symptom

Pipeline fails with secret detection findings.

### Diagnosis

Run Gitleaks locally if installed:

```bash
gitleaks detect --source .
```

Check GitLab job logs for file path and line number.

### Common Causes

- API key committed
- Password committed
- Private key committed
- Token inside `.env`
- Kubeconfig accidentally committed
- Cloud credential committed

### Resolution

1. Remove the secret from the file.
2. Rotate the exposed credential immediately.
3. Add secret file patterns to `.gitignore`.
4. Review Git history for exposure.
5. Rewrite history only through an approved process if needed.
6. Re-run the pipeline.

### Prevention

Add `.gitignore` entries:

```text
.env
*.key
*.pem
kubeconfig
admin.conf
secrets.yaml
```

---

## Issue 2.3: Pipeline Fails at Semgrep SAST

### Symptom

Pipeline fails because Semgrep detects insecure code.

### Diagnosis

Review GitLab job logs.

Common findings:

- Insecure command execution
- Hardcoded credentials
- Unsafe deserialization
- Missing input validation
- Insecure HTTP
- Weak cryptography

### Resolution

1. Confirm whether finding is true positive.
2. Fix vulnerable code.
3. Add safe validation or secure library.
4. Commit and push the fix.

```bash
git add .
git commit -m "fix: remediate SAST finding"
git push origin main
```

---

## Issue 2.4: Pipeline Fails at Trivy Config Scan

### Symptom

Pipeline fails due to Kubernetes misconfiguration.

### Diagnosis

Run locally:

```bash
trivy config kubernetes/
```

### Common Causes

- Container running as root
- Missing resource requests and limits
- Privileged container
- HostPath volume usage
- Missing securityContext
- Exposed NodePort service
- Container allows privilege escalation

### Resolution Example

Add security context:

```yaml
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

Add resource limits:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

---

## Issue 2.5: Pipeline Fails at Docker Build

### Symptom

Docker build stage fails.

### Diagnosis

Check GitLab job log and test locally:

```bash
docker build -t test-image:local .
```

### Common Causes

- Dockerfile syntax error
- Missing file in build context
- Wrong working directory
- Package repository unreachable
- Base image unavailable
- Permission issue
- `.dockerignore` excludes required file

### Resolution

Check Dockerfile:

```bash
cat Dockerfile
```

Check build context:

```bash
find . -maxdepth 2 -type f | sort
```

Rebuild:

```bash
docker build --no-cache -t test-image:local .
```

---

## Issue 2.6: Pipeline Fails at Trivy Image Scan

### Symptom

Trivy finds high or critical vulnerabilities.

### Diagnosis

```bash
trivy image REGISTRY/IMAGE_NAME:IMAGE_TAG
```

### Common Causes

- Outdated base image
- Vulnerable OS package
- Vulnerable application dependency
- Unpinned dependency
- Old package manager cache

### Resolution

- Update base image.
- Patch package versions.
- Remove unnecessary packages.
- Rebuild image.
- Re-run scan.

Example:

```bash
docker build -t REGISTRY/IMAGE_NAME:IMAGE_TAG .
trivy image REGISTRY/IMAGE_NAME:IMAGE_TAG
```

---

## Issue 2.7: GitLab Runner Offline

### Symptom

GitLab pipeline is stuck in pending state.

### Diagnosis

On GitLab Runner host:

```bash
sudo gitlab-runner status
systemctl status gitlab-runner --no-pager
sudo gitlab-runner list
```

Check logs:

```bash
journalctl -u gitlab-runner -n 100 --no-pager
```

### Common Causes

- GitLab Runner service stopped
- Runner token invalid
- Runner cannot reach GitLab CE
- DNS issue
- Firewall issue
- Host disk full
- Runner tag mismatch

### Resolution

Restart runner:

```bash
sudo systemctl restart gitlab-runner
sudo gitlab-runner status
```

Check GitLab CE connectivity:

```bash
curl -I http://10.10.1.101
ping -c 4 10.10.1.101
```

---

# Section 3: KUBECONFIG and Kubernetes Authentication Issues

## Issue 3.1: Pipeline Error - You Must Be Logged In to the Server

### Symptom

```text
error: You must be logged in to the server
```

### Diagnosis

Check whether `KUBECONFIG_B64` exists in GitLab CI/CD variables.

Decode locally for validation:

```bash
echo "$KUBECONFIG_B64" | base64 -d > kubeconfig
export KUBECONFIG=$PWD/kubeconfig
kubectl config get-contexts
kubectl get nodes
```

Do not print the kubeconfig content in public logs.

### Common Causes

- Missing `KUBECONFIG_B64`
- Invalid base64 encoding
- Protected variable not available to branch
- Expired certificate
- Wrong context
- Wrong cluster endpoint

### Resolution

Recreate base64 kubeconfig:

```bash
base64 -w 0 ~/.kube/config
```

On macOS:

```bash
base64 < ~/.kube/config | tr -d '\n'
```

Update GitLab CI/CD variable with the corrected value.

---

## Issue 3.2: Certificate Signed by Unknown Authority

### Symptom

```text
certificate signed by unknown authority
```

### Diagnosis

```bash
kubectl config view --minify
kubectl cluster-info
```

Check certificate fields in kubeconfig.

### Common Causes

- Missing certificate authority data
- Wrong kubeconfig generated
- Cluster certificate rotated
- Pipeline using old kubeconfig
- API server endpoint changed

### Resolution

Generate a fresh kubeconfig from the Kubernetes master and update GitLab variable.

Validate:

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Issue 3.3: Wrong Kubernetes Context

### Symptom

Deployment runs against wrong cluster or namespace.

### Diagnosis

```bash
kubectl config current-context
kubectl config get-contexts
kubectl get namespaces
```

### Resolution

Use correct context:

```bash
kubectl config use-context CONTEXT_NAME
```

In pipeline, explicitly set context if needed:

```bash
kubectl config use-context CONTEXT_NAME
```

---

# Section 4: Kubernetes Workload Issues

## Issue 4.1: Pod in ImagePullBackOff

### Symptom

```text
STATUS: ImagePullBackOff
```

### Diagnosis

```bash
kubectl get pods -n NAMESPACE -o wide
kubectl describe pod POD_NAME -n NAMESPACE
```

Check image:

```bash
kubectl get pod POD_NAME -n NAMESPACE -o jsonpath='{.spec.containers[*].image}'
echo
```

### Common Causes

- Wrong image name
- Wrong image tag
- Image not pushed to registry
- Registry authentication issue
- Missing `imagePullSecret`
- Node cannot reach registry
- DNS issue

### Resolution

Check secrets:

```bash
kubectl get secret -n NAMESPACE
```

Check deployment image:

```bash
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

Fix image tag in manifest, then deploy:

```bash
git add kubernetes/
git commit -m "fix: correct container image tag"
git push origin main
```

---

## Issue 4.2: Pod in CrashLoopBackOff

### Symptom

```text
STATUS: CrashLoopBackOff
```

### Diagnosis

```bash
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
kubectl describe pod POD_NAME -n NAMESPACE
```

### Common Causes

- Application startup failure
- Missing environment variable
- Invalid configuration
- Wrong command or args
- Database unavailable
- Permission error
- App binds to wrong port
- Liveness probe too aggressive

### Resolution

Check ConfigMaps and Secrets:

```bash
kubectl get configmap -n NAMESPACE
kubectl get secret -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

Restart after fix:

```bash
kubectl rollout restart deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

---

## Issue 4.3: Pod Pending

### Symptom

```text
STATUS: Pending
```

### Diagnosis

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -30
```

### Common Causes

- Insufficient CPU
- Insufficient memory
- PVC not bound
- Node selector mismatch
- Taints and tolerations issue
- Affinity rules too strict
- Node not ready

### Resolution

Check nodes:

```bash
kubectl describe nodes
kubectl top nodes
```

Check PVC:

```bash
kubectl get pvc -n NAMESPACE
```

Fix resource requests or scheduling rules.

---

## Issue 4.4: Pod OOMKilled

### Symptom

```text
Reason: OOMKilled
```

### Diagnosis

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
kubectl top pod POD_NAME -n NAMESPACE
```

### Common Causes

- Memory limit too low
- Memory leak
- Traffic spike
- Heavy query or batch process
- Application cache growth

### Resolution

Increase memory limit after analysis:

```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"
```

Then redeploy and monitor.

---

## Issue 4.5: Readiness Probe Failed

### Symptom

```text
Readiness probe failed
```

### Diagnosis

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --tail=100
```

### Common Causes

- Wrong readiness path
- Wrong container port
- Application slow to start
- Dependency unavailable
- Health endpoint requires authentication
- Probe timeout too low

### Resolution

Validate endpoint manually:

```bash
kubectl port-forward pod/POD_NAME 8080:CONTAINER_PORT -n NAMESPACE
curl -i http://localhost:8080/health
```

Tune readiness probe:

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
```

---

## Issue 4.6: Liveness Probe Failed

### Symptom

Pod keeps restarting due to liveness probe failure.

### Diagnosis

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

### Common Causes

- Probe too aggressive
- App startup takes too long
- Health endpoint unstable
- CPU starvation
- Application deadlock

### Resolution

Separate readiness and liveness checks.

Example:

```yaml
livenessProbe:
  httpGet:
    path: /live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 20
  timeoutSeconds: 5
```

---

## Issue 4.7: Service Has No Endpoints

### Symptom

```bash
kubectl get endpoints -n NAMESPACE
```

shows no endpoint for service.

### Diagnosis

```bash
kubectl get svc SERVICE_NAME -n NAMESPACE -o yaml
kubectl get pods -n NAMESPACE --show-labels
kubectl get endpoints SERVICE_NAME -n NAMESPACE
```

### Common Causes

- Service selector does not match pod labels
- Pods not ready
- Wrong namespace
- Deployment labels changed
- Readiness probe failing

### Resolution

Compare service selector:

```bash
kubectl describe svc SERVICE_NAME -n NAMESPACE
kubectl get pods -n NAMESPACE --show-labels
```

Fix labels or service selector in Kubernetes manifest.

---

## Issue 4.8: Deployment Rollout Timeout

### Symptom

```text
error: timed out waiting for the condition
```

### Diagnosis

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
kubectl get rs -n NAMESPACE
kubectl get pods -n NAMESPACE -o wide
kubectl get events -n NAMESPACE --sort-by=.metadata.creationTimestamp | tail -30
```

### Common Causes

- New pod not ready
- ImagePullBackOff
- CrashLoopBackOff
- Readiness probe failure
- Insufficient resources
- PVC mount issue

### Resolution

Identify pod-level root cause first. If service impact exists, use rollback runbook.

```bash
kubectl rollout undo deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

---

# Section 5: Kubernetes Node Issues

## Issue 5.1: Node NotReady

### Symptom

```bash
kubectl get nodes
```

shows:

```text
NotReady
```

### Diagnosis

```bash
kubectl describe node NODE_NAME
journalctl -u kubelet -n 100 --no-pager
systemctl status kubelet --no-pager
```

Check container runtime:

```bash
systemctl status containerd --no-pager
crictl ps
```

### Common Causes

- kubelet stopped
- containerd stopped
- network plugin issue
- disk pressure
- memory pressure
- certificate issue
- node cannot reach API server

### Resolution

Restart services:

```bash
sudo systemctl restart containerd
sudo systemctl restart kubelet
```

Check again:

```bash
kubectl get nodes -o wide
```

---

## Issue 5.2: Node DiskPressure

### Symptom

Node condition shows `DiskPressure`.

### Diagnosis

```bash
df -h
sudo du -sh /var/lib/containerd/*
sudo du -sh /var/log/*
crictl images
```

### Resolution

Clean unused images carefully:

```bash
sudo crictl rmi --prune
```

Clean logs if safe:

```bash
sudo journalctl --vacuum-time=7d
```

Check again:

```bash
df -h
kubectl describe node NODE_NAME
```

---

## Issue 5.3: Node MemoryPressure

### Symptom

Node condition shows `MemoryPressure`.

### Diagnosis

```bash
free -h
kubectl top nodes
kubectl top pods -A
```

### Common Causes

- Too many workloads
- Memory limits missing
- Memory leak
- Heavy monitoring workload
- Security tools consuming resources

### Resolution

- Add memory limits.
- Move heavy workloads to larger node.
- Reduce replicas.
- Tune monitoring retention.
- Restart leaking workload only after evidence collection.

---

# Section 6: DNS and Network Issues

## Issue 6.1: Pod Cannot Resolve DNS

### Symptom

Application logs show DNS resolution failure.

### Diagnosis

Run temporary pod:

```bash
kubectl run dns-test --image=busybox:1.36 -it --rm --restart=Never -- nslookup kubernetes.default
```

Check CoreDNS:

```bash
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns --tail=100
```

### Common Causes

- CoreDNS unhealthy
- Upstream DNS issue
- Node DNS issue
- CNI issue
- NetworkPolicy blocking DNS

### Resolution

Restart CoreDNS if required:

```bash
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=300s
```

---

## Issue 6.2: Node Cannot Reach Internet

### Symptom

Apt update, image pull, or external curl fails.

### Diagnosis

```bash
ip route
resolvectl status
ping -c 4 8.8.8.8
ping -c 4 google.com
curl -I https://github.com
```

### Common Causes

- Wrong default gateway
- DNS misconfiguration
- Firewall blocking outbound traffic
- VLAN routing issue
- NAT issue
- Proxy issue

### Resolution

Check Netplan:

```bash
ls -la /etc/netplan
cat /etc/netplan/*.yaml
```

Apply only after careful review:

```bash
sudo netplan try
sudo netplan apply
```

---

## Issue 6.3: Service Not Reachable Through NodePort

### Symptom

NodePort service cannot be reached from browser or curl.

### Diagnosis

```bash
kubectl get svc -n NAMESPACE
kubectl get endpoints -n NAMESPACE
kubectl get pods -n NAMESPACE -o wide
```

Check node port:

```bash
kubectl describe svc SERVICE_NAME -n NAMESPACE
```

Test from node:

```bash
curl -i http://NODE_IP:NODE_PORT
```

### Common Causes

- Firewall blocking NodePort
- Service has no endpoints
- Wrong node IP
- Pod not ready
- kube-proxy issue
- VLAN/firewall routing issue

### Resolution

Check firewall:

```bash
sudo iptables -L -n
sudo ufw status
```

Check kube-proxy:

```bash
kubectl get pods -n kube-system | grep kube-proxy
```

---

# Section 7: Monitoring Issues

## Issue 7.1: Prometheus Target Down

### Symptom

Prometheus target shows `DOWN`.

### Diagnosis

Check ServiceMonitor or ScrapeConfig:

```bash
kubectl get servicemonitor -A
kubectl get scrapeconfig -A
kubectl get pods -n monitoring
```

Check target service:

```bash
kubectl get svc -A | grep exporter
kubectl get endpoints -A | grep exporter
```

### Common Causes

- Exporter not running
- Wrong service label
- Wrong scrape port
- NetworkPolicy blocking scrape
- Prometheus selector mismatch
- Target endpoint unavailable

### Resolution

Verify exporter endpoint:

```bash
curl -i http://EXPORTER_IP:EXPORTER_PORT/metrics
```

Fix labels or scrape configuration.

---

## Issue 7.2: Grafana Dashboard Shows No Data

### Symptom

Grafana panel returns no data.

### Diagnosis

Check Prometheus datasource in Grafana.

Check Prometheus query directly:

```text
up
```

Check Kubernetes metrics:

```bash
kubectl top nodes
kubectl top pods -A
```

### Common Causes

- Wrong PromQL query
- Datasource not configured
- Prometheus target down
- Time range too short
- Metrics not scraped
- Dashboard variable mismatch
- Duplicate instance labels

### Resolution

Use simple query first:

```text
up
```

Then narrow by label:

```text
up{job="node-exporter"}
```

---

## Issue 7.3: Metrics Server Not Working

### Symptom

```bash
kubectl top nodes
```

fails.

### Diagnosis

```bash
kubectl get pods -n kube-system | grep metrics
kubectl logs -n kube-system deployment/metrics-server --tail=100
kubectl get apiservice | grep metrics
```

### Common Causes

- Metrics server unavailable
- TLS issue with kubelet
- Network issue
- APIService not available

### Resolution

Check metrics-server deployment arguments and cluster compatibility.

Validate:

```bash
kubectl top nodes
kubectl top pods -A
```

---

# Section 8: Wazuh Issues

## Issue 8.1: Wazuh Dashboard Not Accessible

### Symptom

Browser cannot access Wazuh dashboard.

### Diagnosis

On Wazuh host:

```bash
sudo systemctl status wazuh-dashboard --no-pager
sudo systemctl status wazuh-manager --no-pager
sudo systemctl status wazuh-indexer --no-pager
ss -tulpen | grep -E '443|5601|9200|1514|1515'
```

### Common Causes

- Dashboard service stopped
- Indexer not healthy
- Port blocked
- Disk full
- Certificate issue
- Firewall issue

### Resolution

Restart services carefully:

```bash
sudo systemctl restart wazuh-indexer
sudo systemctl restart wazuh-manager
sudo systemctl restart wazuh-dashboard
```

Check logs:

```bash
sudo journalctl -u wazuh-dashboard -n 100 --no-pager
sudo journalctl -u wazuh-indexer -n 100 --no-pager
```

---

## Issue 8.2: Wazuh Agent Disconnected

### Symptom

Wazuh dashboard shows agent disconnected.

### Diagnosis

On monitored host:

```bash
sudo systemctl status wazuh-agent --no-pager
sudo journalctl -u wazuh-agent -n 100 --no-pager
```

Check manager connectivity:

```bash
ping -c 4 10.10.1.30
nc -vz 10.10.1.30 1514
nc -vz 10.10.1.30 1515
```

### Common Causes

- Agent service stopped
- Manager unreachable
- Agent key issue
- Firewall issue
- Wrong manager IP
- Time sync issue

### Resolution

Restart agent:

```bash
sudo systemctl restart wazuh-agent
sudo systemctl status wazuh-agent --no-pager
```

---

## Issue 8.3: Wazuh Indexer Disk Full

### Symptom

Wazuh dashboard slow or unavailable, indexer unhealthy.

### Diagnosis

```bash
df -h
sudo du -sh /var/lib/wazuh-indexer/*
sudo journalctl -u wazuh-indexer -n 100 --no-pager
```

### Common Causes

- Log retention too long
- Too much alert data
- Disk undersized
- Index lifecycle policy not tuned

### Resolution

- Increase disk size.
- Tune retention.
- Delete old indices only if safe and approved.
- Restart services after cleanup if needed.

---

# Section 9: Security Onion Issues

## Issue 9.1: Security Onion Console Not Accessible

### Symptom

Browser cannot access Security Onion console.

### Diagnosis

On Security Onion host:

```bash
sudo so-status
ss -tulpen | grep -E '443|80'
df -h
free -h
```

### Common Causes

- Security Onion services not healthy
- Host resource pressure
- Firewall issue
- Wrong IP
- Browser/certificate issue
- Disk full

### Resolution

Check service health:

```bash
sudo so-status
```

Restart only after reviewing service state and logs.

---

## Issue 9.2: No Zeek Logs

### Symptom

Security Onion has no Zeek logs or network visibility.

### Diagnosis

Check interfaces:

```bash
ip link
ip addr
```

Check Security Onion status:

```bash
sudo so-status
```

### Common Causes

- Wrong monitor interface
- No SPAN/mirror traffic
- Interface not receiving packets
- VLAN trunk issue
- Capture service issue
- Sensor not configured correctly

### Resolution

Confirm traffic reaches monitor interface:

```bash
sudo tcpdump -i INTERFACE_NAME -nn
```

If no traffic appears, fix switch/SPAN/VLAN configuration.

---

## Issue 9.3: Suricata Alerts Too Noisy

### Symptom

Too many alerts with low value.

### Diagnosis

Review alert categories and source/destination pairs in Security Onion.

### Common Causes

- Lab traffic generating expected alerts
- Rules too broad
- Scanning tools used in lab
- Repeated noisy signatures
- Misclassified internal traffic

### Resolution

- Tune rules carefully.
- Document expected lab traffic.
- Suppress only known false positives.
- Avoid suppressing alerts without evidence.

---

# Section 10: Storage and Disk Issues

## Issue 10.1: Root Filesystem Full

### Symptom

```text
No space left on device
```

or GitLab Runner pipeline fails to write files.

### Diagnosis

```bash
df -h
sudo du -xh / | sort -h | tail -30
```

Check Docker/containerd:

```bash
docker system df
sudo du -sh /var/lib/docker 2>/dev/null
sudo du -sh /var/lib/containerd 2>/dev/null
```

### Common Causes

- Docker images
- Container logs
- GitLab Runner cache
- Kubernetes images
- Journal logs
- Wazuh/Security Onion logs
- Old artifacts

### Resolution

Docker cleanup:

```bash
docker system prune -af
```

Containerd cleanup:

```bash
sudo crictl rmi --prune
```

Journal cleanup:

```bash
sudo journalctl --vacuum-time=7d
```

Verify:

```bash
df -h
```

---

## Issue 10.2: GitLab Runner Disk Full

### Symptom

Pipeline fails with file write errors.

### Diagnosis

```bash
df -h
sudo du -sh /home/gitlab-runner/*
sudo du -sh /var/lib/gitlab-runner/*
```

### Resolution

Clean runner build directories only after confirming no active jobs:

```bash
sudo gitlab-runner status
sudo rm -rf /home/gitlab-runner/builds/*
sudo rm -rf /home/gitlab-runner/cache/*
```

Restart runner:

```bash
sudo systemctl restart gitlab-runner
```

---

# Section 11: Performance Issues

## Issue 11.1: Application Slow After Deployment

### Symptom

Application responds slowly after deployment.

### Diagnosis

```bash
kubectl top pods -n NAMESPACE
kubectl top nodes
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE --tail=100
```

Check service:

```bash
curl -w "@curl-format.txt" -o /dev/null -s http://APPLICATION_ENDPOINT/health
```

If `curl-format.txt` does not exist, use:

```bash
curl -o /dev/null -s -w "time_total=%{time_total}\n" http://APPLICATION_ENDPOINT/health
```

### Common Causes

- CPU throttling
- Memory pressure
- Slow dependency
- Database issue
- New application bug
- Too few replicas
- Node resource contention

### Resolution

- Check resource requests and limits.
- Scale replicas if appropriate.
- Rollback if impact is severe.
- Review recent code changes.
- Add monitoring or profiling evidence.

---

## Issue 11.2: Kubernetes Cluster Feels Slow

### Diagnosis

```bash
kubectl get nodes -o wide
kubectl top nodes
kubectl get pods -A -o wide
```

Check API server responsiveness:

```bash
time kubectl get pods -A
```

### Common Causes

- Control plane resource pressure
- etcd issue
- Too many pods for homelab resources
- Monitoring stack too heavy
- Disk latency
- Network issue

### Resolution

- Reduce unnecessary workloads.
- Move heavy security workloads to dedicated node.
- Tune monitoring retention.
- Add resources if needed.
- Check disk and memory pressure.

---

# Section 12: Recovery and Escalation

## When to Stop Troubleshooting and Roll Back

Stop troubleshooting and use rollback runbook if:

- Production-style service is unavailable.
- Health check fails after deployment.
- Rollout timeout continues.
- Pod remains in CrashLoopBackOff.
- Security alert indicates risk.
- Troubleshooting exceeds acceptable recovery window.
- User-facing impact is confirmed.

Rollback command:

```bash
kubectl rollout undo deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE --timeout=300s
```

---

## Escalation Criteria

Escalate if:

- Rollback fails.
- Data integrity may be affected.
- Security compromise is suspected.
- Kubernetes control plane is unstable.
- Wazuh or Security Onion reports critical alerts.
- Multiple nodes are NotReady.
- Root filesystem is full on critical systems.
- Repeated failure happens after multiple fixes.

---

## Incident Update Template

```text
Incident Update

Status:
Investigating / Mitigating / Resolved

Affected Component:
GitLab / Kubernetes / Wazuh / Security Onion / Network / Application

Impact:
Describe the service impact.

Detected By:
Pipeline / Monitoring / Health Check / Manual Test / User Report

Current Findings:
Summarize key evidence.

Action Taken:
List commands or recovery steps performed.

Next Action:
Rollback / Continue investigation / Escalate / Monitor
```

---

## Troubleshooting Log Template

| Field | Value |
|---|---|
| Date |  |
| Time |  |
| Engineer |  |
| Affected component |  |
| Symptom |  |
| Severity |  |
| Detection method |  |
| Commands executed |  |
| Key findings |  |
| Root cause |  |
| Fix applied |  |
| Validation result |  |
| Evidence location |  |
| Follow-up action |  |

---

## Post-Fix Validation Checklist

After applying any fix, confirm:

- [ ] Pods are running and ready.
- [ ] Deployment rollout completed.
- [ ] Service has endpoints.
- [ ] Health check passes.
- [ ] Logs show no critical errors.
- [ ] Kubernetes events are clean.
- [ ] GitLab pipeline passes.
- [ ] Wazuh shows no critical alert.
- [ ] Security Onion shows no suspicious traffic.
- [ ] Evidence is captured.
- [ ] Documentation is updated if required.

---

## Interview Explanation

This troubleshooting runbook demonstrates practical operational capability across a DevSecOps homelab.

It shows that the environment is not only built, but also operated and supported with structured troubleshooting steps.

A senior DevOps or SRE engineer should be able to explain:

- How pipeline failures are diagnosed
- How Kubernetes workload failures are handled
- How rollout failures are connected to rollback decisions
- How node-level pressure affects workloads
- How DNS and network issues are isolated
- How Wazuh and Security Onion support security validation
- How evidence is captured before and after fixes
- How repeated issues are converted into better monitoring, automation, or documentation

This runbook supports portfolio credibility because it reflects real operational thinking, not only lab installation steps.

---

## Summary

This troubleshooting runbook provides a structured operational reference for diagnosing and resolving issues across the homelab DevSecOps environment.

It covers:

- Git and GitHub issues
- GitLab CI/CD failures
- GitLab Runner issues
- KUBECONFIG and Kubernetes authentication
- Kubernetes pod, service, deployment, and node issues
- DNS and network troubleshooting
- Prometheus and Grafana monitoring issues
- Wazuh troubleshooting
- Security Onion troubleshooting
- Disk and storage issues
- Performance issues
- Rollback decision points
- Incident communication
- Evidence collection
- Post-fix validation

The goal is to demonstrate production-style troubleshooting discipline and improve operational reliability over time.
