class osdeploy::control {
  class { 'osdeploy::common': }

    class { 'memcached':
        listen_ip => '127.0.0.1',
        tcp_port  => '11211',
        udp_port  => '11211',
    }

}
