<#
.SYNOPSIS
  This script helps to trouble shoot a CVAD issue
.DESCRIPTION
  The script will go through these standard troubleshooting steps obtained from https://support.citrix.com/article/CTX212941
  
  Troubleshooting methodology: (Take a backup of the database before performing the below steps)
  Overview of troubleshooting process diagram

  1. First we would like to understand if all the controllers in the site are actively connected to the database or not
     Load Citrix snap ins with “asnp Citrix.*” on windows PowerShell in elevated mode
     Run Get-brokercontroller
     Get-BrokerController | Select DNSName,State
     You should expect to see the state of all the controllers in the site as ‘Active’
     If one of the controller in the site reports any other status other than ‘Active’, you directly need to shift your 
     focus on that particular controller and follow step 2.
     If all the controller’s state returns ‘Active’ follow step 5.
  2. Check the service status of all the services on the faulty controller (all the FMA services might be running on the OS, 
     however it also need to connect to the DB successfully)
     “Get-Command Get*servicestatus”
     Copy and execute all the commands listed with the above command   and expect to see all the status as ‘OK’
     If you find an error on any of the service, check proper permissions are provided to that particular DDC’s login on SQL server.
     XenDesktop Controllers authenticate using windows authentication to the SQL server and use the host name to login to the 
     SQL server, so if the host name of the controller is DDC1 and you domain is domain1 you should see a login created on the 
     SQL server with “domain1\DDC1$” with all the permissions as per http://support.citrix.com/article/CTX127998
  3. If any of the service status fails with random error like “dbnotfound” best approach is to test the DB connectivity of 
     the failed service by running test-<Servicename>dbconnection command
     E.g Test-brokerdbconnection –dbconnection “<connection strigs>”
     If you get an error message and is unreadable dump the command in the variable and look at the output
     E.g $a=test-brokerdbconnection –dbconnection “<connection string>”
     $a.extrainfo.values
     This will give you more insight to the problem.
  4. Check that there is at least one Delivery Controller in the primary zone that is active. 
     You can find which zone is Primary and what Delivery Controllers are members of that zone by running
     Get-ConfigZone
     Inspect the results for "IsPrimary" and the list of SIDs in the Zone that "IsPrimary" is true.  
     You can get a list of the Delivery Controllers with their SIDs by running:
     Get-Brokercontroller | Select MachineName,Sid,State 
  5. If all the troubleshooting attempts fails to repair the faulty controller which appears as failed it’s advisable to remove 
     the controller from site using Evict Script: (do not run this if you just have one controller in the site) 
     http://support.citrix.com/article/CTX139505  
  
  6. Check to see if we are correctly connected to the Monitor and Configuration Logging database.
     Get-MonitorDatastore
     Get-LogDatastore
     To verify if we are correctly connecting to the required database
     From 7.x we can have separate database for Monitor and Logging hence, one Connection string for Monitor/Logging service points 
     to the site datastore and one string of Monitor/Logging service points to the Monitor/Logging datastore.
  7. The number of services may vary depending on the controller version and hence run the below commands to get list of all the service instances
     Get-command Get*serviceinstance
     Get-command Reset*servicegroupmembership
  8. If the service status returns OK and if all the DDC’s states are also ‘Active’ then you might not be having all the instances 
     registered with the configuration service OR you might have the problem because no Delivery Controller in the primary zone can 
     be contacted by the failed Delivery Controller .
     
     Double-check step 4, to check for multiple zones and the availability of a Delivery Controller in the Primary Zone.
     Configuration service acts as  backbone to all the other FMA services and hence all the instances should be registered with it
     Run the command “Get-ConfigRegisteredServiceInstance | measure” to get the count of total instances registered with the configuration service
     The count will vary with the number of controllers in the site and the version of controller.  
     Run the command "Get-ConfigRegisteredServiceInstance | export-csv c:\temp\registeredserviceinstance.csv.  
     Inspect the results to see what Delivery Controllers have registered service instances and which Delivery Controllers are missing 
     any service instances. 
     Typically a XenDesktop 7.6 deployment has 49 instances per controller, XenDesktop 7.8 deployment has 55 instances per controller 
     and XenDesktop 7.15 deployment has 60 instances per controller.
     If you see issues with count you may unregister all the registered instances with  
     Get-ConfigRegisteredServiceInstance | Unregister-ConfigRegisteredServiceInstance
     (Take a backup of Site DB before doing so as this is going to remove all the instances from DB)
     Register all the instances back by running the command on all the controllers in the site
     Get-AcctServiceInstance | register-configserviceInstance
     Get-ApplibServiceInstance | register-configserviceInstance
     Get-AdminServiceInstance | register-configserviceInstance
     Get-BrokerServiceInstance | register-configserviceInstance
     Get-ConfigRegisteredServiceInstance | register-configserviceInstance
     Get-ConfigServiceInstance | register-configserviceInstance
     Get-EnvTestServiceInstance | register-configserviceInstance
     Get-HypServiceInstance | register-configserviceInstance
     Get-LogServiceInstance | register-configserviceInstance
     Get-MonitorServiceInstance | register-configserviceInstance
     Get-ProvServiceInstance | register-configserviceInstance
     Get-SfServiceInstance | register-configserviceInstance
     Get-TrustServiceInstance | register-configserviceInstance
     Get-OrchServiceInstance | register-configserviceInstance
      Once the instances are Registered you will also have to reset their group memberships
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-AcctServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-AdminServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-ApplibServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-BrokerServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-ConfigServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-EnvTestServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-HypServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-LogServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-MonitorServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-ProvServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-SfServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-TrustServiceGroupMembership
     Get-ConfigRegisteredServiceInstance -servicetype config | Reset-OrchServiceGroupMembership  
  
  9. In course of troubleshooting do not ever re-join the DDC’s to the domain while connected to the Site database as it will change 
     the DDC’s SID and will make the DDC un-usable.
   
     If none of the above yield positive result call Citrix Support and have this issue investigated further.
.EXAMPLE
  Test-CVADHealth
  This will test the Delivery Controllers in the CVAD site to determine if any are not fully funtioning.
  It will then find any that have issues and will proceed to check the service status on each VDC. It 
  will aso check the DB connection to detemine if that is a problem.
.NOTES
  General notes
    Created by:    Brent Denny
    Created on:    4 Jun 2021
    Last Modified: 4 Jun 2021
#>
[cmdletbinding()]
Param(

)

# Important Commands for this process
# I will be building this script to automate its way through the troubleshooting process using these commands 
# to guide the troubleshooting process
<#
  Get-BrokerController
  Get-*ServiceStatus
  Get-*DBConnection 
  Test-*DBConnection
  Get-ConfigZone
  Get-MonitorDataStore
  Get-LogDataStore
  Get-*ServiceInstance
  Reset-*ServiceGroupMembership
  Get-ConfigRegisteredServiceInstance
  Get-ConfigRegisteredServiceInstance | Unregister-ConfigRegisteredServiceInstance
  Get-AcctServiceInstance | register-configserviceInstance
  Get-ApplibServiceInstance | register-configserviceInstance
  Get-AdminServiceInstance | register-configserviceInstance
  Get-BrokerServiceInstance | register-configserviceInstance
  
  Get-ConfigRegisteredServiceInstance | register-configserviceInstance
  Get-ConfigServiceInstance | register-configserviceInstance
  Get-EnvTestServiceInstance | register-configserviceInstance
  Get-HypServiceInstance | register-configserviceInstance
  Get-LogServiceInstance | register-configserviceInstance
  Get-MonitorServiceInstance | register-configserviceInstance
  Get-ProvServiceInstance | register-configserviceInstance
  Get-SfServiceInstance | register-configserviceInstance
  Get-TrustServiceInstance | register-configserviceInstance
  Get-OrchServiceInstance | register-configserviceInstance
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-AcctServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-AdminServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-ApplibServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-BrokerServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-ConfigServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-EnvTestServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-HypServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-LogServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-MonitorServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-ProvServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-SfServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-TrustServiceGroupMembership
  Get-ConfigRegisteredServiceInstance -servicetype config | Reset-OrchServiceGroupMembership
#>