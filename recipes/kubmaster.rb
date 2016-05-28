include_recipe 'dmlb2000_docker::server'

docker_image 'etcd' do
  host 'unix:///var/run/docker-bootstrap.sock'
  repo 'gcr.io/google_containers/etcd'
  tag node['dmlb2000_docker']['etcd_version']
end

docker_container 'etcd' do
  host 'unix:///var/run/docker-bootstrap.sock'
  network_mode 'host'
  repo 'gcr.io/google_containers/etcd'
  tag node['dmlb2000_docker']['etcd_version']
  restart_policy 'always'
  command '/usr/local/bin/etcd '\
          "--listen-client-urls=http://127.0.0.1:4001,http://#{node['ipaddress']}:4001 "\
          "--advertise-client-urls=http://#{node['ipaddress']}:4001 "\
          '--data-dir=/var/etcd/data'
  action :run
end

docker_container 'create-etcd-cidr-range' do
  host 'unix:///var/run/docker-bootstrap.sock'
  network_mode 'host'
  repo 'gcr.io/google_containers/etcd'
  tag node['dmlb2000_docker']['etcd_version']
  command %q(
              etcdctl set /coreos.com/network/config
              '{ "Network": "10.1.0.0/16" }'
            )
  action :run
  only_if { sleep 5 }
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
  command '/opt/bin/flanneld '\
          '--ip-masq=true '\
          "--iface=#{node['dmlb2000_docker']['flannel_iface']}"
  restart_policy 'always'
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
    /var/lib/docker:/var/lib/docker:rw
    /var/lib/kubelet:/var/lib/kubelet:rw
  )
  command '/hyperkube kubelet --api_servers=http://localhost:8080 '\
          '--allow-privileged=true --containerized ' \
          '--v=2 --address=0.0.0.0 --enable_server '\
          "--hostname_override=127.0.0.1 "\
          '--config=/etc/kubernetes/manifests-multi ' \
          '--cluster-dns=10.0.0.10 --cluster-domain=cluster.local'
  restart_policy 'always'
  action :run
end


remote_file '/usr/local/sbin/kubectl' do
  source "http://storage.googleapis.com/kubernetes-release/release/v#{node['dmlb2000_docker']['k8s_version']}/bin/linux/amd64/kubectl"
  owner 'root'
  group 'root'
  mode '0755'
end
