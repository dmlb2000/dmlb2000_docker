#
# Cookbook Name:: dmlb2000_docker
# Recipe:: mgmt
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'x509'
directory '/etc/pki/docker'
x509_ca_certificate 'docker' do
  cacertificate node['dmlb2000_docker']['certs']['ca']['pem']
end
x509_certificate 'docker' do
  ca 'docker'
  key node['dmlb2000_docker']['certs']['ca']['key']
  certificate node['dmlb2000_docker']['certs']['ca']['cert']
  cacertificate node['dmlb2000_docker']['certs']['ca']['pem']
end
x509_certificate 'docker.dmlb2000.org' do
  ca 'docker'
  key node['dmlb2000_docker']['certs']['server']['key']
  certificate node['dmlb2000_docker']['certs']['server']['cert']
  bits 4096
  days 365
end
x509_certificate 'docker-client' do
  ca 'docker'
  key node['dmlb2000_docker']['certs']['client']['key']
  certificate node['dmlb2000_docker']['certs']['client']['cert']
  cn node['fqdn']
  type 'client'
  bits 4096
  days 365
end

include_recipe 'lvm'
lvm_volume_group 'docker' do
  physical_volumes node['dmlb2000_docker']['physical_volumes']
  logical_volume 'data' do
    size '90%VG'
  end
  logical_volume 'metadata' do
    size '10%VG'
  end
end

docker_installation 'default' do
  action :create
end

docker_service 'default' do
  host [ 'unix:///var/run/docker.sock' ]
  storage_driver 'devicemapper'
  storage_opts %w(dm.datadev=/dev/docker/data dm.metadatadev=/dev/docker/metadata dm.fs=xfs)
  group 'wheel'
  action [:create, :start]
end

include_recipe 'apache2'

template "#{node['apache']['dir']}/sites-available/docker.conf" do
  source 'web_app.conf.erb'
  variables(
    ssl_key: node['dmlb2000_docker']['certs']['server']['key'],
    ssl_cert: node['dmlb2000_docker']['certs']['server']['cert'],
    ssl_cacert: node['dmlb2000_docker']['certs']['ca']['pem'],
    doc_root: '/var/www/docker',
    vhost_name: 'docker.dmlb2000.org',
    proxy_url: 'unix:/var/run/docker.sock|http://localhost/'
  )
end

apache_site 'docker'
