class osdeploy::computenode {
  class { 'osdeploy::common': }
  class { 'osdeploy::novacompute': }
}
