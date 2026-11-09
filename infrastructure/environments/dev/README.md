# dev

The `dev` environment. The persistent root is applied. The session root was applied once, and the session layer was destroyed. It has two Terraform roots, one per layer, each with its own state file in the `tfstate-dev` container:

- `persistent/`: resources that outlive a session. The resource group, the monitoring workspaces, the alerts, the Key Vault, the identity for pull request plans and the identity of the sample service with its Key Vault roles are applied.
- `session/`: resources that are created and destroyed each session. The workload identity settings on the cluster and the federated credential for the sample service are written and not applied.
