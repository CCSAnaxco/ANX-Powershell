<#
.SYNOPSIS
    ANXAUTOUpdateSkript.ps1
.DESCRIPTION
    Script zur Durchfuehrung des ANAXCO Standard Release Wechsel. Es werden hierfuer die AOS Dienste beendet und eine Sicherung der Content und Model Datenbank erstellt. 
    Bevor die AX Models importiert werden, nach dem Import wird ein AXBuild, eins DB Sync und eine CIL erstellt. Sowie die jeweiligen Logdateien per Mail versandt.
    Nach den Kompilierungen werden die Cache Ordner auf den AOS Server geleert und die ANX Mobil Dienste neugestartet.

.PARAMETER aosServers 
    Liste der AOSServer (Der erstgenannte Server wir als Main verwendet)
.PARAMETER DBServer
    Datenbankserver
.PARAMETER DBInstance
    Datenbankname Instance
.PARAMETER DBBackupPath
    Backuppfad für die DB
.PARAMETER DatabaseName
    AX Datenbankname
.PARAMETER axAosPath 
    Pfad zur AOS 
.PARAMETER varModelPath
    Pfad zur VAR Model Datei 
.PARAMETER vapModelPath
    Pfad zur VAP Model Datei 
.PARAMETER cusModelPath
    Pfad zur CUS Model Datei 
.PARAMETER clearCUSModel
    CUS Model loeschen, sollte nur auf externen Systemen verwendet werden
.PARAMETER mobilServers
   Liste der MobileServer
.PARAMETER EPServer
   Name des EP Servers
.PARAMETER EPSites
   Liste der bereitzustellenden EP Seiten
.PARAMETER EPUrl
   URL Des Enterprise Portal (http://axaos-ep:52712)
.PARAMETER UpdateAdminEmail
  Mailadressen des Durchfuehrenden fuer das Update

.EXAMPLE
    .\ANXAUTOUpdateSkript.ps1 -AosServer 'AOS1, AOS2' -DBServer 'AXSQL2012-01' -DBInstance 'AX' -DBBackupPath 'D:\Microsoft SQL Server\MSSQL12.AX\Backup' -DatabaseName 'DAX03_Test'

.EXAMPLE
$scriptPath = ".\ANXAutoUpdateSkript.ps1"
$argumentList = @()
$argumentList += ("-aosServer", "AXAOS-2012-07")  
$argumentList += ("-DBServer", "AXSQL2012-01")
$argumentList += ("-DBInstance", "AX")
$argumentList += ("-DBBackupPath",'"D:\Microsoft SQL Server\MSSQL12.AX\Backup"')   
$argumentList += ("-DatabaseName", "DAX2012R3_Test")    
$argumentList += ("-varModelPath", ".\VAR-20170123.axmodel")
$argumentList += ("-axAosPath", '"C:\Program Files\Microsoft Dynamics AX\60\Server\DAX2012R3_MasterQS"')
$argumentList += ("-mobilServers", "AXAOS-2012-07") 
$argumentList += ("-EPServer", "AXSP2013-01")
$argumentList += ("-EPSites", "EPANXEmptiesRollCenter, EPANXServiceServiceOperations, EPANXTMSInboundLogistics")
$argumentList += ("-EPUrl", "http://axaos-07-ep:52712")
$argumentList += ("-clearCUSModel", $true)
$argumentList += ("-UpdateAdminEmail", @('carsten.cors@anaxco.de', 'stefan.wojtas@anaxco.de'))

Invoke-Expression "$scriptPath $argumentList"

.NOTES
Version:        0.1 
Author:         Carsten Cors
Company:        ANAXCO GmbH
Creation Date:  2017-02-07
Purpose/Change: n/a
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)]
 [string[]]$aosServers,
 [Parameter(Mandatory=$true)]
 [string]$DBServer,
 [Parameter(Mandatory=$true)]
 [string]$DBInstance,
 [Parameter(Mandatory=$true)]
 [string]$DBBackupPath,
 [Parameter(Mandatory=$true)]
 [string]$DatabaseName,
 [Parameter(Mandatory=$false)]
 [string]$axAosPath = 'C:\Program Files\Microsoft Dynamics AX\60\Server\DAX2012R3',
 [Parameter(Mandatory=$false)]
 [string]$varModelPath,
 [Parameter(Mandatory=$false)]
 [string]$vapModelPath,
 [Parameter(Mandatory=$false)]
 [string]$cusModelPath, 
 [Parameter(Mandatory=$false)]
 [bool]$clearCUSModel = $false, 
 [Parameter(Mandatory=$false)]
 [string[]]$mobilServers,
 [Parameter(Mandatory=$false)]
 [string]$EPServer,
 [Parameter(Mandatory=$false)]
 [string[]]$EPSites,
 [Parameter(Mandatory=$false)]
 [string]$EPUrl,
 [Parameter(Mandatory=$false)]
 [string[]] $UpdateAdminEmail
)

 [long] $AXSYNCTIMEOUT = 1800000
 [long] $AXCOMPILETIMEOUT = 1800000
 [int] $AXSTOPSERVICETIMEOUT = 120
 [int] $AXSTARTSERVICETIMEOUT = 60
 $ErrorActionPreference = "Stop"
 $SMPTSERVER = 'exchange.anaxco.loc'
 $ScriptStartDate = Get-Date

############################################## Load AX ManagementUtilities ################################################################################################
Write-Debug -Message 'Load AX ManagementUtilities'
$ScripPath = [string]::Format("C:\Program Files\Microsoft Dynamics AX\60\ManagementUtilities\Microsoft.Dynamics.ManagementUtilities.ps1", "C")
try
{
    .$ScripPath  
}
catch
{
    Write-Error -Message "Es konnte kein passendes Script fuer die AX Powershell am angegebenen Pfad gefunden werden. ( $ScripPath )" -Verbose
    Break
}

$ANXUtilitiesPath = '.\ANXUtilitiesLoader.ps1'
try
{
    .$ANXUtilitiesPath  
}
catch
{
    Write-Error -Message "Es konnte kein passendes Script fuer die AX Powershell am angegebenen Pfad gefunden werden. ( $ANXUtilitiesPath )" -Verbose
    Break
}

############################################## Stop AOS Service #######################################################################################
Write-Debug -Message 'Stopp all AOS Services'
#Stopp all AOS Services befor take DB backups.
Stop-AOSServices -aosServers $aosServer

#Add slepp to make sure all services stopped
Write-Debug -Message 'Slepp to make sure all services stopped'
Start-Sleep -Seconds $AXSTOPSERVICETIMEOUT

############################################## DB Backup ################################################################################################
#Backup Content and Model DB
Write-Debug -Message 'Backup Content and Model DB'
Backup-AXDatabase -DBServer $DBServer -DBInstance $DBInstance -DatabaseName $DatabaseName -DBBackupPath $DBBackupPath

############################################### INSTALL MODELS ###########################################################################################
Write-Debug -Message 'Import VAR'
Write-Progress -Activity "Import Model" -Status 'Import VAR' -PercentComplete(35)  
#Install VAR anyway
if(Test-Path $varModelPath){
    Install-AXModel -File $varModelPath -Conflict push -NoPrompt 
}else {
    Throw ("Error: VAR Model konnte nicht gefunden werden. Pfad: {0}" -f $varModelPath)  
}
#Install VAP if stated
if(-Not [string]::IsNullOrEmpty($vapModelPath)){
    Write-Debug -Message 'Import VAP'
    Write-Progress -Activity "Import Model" -Status 'Import VAP' -PercentComplete(75)  
    if(Test-Path $vapModelPath){    
        Install-AXModel -File $vapModelPath -Conflict push -NoPrompt
    }else{
        Throw ("Error: VAP Model konnte nicht gefunden werden. Pfad: {0}" -f $vapModelPath)  
    }
}
else {
     Write-Debug -Message 'VAP not stated'
    # if VAP not stated remove old model if exist.
    $checkRemoveVAP = $true
}

#Install CUS if stated
if(-Not [string]::IsNullOrEmpty($cusModelPath)){
    Write-Debug -Message 'Import CUS'
    Write-Progress -Activity "Import Model" -Status 'Import CUS' -PercentComplete(100)  
    if(Test-Path $cusModelPath){
        Install-AXModel -File $cusModelPath -Conflict push -NoPrompt
    }else{
        Throw ("Error: CUS Model konnte nicht gefunden werden. Pfad: {0}" -f $cusModelPath)  
    }
}
else {    
    if($clearCUSModel)
    {
         Write-Debug -Message 'CUS not stated'
        #remove CUS Model only on external systems
        $checkRemoveCUS = $true
    }
    else    
    {
        #Keep CUS Model on development systems
        $checkRemoveCUS = $false
    }
}

#Remove CUS if not new 
if($checkRemoveCUS)
{
    Write-Debug -Message 'Remove CUS'
    Write-Progress -Activity "Remove Model" -Status 'Remove CUS' -PercentComplete(50)  
    Uninstall-AXModel -Model 'CUS Model' -NoPrompt
}

#Remove VAP if not new
if($checkRemoveVAP)
{ 
     Write-Debug -Message 'Remove VAP'
     Write-Progress -Activity "Remove Model" -Status 'Remove VAP' -PercentComplete(100)  
     Uninstall-AXModel -Model 'VAP Model' -NoPrompt
}

######################################### Run AXBuild ###################################################################################
Write-Debug -Message 'Run AXBuild'
Start-AXBuild -axAosPath $axAosPath

######################################## Send AXBuild Log ###############################################################################
Write-Debug -Message 'Send AXBuild Log'
$LogFile = Join-Path $axAosPath 'Log\AxCompileAll.html'
if(Test-Path $LogFile){
    [string[]] $release = $varModelPath.Split('/')
    $msg = '<p>AXBuild beendet um ' + (Get-Date).ToString() + '</p><p><ul><li>Server: <strong>' +  $aosServer[0]  + '</strong></li><li>Release: <strong>' +  $release[$release.Length - 1] + '</strong></li></ul></p><p>F&uumlr weitere Deteils oder Fehlermeldungen, pr&uumlfen Sie die Datei im Anhang.'
    $msg += Get-Content $LogFile

    Send-MailMessage -Attachments $LogFile -To $UpdateAdminEmail -From 'AnxUpdateScript@anaxco.de' -BodyAsHtml $msg -SmtpServer $SMPTSERVER -Subject ('AXBulid Log für ' + $aosServer[0] + ' Release ' +  $release[$release.Length - 1])
}
else {
    Throw ("Error: AXBuild Logdatei konnte nicht gefunden werden. Pfad: {0}" -f $LogFile)  
}
########################################### Start Main AOS ###############################################################################################
Write-Debug -Message 'Start Main AOS Service'
Start-AOSService -singelAOS $aosServers[0]

#Add slepp to make sure service is running
Write-Debug -Message 'slepp to make sure service is running'
Start-Sleep -Seconds $AXSTARTSERVICETIMEOUT

############################################ Sync DB ###############################################################################################
Write-Debug -Message 'Sync DB'
Start-AXDbSync -AXSYNCTIMEOUT $AXSYNCTIMEOUT

########################################### Build CIL ###############################################################################################
Write-Debug -Message 'Compile CIL'
Start-AXCILCompile -AXCOMPILETIMEOUT $AXCOMPILETIMEOUT

############################################## Send CIL Log ############################################################################################
Write-Debug -Message 'Send CIL Log'
$LogCILFile = Join-Path $axAosPath '\bin\XppIL\Dynamics.Ax.Application.dll.log'
if(Test-Path $LogCILFile){
$msg = '<p>CIL Kompilierung beendet um ' + (Get-Date).ToString() + '</p><p><ul><li>Server: <strong>' +  $aosServer[0]  + '</strong></li><li>Release: <strong>' +  $release[$release.Length - 1] + '</strong></li></ul></p><p>F&uumlr weitere Deteils oder Fehlermeldungen, pr&uumlfen Sie die Datei im Anhang.'
$log += Get-Content $LogCILFile
$msg += '<p>' + $log + '</p>'

Send-MailMessage -Attachments $LogCILFile -To $UpdateAdminEmail -From 'AnxUpdateScript@anaxco.de' -BodyAsHtml $msg -SmtpServer $SMPTSERVER -Subject ('CIL Kompilierung für ' + $aosServer[0] + ' Release ' +  $release[$release.Length - 1])
}else{
     Throw ("Error: CIL Logdatei konnte nicht gefunden werden. Pfad: {0}" -f $LogCILFile)  
}

############################################## Stop AOS Service ######################################################################################
Write-Debug -Message 'Stop Main AOS Service'
Stop-AOSServices -aosServers $aosServer

#Add slepp to make sure all services stopped
Write-Debug -Message 'Slepp to make sure all services stopped'
Start-Sleep -Seconds $AXSTOPSERVICETIMEOUT

############################################## Clear Xppil folder ####################################################################################
Write-Debug -Message 'Clear Xppil folder'
Clear-CILFolder -axAosPath $axAosPath -aosServers $aosServer

########################################### Start AOS Dienste ###############################################################################################
Write-Debug -Message 'Starte AOS Services'
Write-Progress -Activity "Start AOS Services" -Status 'Start AOS Service'
Start-AOSServices -aosServers $aosServer

#Add slepp to make sure all services are running
Write-Debug -Message 'slepp to make sure all services are running'
Start-Sleep -Seconds $AXSTARTSERVICETIMEOUT

########################################### Clear Mobile Cache and restart ##########################################################################
Write-Debug -Message 'Clear Mobile Cache and restart '
Clear-AXMobilCache -mobilServers $mobilServers

######################################### Publish Reports #######################################################################################
Write-Debug -Message 'Publish Reports'
publish-AxReport -ReportName *ANX*

######################################### Deloy EP ###############################################################################################
Write-Debug -Message 'Deloy EP'
Start-DelpoyAXWebComponent  -EPServer $EPServer -EPUrl $EPUrl -EPSites $EPSites

######################################Finishing Notification ####################################################################################
Write-Debug -Message 'Sende Finishing Notification'
[datetime]$ScriptEndDate = Get-Date
[TimeSpan]$duration = $ScriptEndDate.Subtract($ScriptStartDate)

$message = ('<p>Ausf&uumlhrung des ANAXCO Auto Update Script beendet um {0}' -f $ScriptEndDate.ToString())
$message += ('<p><ul><li>Server: <strong>{0}</strong></li><li>Release: <strong>{1}</strong></li></ul></p>' -f $aosServer[0], $release[$release.Length - 1])
$message += ('<p>Script gestartet um <strong>{0}</strong> Uhr<br />' -f $ScriptStartDate.ToShortTimeString())
$message += ('Script beendet um <strong>{0}</strong> Uhr<br />' -f $ScriptEndDate.ToShortTimeString())
$message += ('gesamt Laufzeit: <strong>{0} min</strong><br />' -f [int]$duration.TotalMinutes)

Send-MailMessage  -To $UpdateAdminEmail -From 'AnxUpdateScript@anaxco.de' -BodyAsHtml $message -SmtpServer $SMPTSERVER -Subject ('Autoupdate beendet Server:' + $aosServer[0] + ' Release: ' +  $release[$release.Length - 1])
