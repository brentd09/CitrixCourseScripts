Download the following from Citrix Support
==========================================
* CDFAnalyzer
* CDFMonitor 
* CDFControl 

CDFControl
==========
Run this tool to trace events that happen on the DDC, for example, to track what is happening with the XML broker tick the citrix-Broker and the BrokerXMLService traces and start tracing. Then go and launch a Citrix resource.  
You can also select any number of these traces then RightClick on the CDFControl screen to create a CTL file that can be used when running this 
command as CLI as seen below...  
When running as CLI you can also get this tool to parse the log and output it to a CSV file. See below...

CDFMonitor
==========
This tool can mointor in real time, however a great use for this tool is to download the TMF files that parse the trace logs and decipher them. A parameter for this command allows you to download all of the TMFs and automatically dumps them into a directory in your current directory called TMFs.

Command: **CDFMonitor /downloadTMFs**

CDFAnalyzer
===========
This tools uses the TMF files to parse the trace log created by CDFControl.  
The first time you open the Analyzer an option needs to be changed that points to the TMFs directory.
Once the TMFs path option is set, Open the Trace Log created by CDFControl.

This will give you a lot of details regarding the internal workings of XA/XD in a GUI form.

CLI Support for CDFControl
--------------------------

**CDFControl -start -guids TraceProvider.ctl -path c:\temp\trace**

**CDFControl -decode CDFLogfile.etl -tmf C:\CDFTracing -o C:\temp\CDFLog.csv**
