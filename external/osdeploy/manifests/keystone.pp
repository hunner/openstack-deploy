class osdeploy::keystone (
  $keystone_admin_token,
  $admin_email,
  $admin_pass,
  $admin_tenant = 'admin',
  $keystone_public_address = '127.0.0.1',
  $keystone_admin_address = '127.0.0.1',
  $keystone_internal_address = '127.0.0.1',
  $keystone_public_network = '0.0.0.0',
  $keystone_private_network = '0.0.0.0',
  $region = 'openstack',
  $keystone_admin_user = 'keystone',
  $keystone_db_host = 'localhost',
  $keystone_db_user = 'keystone',
  $keystone_db_password = 'keystone-password',
  $keystone_db_name = 'keystone',
  $keystone_db_allowed_hosts = false,) 
{ 


  # public API access
  firewall { '5000 - Keystone Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '5000',
    source => $keystone_public_network,
  } 

  # admin API access
  firewall { '35357 - Keystone Admin':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '35357',
    source => $keystone_private_network,
  }

  $keystone_sql_connection = "mysql://$keystone_db_user:$keystone_db_password@$keystone_db_host/$keystone_db_name"

  class { 'keystone::db::mysql':
    user          => $keystone_db_user,
    password      => $keystone_db_password,
    dbname        => $keystone_db_dbname,
    allowed_hosts => $keystone_db_allowed_hosts,
  } ->

  class { '::keystone':
    admin_token    => $keystone_admin_token,
    sql_connection => $keystone_sql_connection,
  } ->

  class { 'keystone::roles::admin': 
    email        => $admin_email,
    password     => $admin_pass,
    admin_tenant => $admin_tenant,
  } ->

  class { 'keystone::endpoint':
    public_address   => $keystone_public_address,
    admin_address    => $keystone_admin_address,
    internal_address => $keystone_internal_address,
    region           => $region,
  }
}
