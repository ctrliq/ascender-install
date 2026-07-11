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

DOCUMENTATION = '''
    name: minimum_text
    type: stdout
    short_description: Minimal stdout callback for the Ascender configuration wizard.
    description:
      - Prints only the name of interactive prompt tasks and any task errors.
      - All other output (ok, changed and skipped results, play banners and the
        play recap) is suppressed so the wizard reads like a plain command line
        application.
    requirements:
      - Set as the main stdout callback.
'''

from ansible.module_utils.common.text.converters import to_text
from ansible.plugins.callback import CallbackBase


class CallbackModule(CallbackBase):
    """Stdout callback that shows prompt questions and errors, nothing else."""

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'minimum_text'

    def v2_runner_on_failed(self, result, ignore_errors=False):
        if not ignore_errors:
            self._display_error(result)

    def v2_runner_on_unreachable(self, result):
        self._display_error(result)

    def _display_error(self, result):
        name = to_text(result._task.get_name()).strip()
        message = to_text(
            result._result.get('msg')
            or result._result.get('reason')
            or u'task failed'
        )
        self._display.display(u'ERROR (%s): %s' % (name, message), color='red', stderr=True)
