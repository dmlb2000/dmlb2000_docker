include_recipe 'dmlb2000_docker::server'

master_ip = if Chef::Config[:solo]
              '127.0.0.1'
            else
              search(:node, "chef_environment:#{node.environment} AND "\
              'recipe:dmlb2000_docker\:\:kubmaster')[0]['ipaddress']
            end

docker_image 'flannel' do
  host 'unix:///var/run/docker-bootstrap.sock'
  repo 'quay.io/coreos/flannel'
  tag node['dmlb2000_docker']['flannel_version']
end

docker_container 'flannel' do
  host 'unix:///var/run/docker-bootstrap.sock'
  network_mode 'host'
  repo 'quay.io/coreos/flannel'
  tag node['dmlb2000_docker']['flannel_version']
  privileged true
  binds ['/dev/net:/dev/net']
  restart_policy 'always'
  command "/opt/bin/flanneld --etcd-endpoints=http://#{master_ip}:4001 "\
          '--ip-masq=true '\
          "--iface=#{node['dmlb2000_docker']['flannel_iface']}"
  action :run
end

ruby_block 'gather-flannel-env' do
  block do
    node.run_state[:flannel] = { bip: '', mtu: '' }
    # rubocop:disable Metrics/LineLength
    flannel_id = `docker -H unix:///var/run/docker-bootstrap.sock ps -a| grep flannel | cut -d ' ' -f 1`.strip
    env = `docker -H unix:///var/run/docker-bootstrap.sock exec #{flannel_id} cat /run/flannel/subnet.env`
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
  storage_driver 'devicemapper'
  storage_opts %w(dm.datadev=/dev/docker/default-data
                  dm.metadatadev=/dev/docker/default-metadata)
  group 'wheel'
  action [:create, :start]
end

docker_image 'hyperkube' do
  repo 'gcr.io/google_containers/hyperkube-amd64'
  tag "v#{node['dmlb2000_docker']['k8s_version']}"
end

docker_container 'kubelet' do
  network_mode 'host'
  pid_mode 'host'
  privileged true
  repo 'gcr.io/google_containers/hyperkube-amd64'
  tag "v#{node['dmlb2000_docker']['k8s_version']}"
  binds %w(
    /var/run:/var/run:rw
    /sys:/sys:ro
    /:/rootfs:ro
    /var/lib/docker/:/var/lib/docker:rw
    /var/lib/kubelet/:/var/lib/kubelet:rw
  )
  command '/hyperkube kubelet --allow-privileged=true '\
          "--api_servers=http://#{master_ip}:8080 "\
          '--v=2 --address=0.0.0.0 --enable_server '\
          '--containerized --cluster-dns=10.0.0.10 '\
          '--cluster-domain=cluster.local'
  restart_policy 'always'
  action :run
end

docker_container 'proxy' do
  network_mode 'host'
  repo 'gcr.io/google_containers/hyperkube-amd64'
  tag "v#{node['dmlb2000_docker']['k8s_version']}"
  privileged true
  restart_policy 'always'
  command "/hyperkube proxy --master=http://#{master_ip}:8080 --v=2"
  action :run
end
