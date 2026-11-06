# dev

The `dev` environment. Both roots were applied once. The persistent group exists, and the session layer was destroyed. It has two Terraform roots, one per layer, each with its own state file in the `tfstate-dev` container:

- `persistent/`: resources that outlive a session. The resource group is applied. The monitoring workspaces, Key Vault and the identity for pull request plans are written and not applied.
- `session/`: resources that are created and destroyed each session.
