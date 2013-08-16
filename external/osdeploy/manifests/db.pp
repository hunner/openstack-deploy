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
}
