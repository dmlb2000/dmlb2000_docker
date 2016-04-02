default['apache']['listen'] = %w( *:80 *:443 )
%w( ssl access_compat proxy proxy_http ).each do |my_mod|
  default['apache']['default_modules'] << my_mod
end
default['dmlb2000_docker']['physical_volumes'] = ['/dev/vdb']
default['dmlb2000_docker']['certs']['ca']['pem'] = '/etc/pki/docker/docker-ca.pem'
default['dmlb2000_docker']['certs']['ca']['key'] = '/etc/pki/docker/docker-ca.key'
default['dmlb2000_docker']['certs']['ca']['cert'] = '/etc/pki/docker/docker-ca.cert'
default['dmlb2000_docker']['certs']['client']['key'] = '/etc/pki/docker/docker-client.key'
default['dmlb2000_docker']['certs']['client']['cert'] = '/etc/pki/docker/docker-client.cert'
default['dmlb2000_docker']['certs']['server']['key'] = '/etc/pki/docker/docker-server.key'
default['dmlb2000_docker']['certs']['server']['cert'] = '/etc/pki/docker/docker-server.cert'
