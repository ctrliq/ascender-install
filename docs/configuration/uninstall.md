# Uninstalling Ascender or Ledger

### Using deployment manifests
After running `setup.sh`, `tmp_dir` will contain timestamped kubernetes manifests for:

- `ascender-deployment-{{ k8s_platform }}.yml`
- `ledger-{{ k8s_platform }}.yml` (if you installed Ledger)
- `kustomization.yml`

There will be several, so find the latest and remove the timestamp from the filename and then run the following
commands from within `tmp_dir`:

The `ascender-deployment` file will remove Ascender and the `ledger` file will remove the Ledger installation. The last command will remove the awx-operator deployment.

- `$ kubectl delete -f ascender-deployment-{{ k8s_platform }}.yml`
- `$ kubectl delete -f ledger-{{ k8s_platform }}.yml`
- `$ kubectl delete -k .`

Running the Ascender deletion will remove all related deployments and
statefulsets, however, persistent volumes and secrets will remain. To
enforce secrets also getting removed, you can use
`ascender_garbage_collect_secrets: true` in the `default.config.yml`
file.


### Removing Namespaces
Another way to completely remove Ascender or Ledger is by deleting its namespace.

- ***This will delete all resources in the namespace, including PVCs, without prompting.  So be sure you are deleting the proper namespace and that only Ascender / Ledger lives in that namespace***

```bash
kubectl delete namespace ascender
kubectl delete namespace ledger
```

In Ascender's case, if the namespace deletion hangs and you had previously setup Automation Mesh, you may need take [additional steps](../issues/delete_namespace.md).
