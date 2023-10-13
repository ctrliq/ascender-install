The Ascender installer is a script that makes for relatively easy
install of Ascender Automation Platform on Kubernetes platforms of
multiple flavors. The installer is being expanded to new Kubernetes
platforms as users/contributors allow, and if you have specific needs
for a platform not yet supported, please submit an issue to this
Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [K3s-specific Prerequisites](#k3s-specific-prerequisites)
- [Install Instructions](#install-instructions)

## General Prerequisites

If you have not done so already, be sure to follow the general
prerequisites found in the [Ascender-Install main
README](../../README.md#general-prerequisites)

## K3s-specific Prerequisites

- NOTE: The K3s install of Ascender is not yet meant for production,
  but rather as a sandbox on which to try Ascender. As such, the
  Installer expects a single-node K3s cluster which will act as both
  master and worker node.
- These instructions accomodate both an existing K3s cluster, and will
  set one up on your behalf if needed. This behavior is determined by
  the variable `kube_install`
  - If `kube_install` is set to true, the installer will set up K3s on
    the `ascender_host`in the inventory file. (`ascender_host` can be
    localhost)
  - If `kube_install` is set to false, the installer will not perform
    a K3s install
- SSL Certificate and Key
  - To enable HTTPS on your website, you need to provide the Ascender
    installer with an SSL Certificate file, and a Private Key
    file. While these can be self-signed certificates, it is best
    practice to use a trusted certificate, issued by a Certificate
    Authority. A good way to generate a trusted Certificate for the
    purpose of sandboxing, is to use the free Certificate Authority,
    [Let's Encrypt](https://letsencrypt.org/getting-started/).
  - Once you have a Certificate and Private Key file, make sure they
    are present on the Ascender installing server, and specify their
    locations in the default config file, with the variables
    `tls_crt_path`and `tls_key_path`, respectively. The installer will
    parse these files for their content, and use the content to create
    a Kubernetes TLS Secret for HTTPS enablement.

## Install Instructions

### Obtain the sources

You can use the `git` command to clone the ascender-install repository or you can download the zipped archive. 

To use git to clone the repository run:

```
git clone https://github.com/ctrliq/ascender-install.git
```
This will create a directory named `ascender-install` in your present working directory (PWD).

We will refer to this directory as the <ASCENDER-INSTALL-SOURCE> in the remainder of this instructions.

### Set the configuration variables for a K3s Install

You can use the README.md in the ASCENDER-INSTALL-SOURCE directory as a K3s reference, but
the file used by the `setup.sh` script must be located at in this path:

```
<ASCENDER-INSTALL-SOURCE>/default.config.yml
```

Because these are instructions to install Ascender on a k3s single-node K3s cluster, you'll need set the value of kube_install variable 
to from the default value of `false` to `true` in <ASCENDER-INSTALL-SOURCE>/default.config.yml

Use your favorite text editor or the quick `sed` command below to quickly make the change inplace. 

```
sed -i.bak 's/kube_install: false/kube_install: true/' default.config.yml
```

### Run the setup script

Run `./setup.sh` from top level directory in this repository.

The setup must run as a user with Administrative or sudo priviledges.  

To begin the setup process, type:

```
sudo ./setup.sh
```

Once the setup is completed successfully, you should see a final output similar to:

```
...<OUTPUT TRUNCATED>...
PLAY RECAP *************************************************************************************************************************
ascender_host              : ok=14   changed=6    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
localhost                  : ok=72   changed=27   unreachable=0    failed=0    skipped=4    rescued=0    ignored=0

ASCENDER SUCCESSFULLY SETUP
```


### Connecting to Ascender Web UI

This is a quick and temporary work-around for connecting to your new Ascender installation. 
By default the Ascender web service is accessible over its internal CLUSTER IP address. 
You can use SSH forwarding from any remote host to connect to the internal CLUSTER IP.

For the example here, you'll use the kubectl utility to query for the CLUSTER IP and store the value in a variable named "ASCENDER_WEB_INTERNAL_IP". 

While still logged on to the server running Ascender, type:

```
export ASCENDER_WEB_INTERNAL_IP=$(kubectl -n ascender get service/ascender-app-service -o jsonpath='{.spec.clusterIP}')
```

To see the value of ASCENDER_WEB_INTERNAL_IP type:

```
echo $ASCENDER_WEB_INTERNAL_IP
```

Now, to use SSH forwarding to connect to your Ascender installation from any remote workstation you can use a command like:

```
$ ssh -L 80:<ASCENDER_WEB_INTERNAL_IP>:80   user@ASCENDER_SERVER_IP
```

For example, if your the value of $ASCENDER_WEB_INTERNAL_IP is `10.43.9.224`, and the ASCENDER_SERVER_IP is `1.2.3.4`, the full command to connect as the root user will be:

```
$ ssh -L 80:10.43.9.224:80 root@1.2.3.4
```

With forwarding successfully, you can visit/Browse/Administer your Ascender instance by pointing your web browser to:

https://localhost


Username is "Admin" and the corresponding password is stored in <ASCENDER-INSTALL-SOURCE>/default.config.yml under the `ASCENDER_ADMIN_PASSWORD` variable.


