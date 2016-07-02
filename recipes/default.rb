#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'x509'
include_recipe 'dmlb2000_chef'
include_recipe 'dmlb2000_distro'
include_recipe 'dmlb2000_users'
directory '/etc/pki/docker'

x509_ca_certificate 'dockerCA' do
  cacertificate node['dmlb2000_docker']['certs']['ca']['pem']
end

x509_certificate 'docker.dmlb2000.org' do
  ca 'dockerCA'
  key node['dmlb2000_docker']['certs']['server']['key']
  certificate node['dmlb2000_docker']['certs']['server']['cert']
  bits 4096
  days 365
end

x509_certificate "dmlb2000-#{node['fqdn']}" do
  cn node['fqdn']
  owner 'dmlb2000'
  ca 'dockerCA'
  type 'client'
  key node['dmlb2000_docker']['certs']['client']['key']
  certificate node['dmlb2000_docker']['certs']['client']['cert']
end

docker_installation 'default' do
  action :create
end

docker_service 'default' do
  host ["tcp://#{node['ipaddress']}:2376", 'unix:///var/run/docker.sock']
  group 'wheel'
  action [:create, :start]
end
