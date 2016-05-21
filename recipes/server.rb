#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'x509'
include_recipe 'lvm'
include_recipe 'dmlb2000_users'
directory '/etc/pki/docker'

lvm_volume_group 'docker' do
  physical_volumes ['/dev/vdb']
  wipe_signatures true

  logical_volume 'default-metadata' do
    size        '5%VG'
  end

  logical_volume 'default-data' do
    size        '45%VG'
  end

  logical_volume 'system-metadata' do
    size        '5%VG'
  end
  logical_volume 'system-data' do
    size        '45%VG'
  end
end

x509_ca_certificate 'dockerCA' do
  cacertificate node['dmlb2000_docker']['certs']['ca']['pem']
end

x509_certificate node['fqdn'] do
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
  tls_ca_cert node['dmlb2000_docker']['certs']['ca']['pem']
  tls_server_cert node['dmlb2000_docker']['certs']['server']['cert']
  tls_server_key node['dmlb2000_docker']['certs']['server']['key']
  tls_verify node['dmlb2000_docker']['tls_verify']
  storage_driver 'devicemapper'
  storage_opts %w(dm.datadev=/dev/docker/default-data dm.metadatadev=/dev/docker/default-metadata)
  group 'wheel'
  action [:create, :start]
end

directory '/var/lib/docker-system'
docker_service 'system' do
  host ['unix:///var/run/docker-system.sock']
  tls_ca_cert node['dmlb2000_docker']['certs']['ca']['pem']
  tls_server_cert node['dmlb2000_docker']['certs']['server']['cert']
  tls_server_key node['dmlb2000_docker']['certs']['server']['key']
  tls_verify node['dmlb2000_docker']['tls_verify']
  storage_driver 'devicemapper'
  graph '/var/lib/docker-system'
  storage_opts %w(dm.datadev=/dev/docker/system-data dm.metadatadev=/dev/docker/system-metadata)
  group 'wheel'
  action [:create, :start]
end
