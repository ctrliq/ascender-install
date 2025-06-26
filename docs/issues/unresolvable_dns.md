# Issue: Ascender Website Not Loading Due to DNS Resolution Failure

## Issue Summary

After installation, the Ascender web interface does not load, and attempts to access it via the browser result in DNS resolution failures. For example:

```
DNS_PROBE_FINISHED_NXDOMAIN
```
or
```
curl: (6) Could not resolve host: ascender.mycompany.com
```

### Root Cause

This issue is typically caused by one of the following misconfigurations:

- The `ASCENDER_HOSTNAME` variable was **not set correctly** during setup. It must be set to a fully-qualified domain name (FQDN) under your control (e.g., `ascender.mycompany.com`).
- A corresponding **DNS record** (usually an `A` or `CNAME` record) for the FQDN does **not exist** or was not created in your DNS provider.

## Resolution Steps

### 1. Verify `ASCENDER_HOSTNAME` Configuration

Check your installation configuration (e.g., environment files or Ansible variables) and confirm that `ASCENDER_HOSTNAME` is set to a valid FQDN:

```bash
grep "ASCENDER_HOSTNAME:" custom.config.yml
```

If it is blank or incorrectly set, update the value and re-run the setup process.

### 2. Confirm DNS Record Exists

Ensure that a DNS record exists for your hostname. You can use `dig` or `nslookup` to test from your terminal.

#### Using `dig`:

``` bash
dig ascender.mycompany.com +short  
123.45.67.89
```

If the output is empty, the DNS entry does not exist or is not propagated yet.

#### Using `nslookup`:

```bash
nslookup ascender.mycompany.com
```

Expected output includes the DNS server and resolved IP address. If you see "server can't find", then DNS is not resolving properly.

### 3. Create or Update the DNS Record

Log into your DNS provider and add a record for `ascender.mycompany.com`. Common setups:

- **A Record**: Pointing to the external IP address of your Ascender host (not the internal Kubernetes IP)
- **CNAME Record**: Pointing to another FQDN (for example, pointing to the servers hostname)

Allow a few minutes for the record to propagate (or longer depending on TTL).

## Notes

- For local development, you may add a line to your workstations `/etc/hosts` file (Linux) or `c:\windows\system32\drivers\etc\hosts` (Windows) as a temporary workaround:
```bash
192.168.1.100 ascender.mycompany.com
```
- You can verify ingress status with:
```bash
kubectl get ingress -A
```

