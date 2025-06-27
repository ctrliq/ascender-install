# Issue: Installation Fails While Waiting for Ascender API to Come Up

## Issue Summary

During installation, the following task fails after several retry attempts:

```shell
TASK [ascender_install : Wait until Ascender API is Up (This may take between 10-20 mins)]
...
FAILED - RETRYING: [localhost]: Wait until Ascender API is Up (This may take between 10-20 mins) (0 retries left)
fatal: [localhost]: FAILED! => {"attempts": 200, "changed": false, "content": "", "elapsed": 0, "msg": "Status code was -1 and not [200]: Request failed: <urlopen error [Errno -2] Name or service not known>", "redirected": false, "status": -1, "url": "https://ascender.example.com:443/api/v2/ping/"}
```

This task is responsible for polling the Ascender API until it becomes responsive. While this can take several minutes, in some cases the task eventually fails even though the pods are up and running.

### Important Note

Seeing repeated **FAILED - RETRYING** messages during this task is **normal**. Ansible displays a failure message for each retry attempt, even if it eventually succeeds. The task only truly fails if you see `(0 retries left)` and the setup ends.

## Troubleshooting

If you see the task fail completely, you can check the current status of the Ascender pods with:

```bash
kubectl get pods -n ascender
```

Example output:

```
NAME                                               READY   STATUS      RESTARTS   AGE
ascender-app-mesh-5c995776b-kx47m                  1/1     Running     0          7m7s  
ascender-app-migration-25.0.0-zztfc                0/1     Completed   0          5m17s  
ascender-app-postgres-15-0                         1/1     Running     0          6m41s  
ascender-app-task-856fffc6c8-9tjkx                 4/4     Running     0          5m41s  
ascender-app-web-cfc554686-zfpqw                   3/3     Running     0          5m45s  
awx-operator-controller-manager-58b7c97f4b-5fdvd   2/2     Running     0          8m1s
```
If your pods look similar — with all components `Running` or `Completed` — then the issue is likely related to DNS resolution.

## Root Cause

The task fails because the target system (where Ansible is running) is unable to resolve the hostname specified in the `ASCENDER_HOSTNAME` variable. The installer attempts to contact the Ascender API using that hostname, but if DNS is not properly configured, the check fails.

## Resolution Steps

### Option 1: Fix DNS Resolution on the Host

Ensure the host running the installer can resolve the value of `ASCENDER_HOSTNAME`. Test DNS resolution with:

```bash
dig ascender.example.com +short
```
or

```bash
nslookup ascender.example.com
```

If the domain does not resolve, ensure your DNS provider has the correct `A` or `CNAME` record and that your host is using the correct DNS server(s).

### Option 2: Use `/etc/hosts` Instead

If you're in a development or test environment and cannot fix DNS, you can instruct the installer to use the `/etc/hosts` file for hostname resolution. Set the following variable in your installer configuration:

```yaml
use_etc_hosts: true
```

This will add the appropriate hostname and IP mapping to the local `/etc/hosts` file during setup, allowing the installer to access the API and continue.
