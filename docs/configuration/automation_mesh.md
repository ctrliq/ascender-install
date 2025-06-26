# Configuration Guide: Enabling Automation Mesh for Ascender

## Overview

Automation Mesh allows Ascender to communicate and launch jobs from Execution Nodes.  In order to achieve this, as Ascender is running in a Kubernetes environment, we setup a `hop node` inside the Kubernetes cluster that acts as a bridge between Execution Nodes and the Ascender control plane.  This `hop node` is accessed via an `ingress` using a custom URL, instead of over the normal receptor port.


## Prerequisites

- A running Ascender installation inside a Kubernetes cluster
- DNS access or `/etc/hosts` modification on Execution Nodes
- Access to edit your `default.config.yml` used by the Ascender installer

## Configuration Steps

### 1. Set `ASCENDER_MESH_HOSTNAME` in Your Config File

Open your `default.config.yml` file and uncomment the `ASCENDER_MESH_HOSTNAME` variable with the hostname you want Execution Nodes to use. Example:

```yaml
ASCENDER_MESH_HOSTNAME: mesh.ascender.mycompany.com
```

This url must be different than the ASCENDER_HOSTNAME url.

This will instruct the installer to create the `hop node` and a Kubernetes ingress for the `hop node` under the specified hostname.

> ⚠️ If this variable is **not set**, the installer will **skip** mesh ingress setup entirely.

### 2. Re-run Installer

After setting `ASCENDER_MESH_HOSTNAME`, re-run the installer:

```bash
./setup.sh
```

This will:

- Create a new Kubernetes ingress for the hop node
- Configure internal mesh routing via hostname

### 3. Configure DNS or `/etc/hosts` for Resolution

#### Preferred: DNS Resolution

Ensure that `mesh.ascender.mycompany.com` resolves to the appropriate internal IP address or DNS name of your cluster's ingress controller or VIP.

You can test this from your Execution Node with:

```bash
nslookup mesh.ascender.mycompany.com  
ping mesh.ascender.mycompany.com
```

#### Alternative: Use `/etc/hosts`

If you don’t have internal DNS resolution available, you can manually define the mapping in `/etc/hosts` on each Execution Node:

```bash
sudo echo "192.168.1.50 mesh.ascender.mycompany.com" >> /etc/hosts
```

Replace `192.168.1.50` with the correct IP of your cluster’s ingress endpoint.

## Verifying Installation

Once installed, confirm that the ingress was created:

```bash
kubectl get ingressroutetcp.traefik.io -n ascender
```

You should see an entry for `ascender-app-mesh`.  Describing the resource will show a route match with the hostname you defined and point to the Service on the normal receptor port 21799.

```bash
kubectl describe ingressroutetcp.traefik.io/ascender-app-mesh -n ascender
```

```yaml
Name:         ascender-app-mesh
Namespace:    ascender
Labels:       <none>
Annotations:  <none>
API Version:  traefik.io/v1alpha1
Kind:         IngressRouteTCP
Metadata:
  Generation:          1
  Owner References:
    API Version:     awx.ansible.com/v1alpha1
    Kind:            AWXMeshIngress
    Name:            ascender-app-mesh
    UID:             4e2e05e2-2e89-406b-af56-1e2795cff176
  Resource Version:  3405
  UID:               3abb75aa-f74e-42b2-ba64-fa7125c9578c
Spec:
  Entry Points:
    websecure
  Routes:
    Match:  HostSNI(`mesh.ascender.mycompany.com`)
    Services:
      Name:  ascender-app-mesh
      Port:  27199
  Tls:
    Passthrough:  true
Events:           <none>

```

## Notes

- If you ever need to disable the mesh, simply remove `ASCENDER_MESH_HOSTNAME` from your config and re-run the installer.
- Execution Nodes must be able to reach the hostname via TCP (usually HTTPS).
- Ingress class and controller must be properly configured in the cluster for this to work.

## Example

Here’s a minimal example section from `default.config.yml`:

```yaml
ASCENDER_HOSTNAME: ascender.mycompany.com  
ASCENDER_MESH_HOSTNAME: mesh.ascender.mycompany.com
```
## References

[AWX Automation Mesh Documentation](https://github.com/ansible/awx-operator/blob/2.19.1/docs/user-guide/advanced-configuration/mesh-ingress.md?plain=1)