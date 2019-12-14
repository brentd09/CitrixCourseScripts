To List all the XS VMs
---------------------
xe vm-list    
  - take note of the UUID of the hidden VM that you want to unhide. 
  - For example:85029fe4-1aa0-82cb-a957-4be06b0a589b.

To Unhide a VM in XS
----------
xe vm-param-remove uuid=85029fe4-1aa0-82cb-a957-4be06b0a589b  param-name=other-config param-key=HideFromXenCenter
  - This will immediately unhide the VM and this will be reflected in XenCenter without a refresh.
