# Choosing the PostgreSQL Instance for Ascender React

Ascender React (EDA) needs a PostgreSQL database. The installer offers three ways to
provide one, selected with `REACT_PGSQL_MODE` in `default.config.yml` (or
`custom.config.yml`).

| `REACT_PGSQL_MODE` | Where the data lives | Who creates the database and roles |
|---|---|---|
| `managed` (default) | `ascender-react-postgres` StatefulSet in `REACT_NAMESPACE` | the EDA Operator |
| `ascender` | the instance Ascender already runs, in its own database | the installer |
| `external` | a server you run yourself | you, before the install |

## Why this is not just a hostname

The EDA Operator decides whether it owns the database purely from the `type` key of the
PostgreSQL configuration secret it finds in `REACT_NAMESPACE`: `managed` means it
deploys and runs the StatefulSet, anything else means it keeps its hands off. And when
it keeps its hands off it also refuses to reconcile at all unless it is given a second
secret for the event-stream database user, because that is a role it can only create by
itself on an instance it manages.

So `playbooks/roles/ascender_react/tasks/react_postgres.yml` builds both secrets, and
for the `ascender` mode creates the database and both roles first. It also applies a
NetworkPolicy that lets React's pods reach the server: the operator's own policy opens
port 5432 only towards the PostgreSQL pod it manages, which cuts the migration pods off
from any other instance.

## `managed`

Nothing to configure. React gets its own PostgreSQL pod and PVC beside Ascender's.
Simple, and the mode to keep on a cluster where the two products are sized separately.

## `ascender` - one database server for both products

```yaml
REACT_PGSQL_MODE: ascender
REACT_PGSQL_DB: react
REACT_PGSQL_USER: react
REACT_PGSQL_PWD: "somethingwithoutspecialcharacters"
REACT_PGSQL_EVENT_STREAM_USER: react_event_stream
```

Ascender must be installed first: the installer reads its connection details from the
`ascender-app-postgres-configuration` secret in `ASCENDER_NAMESPACE`, then runs `psql`
inside the Ascender PostgreSQL pod to create `REACT_PGSQL_USER`, the database it owns,
and the event-stream role with `CONNECT` on it. React's pods reach the instance through
`ascender-app-postgres-15.<ASCENDER_NAMESPACE>.svc.cluster.local`.

The two products keep separate databases in one server, so they share the resources,
the backup and the upgrade cycle but not a schema. If Ascender itself points at an
external server (`ASCENDER_PGSQL_HOST`), React follows it there - but then the database
and the roles have to be created by hand, exactly as for `external` below, because the
installer has no superuser shell on that server.

### Switching an existing install

Changing the mode of a React install that already has data does not migrate anything.
The operator stops using the old database and runs its migrations against the new, empty
one; React starts over with a fresh admin user and no rulebook activations. The old
`ascender-react-postgres-15` StatefulSet and its PVC are left in place - the operator
does not delete what it no longer manages - so the old data is still there if you need
to dump it, and the StatefulSet can be removed by hand once you are sure you do not.

## `external`

```yaml
REACT_PGSQL_MODE: external
REACT_PGSQL_HOST: "reactpghost.example.com"
REACT_PGSQL_PORT: 5432
REACT_PGSQL_DB: react
REACT_PGSQL_USER: react
REACT_PGSQL_PWD: "somethingwithoutspecialcharacters"
REACT_PGSQL_EVENT_STREAM_USER: react_event_stream
REACT_PGSQL_EVENT_STREAM_PWD: "anotherpassword"
REACT_PGSQL_SSLMODE: prefer
```

Create these before running the install:

```sql
CREATE ROLE "react" WITH LOGIN PASSWORD '...';
CREATE DATABASE "react" OWNER "react";
CREATE ROLE "react_event_stream" WITH LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE "react" TO "react_event_stream";
```

The NetworkPolicy the installer applies in this mode opens egress on the configured port
to any address, since a server outside the cluster has no namespace or pod to select.

## Checking which instance is in use

```bash
kubectl -n react get secret | grep postgres
kubectl -n react get deploy ascender-react-api \
  -o jsonpath='{.spec.template.spec.containers[0].env}' | tr ',' '\n' | grep -A1 EDA_DB_HOST
```

A `ascender-react-postgres-external-configuration` secret means React is on a shared or
external instance; only `ascender-react-postgres-configuration` means the operator is
managing its own. On a shared instance the tables are visible with:

```bash
kubectl -n ascender exec ascender-app-postgres-15-0 -c postgres -- \
  psql -d react -tAc "select count(*) from information_schema.tables where table_schema='public'"
```

## Passwords

`REACT_PGSQL_PWD` goes into a Django connection string and into SQL the installer runs,
so keep it to letters and digits. A password with a single quote in it will break the
role creation; one with the characters Django rejects will break the API at startup.
