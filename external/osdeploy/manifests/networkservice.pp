class osdeploy::networkservice (
  $network_user_password,
  $network_auth_host,
  $network_public_address = '127.0.0.1',
  $network_admin_address = '127.0.0.1',
  $network_internal_address = '127.0.0.1',
  $network_public_network = '0.0.0.0',
  $network_private_network = '0.0.0.0',
  $region = 'openstack',
  $network_db_host = 'localhost',
  $network_db_user = 'network',
  $network_db_password = 'network-password',
  $network_db_name = 'network',
  $rabbit_host = 'localhost',
  $rabbit_password = 'guest',
) {


  $sql_connection = "mysql://${network_db_user}:${network_db_password}@${network_db_host}/${network_db_name}?charset=utf8"

  # public API access
  firewall { '09696 - Quantum API Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9696',
    source => $network_public_network,
  } 

  # private API access
  firewall { '09696 - Quantum API Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9696',
    source => $network_private_network,
  } 

  class {'::quantum':
    rabbit_host     => $rabbit_host,
    rabbit_password => $rabbit_password,
    verbose         => 'True',
    debug           => 'True',
  }

  class { 'keystone::client': } ->

  class {'quantum::server':
    auth_host     => $network_auth_host,
    auth_password => $network_user_password,
  }

  class {'quantum::plugins::ovs':
    sql_connection      => $sql_connection,
    tenant_network_type => 'gre',
  }

  class {'quantum::agents::ovs':
    enable_tunneling => 'True',
    local_ip         => $network_internal_address,
  }
}
