#!/opt/puppetlabs/puppet/bin/ruby
# tasks/facter_conf_manage.rb
require 'json'
require_relative '../lib/facter_conf_helper'

begin
  helper = FacterConfHelper.new
  helper.sync_with_facter!

  result = {
    status: 'ok',
    message: "facter.conf synced with available facts",
    file: helper.file_path
  }

  puts result.to_json
rescue => e
  puts({ status: 'error', message: e.message }.to_json)
  exit 1
end
