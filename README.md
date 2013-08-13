# Preliminary

This tuturial assumes a RedHat-based operating system. In particular, a minimal installation of
Scientific Linux 6.4. In addition to the minimal installation, git and your favorite text
editor should be installed. Finally, Puppet should be installed. Our suggestion is to use
the [Puppet Labs repository] (http://docs.puppetlabs.com/guides/puppetlabs_package_repositories.html).

This will be a multi-node installation, with the following servers:

* A Puppet Master for developing and deploying the services
* An OpenStack controller running the following services
  * memcached
  * RabbitMQ
  * MySQL
  * Keystone
  * Glance API
  * Glance Registry
  * Cinder API
  * Cinder Scheduler
  * Nova API
  * Nova Scheduler
  * Horizon
* An OpenStack network node running the Quantum server
* One or more compute nodes running
  * Nova Compute
  * Quantum Agent
  * Cinder Volume

Each server will need a minimum of three network devices. In this deployment they will be assigned as follows:

* eth1 is the management network
* eth2 is the external network
* eth3 is the api network

This deployment guide will build out the system in several stages.

* Chapter 1 will discuss the installation of the Puppet Master, including configuration and source control.
* Chapter 2 will begin setup of the controller node base services: memcached, RabbitMQ, and MySQL.
* Chapter 3 will show the basic setup the Keystone service on the controller node.
* Chapter 4 will set up the complete Glance service on the controller node.
* Chapter 5 will set up Quantum/Neutron on the network node.
* Chapter 6 will set up the Nova API and Scheduler on the controller node.
* Chapter 7 will set up the Nova Compute and Quantum Agents on the compute node.
* Chapter 8 will set up the Cinder API and Scheduler on the controller, as well as Cinder Volume on compute.
* Chapter 9 will tie the entire installation together with Horizon.

# Chapter 1: Puppet Configuration and Source Control

When using the Puppet repositories provided by Puppet Labs, it is simple to install and start your puppet master 
service:

`yum install puppet puppet-server
service puppetmaster start`

This will start up your server with the default settings. We're assuming that the hostname of your puppet
master is `puppet`. This can be set in the `/etc/sysconfig/network` file.

## Setting up git as source control

Before we start modifying the puppet manifests, we should set up source control so we can make changes to
our configuration changes and not worry about making mistakes we can't undo. First, start by creating
an empty repository on GitHub. In this instance, I called mine `openstack-deploy`.

Next go to your puppet configuration directory on your puppet server: 

`cd /etc/puppet`

Create a `README.md` file, initialize the repository, and set your GitHub repository as a remote:

`git init
git add README.md auth.conf fileserver.conf puppet.conf manifests/ modules/
git remote add origin <your repository origin>`

## Connecting the puppet master to itself

To illustrate configuration management with Puppet, we'll start by having the puppet server manage itself. 
Initiate a puppet agent run:

`puppet agent -t`

You should get output that looks like this back:

`Info: Retrieving plugin
Info: Caching catalog for puppet.localdomain
Info: Applying configuration version '1376343076'
Info: Creating state file /var/lib/puppet/state/state.yaml
Notice: Finished catalog run in 0.02 seconds`

There are no configurations set up, so let's start by creating a base that installs an ntp server. Begin by
creating a file `/etc/puppet/manifests/site.pp` with the following content:

`import 'nodes.pp'`

and a file `/etc/puppet/manifests/nodes.pp` with the content:

`node 'puppet' {
  include ::ntp
}`

Install the ntp module available from the Puppet Labs Forge:

`puppet module install puppet/ntp`

Start the puppet agent run again, `puppet agent -t` and if all goes well, you should see quite a bit of
output, and if the run was successful the `ntp` daemon should be running:

`service ntpd status`

Finally, we'll need to set up the firewall on the puppet node. By default, the RHEL firewall will block all
incoming connections. Install the firewall module:

`puppet module install puppetlabs/firewall`

This configuration is going to be a bit more complex, so we're going to break it out into its own module. 
To keep the repository simple, we'll create a directore called `/etc/puppet/external` where our own
module development will happen. We'll create a master module to manage the puppet master node.

`mkdir /etc/puppet/external
cd /etc/puppet/external
puppet module generate hogepodge-master
mv /etc/puppet/external/hogepodge-master /etc/puppet/external/master
cd /etc/puppet/external/master`

Within this module, we're going to create two classes to help manage the firewall. These are pre and post rules 
that allow us to set up the firewall rules, then ensure the rest of the system is locked down once all of
the rules have been applied. Make a firewall directory within the manifests directory,

`mkdir /etc/puppet/external/master/manifests/firewall`

Then create two files, `/etc/puppet/external/master/manifests/firewall/pre.pp`:

```
# set up the firewall rules

class master::firewall::pre {
  Firewall {
    require => undef,
  }   
    
  # Default firewall rules, based on the RHEL defaults
  #Table: filter
  #Chain INPUT (policy ACCEPT)
  #num  target     prot opt source               destination         
  #1    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           state RELATED,ESTABLISHED 
  firewall { '00001':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  } ->
  #2    ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0           
  firewall { '00002':
    proto  => 'icmp',
    action => 'accept',
  } ->  
  #3    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           
  firewall { '00003':
    proto  => 'all',
    action => 'accept', 
  } -> 
  #4    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:22 
  firewall { '00004': 
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 22,
  } -> 
  #5    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:8140 
  firewall { '00005':
   proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 8140,
  }

  # Puppet Master Firewall Rules

  firewall { '08140':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 5000,
  }
}
```

and `/etc/puppet/external/master/manifests/firewall/post.pp`

```
class master::firewall::post {
  #6    REJECT     all  --  0.0.0.0/0            0.0.0.0/0           reject-with icmp-host-prohibited 
  firewall { '99999':
    action => 'reject',
    proto  => 'all',
    reject => 'icmp-host-prohibited',
    before => undef,
  }

  #Chain FORWARD (policy ACCEPT)
  #num  target     prot opt source               destination         
  #1    REJECT     all  --  0.0.0.0/0            0.0.0.0/0           reject-with icmp-host-prohibited 

  #Chain OUTPUT (policy ACCEPT)
  #num  target     prot opt source               destination   

}
```

Update the `/etc/puppet/external/master/manifests/init.pp` to load the firewall rules:

```
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
```

Update the `nodes.pp` file to include the new master configuration class.

```
node 'puppet' {
  include ::ntp
  include ::master
}
```

Once you've verified that your configuration is working, push the changes up to github to save them remotely.

```
git add manifests/site.pp manifests/nodes.pp external/.
git commit
git push
```


# Chapter 2: Controller node Part I - memcached, RabbitMQ, MqSQL, Repositories

The next step in building out the OpenStack cluster is installing the basic services that OpenStack depends 
upon. These are memcached for key-value storage, RabbitMQ for messaging, and MySQL to maintain the state 
of your OpenStack cluster.

## 2.1 Connecting the controller node to the puppet master.

The first step in setting up the controller is to connect it to the puppet master. On first connection, 
the Certificate of Authority (CA) on the puppet master will be used in conjunction with the agent to
create an SSL identity that can be used to verify the puppet agent on the controller node. With puppet
installed on the controller, run the command

`puppet agent -t`

You should see a response that looks like this:

```
Info: Caching certificate for ca
Info: Creating a new SSL certificate request for control.localdomain
Info: Certificate Request fingerprint (SHA256): 06:6C:A1:ED:0A:F3:40:F6:5C:D7:4E:D2:55:B3:AC:DC:50:CD:CC:BA:19:7D:11:09:B2:49:B4:32:B6:DC:59:91
Exiting; no certificate found and waitforcert is disabled
```

This means that the agent successfully connected, but it could not send or recieve any other configuration
data as the puppet master had not yet signed this key. On the puppet server, list the waiting keys:

`puppet cert --list`

The outstanding keys will be listed. 

`"control.localdomain" (SHA256) 06:6C:A1:ED:0A:F3:40:F6:5C:D7:4E:D2:55:B3:AC:DC:50:CD:CC:BA:19:7D:11:09:B2:49:B4:32:B6:DC:59:91`

Sign the key:

`puppet cert --sign control.localdomain`

```
Notice: Signed certificate request for control.localdomain
Notice: Removing file Puppet::SSL::CertificateRequest control.localdomain at '/var/lib/puppet/ssl/ca/requests/control.localdomain.pem'
```

Now run the `puppet agent -t` on the control node again and verify that a connection was made, but that no 
configuration for the node exists.

```
Error: Could not retrieve catalog from remote server: Error 400 on SERVER: Could not find default node or by name with 'control.localdomain, control' on node control.localdomain
Warning: Not using cache on failed catalog
Error: Could not retrieve catalog; skipping run
```

Update the node.pp file to add a new entry for `control.localdomain`, and install ntp.

```
node 'puppet' {
  include ::ntp
}

node 'control.localdomain' {
  include ::ntp
}
```

Rerun the agent on the control node, and verify that ntp is installed and running.
