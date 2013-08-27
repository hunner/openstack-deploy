class osdeploy::control {
  class { 'osdeploy::common': } ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::db': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::keystone': } ->
  class { 'osdeploy::glance': } ->
  class { 'osdeploy::firewall::post': } 
}
