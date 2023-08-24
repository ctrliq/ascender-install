#prerequisites
- Rocky Linus 8 or 9 server with public internet access
- Following open ports:
  - 22
  - 80
  - 443
  - 6443 (kubeapi server)

#Install k3s
https://docs.k3s.io/quick-start

obtain kubeconfig file and place it on local server at ~/.kube/config, replacing the kubeapiserver address from 127.0.0.1 to the public IP address of the server
https://docs.k3s.io/cluster-access

Change the inventory file to reflect the username on the k3s server that will be used in running ascender install. This user should be able to sudo into root.

Run `sudo ./setup` from top level directory in this git repo
