# Backing Up and Restoring Ascender

## Overview

`setup.sh` takes a backup with `-b` and restores one with `-r`. Both options drive the AWX operator's backup and
restore objects, so they work the same way on every platform the installer supports, k3s included, and neither one
needs the cluster to be reachable in any way other than the kubeconfig the installer already uses.

A backup holds the Ascender database and the secrets that go with it, which is what the operator needs to bring a
deployment back. Ledger keeps its own database and is not part of these files.

## Prerequisites

- A running Ascender deployment, and the configuration file the installer was run with.
- A working kubeconfig for the cluster, in the same place the install used.
- The database managed by the operator. When `ASCENDER_PGSQL_HOST` is set, Ascender uses an external database, which
  the operator does not back up. Both options then print a message and stop, and the database has to be covered by
  whatever backup strategy that server already has.

## Taking a Backup

### 1. Run the Backup

```bash
./setup.sh -b
```

The run creates an `AWXBackup` object, waits for the operator to write the backup into its backup volume, and copies
the result back to the machine you ran the installer from.

### 2. Check What It Produced

Backups are written under `ascender_install_artifacts/backups/`:

```bash
ls -l ascender_install_artifacts/backups/
```

Each run leaves a `backup-<timestamp>` directory holding `tower.db`, `secrets.yml` and `awx_object`, and the `current`
symlink points at the newest one:

```
backups/backup-20260823T120000/
backups/current -> backups/backup-20260823T120000
```

### 3. Copy the Backup Somewhere Else

The files live next to the installer, which on a single node k3s install is the same machine that runs the cluster.
Copy the timestamped directory to another host or to your usual backup target, otherwise losing the node loses the
backup with it.

## Restoring a Backup

### 1. Put the Backup In Place

The restore reads `ascender_install_artifacts/backups/current`. After a `-b` run on the same machine it already points
at the newest backup. Otherwise, copy the `tower.db`, `secrets.yml` and `awx_object` files of the backup you want into
that directory, or point the symlink at the timestamped directory you copied back:

```bash
ln -sfn "$PWD/ascender_install_artifacts/backups/backup-20260823T120000" \
        "$PWD/ascender_install_artifacts/backups/current"
```

The restore checks for all three files before it touches the deployment, and stops with the names of the missing ones
if the directory is incomplete.

### 2. Run the Restore

```bash
./setup.sh -r
```

### 3. What the Restore Does

The run takes a fresh backup of the deployment as it stands, so the state you are replacing is still recoverable, and
then it replaces the database:

1. Copies the local backup files into the operator's backup volume.
2. Restores the database credentials from the `secrets.yml` in the backup.
3. Scales down the operator, the web pods and the task pods, then deletes the database volume and recreates it.
4. Creates an `AWXRestore` object that loads the backup into the new database.
5. Scales the operator back up and waits for the database and web pods to come back.

### 4. Verify

```bash
kubectl get pods -n ascender
curl -sS http://ascender.mycompany.com/api/v2/ping/
```

Then log in and confirm your job templates, projects and credentials are the ones from the backup.

## Restoring Onto a Rebuilt k3s Node

A backup is restored into a running deployment, so a node that was rebuilt needs Ascender installed again first:

1. Run `./setup.sh` with the configuration file the original install used, and let it finish.
2. Copy the backup directory back under `ascender_install_artifacts/backups/` and point `current` at it.
3. Run `./setup.sh -r`.

Use the same `ASCENDER_HOSTNAME` as the original install. A restore replaces the database, not the hostname the
deployment is published under, so moving to a different name is a separate change to the configuration file.

## Notes

- The admin password in the restored database is the one from the backup, not the value in your configuration file.
- Backups taken by the operator stay in the cluster until the `AWXBackup` object is deleted. `-b` leaves one object
  per run, so remove the old ones with `kubectl delete awxbackup -n ascender <name>` when the backup volume grows.
- Execution environments, projects and inventories are restored from the database, but anything a job wrote to a
  project volume by hand is not part of the backup.
