class osdeploy::cindercontrol (
  $cinder_user_password,
  $cinder_public_address = '127.0.0.1',
  $cinder_admin_address = '127.0.0.1',
  $cinder_internal_address = '127.0.0.1',
  $cinder_public_network = '0.0.0.0',
  $cinder_private_network = '0.0.0.0',
  $region = 'openstack',
  $cinder_db_host = 'localhost',
  $cinder_db_user = 'cinder',
  $cinder_db_password = 'cinder-password',
  $cinder_db_name = 'cinder',
  $cinder_db_allowed_hosts = false,
  $rabbit_host = ['127.0.0.1'],
  $rabbit_password = 'guest',
  $cinder_auth_host = '127.0.0.1',
) {

  $cinder_db_connection = "mysql://$cinder_db_user:$cinder_db_password@$cinder_db_host/$cinder_db_name"

  class { 'cinder::db::mysql':
    user          => $cinder_db_user,
    password      => $cinder_db_password,
    dbname        => $cinder_db_name,
    allowed_hosts => $cinder_db_allowed_hosts,
  }

  class { 'cinder::keystone::auth':
    password         => $cinder_user_password,
    public_address   => $cinder_public_address,
    admin_address    => $cinder_admin_address,
    internal_address => $cinder_internal_address,
    region           => $region,
  } 

  # public API access
  firewall { '03260 - Cinder Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '3260',
    source => $cinder_public_network,
  }

  # private API access
  firewall { '03260 - Cinder Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '3260',
    source => $cinder_private_network,
  }

  # admin API access
  firewall { '08776 - Metadata Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8776',
    source => $cinder_public_network,
  }

  # admin API access
  firewall { '08776 - Metadata Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '8776',
    source => $cinder_private_network,
  }

  class { '::cinder':
    sql_connection    => $cinder_db_connection,
    rabbit_hosts      => $rabbit_host,
    rabbit_userid     => $rabbit_user,
    rabbit_password   => $rabbit_password,
    debug             => true,
    verbose           => true,
  } 

  class { '::cinder::api':
    keystone_password  => $cinder_user_password,
    keystone_auth_host => $cinder_auth_host,
  } 

  class { '::cinder::scheduler':
    scheduler_driver => 'cinder.scheduler.simple.SimpleScheduler',
  }
}
