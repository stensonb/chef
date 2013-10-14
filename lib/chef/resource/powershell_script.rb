#
# Author:: Adam Edwards (<adamed@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
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
#

require 'chef/resource/windows_script'

class Chef
  class Resource
    class PowershellScript < Chef::Resource::WindowsScript

      EXIT_STATUS_NORMALIZATION_SCRIPT = "\nif ($? -eq $true) {exit 0} elseif ( $LASTEXITCODE -ne 0) {exit $LASTEXITCODE} else { exit 1 }"
      EXIT_STATUS_RESET_SCRIPT = "$LASTEXITCODE=0\n"

      # Process exit codes are strange with PowerShell. Unless you
      # explicitly call exit in Powershell, the powershell.exe
      # interpreter returns only 0 for success or 1 for failure. Since
      # we'd like to get specific exit codes from executable tools run
      # with Powershell, we do some work using the automatic variables
      # $? and $LASTEXITCODE to return the process exit code of the
      # last process run in the script if it is the last command
      # executed, otherwise 0 or 1 based on whether $? is set to true
      # (success, where we return 0) or false (where we return 1).
      def NormalizeScriptExitStatus( code )
        (! code.nil?) ? ( EXIT_STATUS_RESET_SCRIPT + code + EXIT_STATUS_NORMALIZATION_SCRIPT ) : nil
      end

      def command_flags
        default_flags = [
          "-NoLogo",
          "-NonInteractive",
          "-NoProfile",
          "-ExecutionPolicy RemoteSigned",
          # Powershell will hang if STDIN is redirected
          # http://connect.microsoft.com/PowerShell/feedback/details/572313/powershell-exe-can-hang-if-stdin-is-redirected
          "-InputFormat None",
          "-Command"
        ]

        interpreter_flags = default_flags.join(' ')
      end
      
      def initialize(name, run_context=nil)
        super(name, run_context, :powershell_script, "powershell.exe")
      end

      def guard_command( command )
        "powershell.exe #{command_flags} #{command}" if ! command.nil?
      end
      
      def not_if(command=nil, opts={}, &block)
        powershell_command = guard_command(command)
        super(powershell_command, opts, &block)
      end
      
      def only_if(command=nil, opts={}, &block)
        powershell_command = guard_command(command)        
        super(powershell_command, opts, &block)
      end

    end
  end
end
