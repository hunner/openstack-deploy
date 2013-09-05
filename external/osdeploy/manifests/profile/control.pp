class osdeploy::profile::control {
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::db': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::keystone': } ->
  class { 'osdeploy::users':} ->
  class { 'osdeploy::glance': } ->
  class { 'osdeploy::networkdb': } ->
  class { 'osdeploy::networkauth': } ->
  class { 'osdeploy::cindercontrol': } ->
  class { 'osdeploy::novacontrol': } ->
  class { 'osdeploy::firewall::post': } 

  exec { 'restart eth1':
    command     => '/sbin/ifdown eth1; /sbin/ifup eth1',
  } 

  network_config { 'eth1':
    ensure      => present,
    family      => 'inet',
    ipaddress   => '172.16.211.10',
    method      => 'static',
    onboot      => 'true',
    reconfigure => 'true',
    notify      => Exec['restart eth1'],
  }

  exec { 'restart eth3':
    command     => '/sbin/ifdown eth3; /sbin/ifup eth3',
  } 

  network_config { 'eth3':
    ensure      => present,
    family      => 'inet',
    ipaddress   => '192.168.85.10',
    method      => 'static',
    onboot      => 'true',
    reconfigure => 'true',
    notify      => Exec['restart eth3'],
  }
}
