#!/bin/bash
ANSIBLE_STDOUT_CALLBACK=minimum_text ansible-playbook -i 'localhost,' playbooks/config_vars.yml
