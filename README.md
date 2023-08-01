# Run everything
Modify the inventory file point to the place(s) you want to install Ascender and Ledger and then run

```setup.sh```

It will check and ensure both ansible and the collections are installed before proceeding


# Ascender Only Installation
1) Modify the Inventory file to point to the host you want to install Ascender on
2) Run the install_ascender.yml playbook

# Ledger Only Installation
1) Modify the Inventory file to point to the host you want to install Ledger on
2) Run the install_ledger.yml playbook

# Configuring Ascender Logging
1) Ensure your Inventory points to both the ascender and ledger hosts
2) Run the configure_logs.yml playbook

