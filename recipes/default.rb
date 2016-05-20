#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'x509'
directory '/etc/pki/docker'

x509_ca_certificate "dockerCA" do
  cacertificate node['dmlb2000_docker']['certs']['ca']['pem']
end

x509_certificate 'docker.dmlb2000.org' do
  ca 'dockerCA'
  key node['dmlb2000_docker']['certs']['server']['key']
  certificate node['dmlb2000_docker']['certs']['server']['cert']
  bits 4096
  days 365
end

docker_installation 'default' do
  action :create
end

docker_service 'default' do
  host [ "tcp://#{node['ipaddress']}:2376", 'unix:///var/run/docker.sock' ]
  tls_ca_cert node['dmlb2000_docker']['certs']['ca']['pem']
  tls_server_cert node['dmlb2000_docker']['certs']['server']['cert']
  tls_server_key node['dmlb2000_docker']['certs']['server']['key']
  tls_verify node['dmlb2000_docker']['tls_verify']
  group 'wheel'
  action [:create, :start]
end
