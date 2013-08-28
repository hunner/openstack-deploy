class osdeploy::glance (
  $glance_user_password,
  $glance_public_address = '127.0.0.1',
  $glance_admin_address = '127.0.0.1',
  $glance_internal_address = '127.0.0.1',
  $glance_public_network = '0.0.0.0',
  $glance_private_network = '0.0.0.0',
  $region = 'openstack',
  $glance_db_host = 'localhost',
  $glance_db_user = 'glance',
  $glance_db_password = 'glance-password',
  $glance_db_name = 'glance',
  $glance_db_allowed_hosts = false 
) {

  # public API access
  firewall { '09292 - Glance Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9292',
    source => $glance_public_network,
  }

  # private API access
  firewall { '09292 - Glance Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9292',
    source => $glance_private_network,
  }

  # admin API access
  firewall { '09191 - Glance Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9191',
    source => $glance_private_network,
  }

  # database setup
  $glance_sql_connection = "mysql://$glance_db_user:$glance_db_password@$glance_db_host/$glance_db_name"
  class { 'glance::db::mysql':
    user          => $glance_db_user,
    password      => $glance_db_password,
    dbname        => $glance_db_name,
    allowed_hosts => $glance_db_allowed_hosts,
  } 

  # Keystone setup for Glance. Creates glance admin user and creates catalog settings
  # sets the glance user to be 'glance', tenant 'services'
  class  { 'glance::keystone::auth':
    password         => $glance_user_password,
    public_address   => $glance_public_address,
    admin_address    => $glance_admin_address,
    internal_address => $glance_internal_address,
    region           => $region,
  }

  # Note that the api node and registry node both reside on the controller
  # It's reasonable that all API functions could be separated from other
  # backend functions

  # The api server depends on the registry, so install the registry first
  class { 'glance::api':
    keystone_password => $glance_user_password,
    auth_host         => $keystone_admin_endpoint,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    sql_connection    => $glance_sql_connection,
    verbose          => true,
    debug            => true,
  }

  class { 'glance::registry':
    keystone_password => $glance_user_password,
    sql_connection    => $glance_sql_connection,
    auth_host         => $keystone_admin_endpoint,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    verbose          => true,
    debug            => true,
  } 

  class { 'glance::backend::file': }
}
