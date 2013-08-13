node 'puppet' {
  include ::ntp
  include ::master
}

node 'control.localdomain' {
  include ::ntp
  include ::osdeploy::control
}
