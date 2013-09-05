# == Class: osdeploy
#
# Full description of class osdeploy here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { osdeploy:
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ]
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2013 Your name here, unless otherwise noted.
#

class osdeploy (
  $ovs_local_ip,
  $internal_address,
  $quantum_user_password,
  $libvirt_type = 'kvm', # use 'qemu' for virtualized test environments
  $nova_db_user = 'nova',
  $nova_db_password = 'password',
  $nova_db_host = '127.0.0.1',
  $nova_db_name = 'nova',
  $rabbit_user = 'guest',
  $rabbit_password = 'guest',
  $rabbit_host = '127.0.0.1',
  $glance_api_servers = 'http://127.0.0.1:9292',
  $vncproxy_host = '127.0.0.1',
  $keystone_host = '127.0.0.1',
  $quantum_host = '127.0.0.1',
  $cinder_db_user = 'cinder',
  $cinder_db_password = 'password',
  $cinder_db_host = '127.0.0.1',
  $cinder_db_name = 'cinder',
  $nova_sql_connection = "mysql://{$nova_db_user}:${nova_db_password}@{nova_db_host}/{nova_db_name}",
) {
}
