class osdeploy::novacompute inherits osdeploy {

  # base configuration for nova
  class { '::nova':
    sql_connection     => $nova_sql_connection,
    rabbit_userid      => $rabbit_user,
    image_service      => 'nova.image.glance.GlanceImageService',
    glance_api_servers => $glance_api_servers,
    verbose            => true,
    rabbit_host        => $rabbit_host,
  }

  # set up nova-compute
  class { '::nova::compute':
    enabled                       => true,
    vnc_enabled                   => true,
    vncserver_proxyclient_address => $internal_address,
    vncproxy_host                 => $vncproxy_host,
  }

  # configure libvirt
  class { '::nova::compute::libvirt':
    libvirt_type     => $libvirt_type,
    vncserver_listen => $internal_address,
  }

  # configure quantum
  class { '::quantum':
    rabbit_host     => $rabbit_host,
    rabbit_password => $rabbit_password,
  }

  class { '::quantum::agents::ovs':
    enable_tunneling => true,
    local_ip         => $internal_address,
  }

  class { '::nova::compute::quantum': }

  class { '::nova::network::quantum':
    quantum_admin_password    => $quantum_user_password,
    quantum_auth_strategy     => 'keystone',
    quantum_url               => "http://${quantum_host}:9696",
    quantum_admin_username    => 'quantum',
    quantum_admin_tenant_name => 'service',
    quantum_admin_auth_url    => "http://${keystone_host}:35357/v2.0",
  }

  # configure cinder

  $cinder_sql_connection = "mysql://${cinder_db_user}:${cinder_db_password}@${cinder_db_host}/${cinder_db_name}"

  class { '::cinder':
    sql_connection    => $cinder_sql_connection,
    rabbit_host       => $rabbit_host,
    rabbit_userid     => $rabbit_user,
    rabbit_password   => $rabbit_password,
    debug             => true,
    verbose           => true,
  } 

  class { '::cinder::setup_test_volume': } ->

  class { '::cinder::volume':
    package_ensure => true,
    enabled        => true,
  }

  class { '::cinder::volume::iscsi':
    iscsi_ip_address => $internal_address,
  }

}
