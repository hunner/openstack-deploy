define osdeploy::create_user (
  $password,
  $tenant,
  $email) {
    keystone_user { "$name":
      ensure   => present,
      enabled  => "True",
      password => "$password",
      tenant   => "$tenant",
      email    => "$email",
    }

    keystone_user_role { "$name@$tenant":
      roles  => ['Member'],
      ensure => present,
    }
}

