# infrastructure

Terraform for the platform. Planned. No resources are defined yet.

- `bootstrap/`: the Azure CLI script that creates the state backend. It is not a Terraform root.
- `modules/`: shared modules. Planned.
- `environments/<env>/`: one folder per environment, each with a persistent and a session root. Only `dev` exists. `staging` and `prod` are added when they are needed.

There are two Terraform roots today, `environments/dev/persistent` and `environments/dev/session`. Each environment root is its own Terraform configuration. Terraform workspaces are not used. Environment inputs are written in `.tf` files, because `.gitignore` excludes `*.tfvars`.

See [ADR 0010](../docs/adr/0010-environment-separation.md) and section 9 of [the architecture document](../docs/architecture.md).
