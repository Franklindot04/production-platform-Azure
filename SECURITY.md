# Security policy

## Supported versions

The latest release is v0.2.0. Only the `main` branch is maintained.

## Reporting a vulnerability

Do not open a public issue for a vulnerability.

Use one of these:

- GitHub private vulnerability reporting: go to the [Security tab](https://github.com/Franklindot04/production-platform-Azure/security/advisories/new) of this repository and open a new report.
- Email ajerofranklin_dev@proton.me.

## What to include

- What you found.
- Where it is (file, line, or configuration).
- Steps to reproduce it.
- The impact, as far as you can tell.

## What to expect

This project has one maintainer. Replies are best effort. The aim is to acknowledge a report within 7 days. There are no promises beyond that, including fix dates.

## Leaked credentials

A credential committed to this repository counts as a security report. This includes keys, tokens, passwords, certificates, and connection strings. Report it the same way. Do not open a public issue.

## Scope

The repository holds documentation, Terraform for the `dev` environment, a sample service with its Helm chart, Kubernetes and GitOps manifests, and GitHub Actions workflows. The cluster exists only while a live session runs. The session layer, which holds the cluster, is created at the start of a session and destroyed at the end. The scope will grow as code is added, and this file will be updated when it does.
