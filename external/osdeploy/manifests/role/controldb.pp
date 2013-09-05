class osdeploy::role::controldb inherits osdeploy::role {
  include osdeploy::profile::control
  include osdeploy::profile::database
}
