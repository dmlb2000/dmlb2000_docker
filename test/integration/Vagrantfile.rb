# rubocop:disable Style/FileName
Vagrant.configure(2) do |config|
  config.vm.provider 'libvirt' do |libvirt|
    libvirt.storage :file, size: '100G'
  end
end
