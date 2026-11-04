# dev persistent layer

Planned. Will hold the resources of `dev` that outlive a session: Key Vault and the monitoring workspaces. The container registry is an open question.

State file: `persistent.tfstate` in the `tfstate-dev` container. The backend is not configured yet.

The root has version constraints only. It defines no resources yet.
