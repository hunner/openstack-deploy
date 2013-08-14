class osdeploy::adminnetwork {

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

}
