class osdeploy::networkauth (
  $network_user_password = '127.0.0.1',
  $network_public_address = '127.0.0.1',
  $network_admin_address = '127.0.0.1',
  $network_internal_address = '127.0.0.1',
  $region = 'openstack',
) {
  class { 'quantum::keystone::auth':
    password         => $network_user_password,
    public_address   => $network_public_address,
    admin_address    => $network_admin_address,
    internal_address => $network_internal_address,
    region           => $region,
  }
}
