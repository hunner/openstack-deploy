# == Class: master
#
# Configures the Puppet Master that manages an OpenStack deployment
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if it
#   has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should not be used in preference to class parameters  as of
#   Puppet 2.6.)
#
# === Examples
#
#  class { master: }
#
# === Authors
#
# Chris Hoge <chris.hoge@puppetlabs.com>
#
# === Copyright
#
# Copyright 2013 Puppet Labs
#
class master {

  Firewall {
    before  => Class['master::firewall::post'],
    require => Class['master::firewall::pre'],
  }

  class { 'master::firewall::pre': }
  class { 'master::firewall::post': }

}
