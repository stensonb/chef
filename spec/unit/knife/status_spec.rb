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
  before(:each) do
    @node = Chef::Node.new.tap do |n|
      n.automatic_attrs["fqdn"] = "foobar"
      n.automatic_attrs["ohai_time"] = 1343845969
    end
    query = double("Chef::Search::Query")
    query.stub(:search).and_yield(@node)
    Chef::Search::Query.stub(:new).and_return(query)
    @knife  = Chef::Knife::Status.new
    @stdout = StringIO.new
    @knife.stub(:highline).and_return(HighLine.new(StringIO.new, @stdout))
  end

  describe "run" do
    it "should not colorize output unless it's writing to a tty" do
      @knife.run
      @stdout.string.match(/foobar/).should_not be_nil
      @stdout.string.match(/\e.*ago/).should be_nil
    end

    it 'returns nodes sorted via ohai_time' do

    end

    it 'returns nodes sorted in reverse of ohai_time if specified' do

    end

    describe 'node has ec2 key' do
      it 'returns fqdn and ipaddress using node.ec2.public_hostname and node.ec2.public_ipv4' do

      end
    end

  end

  describe "::formatSingleNodeStatus" do
    it "returns a formatted string containing time elapsed since last node check-in, and other node data" do
      @knife.formatSingleNodeStatus(@node).match(/ago/).should_not be nil
    end

    def mostSignificantUnitIndex hms_time
      hms_time.each_with_index do |val, idx|
        return idx if val > 0
      end
    end

    def returnsUnitsandColorMaybe(hms_time, unit, color)
      timetext = "#{hms_time[mostSignificantUnitIndex(hms_time)]} #{unit}#{hms_time[mostSignificantUnitIndex(hms_time)] == 1 ? '' : 's'}"
      ui = double()
      @knife.instance_eval {@ui = ui}
      @knife.should_receive(:time_difference_in_hms).and_return hms_time
      ui.should_receive(:color).with(timetext, color).and_return timetext
      @knife.formatSingleNodeStatus(@node).match(/#{timetext} ago/).should_not be nil
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
end
