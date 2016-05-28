default['dmlb2000_docker']['certs']['ca']\
       ['pem'] = '/etc/pki/docker/docker-ca.pem'
default['dmlb2000_docker']['certs']['client']\
       ['key'] = '/etc/pki/docker/docker-client.key'
default['dmlb2000_docker']['certs']['client']\
       ['cert'] = '/etc/pki/docker/docker-client.cert'
default['dmlb2000_docker']['certs']['server']\
       ['key'] = '/etc/pki/docker/docker-server.key'
default['dmlb2000_docker']['certs']['server']\
       ['cert'] = '/etc/pki/docker/docker-server.cert'
default['dmlb2000_docker']['tls_verify'] = nil

default['dmlb2000_docker']['k8s_version'] = '1.2.4'
default['dmlb2000_docker']['etcd_version'] = '2.2.1'
default['dmlb2000_docker']['flannel_version'] = '0.5.5'
default['dmlb2000_docker']['flannel_iface'] = 'eth0'
