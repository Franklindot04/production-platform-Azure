# dev

The `dev` environment. Both roots define resources and have been planned. Nothing is applied. It has two Terraform roots, one per layer, each with its own state file in the `tfstate-dev` container:

- `persistent/`: resources that outlive a session.
- `session/`: resources that are created and destroyed each session.
