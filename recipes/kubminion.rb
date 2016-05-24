include_recipe 'dmlb2000_docker::server'

master_ip = if Chef::Config[:solo]
              '127.0.0.1'
            else
              search(:node, "chef_environment:#{chef_environment} AND "\
              'recipe:dmlb2000_docker\:\:kubmaster')[0]['ipaddress']
            end

flannel_version = '0.5.5'
k8s_version = '1.1.2'

docker_image 'flannel' do
  host 'unix:///var/run/docker-system.sock'
  repo 'quay.io/coreos/flannel'
  tag flannel_version
end

docker_container 'flannel' do
  host 'unix:///var/run/docker-system.sock'
  network_mode 'host'
  repo 'quay.io/coreos/flannel'
  tag flannel_version
  privileged true
  binds ['/dev/net:/dev/net']
  restart_policy 'always'
  command "/opt/bin/flanneld --etcd-endpoints=http://#{master_ip}:4001"
  action :run
end

ruby_block 'gather-flannel-env' do
  block do
    node.run_state[:flannel] = { bip: '', mtu: '' }
    # rubocop:disable Metrics/LineLength
    flannel_id = `docker -H unix:///var/run/docker-system.sock ps -a| grep flannel | cut -d ' ' -f 1`.strip
    env = `docker -H unix:///var/run/docker-system.sock exec #{flannel_id} cat /run/flannel/subnet.env`
    # rubocop:enable Metrics/LineLength
    raise 'Unable to gather flannel networking information!' if env.empty?
    env = env.split
    node.run_state[:flannel][:bip] = env[1].split('=')[1].strip
    node.run_state[:flannel][:mtu] = env[2].split('=')[1].strip
  end
  retries 5
end

package 'bridge-utils'

docker_service 'default' do
  host ["tcp://#{node['ipaddress']}:2376", 'unix:///var/run/docker.sock']
  bip lazy { node.run_state[:flannel][:bip] }
  mtu lazy { node.run_state[:flannel][:mtu] }
  tls_ca_cert node['dmlb2000_docker']['certs']['ca']['pem']
  tls_server_cert node['dmlb2000_docker']['certs']['server']['cert']
  tls_server_key node['dmlb2000_docker']['certs']['server']['key']
  tls_verify node['dmlb2000_docker']['tls_verify']
  storage_driver 'devicemapper'
  storage_opts %w(dm.datadev=/dev/docker/default-data
                  dm.metadatadev=/dev/docker/default-metadata)
  group 'wheel'
  action [:create, :start]
end

docker_image 'hyperkube' do
  host 'unix:///var/run/docker-system.sock'
  repo 'gcr.io/google_containers/hyperkube'
  tag "v#{k8s_version}"
end

docker_container 'kubelet' do
  host 'unix:///var/run/docker-system.sock'
  network_mode 'host'
  pid_mode 'host'
  privileged true
  repo 'gcr.io/google_containers/hyperkube'
  tag "v#{k8s_version}"
  binds %w(
    /var/run/docker.sock:/var/run/docker.sock
    /sys:/sys:ro
    /:/rootfs:ro
    /var/lib/docker/:/var/lib/docker:rw
    /var/lib/kubelet/:/var/lib/kubelet:rw
  )
  command "/hyperkube kubelet --api_servers=http://#{master_ip}:8080 "\
          '--v=2 --address=0.0.0.0 --enable_server '\
          "--hostname_override=#{node['ipaddress']} "\
          '--config=/etc/kubernetes/manifests-multi'
  restart_policy 'always'
  action :run
end

docker_container 'proxy' do
  host 'unix:///var/run/docker-system.sock'
  network_mode 'host'
  repo 'gcr.io/google_containers/hyperkube'
  tag "v#{k8s_version}"
  privileged true
  restart_policy 'always'
  command "/hyperkube proxy --master=http://#{master_ip}:8080 --v=2"
  action :run
end