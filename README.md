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
master is `puppet`. This can be set in the `/etc/sysconfig/network` file. Don't use the version of Puppet supplied
by EPEL. It is out of date, unsupported, and severely lacking in features. The puppet-openstack modules won't
work with it.

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

## 2.7 Firewall

Set up the firewall for the controller node. Begin by creating the `firewall/pre.pp`
and `firewall/post.pp` files. These files will include a rule for RabbitMQ as well
as well as the basic services

```
# set up the firewall rules

class osdeploy::firewall::pre {
  Firewall {
    require => undef,
  }   
    
  # Default firewall rules, based on the RHEL defaults
  #Table: filter
  #Chain INPUT (policy ACCEPT)
  #num  target     prot opt source               destination         
  #1    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           state RELATED,ESTABLISHED 
  firewall { '00001 - related established':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  } ->
    #2    ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0           
  firewall { '00002 - localhost':
    proto  => 'icmp',
    action => 'accept',
    source => '127.0.0.1',
  } ->  
  #3    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           
  firewall { '00003 - localhost':
    proto  => 'all',
    action => 'accept',
    source => '127.0.0.1',
  } -> 
  #4    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:22 
  firewall { '00022 - ssh': 
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 22,
  } -> 
  #5    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:8140 
  # RabbitMQ
  firewall { '05672 - RabbitMQ':
   proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 5672,
  }
}
```

```
class osdeploy::firewall::post {
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

Add the firewall rules to the `control.pp` manifest. Note the addition of dependency
chaining to make sure everything is applied in the proper order.

```
class osdeploy::control {
  class { 'osdeploy::common': } ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::firewall::post': } 
}
```

## 2.8 MySQL

The next step for the setup of the base services is to install MySQL on the controller node.
This will just cover the initial setup, with the admin user and bind port. As services
are added to the controller, the relevant databases will be created for this. In general,
the openstack::db:mysql class can handle and entire deployment, but for our purposes
we're going to add the OpenStack databases as needed.

Begin by creating a db.pp file in your manifest. We'll create a database entry with a root
password, and bind it to the OpenStack admin address. We'll also disable the default
accounts to improve the security of the database. The firewall needs to be opened up
to allow MySQL access on the admin network.

```
class osdeploy::db (
  $mysql_root_password,
  $bind_address) { 
  class { 'mysql::server': 
    config_hash       => {
      'root_password' => $mysql_root_password,
      'bind_address'  => $bind_address,
    },
  } 

  class { 'mysql::server::account_security': }

  # MySQL
  firewall { '03306 - MySQL':
   proto   => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '3306',
    source => '172.16.211.0/24',
  }
  
}
```

The database root password and bind address should be set in your hiera database.

```
osdeploy::db::mysql_root_password: 'fi-de-hi'
osdeploy::db::bind_address: '172.16.211.10'
```

Add the database class to your control class:

```
class osdeploy::control {
  class { 'osdeploy::common': } ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::db': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::firewall::post': } 
}
```

Apply this on the control node. Note that you might need to manually set your
password on the mysql database if this update fails. If so, on the control node, 
execute the command 

```
mysqladmin -u root password fi-de-hi
```

To set the password (note it matches the entry in osdeploy). Apply the configuration again, and 
your setup database should be complete.


# Chapter 3: Keystone

Every other OpenStack project depends upon the Keystone as both an identity service
and a service catalog for all of the OpenStack system.

## 3.1 Deplying the Keystone services

There are several parts of Keystone that need to be deployed. We'll start by 
creating a `keystone.pp` file to contain the keystone deployment. Start
with a class, with several parameters to control the particulars of our
installation:

```
class osdeploy::keystone (
  $keystone_admin_token,
  $admin_email,
  $admin_pass,
  $admin_tenant = 'admin',
  $keystone_public_address = '127.0.0.1',
  $keystone_admin_address = '127.0.0.1',
  $keystone_internal_address = '127.0.0.1',
  $keystone_public_network = '0.0.0.0',
  $keystone_private_network = '0.0.0.0',
  $region = 'openstack',
  $keystone_admin_user = 'keystone',
  $keystone_db_host = 'localhost',
  $keystone_db_user = 'keystone',
  $keystone_db_password = 'keystone-password',
  $keystone_db_name = 'keystone',
  $keystone_db_allowed_hosts = false,) 
{ 
}
```

An important note: Keystone is the authentication and authorization service. Its
public interface should be running over `https`. This configuration runs keystone
over http, meaning all of your passwords and authentication tokens will be sent over
plain text. Currently setting up https (which requires certificates) is out of the
scope of this document. It is an important issue, however, and will be addressed
in a future revision.

Other items no note in the configuration settings. The `$keystone_admin_token` is
not attached to any particular user, and gives complete administrative control
over Keystone. It's used to bootstrap users and catalogs into the system. Needless to
say, it must be kept secret. We'll set it using hiera, and this underscores the
importance of making sure your hiera data source is secure.

Keystone needs a public network that its API service runs on. In this instance,
the public network is on `192.168.85.0/24`. Update the network configuration 
in `adminnetwork.pp` to add this network and IP address at `192.168.85.10`.

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
    notify      => Exec['restart eth1'],
  }

  exec { 'restart eth3':
    command     => '/sbin/ifdown eth3; /sbin/ifup eth3',
  } 

  network_config { 'eth3':
    ensure      => present,
    family      => 'inet',
    ipaddress   => '192.168.85.10',
    method      => 'static',
    onboot      => 'true',
    reconfigure => 'true',
    notify      => Exec['restart eth3'],
  }
}
```

Set up the firewall in our new keystone class to allow for public and private
network access. The public port is 5000, the admin port is 35357. The keystone
service is going to be running on `0.0.0.0`, which means it will be available
on all network devices. However, we want to enforce network segmentation, so
these firewall rules will enforce that public traffic be routed through the
public network interface, and admin traffic will be routed over the admin
network interface.

```
  # public API access
  firewall { '5000 - Keystone Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '5000',
    source => $keystone_public_network,
  }

  # admin API access
  firewall { '35357 - Keystone Admin':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '35357',
    source => $keystone_private_network,
  }
```

Next, keystone needs to have its database connection configured:

```
  $keystone_sql_connection = "mysql://$keystone_db_user:$keystone_db_password@$keystone_db_host/$keystone_db_name"

  class { 'keystone::db::mysql':
    user          => $keystone_db_user,
    password      => $keystone_db_password,
    dbname        => $keystone_db_dbname,
    allowed_hosts => $keystone_db_allowed_hosts,
  } ->
```

Note the dependency arrow, what follows will be the keystone installation, and we
need to enforce the installation order. What follows next is the keystone
service installation:

```
  class { '::keystone':
    admin_token    => $keystone_admin_token,
    sql_connection => $keystone_sql_connection,
  } ->
```

Once the service is set up, the keystone admin role can be created and
keystone can add itself to its service catalog:

```
  class { 'keystone::roles::admin': 
    email        => $admin_email,
    password     => $admin_pass,
    admin_tenant => $admin_tenant,
  } ->

  class { 'keystone::endpoint':
    public_address   => $keystone_public_address,
    admin_address    => $keystone_admin_address,
    internal_address => $keystone_internal_address,
    region           => $region,
  }
```

The entire configuration manifest looks like this:

```
class osdeploy::keystone (
  $keystone_admin_token,
  $admin_email,
  $admin_pass,
  $admin_tenant = 'admin',
  $keystone_public_address = '127.0.0.1',
  $keystone_admin_address = '127.0.0.1',
  $keystone_internal_address = '127.0.0.1',
  $keystone_public_network = '0.0.0.0',
  $keystone_private_network = '0.0.0.0',
  $region = 'openstack',
  $keystone_admin_user = 'keystone',
  $keystone_db_host = 'localhost',
  $keystone_db_user = 'keystone',
  $keystone_db_password = 'keystone-password',
  $keystone_db_name = 'keystone',
  $keystone_db_allowed_hosts = false,) 
{ 


  # public API access
  firewall { '5000 - Keystone Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '5000',
    source => $keystone_public_network,
  } 

  # admin API access
  firewall { '35357 - Keystone Admin':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '35357',
    source => $keystone_private_network,
  }

  $keystone_sql_connection = "mysql://$keystone_db_user:$keystone_db_password@$keystone_db_host/$keystone_db_name"

  class { 'keystone::db::mysql':
    user          => $keystone_db_user,
    password      => $keystone_db_password,
    dbname        => $keystone_db_dbname,
    allowed_hosts => $keystone_db_allowed_hosts,
  } ->

  class { '::keystone':
    admin_token    => $keystone_admin_token,
    sql_connection => $keystone_sql_connection,
  } ->

  class { 'keystone::roles::admin': 
    email        => $admin_email,
    password     => $admin_pass,
    admin_tenant => $admin_tenant,
  } ->

  class { 'keystone::endpoint':
    public_address   => $keystone_public_address,
    admin_address    => $keystone_admin_address,
    internal_address => $keystone_internal_address,
    region           => $region,
  }
}
```

To make this configuration work for your environment, configure
the hiera database in `heiradata/common.yaml` to have your custom variables.

```
osdeploy::db::mysql_root_password: 'fi-de-hi'
osdeploy::db::bind_address: '172.16.211.10'

osdeploy::keystone::keystone_admin_token: 'pala-vif'
osdeploy::keystone::admin_email: 'chris.hoge@puppetlabs.com'
osdeploy::keystone::admin_pass: 'quu-rhyw'
osdeploy::keystone::keystone_public_address: '192.168.85.10'
osdeploy::keystone::keystone_admin_address: '172.16.211.10'
osdeploy::keystone::keystone_internal_address: '192.168.85.10'
osdeploy::keystone::keystone_public_network: '192.168.85.0/24'
osdeploy::keystone::keystone_private_network: '172.16.211.0/24'
osdeploy::keystone::keystone_db_password: 'rhof-nibs'
osdeploy::keystone::keystone_db_allowed_hosts: ['localhost', '127.0.0.1', '172.16.211.%']
```

Finally, update the `control.pp` configuration to add the keystone deployment:

```
class osdeploy::control {
  class { 'osdeploy::common': } ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::db': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::keystone': } ->
  class { 'osdeploy::firewall::post': } 
}
```

Once you apply the configuration, you can run keystone through its paces:

```
[root@control ~]# service openstack-keystone status
keystone (pid  20117) is running...
[root@control ~]# keystone --os-token pala-vif --os-endpoint http://172.16.211.10:35357/v2.0 endpoint-list
+----------------------------------+-----------+--------------------------------+--------------------------------+---------------------------------+----------------------------------+
|                id                |   region  |           publicurl            |          internalurl           |             adminurl            |            service_id            |
+----------------------------------+-----------+--------------------------------+--------------------------------+---------------------------------+----------------------------------+
| b6a97a323e084741bf90fbfb59a8692d | openstack | http://192.168.85.10:5000/v2.0 | http://192.168.85.10:5000/v2.0 | http://172.16.211.10:35357/v2.0 | 8f2d22b00ed24adfa410b9e9d771461b |
+----------------------------------+-----------+--------------------------------+--------------------------------+---------------------------------+----------------------------------+
[root@control ~]# keystone --os-token pala-vif --os-endpoint http://172.16.211.10:5000/v2.0 endpoint-list
[Errno 113] No route to host
[root@control ~]# curl http://192.168.85.10:5000
{"versions": {"values": [{"status": "stable", "updated": "2013-03-06T00:00:00Z", "media-types": [{"base": "application/json", "type": "application/vnd.openstack.identity-v3+json"}, {"base": "application/xml", "type": "application/vnd.openstack.identity-v3+xml"}], "id": "v3.0", "links": [{"href": "http://localhost:5000/v3/", "rel": "self"}]}, {"status": "stable", "updated": "2013-03-06T00:00:00Z", "media-types": [{"base": "application/json", "type": "application/vnd.openstack.identity-v2.0+json"}, {"base": "application/xml", "type": "application/vnd.openstack.identity-v2.0+xml"}], "id": "v2.0", "links": [{"href": "http://localhost:5000/v2.0/", "rel": "self"}, {"href": "http://docs.openstack.org/api/openstack-identity-service/2.0/content/", "type": "text/html", "rel": "describedby"}, {"href": "http://docs.openstack.org/api/openstack-identity-service/2.0/identity-dev-guide-2.0.pdf", "type": "application/pdf", "rel": "describedby"}]}]}}[root@control ~]#
```

This is a good opportunity to take a look at `/etc/keystone/keystone.conf` that's been 
generated on the controller node. You can get a sense of what puppet configured through 
the modules, and the possibilities of how you can change the configuration to enable 
other features.

## 3.2 Adding test tenants and users

The puppet-keystone module offers keystone user and tenant types and providers to help manage users
with puppet. We'll add some functionality to allow us to define new users with Heira that will
then automatically be generated for Keystone.

Start by defining a new resource that will create users, `create_user.pp`:

```
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
```

In addition to its name, this resource requires a password, tenant, and an e-mail for the user.
It then creates the `keystone_user` type and ensures that its created. Although tenant assignment
is implied by the creation of the user, an explicit assignment to a tenant is created using the
`keystone_user_role` type. Note that this simple implementation limits a user to one tenancy. In 
the OpenStack world, you can assign users to new tenants by assigning a role to a user for a tenant. 
You could easily extent this model to allow multi-tenancy with a new `assign_user_tenant` resource.

This helper function is then applied using an `osdeploy::users` class in `users.pp`:

```
class osdeploy::users {
  $users = hiera(users)
  create_resources("osdeploy::create_user", $users)
}
```

The `create_resources` function will iterator over a users hash loaded from the hiera database,
creating a new resource for every entry. Add the user definition to the `hieradata/common.yaml`
file:

```
users:
    "test":
        password: "abc123"
        tenant: "test"
        email: "test@example.com"
```

Run your configuration on the control node. Check for the existence of the new users and tenants.

```
[root@control ~]# puppet resource keystone_user
keystone_user { 'admin':
  ensure  => 'present',
  email   => 'chris.hoge@puppetlabs.com',
  enabled => 'True',
  id      => '4a34807e3a6241e2becf66cf5e530d80',
  tenant  => 'admin',
}
keystone_user { 'glance':
  ensure  => 'present',
  email   => 'glance@localhost',
  enabled => 'True',
  id      => '90b79f61f9e04330aa5d89103f140556',
  tenant  => 'services',
}
keystone_user { 'test':
  ensure  => 'present',
  email   => 'test@example.com',
  enabled => 'True',
  id      => '82c4952cbad5420db7213c62bb70b869',
  tenant  => 'test',
}
[root@control ~]# puppet resource keystone_tenant
keystone_tenant { 'admin':
  ensure      => 'present',
  description => 'admin tenant',
  enabled     => 'True',
  id          => 'a5ee76117fc947ed8a2438ca702888ce',
}
keystone_tenant { 'services':
  ensure      => 'present',
  description => 'Tenant for the openstack services',
  enabled     => 'True',
  id          => 'd360da8ed5cc4691bc5e8a58ebfdf844',
}
keystone_tenant { 'test':
  ensure  => 'present',
  enabled => 'True',
  id      => '2d2fe5c9d8b04e9fb70ef7127a2c8422',
}
[root@control ~]# puppet resource keystone_user_role
keystone_user_role { 'admin@admin':
  ensure => 'present',
  roles  => ['admin'],
}
keystone_user_role { 'glance@services':
  ensure => 'present',
  roles  => ['admin'],
}
keystone_user_role { 'test@test':
  ensure => 'present',
  roles  => ['Member'],
}
```

##

# Chapter 4: Glance

Now we'll move on to installing Glance on the controller node. For this deployment
we'll be using a basic filesystem-backed storage system. Normally you would
want to use a more robust image storage backend, such as Swift (which gives
you large object storage with redundancy across availablity zones) or Ceph (which
give you redundant block and object storage).

The configuration file for Glance is similar to Keystone. Here's the file, section-by-section. First, the
class parameters to specify the network settings and passwords.

```
class osdeploy::glance (
  $glance_user_password,
  $glance_public_address = '127.0.0.1',
  $glance_admin_address = '127.0.0.1',
  $glance_internal_address = '127.0.0.1',
  $glance_public_network = '0.0.0.0',
  $glance_private_network = '0.0.0.0',
  $region = 'openstack',
  $glance_db_host = 'localhost',
  $glance_db_user = 'glance',
  $glance_db_password = 'glance-password',
  $glance_db_name = 'glance',
  $glance_db_allowed_hosts = false 
) {
```

Next, the firewall setup to open the private and public APIs up. The API
server uses the same port for both public and private access, so both
addresses need to be exposed through the firewall.

```
  # public API access
  firewall { '09292 - Glance Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9292',
    source => $glance_public_network,
  }

  # private API access
  firewall { '09292 - Glance Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9292',
    source => $glance_private_network,
  }


  # admin API access
  firewall { '09191 - Glance Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9191',
    source => $glance_private_network,
  }
```

The database is configured.

```
  # database setup
  $glance_sql_connection = "mysql://$glance_db_user:$glance_db_password@$glance_db_host/$glance_db_name"
  class { 'glance::db::mysql':
    user          => $glance_db_user,
    password      => $glance_db_password,
    dbname        => $glance_db_name,
    allowed_hosts => $glance_db_allowed_hosts,
  } 
```

The Glance endpoints and admin user are created.

```
  # Keystone setup for Glance. Creates glance admin user and creates catalog settings
  # sets the glance user to be 'glance', tenant 'services'
  class  { 'glance::keystone::auth':
    password         => $glance_user_password,
    public_address   => $glance_public_address,
    admin_address    => $glance_admin_address,
    internal_address => $glance_internal_address,
    region           => $region,
  }
```

The api and registry services are initialized.

```
  # Note that the api node and registry node both reside on the controller
  # It's reasonable that all API functions could be separated from other
  # backend functions

  # The api server depends on the registry, so install the registry first
  class { 'glance::api':
    keystone_password => $glance_user_password,
    auth_host         => $keystone_admin_endpoint,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    sql_connection    => $glance_sql_connection,
  }

  class { 'glance::registry':
    keystone_password => $glance_user_password,
    sql_connection    => $glance_sql_connection,
    auth_host         => $keystone_admin_endpoint,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
  } 
```

This deployment uses the local file backend. Other available options include Ceph
and Swift.

```
  class { 'glance::backend::file': }
}
```

The `heiradata/common.yaml` file needs to be updated for glance

```
osdeploy::db::mysql_root_password: 'fi-de-hi'
osdeploy::db::bind_address: '172.16.211.10'

osdeploy::keystone::keystone_admin_token: 'pala-vif'
osdeploy::keystone::admin_email: 'chris.hoge@puppetlabs.com'
osdeploy::keystone::admin_pass: 'quu-rhyw'
osdeploy::keystone::keystone_public_address: '192.168.85.10'
osdeploy::keystone::keystone_admin_address: '172.16.211.10'
osdeploy::keystone::keystone_internal_address: '192.168.85.10'
osdeploy::keystone::keystone_public_network: '192.168.85.0/24'
osdeploy::keystone::keystone_private_network: '172.16.211.0/24'
osdeploy::keystone::keystone_db_password: 'rhof-nibs'
osdeploy::keystone::keystone_db_allowed_hosts: ['localhost', '127.0.0.1', '172.16.211.%']

osdeploy::glance::glance_user_password: 'quu-rhyw'
osdeploy::glance::glance_public_address: '192.168.85.10'
osdeploy::glance::glance_admin_address: '172.16.211.10'
osdeploy::glance::glance_internal_address: '192.168.85.10'
osdeploy::glance::glance_public_network: '192.168.85.0/24'
osdeploy::glance::glance_private_network: '172.16.211.0/24'
osdeploy::glance::glance_db_password: 'rhof-nibs'
osdeploy::glance::glance_db_allowed_hosts: ['localhost', '127.0.0.1', '172.16.211.%']
```

Add the class to the control configuration

```
class osdeploy::control {
  class { 'osdeploy::common': } ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::db': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::keystone': } ->
  class { 'osdeploy::glance': } ->
  class { 'osdeploy::firewall::post': } 
}
```

Apply the configuration to your control environment. Check that the services are running on the
correct ports, 9191 for the administrative API, 9292 for the public API:

```
curl http://192.168.85.10:9191
curl: (7) couldn't connect to host

curl http://192.168.85.10:9292
{"versions": [{"status": "CURRENT", "id": "v2.1", "links": [{"href": "http://192.168.85.10:9292/v2/", "rel": "self"}]}, {"status": "SUPPORTED", "id": "v2.0", "links": [{"href": "http://192.168.85.10:9292/v2/", "rel": "self"}]}, {"status": "CURRENT", "id": "v1.1", "links": [{"href": "http://192.168.85.10:9292/v1/", "rel": "self"}]}, {"status": "SUPPORTED", "id": "v1.0", "links": [{"href": "http://192.168.85.10:9292/v1/", "rel": "self"}]}]}

curl http://172.16.211.10:9292
curl: (7) couldn't connect to host

curl http://172.16.211.10:9191
<html>
 <head>
  <title>401 Unauthorized</title>
 </head>
 <body>
  <h1>401 Unauthorized</h1>
  This server could not verify that you are authorized to access the document you requested. Either you supplied the wrong credentials (e.g., bad password), or your browser does not understand how to supply the credentials required.<br /><br />
Authentication required


 </body>
</html>
```

Test the service with the test user:

```
glance  --os-username test --os-tenant-name test --os-password abc123  --os-auth-url http://192.168.85.10:5000/v2.0 image-list

```

There should be no output. Note that the glance client connects to the keystone public
API, which redirects the calls to the correct glance server. If you run into an auth
error, you might need to do the puppet run again to make sure that the glance service
user has been created.

# Chapter 5 Network Node: Quantum/Neutron

# 5.1 Network Node Setup

It's time to add another node to the configuration. Edit the nodes.pp file to add the new node.

```
node 'puppet' {
  include ::ntp
  include ::master
}

node 'control.localdomain' {
  include ::ntp
  include ::osdeploy::adminnetwork
  include ::osdeploy::control
}

node 'network.localdomain' {
  include ::ntp
  include ::osdeploy::networknetwork
  include ::osdeploy::networknode
}
```

Set up the network configuration for the network node in the `oscontrol/manifests/networknetwork.pp' file:

```
class osdeploy::networknetwork {

  exec { 'restart eth1':
    command     => '/sbin/ifdown eth1; /sbin/ifup eth1',
  } 

  network_config { 'eth1':
    ensure      => present,
    family      => 'inet',
    ipaddress   => '172.16.211.11',
    method      => 'static',
    onboot      => 'true',
    reconfigure => 'true',
    notify      => Exec['restart eth1'],
  }

  exec { 'restart eth3':
    command     => '/sbin/ifdown eth3; /sbin/ifup eth3',
  } 

  network_config { 'eth3':
    ensure      => present,
    family      => 'inet',
    ipaddress   => '192.168.85.11',
    method      => 'static',
    onboot      => 'true',
    reconfigure => 'true',
    notify      => Exec['restart eth3'],
  }

}
```

Create the network base class file, `osdeploy/manifests/control.pp`, to deploy
the common packages for OpenStack.

```
class osdeploy::networknode {
    class { 'osdeploy::common': }
}
``` 


Kick off a puppet run on the network node, sign the cert on the master node, then make 
another run on the network node.

```
[root@network ~]# puppet agent -t
Info: Creating a new SSL key for network.localdomain
Info: Caching certificate for ca
Info: Creating a new SSL certificate request for network.localdomain
Info: Certificate Request fingerprint (SHA256): 4D:8C:49:AC:62:81:1E:D1:A4:F6:9C:6A:BD:80:D3:30:DB:68:E2:EB:B1:C2:A0:AC:E6:65:C0:97:31:21:AC:D4
Exiting; no certificate found and waitforcert is disabled
```

```
[root@puppet puppet]# puppet cert --list
"network.localdomain" (SHA256) 4D:8C:49:AC:62:81:1E:D1:A4:F6:9C:6A:BD:80:D3:30:DB:68:E2:EB:B1:C2:A0:AC:E6:65:C0:97:31:21:AC:D4
[root@puppet puppet]# puppet cert --sign network.localdomain
Notice: Signed certificate request for network.localdomain
Notice: Removing file Puppet::SSL::CertificateRequest network.localdomain at '/var/lib/puppet/ssl/ca/requests/network.localdomain.pem'
```

```
puppet agent -t
...
```

After a success application, you'll need to reboot the node. The RDO repository
includes a patched kernel and module to support network namespaces in OpenVSwitch.

Now that the foundations are set up for the node, we're ready to configure the 
Quantum/Neutron network service

## 5.2 Configuring the Quantum/Neutron database and Keystone data

The database for the Quantum/Neutron service needs to be installed on the controller
node. This configuration is slightly different, and is going to introduce
some redundancy into our hiera database. The db service is going to reside
on a different node than the controller service.

Create a file `osdeploy/manifests/networkdb.pp`.

```
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
```

Add the db configuration to your hiera database, `hieradata/common.yaml`.

```
osdeploy::networkdb::network_db_password: 'rhof-nibs'
osdeploy::networkdb::network_db_allowed_hosts: ['localhost', '127.0.0.1', '172.16.211.%']

osdeploy::networkauth::network_user_password: 
osdeploy::networkauth::network_public_address: '192.168.85.11'
osdeploy::networkauth::network_admin_address: '172.16.211.11'
osdeploy::networkauth::network_internal_address: '192.168.85.11'
```

Create a class to create the network user and catalog endpoints for Keystone,
`osdeploy/manifests/networkauth.pp`

```
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
```

Add the database and auth configuration to the controller node, 
`osdeploy/manifests/control.pp`:

```
class osdeploy::control {
  class { 'osdeploy::common': } ->
  class { 'osdeploy::firewall::pre': } ->
  class { 'osdeploy::db': } ->
  class { 'memcached':
      listen_ip => '127.0.0.1',
      tcp_port  => '11211',
      udp_port  => '11211',
  } ->
  class { 'nova::rabbitmq': } ->
  class { 'osdeploy::keystone': } ->
  class { 'osdeploy::users':} ->
  class { 'osdeploy::glance': } ->
  class { 'osdeploy::networkdb': } ->
  class { 'osdeploy::networkauth': } ->
  class { 'osdeploy::firewall::post': } 
}
```

Run the configuration on the controller node. Now that the database is installed
the network node configuration can be completed.

## 5.3 Configuring the Quantum/Neutron services

The setup for the Quantum service on its own node is a little bit more complex.
Begin with the signature for the `osdeploy::networkservice` class, which 
is similar to the glance and keystone classes preceeding it.

```
class osdeploy::networkservice (
  $network_user_password,
  $network_auth_host,
  $network_public_address = '127.0.0.1',
  $network_admin_address = '127.0.0.1',
  $network_internal_address = '127.0.0.1',
  $region = 'openstack',
  $network_db_host = 'localhost',
  $network_db_user = 'network',
  $network_db_password = 'network-password',
  $network_db_name = 'network',
  $rabbit_host = 'localhost',
  $rabbit_password = 'guest',
) {
```

The sql connection string needs to be constructed, and the firewall opened up to allow connections
to the quantum service.

```
  $sql_connection = "mysql://${network_db_user}:${network_db_password}@${network_db_host}/${network_db_name}?charset=utf8"

  # public API access
  firewall { '09696 - Quantum API Public':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9696',
    source => $network_public_network,
  } 

  # private API access
  firewall { '09696 - Quantum API Private':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => '9696',
    source => $network_private_network,
  } 
```

The connectors to the control node, where the RabbitMQ scheduler and the database
reside are configured. The quantum class also pulls in all of the packages
necessary to install quantum, except for the keystone client which is 
installed explicitly.

```
  class {'::quantum':
    rabbit_host     => $rabbit_host,
    rabbit_password => $rabbit_password,
    verbose         => 'True',
    debug           => 'True',
  }

  class { 'keystone::client': } ->
```

The server is now set up, pointing it to the keystone service. By default
quantum uses the Open VSwitch driver, `ovs`.

```
  class {'quantum::server':
    auth_host     => $network_auth_host,
    auth_password => $network_user_password,
  }
```

The ovs plugin needs to be configured. It is given the sql connection string,
and configures the tunnel type. By default the modules will run on a vlan
tunnel, but it's simpler to set up the Generalized Routing Encapsulation (gre) 
tunnel that ovs provides.

```
  class {'quantum::plugins::ovs':
    sql_connection      => $sql_connection,
    tenant_network_type => 'gre',
  }
```

Finally, the quantum network agent is configured to run on the server, with the
specified internal network address.

```
  class {'quantum::agents::ovs':
    enable_tunneling => 'True',
    local_ip         => $network_internal_address,
  }
}
```

Add the file to the `networknode.pp` file.

```
class osdeploy::networknode {
  class { 'osdeploy::common':}
  class { 'osdeploy::networkservice': }
}
``` 

Apply the configuration to the network node. You can check the configuration on the
network node by running the command:

```
quantum  --os-username test --os-password abc123 --os-tenant-name test --os-auth-url http://192.168.85.10:5000/v2.0 net-list
```

This should return an empty string with no error.

# Chapter 6 Nova API and Scheduler

# Chapter 7 Compute Node: Nova Compute and Quantum Agents

# Chapter 8 Cinder: Controller API and Scheduler, Compute Volume

# Chapter 9 Horizon

