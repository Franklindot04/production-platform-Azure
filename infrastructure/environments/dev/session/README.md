# dev session layer

Planned. Will hold the resources of `dev` that are created at the start of a session and destroyed at the end: the virtual network and the AKS cluster.

State file: `session.tfstate` in the `tfstate-dev` container. The backend is not configured yet.

The root has version constraints only. It defines no resources yet.
