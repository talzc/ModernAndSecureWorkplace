########################################################
##
##  This script enables an OSD Message which is showed 
##  bevore the first user logs in
##
##  Author: Thomas Kurth/baseVISION
##  Date:   12.05.2016
##
##  Histroy 
##        001: Basis version
##        002: Update Erkennung anpassen/ Loging to Status Messages 
##        003: RemoveScript direkt erstellen, Berechtigungen für Benutzer richtig setzen
##		  004: Abfrage Bitlocker Status angepasst
##        005: Virus Scan Abfrage korrigiert
##        006: Generic Virus Scan Abfrage, Display Executed Scripts
##        007: Extended Virus Scan Abfrage
##        008: If no netECM:Launcher Keys are found, Default Add/Remove Program Entries are displayed
########################################################

$LogFilePath = "C:\Windows\Logs\OSDEnableOSDMessage_" + (get-date -uformat %Y%m%d%H%M) + ".log"

function WriteLog($Text){
    Out-file -FilePath $LogFilePath -force -append -InputObject ((Get-Date –f o) + "        " +  $Text)
    Write-Host $Text
}

# Type = Binary, DWord, ExpandString, MultiString, String, QWord
function SetRegValue ([string]$Path, [string]$Name, [string]$Value, [string]$Type) {
    try {
        $ErrorActionPreference = 'Stop' # convert all errors to terminating errors
        Start-Transaction

	if (Test-Path $Path -erroraction silentlycontinue) {      
        } else {
            New-Item -Path $Path -Force
            WriteLog "Registry key $Path created"  
        } 
    
        $null = New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force
        WriteLog "Registry Value $Path, $Name, $Type, $Value set"
        Complete-Transaction
    }
    catch {
        Undo-Transaction
        WriteLog "ERROR Registry value not set $Path, $Name, $Value, $Type"
    }

}

function CreateFolder ([string]$Path) {

	# Check if the folder Exists

	if (Test-Path $Path) {
		WriteLog "Folder: $Path Already Exists"
	} else {
		WriteLog "Creating $Path"
		New-Item -Path $Path -type directory | Out-Null
	}
}

function parseProductState{
    param (
    [Parameter(Mandatory=$True,Position=1)]
    [int]$productState
    )
    $OutputObj  = New-Object -Type PSObject
    $OutputObj | Add-Member -MemberType NoteProperty -Name ThirdPartyFirewallPresent -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name AutoUpdate -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name AntivirusPresent -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name AntiSpywarePresent -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name InternetSettings -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name UAC -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name Service -Value "No"
    $OutputObj | Add-Member -MemberType NoteProperty -Name OnAccessScanner -Value "Unknown"
    $OutputObj | Add-Member -MemberType NoteProperty -Name Definition -Value "Unknown"
    
    $HexProductState = "{0:x6}" -f $productState 
    
    $FirstByte = -join (“0x”, $HexProductState.Substring(0,2))
    $SecondByte = -join (“0x”, $HexProductState.Substring(2,2))
    $ThirdByte = -join (“0x”, $HexProductState.Substring(4,2))

    switch ($FirstByte) {
        {($_ -band 1) -gt 0} {$OutputObj.ThirdPartyFirewallPresent = $true}
        {($_ -band 2) -gt 0} {$OutputObj.AutoUpdate = "Active"}
        {($_ -band 4) -gt 0} {$OutputObj.AntivirusPresent = "Yes"}
        {($_ -band 8) -gt 0} {$OutputObj.AntiSpywarePresent = "Yes"}
        {($_ -band 16) -gt 0} {$OutputObj.InternetSettings = "Yes"}
        {($_ -band 32) -gt 0} {$OutputObj.UAC = "Yes"}
        {($_ -band 64) -gt 0} {$OutputObj.Service = "Yes"}
    }

    switch ($SecondByte) {
        {($_ -band 1) -gt 0} {}
        {($_ -band 16) -gt 0} {$OutputObj.OnAccessScanner = "Running"}
    }
    switch ($ThirdByte) {
        {$_ -eq "0x00"} {$OutputObj.Definition = "OK"}
        {($_ -band 1) -gt 0} {$OutputObj.Definition = "NotMonitored"}
        {($_ -band 2) -gt 0} {$OutputObj.Definition = "Poor"}
        {($_ -band 4) -gt 0} {$OutputObj.Definition = "Snooze"}
    }
    $OutputObj
}

CreateFolder "C:\Windows\Logs\SCCM"

WriteLog "Start OSD Enable OSD Message"

# Basic Information
WriteLog "Basic Information"
$ComputerName = gc env:computername
$header = "$ComputerName   S U C C E S S F U L L Y    installed Windows"

# Bitlocker Status
WriteLog "Bitlocker Status"
$ManageBDE = manage-bde -status
if($ManageBDE -match "Protection On"){
    $BitLockerStatus = "        Protection ON`n"
    WriteLog "Bitlocker Protection ON"
} else {
    $BitLockerStatus = "Protection Off`n"
    WriteLog "Bitlocker Protection Off"
}

# Installed Applications (Launcher Keys)
WriteLog "Installed Applications (Launcher Keys)"
if (Test-Path "HKLM:\Software\_Custom\Apps" -erroraction silentlycontinue) {
    $Applications  = Get-ChildItem "HKLM:\Software\_Custom\Apps" 
    $AppList = ""
    $appname = ""
    foreach($app in $Applications){
        WriteLog "App $app found"
        If((get-ItemProperty $app.pspath).LastAction -eq "Install"){
            $appname = $app.PSChildName
            $status = (get-ItemProperty $app.pspath).LastActionStatus
            $AppList += "      $appname            $status`n"
        }
    }
} else {
    WriteLog "No Launcher Application Keys Found."    #Retrieve an array of string that contain all the subkey names        $subkeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue    $subkeys += Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue        #Open each Subkey and use GetValue Method to return the required values for each    foreach($key in $subkeys){        $obj = New-Object PSObject        $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($key.GetValue("DisplayName"))        $obj | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($key.GetValue("DisplayVersion"))        $obj | Add-Member -MemberType NoteProperty -Name "Architecture" -Value $(if($key.PSPath -match "Wow6432Node"){ "x86" } else { "x64" })        if(-not [String]::IsNullOrWhiteSpace($key.GetValue("DisplayName"))){            $AppList += "      $($obj.DisplayName) $($obj.DisplayVersion) ($($obj.Architecture))`n"            WriteLog "App $($obj.DisplayName) $($obj.DisplayVersion) ($($obj.Architecture)) found"        }    }
}

# Check if Virus Scan is installed
WriteLog "Check if Virus Scan is installed"
$virusscan = "      Virus Scan:         Not Installed!`n"
$vs = Get-WmiObject -Namespace Root\SecurityCenter -Class AntiVirusProduct
$vs += Get-WmiObject -Namespace Root\SecurityCenter2 -Class AntiVirusProduct
if($vs -ne $null){
    $virusscan = "      Virus Scan:         $($vs.displayName) ($($vs.timestamp))`n"
    WriteLog "Virus Scan installed $($vs.displayName) ($($vs.timestamp))!"
}
#VirusScan Status

try{
    
    $AntiVirusProductWmi = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct
    
    $AntiVirus = parseProductState -productState $AntiVirusProductWmi.productState

    $virusscan += "      On Access Scanner:  $($AntiVirus.OnAccessScanner)`n"
    $virusscan += "      Definition:         $($AntiVirus.Definition)`n"
    $virusscan += "      Auto Update:        $($AntiVirus.AutoUpdate)`n"

} catch {
 
}


# Check if Spyware Scan is installed
WriteLog "Check if Spyware Scan is installed"
$spywarescan = "      Spyware Scan:           Not Installed!`n"
$ss = Get-WmiObject -Namespace Root\SecurityCenter -Class AntiSpywareProduct
$ss += Get-WmiObject -Namespace Root\SecurityCenter2 -Class AntiSpywareProduct
if($vs -ne $null){
    $spywarescan = "      Spyware:            $($ss.displayName) ($($ss.timestamp))`n"
    WriteLog "Spyware installed $($ss.displayName) ($($ss.timestamp))!"
}

# Get Installed Updates
WriteLog "Get installed updates"
$wusearcher= new-object -com "Microsoft.Update.Searcher"
$totalupdates = $wusearcher.GetTotalHistoryCount()
$results = $wusearcher.QueryHistory(0,$totalupdates)
$SearchResult = ($results | where {$_.ResultCode -eq '2'} | Select Title)
foreach($Update in $SearchResult)
{
    $updatename = $Update.Title
    $UpdateList += "      $updatename`n"
}

# Get executed Scripts
WriteLog "Check for executed Scripts"
If(Test-Path "HKLM:\Software\_Custom\Scripts"){
    $Scripts  = Get-ChildItem "HKLM:\Software\_Custom\Scripts" 
    $scriptList = ""
    foreach($Script in $Scripts){
	    $scriptList += "      " + $Script.PSChildName + "			" + (get-ItemProperty $Script.pspath).ExitMessage
    }
} else {
    $scriptList = "      No scripts found!"
    WriteLog "No executed scripts found."
}

# Building Message
WriteLog "Building Message"
$Message = ""
$Message += "Security Status:`n"
$Message += "      Bitlocker: $BitLockerStatus"
$Message += $virusscan
$Message += $spywarescan
$Message += "`n"
$Message += "`n"
$Message += "Applications:`n"
$Message += $AppList
$Message += "`n"
$Message += "Updates:`n"
$Message += $UpdateList
$Message += "`n"
$Message += "Scripts:`n"
$Message += $scriptList
$Message += "`n"

WriteLog "Message to display:"
WriteLog $Message


WriteLog "Set registry Keys for Legal Notice"
SetRegValue "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\" "LegalNoticeCaption" $header "String"
SetRegValue "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\" "LegalNoticeText" $Message "String"

WriteLog "Register disable OSD Message Script"

Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -InputObject '$null = New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\" -Name LegalNoticeCaption -PropertyType String -Value "" -Force'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject '$null = New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\" -Name LegalNoticeText -PropertyType String -Value "" -Force'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject '$null = Remove-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\RemoveOSDMessage.lnk" -Force'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject '$sid = new-object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject '$acl = Get-Acl "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\"'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject '$rule = New-Object System.Security.AccessControl.RegistryAccessRule($sid,"FullControl", "Allow")'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject '$acl.RemoveAccessRuleAll($rule)'
Out-file -FilePath C:\Windows\RemoveLegalNotice.ps1 -force -append -InputObject 'Set-Acl "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\" $acl'

$wshshell = New-Object -ComObject WScript.Shell
$lnk = $wshshell.CreateShortcut("C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\RemoveOSDMessage.lnk")
$lnk.Arguments = "-executionpolicy bypass -file C:\Windows\RemoveLegalNotice.ps1"
$lnk.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$lnk.Save()

$sid = new-object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$acl = Get-Acl "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\RemoveOSDMessage.lnk"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid,"FullControl", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\RemoveOSDMessage.lnk" $acl

SetRegValue "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce\" "RemoveLegalNoticeCaption" 'REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "LegalNoticeCaption" /d "" /f' "String"
SetRegValue "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce\" "RemoveLegalNoticeText" 'REG ADD "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v "LegalNoticeText" /d "" /f' "String"

WriteLog "Set User Permissions to Winlogon Key"
$sid = new-object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$acl = Get-Acl "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
$rule = New-Object System.Security.AccessControl.RegistryAccessRule($sid,"FullControl", "Allow")
$acl.AddAccessRule($rule)
Set-Acl "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" $acl


WriteLog "Ending OSD Enable OSD Message"