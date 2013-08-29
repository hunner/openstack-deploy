class osdeploy::networkdb(
  $network_db_user = 'network',
  $network_db_password = 'network-password',
  $network_db_name = 'network',
  $network_db_allowed_hosts = false 
)
{
  # database setup
  $network_sql_connection = "mysql://$network_db_user:$network_db_password@$network_db_host/$network_db_name"
  class { 'quantum::db::mysql':
    user          => $network_db_user,
    password      => $network_db_password,
    dbname        => $network_db_name,
    allowed_hosts => $network_db_allowed_hosts,
  } 

}

