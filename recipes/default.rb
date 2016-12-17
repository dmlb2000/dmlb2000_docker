#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'dmlb2000_chef'
include_recipe 'dmlb2000_distro'
include_recipe 'dmlb2000_users'

docker_installation 'default' do
  action :create
end

docker_service 'default' do
  host ["tcp://#{node['ipaddress']}:2376", 'unix:///var/run/docker.sock']
  group 'wheel'
  action [:create, :start]
end
