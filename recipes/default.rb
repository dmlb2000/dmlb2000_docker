#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'x509'
directory '/etc/pki/docker'

x509_ca_certificate "dockerCA" do
  cacertificate "/etc/pki/docker/ca.pem"
end

x509_certificate 'docker.dmlb2000.org' do
  ca 'dockerCA'
  key node['dmlb2000_docker']['certs']['ca']['key']
  certificate node['dmlb2000_docker']['certs']['ca']['cert']
  bits 4096
  days 365
end

docker_installation 'default' do
  action :create
end

docker_service 'default' do
  
  group 'wheel'
  action [:create, :start]
end
