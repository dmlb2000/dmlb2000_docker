#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

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
