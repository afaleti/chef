#
# Author:: Tim Smith (<tsmith@chef.io>)
# Copyright:: 2016-2017, Chef Software, Inc.
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

require "chef/provider"
require "chef/dsl/declare_resource"
require "chef/provider/noop"
require "chef/mixin/which"
require "chef/log"

class Chef
  class Provider
    class AptPreference < Chef::Provider
      extend Chef::Mixin::Which

      provides :apt_preference do
        which("apt-get")
      end

      APT_PREFERENCE_DIR = "/etc/apt/preferences.d".freeze

      def load_current_resource
      end

      action :add do
        preference = build_pref(
          new_resource.glob || new_resource.package_name,
          new_resource.pin,
          new_resource.pin_priority
        )

        declare_resource(:directory, APT_PREFERENCE_DIR) do
          mode "0755"
          recursive true
          action :create
        end

        name = safe_name(new_resource.name)

        declare_resource(:file, ::File.join(APT_PREFERENCE_DIR, "#{new_resource.name}.pref")) do
          action :delete
          if ::File.exist?(::File.join(APT_PREFERENCE_DIR, "#{new_resource.name}.pref"))
            Chef::Log.warn "Replacing #{new_resource.name}.pref with #{name}.pref in #{APT_PREFERENCE_DIR}"
          end
          only_if { name != new_resource.name }
        end

        declare_resource(:file, ::File.join(APT_PREFERENCE_DIR, "#{new_resource.name}")) do
          action :delete
          if ::File.exist?(::File.join(APT_PREFERENCE_DIR, "#{new_resource.name}"))
            Chef::Log.warn "Replacing #{new_resource.name} with #{new_resource.name}.pref in #{APT_PREFERENCE_DIR}"
          end
        end

        declare_resource(:file, ::File.join(APT_PREFERENCE_DIR, "#{name}.pref")) do
          mode "0644"
          content preference
          action :create
        end
      end

      action :delete do
        name = safe_name(new_resource.name)
        if ::File.exist?(::File.join(APT_PREFERENCE_DIR, "#{name}.pref"))
          Chef::Log.info "Un-pinning #{name} from #{APT_PREFERENCE_DIR}"
          declare_resource(:file, ::File.join(APT_PREFERENCE_DIR, "#{name}.pref")) do
            action :delete
          end
        end
      end
    end

    # Build preferences.d file contents
    def build_pref(package_name, pin, pin_priority)
      "Package: #{package_name}\nPin: #{pin}\nPin-Priority: #{pin_priority}\n"
    end

    def safe_name(name)
      name.tr(".", "_").gsub("*", "wildcard")
    end
  end
end

Chef::Provider::Noop.provides :apt_preference
