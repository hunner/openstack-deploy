class osdeploy::networknode {
  class { 'osdeploy::common':} ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::networkservice': }
  class { 'osdeploy::firewall::post': }
}
 
