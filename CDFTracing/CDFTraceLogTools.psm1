function Get-CDFOutput {
  <# 
  .SYNOPSIS
    This command takes the CDFControl trace logs and turns them into PowerShell objects
  .DESCRIPTION
    As a prefix to this description you will need to download two files from Citrix Support:
      CDFControl.exe
      CDFMonitor.exe
      CDFAnalyzer.exe (This one is Optional)
      ** This command by default expects these files to be downloaded into C:\CDF\ directory
      ** The following is the default directory layout used by this command, if you use a different 
         directory structure, utilise the parameters to point to the relevant files and directories.
         C:\CDF
         C:\CDF\CTLs
         C:\CDF\TMFs

    Before running Get-CDFOutput you will need to capture a trace this can be done via CLI using the 
    following command (Make sure you run this from the directory that contains the CDFControl.exe file): 
      CDFControl.exe -start -guids .\CTLs\All.ctl -path .\ -noprompt
       ** You will need to create the CTL file before you run this trace command,
          CTL files are created by opening the GUI version of CDFControl.exe
          and selecting the traces you wish to use and then you Right-Click on
          the GUI interface and a menu will show an option to create a CTL file
    While the trace is running, perform Citrix activities that will generate log events, and once you
    have all of the citrix events triggered, stop the trace with the following command:
      CDFControl.exe -stop -noprompt
    This will produce a new subdirectory within you current directory in which an new .ETL file exists.
    This command will attempt to find the latest .ETL file, and parse its contents to create the 
    PowerShell object collection output.
  .EXAMPLE
    Get-CDFOutput -CDFRootPath 'C:\CDF' -OutputFilePath 'C:\CDF\output.csv' -TMFPath 'C:\CDF\TMFs' -ETLFilePath 'c:\CDF\CDFControl_log_16.05.2019_18-57-24\CDFLogFile1.etl'
    This decodes the trace file into a powershell object collection
  .PARAMETER CDFRootPath
    This path is where the CDF*.exe files exist, you must have downloaded and used these files to create a 
    trace before you can use this command to convert the trace log into a PowerShell object collection.
  .PARAMETER Outputfile
    This is the path to the filename of the CSV outputfile, this file is an intermediate file that the
    CDF commands produce and the PowerShell command uses to create the Object results. If this file exits
    this command will increment a number to add to the end of the name as the CDFControl.exe will not 
    overwrite and existing log file. 
  .PARAMETER TMFPath
    This is the path to the directory that holds the TMF files that you need to download from the 
    internet using this command: 
      CDFMonitor /downloadTMFs
    The TMF files are parser files that interpret the logs into a human readable form.  
  .PARAMETER ETLFilePath
    This is the full path to the ETL trace file that you wish to decode
  .NOTES
    General notes
      Created by: Brent Denny
      Created on: 15-May-2019
  #>
  [CmdletBinding()]
  Param (
    [string]$CDFRootPath = 'C:\CDF',
    [string]$OutputFile = 'C:\CDF\output.csv',
    [string]$TMFPath = 'C:\CDF\TMFS',
    [string]$ETLFilePath = ''
  )
  
  Function Test-IsFileLocked {
    [cmdletbinding()]
    Param (
      [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
      [Alias('FullName','PSPath')]
      [string]$Path
    )
    do {
    } until (Test-Path $Path)
    $Item = Convert-Path $Path
    #Verify that this is a file and not a directory
    If ([System.IO.File]::Exists($Item)) {
      Try {
        $FileStream = [System.IO.File]::Open($Item,'Open','Write')
        $FileStream.Close()
        $FileStream.Dispose()
        $IsLocked = $False
      } 
      Catch [System.UnauthorizedAccessException] {
        $IsLocked = 'AccessDenied'
      } 
      Catch {
        $IsLocked = $True
      }
      $IsLocked
    }
  }

  Set-Location $CDFRootPath
  if ($ETLFilePath -eq '') {
    $ETLFilePath = (Get-ChildItem -File -Path $CDFRootPath\*.etl -Recurse | Sort-Object -Property lastwritetime -Descending | Select-Object -First 1).fullname
  }  
  Write-Verbose "$ETLFilePath - ETL"
  Write-Verbose "$CDFRootPath - Root"
  Write-Verbose "$TMFPath - TMF"
  
  if (
      (Test-Path -PathType Leaf $CDFRootPath\CDFControl.exe) -and 
      (Test-Path -PathType Leaf $TMFPath\*.tmf) -and 
      (Test-Path -PathType Leaf -Path $ETLFilePath)
    )  {
    $Counter = 0
    $OutputExists = Test-Path -PathType Leaf $OutputFile
    while ($OutputExists -eq $true) {
      $Counter++
      $OutputFile = ($OutputFile -replace '^(.*?)\d*\.csv$','$1') + ($Counter -as [string]) + '.csv'
      $OutputExists = Test-Path -PathType Leaf $OutputFile
      write-verbose "$OutputFile - output file"
      Write-Verbose "$OutputExists - exists"
    }
    Write-Verbose "Now starting the decode"
    .\CDFControl.exe -decode $ETLFilePath -tmf $TMFPath -o $OutputFile -noprompt *> $null
    $NewCSVHeaders = 'Number','CPU','Time','ThreadID','ProcessID','SessionID','Module','Src','Line','Function','Level','Class','Message','Comments'
    do {
    } while (Test-IsFileLocked -Path $OutputFile)
    Write-Verbose "Finished decode, now creating PS obj" 
    $RawCSV = Get-Content $OutputFile
    $RawCSVStripHeader = $RawCSV | Select-Object -Skip 1 
    $CDFTraceObj = $RawCSVStripHeader | ConvertFrom-Csv -Header $NewCSVHeaders
    $CDFTraceObj
  }
  else {Write-Warning "The necessary files were not found - aborting command"}
}