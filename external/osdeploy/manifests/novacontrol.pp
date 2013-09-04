class osdeploy::novacontrol (
  $nova_user_password,
  $quantum_user_password,
  $nova_public_address = '127.0.0.1',
  $nova_admin_address = '127.0.0.1',
  $nova_internal_address = '127.0.0.1',
  $nova_public_network = '0.0.0.0',
  $nova_private_network = '0.0.0.0',
  $region = 'openstack',
  $nova_db_host = 'localhost',
  $nova_db_user = 'nova',
  $nova_db_password = 'nova-password',
  $nova_db_name = 'nova',
  $nova_db_allowed_hosts = false,
  $glance_api_server = 'http://127.0.0.1:9292',
  $vncproxy_host = '127.0.0.1',
  $rabbit_host = ['127.0.0.1'],
  $rabbit_password = 'guest',
  $memcached_host = ['127.0.0.1:11211'],
  $nova_auth_host = '127.0.0.1',
  $keystone_admin_url = 'http://127.0.0.1:35357/v2.0',
  $quantum_url = 'http://127.0.0.1:9696',
) {

  $nova_db_connection = "mysql://$nova_db_user:$nova_db_password@$nova_db_host/$nova_db_name"

  class { 'nova::db::mysql':
    user          => $nova_db_user,
    password      => $nova_db_password,
    dbname        => $nova_db_name,
    allowed_hosts => $nova_db_allowed_hosts,
  }

  class { 'nova::keystone::auth':
    password         => $nova_user_password,
    public_address   => $nova_public_address,
    admin_address    => $nova_admin_address,
    internal_address => $nova_internal_address,
    region           => $region,
    cinder           => true,
  } 

  # public API access
  firewall { '08774 - Nova Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8774',
    source => $nova_public_network,
  }

  # private API access
  firewall { '08774 - Nova Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8774',
    source => $nova_private_network,
  }

  # admin API access
  firewall { '08775 - Metadata Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8775',
    source => $nova_public_network,
  }

  # admin API access
  firewall { '08775 - Metadata Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8775',
    source => $nova_private_network,
  }

  class { 'nova::network::quantum':
    quantum_admin_password => $quantum_user_password,
    quantum_region_name    => $region,
    quantum_admin_auth_url => $keystone_admin_url,
    quantum_url            => $quantum_url,
  } 

  class { 'nova':
    sql_connection     => $nova_db_connection,
    glance_api_servers => $glance_api_server,
    memcached_servers => $memcached_host,
    rabbit_hosts      => $rabbit_host,
    rabbit_userid     => $rabbit_user,
    rabbit_password   => $rabbit_password,
    debug             => true,
    verbose           => true,
  } 

  class { 'nova::api':
    admin_password => $nova_user_password,
    auth_host      => $nova_auth_host,
    enabled        => true,
  } ->

  # a bunch of nova services that require no configuration
  class { [ 
    'nova::scheduler',
    'nova::objectstore',
    'nova::cert',
    'nova::consoleauth',
    'nova::conductor'
  ]:  
    enabled => true,
  } 


  class { 'nova::vncproxy':
    host     => $vncproxy_host,
    enabled => true,
  }
}
