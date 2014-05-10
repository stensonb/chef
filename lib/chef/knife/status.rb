#
# Author:: Ian Meyer (<ianmmeyer@gmail.com>)
# Copyright:: Copyright (c) 2010 Ian Meyer
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

require 'chef/knife'

class Chef
  class Knife
    class Status < Knife

      deps do
        require 'highline'
        require 'chef/search/query'
      end

      banner "knife status QUERY (options)"

      option :run_list,
        :short => "-r",
        :long => "--run-list",
        :description => "Show the run list"

      option :sort_reverse,
        :short => "-s",
        :long => "--sort-reverse",
        :description => "Sort the status list by last run time descending"

      option :hide_healthy,
        :short => "-H",
        :long => "--hide-healthy",
        :description => "Hide nodes that have run chef in the last hour"

      def highline
        @h ||= HighLine.new
      end

      def run
        all_nodes = search_nodes(@name_args[0] || '*:*')
        sorted_nodes = sort_nodes(all_nodes)
        remove_healthy_nodes(sorted_nodes) if config[:hide_healthy]

        sorted_nodes.each do |node|
          highline.say(format_single_node_status(node) + '.')
        end

      end

      def remove_healthy_nodes(node_list)
        node_list.select{|node| time_difference_in_hms(node['ohai_time']).first > 0}
      end

      def search_nodes(query_string = '*:*')
        results = []
        q = Chef::Search::Query.new
        q.search(:node, query_string) do |node|
          results << node
        end
        results
      end

      def sort_nodes(node_list, reverse = false)
        return [node_list] if !node_list.is_a?(Array)
        return node_list if node_list.length == 1

        node_list.sort!{ |n1, n2|
          if (reverse)
            (n2["ohai_time"] or 0) <=> (n1["ohai_time"] or 0)
          else
            (n1["ohai_time"] or 0) <=> (n2["ohai_time"] or 0)
          end
        }
      end

      def format_single_node_status(node)
        fqdn, ipaddress = get_fqdn_and_ip(node)
        line_parts = Array.new
        line_parts << formatTimeDiff(node)
        line_parts << node.name
        line_parts << fqdn if fqdn
        line_parts << ipaddress if ipaddress
        line_parts << formatPlatformVersion(node) if node['platform']

        line_parts.join(', ')
      end

      def formatPlatformVersion(node)
        answer = []
        if node['platform']
          answer << node['platform']
          if node['platform_version']
            answer << node['platform_version']
          end
        end
        answer
      end

      def formatTimeDiff(node)
        hours, minutes, seconds = time_difference_in_hms(node["ohai_time"])

        hours_text   = "#{hours} hour#{hours == 1 ? '' : 's'}"
        minutes_text = "#{minutes} minute#{minutes == 1 ? '' : 's'}"

        if hours > 24
          color = :red
          text = hours_text
        elsif hours >= 1
          color = :yellow
          text = hours_text
        else
          color = :green
          text = minutes_text
        end

        @ui.color(text, color) + " ago"
      end

      def get_fqdn_and_ip(node)
        return [node['ec2']['public_hostname'], node['ec2']['public_ipv4']] if node.has_key?('ec2')
        [node['fqdn'], node['ipaddress']]
      end

      # :nodoc:
      # TODO: this is duplicated from StatusHelper in the Webui. dedup.
      def time_difference_in_hms(unix_time)
        now = Time.now.to_i
        difference = now - unix_time.to_i
        hours = (difference / 3600).to_i
        difference = difference % 3600
        minutes = (difference / 60).to_i
        seconds = (difference % 60)
        return [hours, minutes, seconds]
      end

    end
  end
end
