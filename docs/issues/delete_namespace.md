# Issue: Namespace Deletion Hangs When Automation Mesh Is Enabled

## Issue Summary

When attempting to delete the `ascender` namespace in a Kubernetes cluster with **Automation Mesh** enabled, the deletion process hangs and never completes. This occurs because a finalizer on the **AWX Mesh Ingress** resource prevents the namespace from terminating.

### Root Cause

Automation Mesh is enabled by setting the `ASCENDER_MESH_HOSTNAME` environment variable. This configuration creates an `Ingress` object (specifically an `awxmeshingress.awx.ansible.com` custom resource). When the `ascender` namespace is deleted, the finalizer on this resource blocks deletion until it is manually cleared.

## Symptoms

- Running `kubectl delete namespace ascender` hangs indefinitely.
- Inspecting the namespace shows a `Terminating` status.
- The `awxmeshingress.awx.ansible.com` resource named `ascender-app-mesh` exists with finalizers.

After attempting to delete the namespace, you can verify what remains by executing this command.
```bash
kubectl api-resources --verbs=list --namespaced -o name   | xargs -n 1 kubectl get --show-kind --ignore-not-found -n ascender
```

You should only see this object remaining.
```
ingressroutetcp.traefik.io/ascender-app-mesh
```

## Resolution Steps

To resolve this issue, manually remove the finalizers from the AWX Mesh Ingress resource and reattempt the namespace deletion.

### 1. Initiate Namespace Deletion (Without Waiting)
This starts the deletion process without blocking the shell, allowing you to proceed to the next step.

```bash
kubectl delete --wait=false namespace ascender
```

### 2. Remove Finalizers From the Mesh Ingress
This command removes the finalizers that are preventing the namespace from being deleted.

```bash
kubectl patch awxmeshingress.awx.ansible.com/ascender-app-mesh -n ascender -p '{"metadata":{"finalizers":[]}}' --type=merge
```
After running this command, the namespace deletion should continue.

### 3. Retry Namespace Deletion
Now lets attempt to delete the namespace again to verify its gone.

```bash
kubectl delete namespace ascender
```
This time, the namespace should be deleted successfully.


## Notes

* Ensure you have cluster-admin privileges to modify finalizers and delete namespaces.
* This issue only arises when Automation Mesh is enabled via the ASCENDER_MESH_HOSTNAME environment variable.
* Consider filing a bug report or enhancement request if deleting the namespace continues to hang in your deployment.

## References

[Kubernetes Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)

[AWX Automation Mesh Documentation](https://github.com/ansible/awx-operator/blob/2.19.1/docs/user-guide/advanced-configuration/mesh-ingress.md?plain=1)