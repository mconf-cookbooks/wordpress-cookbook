#
# Cookbook Name:: wordpress
# Recipe:: apache
#
# Copyright 2009-2010, Opscode, Inc.
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

include_recipe "php"

# On Windows PHP comes with the MySQL Module and we use IIS on Windows
unless platform? "windows"
  include_recipe "php::module_mysql"
  include_recipe "apache2"
  include_recipe "apache2::mod_php5"
end

include_recipe "wordpress::app"


certs = {
  certificate_file: nil,
  certificate_key_file: nil,
  ca_certificate_file: nil,
  certificate_chain_file: nil
}

if node['wordpress']['ssl']['enable']
  apache_module 'socache_shmcb'
  apache_module 'ssl'

  certs.each do |cert_name, value|
    file = node['wordpress']['ssl']['certificates'][cert_name]
    if file && file.strip != ''
      path = "#{node['wordpress']['ssl']['certificates']['path']}/#{file}"

      cookbook_file path do
        source file
        owner 'root'
        group node['apache']['group']
        mode 00640
        action :create
        only_if { node['wordpress']['ssl']['copy_certificates'] }
      end
    end
  end
end

path = node['wordpress']['ssl']['certificates']['path']
directory path do
  owner 'root'
  group node['apache']['group']
  mode 00640
  recursive true
  action :create
  only_if { path && path.strip != '' }
end

if platform?('windows')

  include_recipe 'iis::remove_default_site'

  iis_pool 'WordpressPool' do
    no_managed_code true
    action :add
  end

  iis_site 'Wordpress' do
    protocol :http
    port 80
    path node['wordpress']['dir']
    application_pool 'WordpressPool'
    action [:add,:start]
  end
else
  web_app "wordpress" do
    template "wordpress.conf.erb"
    docroot node['wordpress']['dir']
    server_name node['wordpress']['server_name']
    server_aliases node['wordpress']['server_aliases']
    server_port node['wordpress']['server_port']
    ssl node['wordpress']['ssl']
    certs certs
    enable true
  end
end
