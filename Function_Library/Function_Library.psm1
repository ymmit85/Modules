function New-IsoFile  
{  
  <#  
   .Synopsis  
    Creates a new .iso file  
   .Description  
    The New-IsoFile cmdlet creates a new .iso file containing content from chosen folders  
   
   .Example  
    New-IsoFile "c:\tools","c:Downloads\utils"  
    This command creates a .iso file in $env:temp folder (default location) that contains c:\tools and c:\downloads\utils folders. The folders themselves are included at the root of the .iso image.  
   
   .Example 
    New-IsoFile -FromClipboard -Verbose 
    Before running this command, select and copy (Ctrl-C) files/folders in Explorer first.  
   
   .Example  
    dir c:\WinPE | New-IsoFile -Path c:\temp\WinPE.iso -BootFile "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin" -Media DVDPLUSR -Title "WinPE" 
    This command creates a bootable .iso file containing the content from c:\WinPE folder, but the folder itself isn't included. Boot file etfsboot.com can be found in Windows ADK. Refer to IMAPI_MEDIA_PHYSICAL_TYPE enumeration for possible media types: http://msdn.microsoft.com/en-us/library/windows/desktop/aa366217(v=vs.85).aspx  
   
   .Notes 
    NAME:  New-IsoFile  
    AUTHOR: Chris Wu 
    LASTEDIT: 03/23/2016 14:46:50  
 #>  
  
  [CmdletBinding(DefaultParameterSetName='Source')]Param( 
    [parameter(Position=1,Mandatory=$true,ValueFromPipeline=$true, ParameterSetName='Source')]$Source,  
    [parameter(Position=2)][string]$Path = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss.ffff')).iso",  
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})][string]$BootFile = $null, 
    [ValidateSet('CDR','CDRW','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','BDR','BDRE')][string] $Media = 'DVDPLUSRW_DUALLAYER', 
    [string]$Title = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),  
    [switch]$Force, 
    [parameter(ParameterSetName='Clipboard')][switch]$FromClipboard 
  ) 
 
  Begin {  
    ($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe' 
    if (!('ISOFile' -as [type])) {  
      Add-Type -CompilerParameters $cp -TypeDefinition @' 
public class ISOFile  
{ 
  public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)  
  {  
    int bytes = 0;  
    byte[] buf = new byte[BlockSize];  
    var ptr = (System.IntPtr)(&bytes);  
    var o = System.IO.File.OpenWrite(Path);  
    var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;  
  
    if (o != null) { 
      while (TotalBlocks-- > 0) {  
        i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);  
      }  
      o.Flush(); o.Close();  
    } 
  } 
}  
'@  
    } 
  
    if ($BootFile) { 
      if('BDR','BDRE' -contains $Media) { Write-Warning "Bootable image doesn't seem to work with media type $Media" } 
      ($Stream = New-Object -ComObject ADODB.Stream -Property @{Type=1}).Open()  # adFileTypeBinary 
      $Stream.LoadFromFile((Get-Item -LiteralPath $BootFile).Fullname) 
      ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream) 
    } 
 
    $MediaType = @('UNKNOWN','CDROM','CDR','CDRW','DVDROM','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','HDDVDROM','HDDVDR','HDDVDRAM','BDROM','BDR','BDRE') 
 
    Write-Verbose -Message "Selected media type is $Media with value $($MediaType.IndexOf($Media))" 
    ($Image = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$Title}).ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media)) 
  
    if (!($Target = New-Item -Path $Path -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) { Write-Error -Message "Cannot create file $Path. Use -Force parameter to overwrite if the target file already exists."; break } 
  }  
 
  Process { 
    if($FromClipboard) { 
      if($PSVersionTable.PSVersion.Major -lt 5) { Write-Error -Message 'The -FromClipboard parameter is only supported on PowerShell v5 or higher'; break } 
      $Source = Get-Clipboard -Format FileDropList 
    } 
 
    foreach($item in $Source) { 
      if($item -isnot [System.IO.FileInfo] -and $item -isnot [System.IO.DirectoryInfo]) { 
        $item = Get-Item -LiteralPath $item 
      } 
 
      if($item) { 
        Write-Verbose -Message "Adding item to the target image: $($item.FullName)" 
        try { $Image.Root.AddTree($item.FullName, $true) } catch { Write-Error -Message ($_.Exception.Message.Trim() + ' Try a different media type.') } 
      } 
    } 
  } 
 
  End {  
    if ($Boot) { $Image.BootImageOptions=$Boot }  
    $Result = $Image.CreateResultImage()  
    [ISOFile]::Create($Target.FullName,$Result.ImageStream,$Result.BlockSize,$Result.TotalBlocks) 
    Write-Verbose -Message "Target image ($($Target.FullName)) has been created" 
    $Target 
  } 
} 
Function SyslogSender ()
{
       <#
              .SYNOPSIS
                     UDP client creation to send message to a syslog server.
					 This script was sourced from https://www.sgc-univ.net/powershell-udp-client-and-syslog-messages/.
					 
					 
              .DESCRIPTION
                     Basic usage:
                           $Obj = ./SyslogSender 192.168.2.4
                           $Obj.Send("string message1")
                           $Obj.Send("string message2")
                $Obj.Send($message)
      
                           This uses the following defaults:
								  - Source : SyslogSender
                                  - Facility : user
                                  - Severity : info
                                  - Timestamp : now
                                  - Computername : name of the computer on which the script is executed.
                                  - Syslog Port: 514
      
                     Advanced usage:
                           $Obj = ./SyslogSender 192.168.231.3 432
                                  This defines a custom port when setting up the object
      
                           $Obj.Send("String Message", "String Facility", "String Severity", "String Timestamp", "String Hostname")
                                  This sends a message with a custom facility, severity, timestamp and hostname.
                                  i.e. $obj.Send("Script Error", "local7", "alert", $(Get-Date), $env:COMPUTERNAME)
								  
						   $Obj.Send("String Message" , "PowerShell Script.ps1", "alert", "user")
								This sends a message with the Source being defined in the message as "PowerShell Script.ps1", the message is also an "alert".
       #>
  
    Param
    (
        [String]$Destination = $(throw "ERROR: SYSLOG Host Required..."),
        [Int32]$Port = 514
    )
  
    $ObjSyslogSender = New-Object PsObject
    $ObjSyslogSender.PsObject.TypeNames.Insert(0, "SyslogSender")
    
	# Initialize the udp 'connection'
    $ObjSyslogSender | Add-Member -MemberType NoteProperty -Name UDPClient -Value $(New-Object System.Net.Sockets.UdpClient)
    $ObjSyslogSender.UDPClient.Connect($Destination, $Port)
    
	# Add the Send method:
    $ObjSyslogSender | Add-Member -MemberType ScriptMethod -Name Send -Value {
        
		Param
        (
                     [String]$Data = $(throw "Error SyslogSender: No data to send!"),
					 [String]$Source = "SyslogSender",
                     [String]$Severity = "info",
                     [String]$Facility = "user",
                     [String]$Timestamp = $(Get-Date),
                     [String]$Hostname = $env:COMPUTERNAME
        )
        
		# Maps used to translate string to corresponding decimal value
        $FacilityMap = @{ 
                     "kern" = 0;"user" = 1;"mail" = 2;"daemon" = 3;"security" = 4;"auth" = 4;"syslog" = 5;
                     "lpr" = 6;"news" = 7;"uucp" = 8;"cron" = 9;"authpriv" = 10;"ftp" = 11;"ntp" = 12;
                     "logaudit" = 13;"logalert" = 14;"clock" = 15;"local0" = 16;"local1" = 17;"local2" = 18;
                     "local3" = 19;"local4" = 20;"local5" = 21;"local6" = 21;"local7" = 23;
			}
        $SeverityMap = @{ 
                     "emerg" = 0;"panic" = 0;"alert" = 1;"crit" = 2;"error" = 3;"err" = 3;"warning" = 4;
                     "warn" = 4;"notice" = 5;"info" = 6;"debug" = 7;
              }
        # Map facility, default to user
              $FacilityDec = 1
        if ($FacilityMap.ContainsKey($Facility))
        {
            $FacilityDec = $FacilityMap[$Facility]
        }
 
        # Map severity, default to info
              $SeverityDec = 6
        if ($SeverityMap.ContainsKey($Severity))
        {
            $SeverityDec = $SeverityMap[$Severity]
        }       
 
        # Calculate PRI code
		$PRI = ($FacilityDec * 8) + $SeverityDec
             
		#Format message content to include severity
		$Content = "$($Severity.Substring(0).ToUpper()) $data"
		#write-host "$content"
 
        #Build message content
        $Message = "<$PRI> $Timestamp $Hostname $Content - $Source"
        #write-host $Message
       
        #Format the data, recommended is a maximum length of 1kb
        $Message = $([System.Text.Encoding]::ASCII).GetBytes($message)
        
		#write-host $Message
        if ($Message.Length -gt 1024)
        {
            $Message = $Message.Substring(0, 1024)
        }
        # Send the message
        $this.UDPClient.Send($Message, $Message.Length) | Out-Null
 
    }
    $ObjSyslogSender
}