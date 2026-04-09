#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
    lookup: awx_templates_with_enabled_notifications
    short_description: Find AWX job templates with notifications
    description:
        - This lookup returns all AWX job templates that have notification templates configured
    options:
        host:
            description: The AWX host URL
            required: True
        username:
            description: The AWX username
            required: True
        password:
            description: The AWX password
            required: True
        max_workers:
            description: Maximum number of concurrent workers
            required: False
            default: 30
            type: int
        page_size:
            description: Number of items to fetch per page
            required: False
            default: 400
            type: int
        verify_ssl:
            description: 
                - Whether to verify SSL certificates or not
                - Useful for environments with self-signed certificates or corporate proxies
                - Setting to false also disables SSL warnings
            required: False
            default: True
            type: bool
    notes:
        - Returns a dictionary with template information, detailed notification data, and performance metrics
'''

EXAMPLES = '''
- name: Show job templates with notifications
  debug:
    msg: "{{ lookup('awx_notification_templates', host='https://awx.example.com', username='admin', password='password') }}"

- name: Get job templates with notifications using 10 workers
  set_fact:
    notification_data: "{{ lookup('awx_notification_templates', host=awx_host, username=awx_username, password=awx_password, max_workers=10)[0] }}"
    
- name: Use specific parts of the results
  debug:
    msg: "Found {{ notification_data.count }} templates with notifications"

- name: Loop through templates with notifications
  debug:
    msg: "Template {{ item.name }} (ID: {{ item.id }}) has {{ item.notification_types | join(', ') }} notifications"
  loop: "{{ notification_data.job_templates }}"
  
- name: Use with SSL verification disabled
  debug:
    msg: "{{ lookup('awx_notification_templates', host='https://awx.example.com', username='admin', password='password', verify_ssl=false) }}"
'''

RETURN = '''
  _list:
    description:
      - List containing a single dictionary with job template notification information
    type: list
    elements: dict
    contains:
      job_templates:
        description: List of dictionaries with template id, name, and notification types
        type: list
        returned: always
      count:
        description: Count of templates with notifications
        type: int
        returned: always
      total_templates:
        description: Total number of job templates in AWX
        type: int
        returned: always
      execution_time_seconds:
        description: Time taken to execute the lookup in seconds
        type: float
        returned: always
      workers_used:
        description: Number of concurrent workers used
        type: int
        returned: always
'''

from ansible.plugins.lookup import LookupBase
from ansible.errors import AnsibleError, AnsibleParserError
from ansible.utils.display import Display
from ansible.module_utils.parsing.convert_bool import boolean

import requests
import json
import time
from urllib3.exceptions import InsecureRequestWarning
from concurrent.futures import ThreadPoolExecutor
import threading

display = Display()

class LookupModule(LookupBase):

    def run(self, terms, variables=None, **kwargs):
        start_time = time.time()
        
        self.set_options(var_options=variables, direct=kwargs)
        
        # Get parameters
        host = self.get_option('host')
        username = self.get_option('username')
        password = self.get_option('password')
        max_workers = self.get_option('max_workers', 30)
        page_size = self.get_option('page_size', 400)
        verify_ssl = self.get_option('verify_ssl', True)
        
        # Convert verify_ssl to boolean if it's not already
        if not isinstance(verify_ssl, bool):
            verify_ssl = boolean(verify_ssl)
            
        # Disable SSL warnings if verify_ssl is False
        if not verify_ssl:
            requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
        
        if not all([host, username, password]):
            raise AnsibleError("Missing required parameters: host, username, and password are required")
        
        try:
            # Setup authentication
            auth = (username, password)
            headers = {'Content-Type': 'application/json'}
            
            display.vvv(f"Fetching job templates from {host} with page size {page_size}")
            
            # Get all job templates with pagination
            template_info = []  # Store both id and name
            next_url = f"{host}/api/v2/job_templates/?page_size={page_size}"
            
            while next_url:
                templates_response = requests.get(next_url, auth=auth, headers=headers, verify=verify_ssl)
                
                if templates_response.status_code != 200:
                    raise AnsibleError(f"Failed to get job templates: {templates_response.status_code}")
                
                templates_data = templates_response.json()
                # Store both id and name for each template
                template_info.extend([{'id': template['id'], 'name': template['name']} for template in templates_data.get('results', [])])
                
                # Get next page URL
                next_url = templates_data.get('next')
                if next_url and not next_url.startswith('http'):
                    next_url = f"{host}{next_url}"
            
            display.vvv(f"Found {len(template_info)} total job templates, checking for notifications with {max_workers} workers")
            
            # Templates with notifications
            templates_with_notifications = []
            lock = threading.Lock()
            
            # Create a session for connection pooling
            session = requests.Session()
            
            def check_template(template_data):
                template_id = template_data['id']
                template_name = template_data['name']
                template_info = {'id': template_id, 'name': template_name, 'notification_types': []}
                has_notifications = False
                
                # Check each notification type
                for notification_type in ['started', 'success', 'error']:
                    url = f"{host}/api/v2/job_templates/{template_id}/notification_templates_{notification_type}/"
                    response = session.get(url, auth=auth, headers=headers, verify=verify_ssl)
                    
                    if response.status_code == 200:
                        data = response.json()
                        count = data.get('count', 0)
                        
                        if count > 0:
                            has_notifications = True
                            template_info['notification_types'].append(notification_type)
                
                if has_notifications:
                    with lock:
                        templates_with_notifications.append(template_info)
            
            # Use ThreadPoolExecutor for concurrent processing
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                executor.map(check_template, template_info)
            
            elapsed_time = time.time() - start_time
            
            # Return with enhanced information
            return [{
                "job_templates": templates_with_notifications,
                "count": len(templates_with_notifications),
                "total_templates": len(template_info),
                "execution_time_seconds": round(elapsed_time, 2),
                "workers_used": max_workers
            }]
            
        except Exception as e:
            raise AnsibleError(f"Error in awx_notification_templates lookup: {str(e)}")