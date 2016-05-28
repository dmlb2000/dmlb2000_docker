#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'x509'
include_recipe 'lvm'
include_recipe 'dmlb2000_distro'
include_recipe 'dmlb2000_chef'
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

  logical_volume 'bootstrap-metadata' do
    size        '5%VG'
  end
  logical_volume 'bootstrap-data' do
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

package 'docker'

directory '/var/lib/docker-bootstrap'
docker_service 'bootstrap' do
  host ['unix:///var/run/docker-bootstrap.sock']
  iptables false
  ip_masq false
  bridge 'none'
  storage_driver 'devicemapper'
  graph '/var/lib/docker-bootstrap'
  storage_opts %w(
    dm.datadev=/dev/docker/bootstrap-data
    dm.metadatadev=/dev/docker/bootstrap-metadata
  )
  group 'wheel'
  action [:create, :start]
end
