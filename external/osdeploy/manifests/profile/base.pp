class osdeploy::profile::base {
  class { 'ntp': }
  class { 'openstack::repo': }
}
