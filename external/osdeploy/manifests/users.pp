class osdeploy::users {
  $users = hiera(users)
  create_resources("osdeploy::create_user", $users)
}
