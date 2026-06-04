# Runbooks

## Overview

This directory contains operational runbooks for the homelab DevSecOps environment.

The purpose of these runbooks is to document how deployment, rollback, troubleshooting, validation, and recovery activities are performed in a controlled and repeatable way.

These documents are written to demonstrate production-style DevOps/SRE operational discipline, including:

- Change control
- Deployment validation
- Rollback readiness
- Incident-style troubleshooting
- Security monitoring
- Evidence collection
- Post-fix validation
- Continuous improvement

> Note: All IP addresses shown in the runbooks are private homelab addresses and do not expose public infrastructure.

---

## Runbook Index

| Runbook | Purpose | When to Use |
|---|---|---|
| [Deployment Runbook](deployment-runbook.md) | Documents the end-to-end deployment process for workloads in the homelab DevSecOps environment | Use before, during, and after application or infrastructure deployment |
| [Rollback Runbook](rollback-runbook.md) | Documents controlled recovery procedures when a deployment fails or causes instability | Use when a deployment causes service impact, failed health checks, or security concerns |
| [Troubleshooting Runbook](troubleshooting.md) | Documents operational troubleshooting steps across GitLab, Kubernetes, Wazuh, Security Onion, monitoring, DNS, storage, and network issues | Use when diagnosing pipeline failures, workload issues, node issues, monitoring issues, or security visibility problems |
| [GitOps Deployment Runbook](gitops-deployment-runbook.md) | Documents ArgoCD-based GitOps deployment, sync, validation, troubleshooting, and rollback process | Use when deploying or recovering workloads managed by ArgoCD |
| [Alert Response Runbook](alert-response-runbook.md) | Documents Prometheus/Alertmanager alert validation, response, restoration, evidence capture, and post-incident review | Use when workload availability alerts fire |

---

## Environment Covered

These runbooks are designed around the following homelab DevSecOps components:

| Component | Role |
|---|---|
| GitLab CE | Source control and CI/CD orchestration |
| GitLab Runner | Pipeline execution |
| Kubernetes | Container orchestration and workload deployment |
| Docker | Container image build and runtime testing |
| Wazuh | Security monitoring and alerting |
| Security Onion | Network visibility and traffic analysis |
| Prometheus | Metrics collection |
| Grafana | Dashboard visualization |
| Linux nodes | Compute, networking, and operational services |

---

## Operational Flow

The runbooks are intended to support the following operational workflow:

```text
Plan Change
    ↓
Validate Code and Configuration
    ↓
Run CI/CD Pipeline
    ↓
Deploy to Kubernetes
    ↓
Verify Application Health
    ↓
Monitor Security and Network Signals
    ↓
Capture Evidence
    ↓
Rollback or Troubleshoot if Required
    ↓
Document Lessons Learned
```

---

## How to Use These Runbooks

### 1. Before Deployment

Use the [Deployment Runbook](deployment-runbook.md) to confirm:

- Git status is clean.
- Kubernetes nodes are healthy.
- CI/CD variables are available.
- Security scans are expected to pass.
- Rollback method is understood.
- Monitoring tools are available.

---

### 2. During Deployment

Use the [Deployment Runbook](deployment-runbook.md) to verify:

- Pipeline stages are successful.
- Kubernetes manifests are applied correctly.
- Pods are running and ready.
- Services have endpoints.
- Health checks pass.
- Logs show no critical errors.

---

### 3. If Deployment Fails

Use the [Rollback Runbook](rollback-runbook.md) when:

- Rollout times out.
- Pods enter `CrashLoopBackOff`.
- Pods enter `ImagePullBackOff`.
- Health check fails.
- Service has no endpoints.
- Wazuh reports critical alerts.
- Security Onion detects suspicious traffic.
- User-facing functionality is broken.

---

### 4. During Troubleshooting

Use the [Troubleshooting Runbook](troubleshooting.md) to diagnose:

- Git and GitHub issues
- GitLab CI/CD failures
- GitLab Runner issues
- KUBECONFIG problems
- Kubernetes pod failures
- Kubernetes service issues
- Node pressure
- DNS and network connectivity
- Prometheus and Grafana issues
- Wazuh issues
- Security Onion issues
- Disk and storage problems

---

## Evidence Collection

The runbooks recommend collecting sanitized evidence under the `evidence/` directory.

Example evidence:

```text
evidence/
├── deployment-status.md
├── health-check-result.md
├── rollout-status.md
├── pipeline-result.md
├── monitoring-check.md
└── troubleshooting/
```

Evidence should help prove:

- What was checked
- What failed
- What was fixed
- What was validated
- What was learned

Do not commit:

- Passwords
- Tokens
- Private keys
- Secret values
- Full kubeconfig files
- Sensitive screenshots
- Customer data

---

## Portfolio Value

These runbooks are included to demonstrate practical DevOps/SRE skills beyond basic lab installation.

They show the ability to:

- Operate a DevSecOps environment
- Troubleshoot real infrastructure and pipeline issues
- Validate deployments safely
- Recover from failed releases
- Monitor security and network signals
- Capture operational evidence
- Communicate incident-style updates
- Improve reliability over time

This is aligned with responsibilities commonly expected in DevOps, DevSecOps, Platform Engineering, and Site Reliability Engineering roles.

---

## Interview Talking Points

These runbooks can be used to explain:

- How deployments are validated before release
- How GitLab CI/CD is connected to Kubernetes
- How security checks are integrated into the deployment process
- How rollback decisions are made
- How Kubernetes workload failures are diagnosed
- How Wazuh and Security Onion support security validation
- How monitoring and logs are used during troubleshooting
- How evidence is captured for audit and learning
- How the homelab simulates production-style operations

---

## Runbook Maintenance

These runbooks should be updated when:

- A new tool is added to the homelab
- A new failure scenario is discovered
- A repeated issue needs better documentation
- Pipeline stages are changed
- Kubernetes architecture changes
- Monitoring dashboards are improved
- Security tooling is expanded
- A post-incident review identifies missing steps

---

## Current Runbook Set

```text
runbooks/
├── README.md
├── deployment-runbook.md
├── rollback-runbook.md
└── troubleshooting.md
```

---

## Summary

The runbooks in this directory provide operational documentation for running, validating, recovering, and troubleshooting a homelab DevSecOps platform.

They are designed to show production-style thinking, not only technical setup.

The main objective is to demonstrate that the environment can be operated with reliability, security awareness, and repeatable processes.
