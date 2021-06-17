# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.provider "virtualbox" do |vb|
  end
  # Don't check for updates to the configured box on every vagrant up.
  config.vm.box_check_update = false

  config.vm.define "loadbalancer1", primary: true do |loadbalancer1|
    loadbalancer1.vm.box = "centos/7"
    loadbalancer1.vm.hostname = "loadbalancer1"
    loadbalancer1.vm.network "private_network", ip: "172.29.1.10"
    loadbalancer1.vm.provision "shell", path: "scripts/provision_haproxy.sh"
  end

  config.vm.define "web1" do |web1|
    web1.vm.box = "centos/7"
    web1.vm.hostname = "web1"
    web1.vm.network "private_network", ip: "172.29.1.101"
    web1.vm.provision "shell", path: "scripts/provision_httpd.sh", args: "web1"
  end

  config.vm.define "web2" do |web2|
    web2.vm.box = "centos/7"
    web2.vm.hostname = "web2"
    web2.vm.network "private_network", ip: "172.29.1.102"
    web2.vm.provision "shell", path: "scripts/provision_httpd.sh", args: "web2"
  end

  config.vm.define "web3" do |web3|
    web3.vm.box = "centos/7"
    web3.vm.hostname = "web3"
    web3.vm.network "private_network", ip: "172.29.1.103"
    web3.vm.provision "shell", path: "scripts/provision_httpd.sh", args: "web3"
  end

end
