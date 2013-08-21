class osdeploy::db (
  $mysql_root_password,
  $bind_address) { 
  class { 'mysql::server': 
    config_hash       => {
      'root_password' => $mysql_root_password,
      'bind_address'  => $bind_address,
    },
  } 

  class { 'mysql::server::account_security': }

  # MySQL
  firewall { '03306 - MySQL':
   proto   => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '3306',
    source => '172.16.211.0/24',
  }
  
}
