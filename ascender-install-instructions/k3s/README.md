# Prerequisites
- Server on which Ascender will run:
  - Rocky Linux 8 or 9 server with public internet access
  - Following open ports:
    - 22
    - 80
    - 443
    - 6443 (kubeapi server)
- Optional external postgres server that the asender application can access
  - Following open ports:
    - 5432 or whatever port you have the PostgreSQL server listening on


# Install k3s on the server on which ascender will run ([Reference](https://docs.k3s.io/quick-start))
- K3s provides an installation script that is a convenient way to install it as a service on systemd or openrc based systems. This script is available at https://get.k3s.io. To install K3s using this method, just run:
  - `$curl -sfL https://get.k3s.io | sh -`
  - NOTE: A k3s installation of Ascender assumes a single node cluster that will double as both a master and worker

# Ensure kubectl access to k3s cluster ([Reference](https://docs.k3s.io/cluster-access))
- If running the installation script from a remote location
  - Copy the kubeconfig file from its default location on the k3s master node (`/etc/rancher/k3s/k3s.yaml`) and place it on local server at `~/.kube/config`
  - Edit `~/.kube/config`, replacing the kubeapiserver address from 127.0.0.1 to a remotely accessible IP address of the master node
- If running the installation script from the k3s master node itself
  - Copy the kubeconfig file from its default location on the k3s master node (`/etc/rancher/k3s/k3s.yaml`) `~/.kube/config`


# Run the setup script
Change the inventory file to reflect the username on the k3s server that will be used in running ascender install. This user should be able to sudo into root.

Run `sudo ./setup` from top level directory in this git repo
