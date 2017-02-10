<#
.SYNOPSIS
   Stop-AOSServices 
.DESCRIPTION
Funktion zum stoppen der AOS Dienste
.PARAMETER aosServers
Liste der zu stopenden AOSServer 
.EXAMPLE
Stop-AOSServices -aosServers @('AXAOS-2012-07')
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Stop-AOSServices {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$aosServers
    )
    $count = 1   

    foreach($aos in $aosServer) {
        Write-Progress -Activity "Stopping AOS Services" -Status $aos -PercentComplete($count / $aosServer.count * 100)  
        Get-Service -Name 'AOS60$01' -ComputerName $aos | Stopp-Service    
        $count++
    }   
}

<#
.SYNOPSIS
Start-AOSServices 
.DESCRIPTION
Funktion zum starten der AOS Dienste
.PARAMETER aosServers
Liste der zu startenden AOSServer 
.PARAMETER singelAOS
Einzel AOS starten
.EXAMPLE
Start-AOSServices -aosServers @('AXAOS-2012-07')
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Start-AOSServices  {
    param(
        [Parameter(Mandatory=$false)]
        [string[]]$aosServers,
        [Parameter(Mandatory=$false)]
        [string] $singelAOS
    )
    
    if(-not [string]::IsNullOrEmpty($singelAOS))
    {
        #start only singel AOS
        Get-Service -Name 'AOS60$01' -ComputerName $singelAOS | Start-Service  
    }else{
        $count = 1   
        foreach($aos in $aosServers) {
            Write-Progress -Activity "Start AOS Services" -Status $aos -PercentComplete($count / $aosServer.count * 100)  
            Get-Service -Name 'AOS60$01' -ComputerName $aos | Start-Service  
            $count++
        }   
    }    
}

<#
.SYNOPSIS
Start-AXBuild
.DESCRIPTION
Funktion zur ausfuerung der AXBuild 
.PARAMETER axAosPath
Pfad zum bin Verzeichnis des AOS Servers
.PARAMETER axClientPath
Pfad zum bin Verzeichnis des AOS Client
.PARAMETER axInstance
Instanz Nummer
.PARAMETER Worker
Anzahl der zu verwendenden Worker
.EXAMPLE
Start-AXBuild -axAosPath 'C:\Program Files\Microsoft Dynamics AX\60\Server\DAX_Test' -worker 8
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Start-AXBuild {
    param(
        [Parameter(Mandatory=$true)]
        [string] $axAosPath,
        [Parameter(Mandatory=$false)]
        [string] $axClientPath = 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin',
        [Parameter(Mandatory=$false)]
        [string] $axInstance = '01',
        [Parameter(Mandatory=$false)]
        [int] $Worker
    )   
    Write-Progress -Activity 'AX Compiling application started it will takes same time' -Status 'AXBuild'       
    $AxBuild = Join-Path $axAosPath 'bin\AxBuild.exe'
    $Compiler = Join-Path $axAosPath 'bin\ax32serv.exe'
    $Command = '& "{0}" xppcompileall /s={1} /a="{2}" /c="{3}"' -f $axInstance, $AxBuild, $axClientPath, $Compiler
    if(-not ($Worker == 0))
    {
        $Command += ' /w={0}' -f $Worker
    }

    Invoke-Expression $Command
}

<#
.SYNOPSIS
Start-AXDbSync
.DESCRIPTION
Funktion zur ausfuerung der AX Datenbank Synchronisierung.
.PARAMETER axClientPath
Pfad zum bin Verzeichnis des AOS Client
.PARAMETER AXSYNCTIMEOUT
Timeout für die Synchronisierung

.EXAMPLE
Start-AXDbSync -axClientPath 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin'
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Start-AXDbSync {
    param(
        [Parameter(Mandatory=$false)]
        [string] $axClientPath = 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin',
        [Parameter(Mandatory=$false)]
        [long] $AXSYNCTIMEOUT = 1800000
    )

    $axProcess = Start-Process -PassThru ($axClientPath + "`\Ax32.exe") -ArgumentList ($params + " -StartupCmd=Synchronize")
    if ($axProcess.WaitForExit($AXSYNCTIMEOUT) -eq $false)
    {
        Throw ("Error: DB Sync did not complete within " + $AXSYNCTIMEOUT / 60000 + " minutes")  
    }
}

<#
.SYNOPSIS
Start-AXCILCompile
.DESCRIPTION
Funktion zur ausfuerung der AX CIL Kompilierung.
.PARAMETER axClientPath
Pfad zum bin Verzeichnis des AOS Client
.PARAMETER AXSYNCTIMEOUT
Timeout für die Kompilierung
.EXAMPLE
Start-AXCILCompile -axClientPath 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin'
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Start-AXCILCompile {
    param(
        [Parameter(Mandatory=$false)]
        [string] $axClientPath = 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin',
        [Parameter(Mandatory=$false)]
        [long] $AXCOMPILETIMEOUT = 1800000
    )   
   
    $axProcess = Start-Process -PassThru ($axClientPath + "`\Ax32.exe") -ArgumentList ($params + " -StartupCmd=CompileAll")
    if ($axProcess.WaitForExit($AXCOMPILETIMEOUT) -eq $false)
    {
        Throw ("Error: Compile did not complete within " + $AXCOMPILETIMEOUT / 60000 + " minutes") 
    }
}

<#
.SYNOPSIS
Backup-AXDatabases 
.DESCRIPTION
Funktion zum erstellen der SQL Backups der Content und Model Datenbank
.PARAMETER DBServer
SQL Server Name
.PARAMETER DBInstance
SQL Server Instance
.PARAMETER DatabaseName
Name der zu sichernend Datenbank, hier reicht die angabe der Content Datenbank.
.PARAMETER DBBackupPath
Speicherpfade für die Backupdateien
.EXAMPLE
Backup-AXDatabase -DBServer 'AXSQL2014-01' -DBInstance 'AX' -DatabaseName 'DAX03_Test' -DBBackupPath 'D:\Microsoft SQL Server\MSSQL12.AX\Backup'
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Backup-AXDatabases {
    param(
        [Parameter(Mandatory=$true)]
        [string] $DBServer,
        [Parameter(Mandatory=$true)]
        [string] $DBInstance,
        [Parameter(Mandatory=$true)]
        [string] $DatabaseName,
        [Parameter(Mandatory=$true)]
        [string] $DBBackupPath
    )

    Invoke-Command -ComputerName $DBServer {
        $backupFile = $DBBackupPath + ('\{0}.bak' -f $DatabaseName)
        Backup-SqlDatabase -ServerInstance $DBServer + ('\{0}' -f $DBInstance) -Database $DatabaseName -BackupFile $backupFile -CompressionOption on -CopyOnly
    }
    
    Invoke-Command -ComputerName $DBServer {
        $backupFile = $DBBackupPath + ('\{0}_model.bak' -f $DatabaseName)
        Backup-SqlDatabase -ServerInstance $DBServer + ('\{0}' -f $DBInstance) -Database ('{0}_model' -f $DatabaseName) -BackupFile $backupFile -CompressionOption on -CopyOnly
    }
}

<#
.SYNOPSIS
Clear-CILFolder 
.DESCRIPTION
Funktion zum leern des Xppil Verzeichnise auf den Angegebene AOS Server
.PARAMETER axAosPath
Pfad zum bin Verzeichnis des AOS Servers
.PARAMETER aosServers
Liste der zu AOS Server, auf denen das Xppil Verzeichnis geleert werden soll.
.EXAMPLE
Clear-CILFolder -axAosPath 'C:\Program Files\Microsoft Dynamics AX\60\Server\DAX_Test' -aosServers 'AXAOS-2012-07'
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Clear-CILFolder {
    param(
        [Parameter(Mandatory=$true)]
        [string] $axAosPath,
        [Parameter(Mandatory=$true)]
        [string[]] $aosServers
    )

    foreach($aos in $aosServer)
    { 
        Invoke-Command -ComputerName $aos {
            Get-ChildItem -Path (Join-Path $axAosPath 'bin\Xppil') | Remove-Item -Recurse  
        }
    }
}

<#
.SYNOPSIS
Clear-AXMobilCache
.DESCRIPTION
Funktion zum leern des Mobil Cache auf den angegebene AOS Server
.PARAMETER mobilServers
Liste der Mobil Server
.EXAMPLE
Clear-AXMobilCache -mobilServers @('AXMobile-01', 'AXMobile-01')
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Clear-AXMobilCache  {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$mobilServers
    )

    foreach ($mobil in $mobilServers) {
        #stop service
        Get-Service -Name ANAXCO* -ComputerName $mobil | Where-Object {$_.StartType -ne 'Disabled'} | Stopp-Service

        #get account
        $service = Get-Service -Name ANAXCO* -ComputerName $mobil | Where-Object {$_.StartType -ne 'Disabled'} 
        foreach($win in $service)
        {
            $startName = Get-WmiObject win32_service -ComputerName $mobil | Where-Object {$_.Name -eq $win.Name } 
            break
        }
        $AccountName = $startName.StartName.Split('@')[0]

        $userAccountPath = ('C:\Users\{0}\AppData\Local\' -f $AccountName)
        Invoke-Command -ComputerName $mobil {
            Get-ChildItem -Path $userAccountPath | Where-Object {($_.Extension -eq '.auc' -or $_.Extension -eq '.kti')} | Remove-Item       
        }
    }

    #restart MobileServer
    foreach ($mobil in $mobilServers) {
        Get-Service -Name ANAXCO* -ComputerName $mobil | Where-Object {$_.StartType -ne 'Disabled'} | Start-Service
    }
}

<#
.SYNOPSIS
Start-DelpoyAXWebComponent 
.DESCRIPTION
Funktion zum bereitstellen der EP Web Components (Sites und WebControls)
.PARAMETER EPServer
Name des EP Servers
.PARAMETER EPUrl
   URL Des Enterprise Portal (http://axaos-ep:52712)
.PARAMETER EPSites
   Liste der bereitzustellenden EP Seiten
.EXAMPLE
Start-DelpoyAXWebComponent -EPServer 'AXAOS-2012-07-EP' -EPUrl 'http://axaos-ep:52712' -EPSites @('EPANXEmptiesRollCenter','EPANXServiceServiceOperations','EPANXTMSInboundLogistics')
.NOTES
Version:        1.0
Autor:          Carsten Cors
Creation Date:  2017-02-08
#>
function Start-DelpoyAXWebComponent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EPServer,                
        [Parameter(Mandatory=$true)]
        [string]$EPUrl,
        [Parameter(Mandatory=$false)]
        [string[]]$EPSites
    )

    

    Invoke-Command -ComputerName $EPServer {
        if($EPSites.Count -eq 0){
            #If EPSites not stated, try to deploy all sites.
            Publish-AXWebComponent -AOTNode 'Web\Web Files\Page Definitions\' -WebSiteUrl $EPUrl
        }
        else {           
            #delpoy stated sites
            foreach($site in $EPSites)
            {
                Write-Progress -Activity "Deploy EP Components" -Status ("Website: {0}" -f $site) -PercentComplete($count / $EPSites.count * 100)  
                Publish-AXWebComponent -AOTNode ("Web\Web Files\Page Definitions\{0}" -f $site) -WebSiteUrl $EPUrl
                $count++
            }
        }

        Write-Progress -Activity "Deploy EP Components" -Status "Web Controls" 
        Publish-AXWebComponent -AOTNode "Web\Web Files\Web Controls\" -WebSiteUrl $EPUrl 
        #reset iis after deploy
        iisreset.exe /status /noforce
    }
}

Export-ModuleMember -Function 'Stop-AOSServices'
Export-ModuleMember -Function 'Backup-AXDatabases'
Export-ModuleMember -Function 'Start-*'
Export-ModuleMember -Function 'Clear-*'