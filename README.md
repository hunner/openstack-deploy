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


# Chapter 2: Controller node Part I - Repositories, memcached, RabbitMQ, MqSQL

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

## 2.2 Install the puppet-openstack modules

From this point forward, we're going to rely upon the puppet-openstack modules. We'll be using some
of the classes from the puppet-openstack module itself, mainly the helpers, but developing our
own classes to build out the nodes as an exercise in how the base modules work. The puppet-openstack
module itself is more of a set of working examples rather than an all-in-one deployment scheme.

To get all of the modules and their dependencies, just type `puppet module install puppetlabs/puppet-openstack`

```
Notice: Preparing to install into /etc/puppet/modules ...
Notice: Downloading from https://forge.puppetlabs.com ...
Notice: Installing -- do not interrupt ...
/etc/puppet/modules
└─┬ puppetlabs-openstack (v2.1.0)
  ├─┬ puppetlabs-cinder (v2.1.0)
  │ ├── dprince-qpid (v1.0.2)
  │ ├── puppetlabs-inifile (v1.0.0)
  │ ├── puppetlabs-mysql (v0.9.0)
  │ └─┬ puppetlabs-rabbitmq (v2.1.0)
  │   └── puppetlabs-apt (v1.2.0)
  ├── puppetlabs-glance (v2.1.0)
  ├─┬ puppetlabs-horizon (v2.1.0)
  │ ├─┬ puppetlabs-apache (v0.8.1)
  │ │ └── ripienaar-concat (v0.2.0)
  │ └── saz-memcached (v2.1.0)
  ├── puppetlabs-keystone (v2.1.0)
  ├─┬ puppetlabs-nova (v2.1.0)
  │ └── duritong-sysctl (v0.0.1)
  ├─┬ puppetlabs-quantum (v2.1.1)
  │ └── puppetlabs-vswitch (v0.1.1)
  └─┬ puppetlabs-swift (v2.1.0)
    ├── puppetlabs-rsync (v0.1.0)
    ├── puppetlabs-xinetd (v1.2.0)
    └── saz-ssh (v1.2.0)
```

## 2.3 Create our OpenStack deployment module

Like the `master` module, we're going to create our own OpenStack deployment module.

```
cd /etc/puppet/external
puppet module generate hogepodge-osdeploy
mv hogepodge-osdeploy osdeploy
```

## 2.4 Set up the module to install the latest Grizzly repository

In your osdeploy module, create a new file called manifests/common.pp, which will hold configuration
common to all of our OpenStack nodes. We'll begin by having this class install the Grizzly repositories.

```
class osdeploy::common {

  class { 'openstack::repo': }

}
```

Now, create a class that represents the controller node in a file `control.pp`

```
class osdeploy::control {
    class { 'osdeploy::common': }
}
```

Update the nodes.pp file to assign the `osdeploy::control` class to the controller node.

```
node 'control.localdomain' {
  include ::ntp
  include ::osdeploy::control
}
```

Try the changes out on the controller node. Note that on RedHat the repositories provide
updates to the kernel necessary for OpenStack Quantum networking to function propertly.
Unfortunately, there's no good way to for updates and reboots, so it's a good time to do 
this manually.

```
yum update
reboot
```

Now's a good time to commit and push your changes up to GitHub.

## 2.5 Installing memcached

Update your control.pp file to include a memcache installation (the required module
was installed as a puppet-openstack dependency).

```
class osdeploy::control {
    class { 'osdeploy::common': }

    class { 'memcached':
        listen_ip => '127.0.0.1',
        tcp_port  => '11211',
        udp_port  => '11211',
    }
}
```

## 2.6 Installing RabbitMQ

### 2.6.1 Network dependency

For this deployment, my system assumes the OpenStack management network is on 172.16.211.0/24
(256 network addresses), on the eth1 device. My network configuration will be static, so I will 
manage it with a Puppet network module. Your configuration may differ. 

Install the `adrien/network` module:

```
puppet module install adrien/network
```

Add a new file to the module manifest, `adminnetwork.pp`:

```
class osdeploy::adminnetwork {
  exec { 'restart eth1':
    command     => '/sbin/ifdown eth1; /sbin/ifup eth1',
  } 

  network_config { 'eth1':
    ensure      => present,
    family      => 'inet',
    ipaddress   => '172.16.211.10',
    method      => 'static',
    onboot      => 'true',
    reconfigure => 'true',
  }
}
```

Add an entry to the `nodes.pp` file to run the network configuration if necessary.

```
node 'control.localdomain' {
  include ::ntp
  include ::osdeploy::adminnetwork
  include ::osdeploy::control
}
```

### 2.6.2 RabbitMQ

For RabbitMQ, we'll install it using the nova::rabbitmq class. For security, we'll also take
advantage of Hiera, the hierarchical database that works with Puppet to separate configuration
parameters from module logic. In this instance, we'll want to set a custom RabbitMQ password
and keep it out of our database.

Begin by creating an `/etc/puppet/hiera.yaml` configuration file.

```
---
:backends:
  - yaml
:yaml:
  :datadir: /etc/puppet/hieradata
:hierarchy:
  - common
```

Next, populate the custom database with the entry for the RabbitMQ parameter. The file is
`/etc/puppet/hieradata/common.yaml`

```
nova::rabbitmq::password: 'xyme-mita'
```

If you look at the nova module, you'll see in the rabbitmq.pp file that the parameter `password`
to the class `nova::rabbitmq` defaults to `guest`. The hiera entry overrides this default
parameter.

Now add the `nova:rabbitmq` class to the `control.pp` file:

```
class osdeploy::control {
  class { 'osdeploy::common': }

    class { 'memcached':
        listen_ip => '127.0.0.1',
        tcp_port  => '11211',
        udp_port  => '11211',
    }

    class { 'nova::rabbitmq': }

}
```

Apply the configuration to your controller, and verify that RabbitMQ is running.

```
puppet agent -t
service rabbitmq-server status
```

## 2.7 MySQL

The final step for the setup of the base services is to install MySQL on the controller node.
This will just cover the initial setup, with the admin user and bind port. As services
are added to the controller, the relevant databases will be created for this. In general,
the openstack::db:mysql class can handle and entire deployment, but for our purposes
we're going to add the OpenStack databases as needed.

Begin by creating a db.pp file in your manifest. We'll create a database entry with a root
password, and bind it to the OpenStack admin address.

```
class osdeploy::db (
  mysql_root_password,
  bind_address) { 
  class { 'mysql::server': 
  config_hash => { 
    'root_password' => mysql_root_password, 
    'bind_address' => bind_address, 
  } 
  enabled     => enabled, 
  } 
}
```

The database root password and bind address should be set in your hiera database.

```
nova::rabbitmq::password: 'xyme-mita'
osdeploy::db::mysql_root_password: 'fi-de-hi'
osdeploy::db::bind_address: '172.16.211.10'
```

Add the database class to your control class:

```
class osdeploy::control {
  class { 'osdeploy::common': }
  class { 'osdeploy::db': }

    class { 'memcached':
        listen_ip => '127.0.0.1',
        tcp_port  => '11211',
        udp_port  => '11211',
    }

    class { 'nova::rabbitmq': }

}
```

Apply this on the control node. Note that the application will fail. You'll need to manually set your
password on the mysql database. On the control node, execute the command 

```
mysqladmin -u root password fi-de-hi
```

To set the password (note it matches the entry in osdeploy).
