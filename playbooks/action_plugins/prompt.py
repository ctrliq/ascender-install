# Copyright (c) 2026, Ctrl IQ, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import getpass
import sys

from ansible.module_utils.common.text.converters import to_text
from ansible.plugins.action import ActionBase


class ActionModule(ActionBase):
    """Display a prompt and return a single line of operator input.

    This is a deliberately minimal action plugin used by the Ascender
    ``config_vars`` role. It writes an optional prompt string, reads one
    line of input (echoed or hidden), and returns it as ``user_input`` so
    the configuration wizard reads like a plain command line application.
    """

    BYPASS_HOST_LOOP = True
    TRANSFERS_FILES = False

    def run(self, tmp=None, task_vars=None):
        if task_vars is None:
            task_vars = {}

        result = super(ActionModule, self).run(tmp, task_vars)
        del tmp  # no longer used

        _validation, args = self.validate_argument_spec(
            argument_spec={
                'prompt': {'type': 'str', 'default': ''},
                'echo': {'type': 'bool', 'default': True},
            },
        )

        prompt = args['prompt'] or ''
        echo = args['echo']

        result['changed'] = False
        result['user_input'] = u''

        # Print the raw task name (the question) here rather than from the
        # callback, so it is only shown when the task actually runs and never
        # for tasks skipped by a ``when`` condition.
        name = to_text(getattr(self._task, 'name', u'') or u'').strip()
        if name:
            sys.stdout.write(u'\n' + name + u'\n')
            sys.stdout.flush()

        try:
            if echo:
                result['user_input'] = self._read_visible(prompt)
            else:
                result['user_input'] = to_text(getpass.getpass(prompt))
        except EOFError:
            # No input available (e.g. a non-interactive run): return empty
            # and let the playbook fall back to its default value.
            result['user_input'] = u''
        except KeyboardInterrupt:
            result['failed'] = True
            result['msg'] = 'Prompt interrupted by user'

        return result

    def _read_visible(self, prompt):
        """Write the prompt and read a single echoed line from the operator."""
        # Ansible replaces sys.stdin inside the task worker process, so the
        # connection preserves the original stdin for interactive plugins.
        stdin = getattr(self._connection, '_new_stdin', None) or sys.stdin

        if prompt:
            sys.stdout.write(prompt)
            sys.stdout.flush()

        line = stdin.readline()
        if not line:
            raise EOFError

        return to_text(line).rstrip(u'\r\n')
