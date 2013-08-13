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

