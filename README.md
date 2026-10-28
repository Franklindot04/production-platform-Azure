# Production Platform / Azure

An Azure production-oriented SRE/DevOps platform focused on infrastructure automation, reliable application delivery, observability, security, and operational resilience.

## Overview

This project demonstrates how to design, deploy, and operate production-oriented cloud infrastructure on Microsoft Azure using modern DevOps, Site Reliability Engineering (SRE), and Platform Engineering practices.

The platform emphasizes repeatable infrastructure provisioning, automated delivery, measurable reliability, proactive monitoring, incident response, and controlled recovery.

## Technology Stack

- **Cloud:** Microsoft Azure
- **Infrastructure as Code:** Terraform
- **Container Orchestration:** Azure Kubernetes Service (AKS)
- **CI/CD:** GitHub Actions
- **GitOps:** Argo CD
- **Application Packaging:** Docker and Helm
- **Observability:** Azure Monitor, Prometheus, Grafana, and OpenTelemetry
- **Security:** Microsoft Entra ID, Azure Key Vault, and Azure RBAC
- **Reliability:** SLOs, error budgets, alerting, incident management, and recovery automation

## Core Objectives

- Provision Azure infrastructure using reusable Terraform modules.
- Automate application build, testing, security checks, and deployment.
- Manage Kubernetes workloads through declarative GitOps workflows.
- Monitor application health, infrastructure performance, and service availability.
- Define and measure Service Level Objectives (SLOs) and error budgets.
- Implement actionable alerting, incident response, and operational runbooks.
- Test failure scenarios, deployment rollbacks, and recovery procedures.
- Apply security controls, least-privilege access, and cloud cost optimization.

## Architecture

The intended workflow is:

```text
Source Code
    |
    v
GitHub Actions
    |
    v
Build, Test & Security Scanning
    |
    v
Azure Container Registry
    |
    v
Argo CD / GitOps
    |
    v
Azure Kubernetes Service
    |
    v
Application Services
    |
    v
Azure Monitor / Prometheus / Grafana
    |
    v
Alerting, Incident Response & Recovery
```

## Project Structure

The repository will evolve to include:

- `infrastructure/` — Terraform modules and Azure environments.
- `applications/` — Application source code and tests.
- `kubernetes/` — Kubernetes manifests and deployment configuration.
- `helm/` — Helm charts.
- `gitops/` — Argo CD applications and environment definitions.
- `monitoring/` — Dashboards, metrics, and alerting rules.
- `security/` — Security policies and scanning configuration.
- `docs/` — Architecture decisions, runbooks, and postmortems.

## Reliability & Validation

Reliability will be evaluated through measurable SLOs, load testing, controlled failure scenarios, alert validation, deployment rollback exercises, and recovery testing.

Test results and operational documentation will be used to assess system behavior and identify improvements.

## Project Status

**Status:** In development.

Components will be implemented and validated incrementally. Architecture diagrams, deployment instructions, test results, and operational documentation will be updated as the project progresses.

## Goals

Build a practical, reproducible Azure platform that demonstrates production-oriented DevOps and SRE engineering, from infrastructure provisioning and secure delivery to observability, incident response, and service recovery.
