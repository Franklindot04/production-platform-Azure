# dev

The `dev` environment. Planned. It has two Terraform roots, one per layer, each with its own state file in the `tfstate-dev` container:

- `persistent/`: resources that outlive a session.
- `session/`: resources that are created and destroyed each session.
