node 'puppet' {
  include ::ntp
  include ::master
}

node 'control.localdomain' {
  include ::ntp
  include ::osdeploy::adminnetwork
  include ::osdeploy::control
}

node 'network.localdomain' {
  include ::ntp
  include ::osdeploy::networknetwork
  include ::osdeploy::networknode
}
