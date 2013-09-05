node 'puppet' {
  include ::ntp
  include ::master
}

node 'control.localdomain' {
  include ::osdeploy::role::controldb
  #include ::ntp
  #include ::osdeploy::adminnetwork
  #include ::osdeploy::control
}

node 'network.localdomain' {
  include ::osdeploy::role::network
  #include ::ntp
  #include ::osdeploy::networknetwork
  #include ::osdeploy::networknode
}

node 'compute.localdomain' {
  include ::osdeploy::role::compute
  #include ::ntp
  #include ::osdeploy::computenetwork
  #include ::osdeploy::computenode
}
