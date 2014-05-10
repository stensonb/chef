#
# Author:: Sahil Muthoo (<sahil.muthoo@gmail.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

require 'spec_helper'
require 'highline'

describe Chef::Knife::Status do

  # a helper method that returns a node with extra attributes
  def node_factory(name, auto_attr_hash)
    Chef::Node.new.tap do |n|
    #node = Chef::Node.new.tap do |n|
      auto_attr_hash.each do |k,v|
        n.automatic_attrs[k] = v
      end
      n.name(name)
    end
  end

  # creates an array for search results, with node_count stock nodes (an integer), and
  # any additional extra_nodes in the splat
  #
  # search_results_factory(4)  # creates 4 nodes in the result set
  # search_results_factory(2, some_node) # creates 3 nodes in the result set (some_node is appended to the result set)
  # search_results_factory(2, some_node, another_node) # a 4 node result set
  # search_results_factory(0, some_node) # a 1 node result set containing only some_node
  def search_results_factory(node_count, *extra_nodes)
    search_results = []
    node_count.times do |i|
      search_results << node_factory("tempnode#{i}", {})
    end

    extra_nodes.each do |node|
      search_results << node unless node.nil? || node.empty?
    end

    search_results
  end

  def mock_chef_node_search(search_results, query_string = '*:*')
    query = double()
    query.stub(:search).with(:node, query_string).and_return(search_results)
    Chef::Search::Query.stub(:new).and_return(query)
  end

  before(:each) do
    @node_name = 'foobar'
    @fqdn = @node_name + '.somedomain'
    @default_node_attr_hash = {"fqdn" => @fqdn, "ohai_time" => 1343845969}
    @node = node_factory(@node_name, @default_node_attr_hash)
    mock_chef_node_search(search_results_factory(0, @node))

    @knife = Chef::Knife::Status.new
    @stdout = StringIO.new
    @knife.stub(:highline).and_return(HighLine.new(StringIO.new, @stdout))
  end
  
  describe "::run" do
    it 'searches for nodes, sorts nodes, and outputs (via highline) all nodes and their statuses' do
      node_list = [@node]
      @knife.should_receive(:search_nodes).and_return node_list
      @knife.should_receive(:sort_nodes).with(node_list).and_return(node_list)
      @knife.should_receive(:format_single_node_status).exactly(node_list.size).times.and_return('another node')
      @knife.run
    end
  end

  describe "::remove_healthy_nodes" do
    it "returns a Chef::Node array which have checked in the the past hour" do
      node1 = node_factory('node1', {'ohai_time' => Time.now.to_i})
      node2 = node_factory('node2', {'ohai_time' => Time.now.to_i - 3600})
      node_list = [node1, node2]
      @knife.remove_healthy_nodes(node_list).should eq [node2]
    end
  end

  describe "::search_nodes" do
    describe 'no search results' do
      before(:each) do
        search_results = double(:search => [])
        Chef::Search::Query.stub(:new).and_return search_results
      end

      it 'returns an empty array' do
       @knife.search_nodes.should eq []
      end
    end

    describe 'some results' do
      it 'returns a non-empty array of Node objects' do
        @knife.search_nodes.each do |obj|
          obj.class.should eq Chef::Node
        end
      end
    end
  end

  describe "::sort_nodes" do
    let (:node1) { {'ohai_time' => 123} }
    let (:node2) { {'ohai_time' => 678} }
    let (:node_list) { [node1, node2] }

    describe 'single element array, or non array node_list passed' do
      it 'returns the single item as an array' do
        node_list = [node1]
        expect(@knife.sort_nodes(node_list)).to eq [node1]

        node_list = :foo
        expect(@knife.sort_nodes(node_list)).to eq [:foo]
      end
    end

    describe 'default sort' do
      it 'returns an array of nodes sorted by ohai_time' do
        expect(@knife.sort_nodes(node_list)).to eq [node1, node2]
      end
    end

    describe 'reverse = true is passed as an argument' do
      it 'returns an array of nodes reverse sorted by ohai_time' do
        expect(@knife.sort_nodes(node_list, true)).to eq [node2, node1]
      end
    end
  end

  describe "::format_single_node_status" do
    it 'returns formatted node status containing results from formatTimeDiff, node.name' do
      @timediff = '1 hour ago'
      @knife.should_receive(:formatTimeDiff).and_return @timediff

      status = @knife.format_single_node_status(@node)
      expect(status.include?(@timediff)).to eq(true)
      expect(status.include?(@node_name)).to eq(true)
    end

    describe 'node contains fqdn attribute' do
      it 'returns node status including fqdn' do
        #subject node contains fqdn, so no additional setup required
        expect(@knife.format_single_node_status(@node).include?(@fqdn)).to eq(true)
      end
    end

    describe 'node contains ipaddress attribute' do
      it 'returns node status including ipaddress' do
        ipaddress = '1.1.1.1'
        node_attrs = @default_node_attr_hash.merge({'ipaddress' => ipaddress})
        node = node_factory(@node_name, node_attrs)

        expect(@knife.format_single_node_status(node).include?(ipaddress)).to eq(true)
      end
    end

    describe 'node contains platform attribute' do
      it 'calls formatPlatformVersion and appends all results from array to formatted output' do
        platform = 'BryanOS'
        platform_version = '1.0'
        node_attrs = @default_node_attr_hash.merge({'platform' => platform, 'platform_version' => platform_version})
        node = node_factory(@node_name, node_attrs)

        @knife.should_receive(:formatPlatformVersion).with(node).and_return([platform, platform_version])

        results = @knife.format_single_node_status(node)
        expect(results.include?(platform)).to eq(true)
        expect(results.include?(platform_version)).to eq(true)
      end
    end
  end

  describe "::formatPlatformVersion" do
    let (:platform) { 'BryanOS' } # :)
    let (:platform_version) { '1.0' }

    describe 'platform does not exist on node' do
      it 'returns empty array' do
        results = @knife.formatPlatformVersion(@node)
        expect(results.class).to eq Array
        expect(results.length).to eq 0
      end
    end

    describe 'node contains platform, but no version attribute' do
      it 'returns platform as a single element array' do
        node = node_factory(@node_name, @default_node_attr_hash.merge({'platform' => platform}))

        results = @knife.formatPlatformVersion(node)
        expect(results.class).to eq Array
        expect(results.length).to eq 1
        expect(results.first).to eq platform
      end
    end

    describe 'node contains platform and platform version' do
      it 'returns platform and platform version as tuple' do
        node = node_factory(@node_name, @default_node_attr_hash.merge({'platform' => platform, 'platform_version' => platform_version}))

        results = @knife.formatPlatformVersion(node)
        expect(results.class).to eq Array
        expect(results.length).to eq 2
        expect(results.first).to eq platform
        expect(results.last).to eq platform_version
      end
    end
  end

  describe "::formatTimeDiff" do
    it "returns a formatted string containing time elapsed since last node check-in" do
      @knife.formatTimeDiff(@node).match(/\d+ (hour|minute)s? ago/).should_not be_nil
    end

    def mostSignificantUnit(hms_time)
      hms_time.each do |val|
        return val if val > 0
      end
    end

    def returnsUnitsandColorMaybe(hms_time, unit_type, color)
      timetext = "#{mostSignificantUnit(hms_time)} #{unit_type}#{mostSignificantUnit(hms_time) == 1 ? '' : 's'}"
      ui = double()
      @knife.instance_eval {@ui = ui}
      @knife.should_receive(:time_difference_in_hms).and_return hms_time
      ui.should_receive(:color).with(timetext, color).and_return timetext
      expect(@knife.formatTimeDiff(@node).include?("#{timetext} ago")).to eq(true)
    end

    describe 'time diff was > 24 hours ago' do
      it 'returns hours, possibly in red' do #color output determined by Chef::Knife::UI.color?
        hms_time = [25, 0, 0]
        returnsUnitsandColorMaybe(hms_time, 'hour', :red)
      end
    end

    describe 'time diff was >= 1 hour, and < 24 hours ago' do
      it 'returns hours, possibly in yellow' do #color output determined by Chef::Knife::UI.color?
        hms_time = [1, 0, 0]
        returnsUnitsandColorMaybe(hms_time, 'hour', :yellow)
      end
    end

    describe 'time diff was < 1 hour ago' do
      it 'returns minutes, possibly in green' do #color output determined by Chef::Knife::UI.color?
        hms_time = [0, 30, 0]
        returnsUnitsandColorMaybe(hms_time, 'minute', :green)
      end
    end

  end

  describe "::get_fqdn_and_ip" do
    describe 'node has ec2 key' do
      it 'returns a tuple containing EC2 details' do
        public_hostname = 'ec2fqdn'
        public_ipv4 = '1.1.1.1'
        node_attrs = @default_node_attr_hash.merge({'ec2' => {'public_hostname' => public_hostname, 'public_ipv4' => public_ipv4}})
        node = node_factory(@node_name, node_attrs)

        fqdn, ip = @knife.get_fqdn_and_ip(node)
        expect(fqdn).to eq(public_hostname)
        expect(ip).to eq(public_ipv4)
      end
    end

    describe 'node does NOT have ec2 key' do
      it 'returns a tuple containing details' do
        fqdn, ip = @knife.get_fqdn_and_ip(@node)
        expect(fqdn).to eq(@fqdn)
        expect(ip).to eq(@ip)
      end
    end
  end
end
