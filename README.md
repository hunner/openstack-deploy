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

Finally, install the ntp module available from the Puppet Labs Forge:

`puppet module install puppet/ntp`

Start the puppet agent run again, `puppet agent -t` and if all goes well, you should see quite a bit of
output, and if the run was successful the `ntp` daemon should be running:

`service ntpd status`

Once you've verified that your configuration is working, push the changes up to github to save them remotely.

`git add manifests/site.pp manifests/nodes.pp
git commit
git push`


