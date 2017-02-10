param(
    [Parameter(Mandatory=$false)]
    [string]$scriptPath = '.\ANXUtilities.psm1'
)

$ScripPath = 'C:\Program Files\Microsoft Dynamics AX\60\ManagementUtilities\Microsoft.Dynamics.ManagementUtilities.ps1'
try{
    .$ScripPath  
}catch{   
    Write-Error -Message "Es konnte kein passendes Script fuer die AX ManagementUtilities Powershell am angegebenen Pfad gefunden werden. ( $ScripPath )" -Verbose
    Break
}

try{
    Write-Output 'Importing ANXUtilities'
    Import-Module $scriptPath -Force
}catch
{
     Write-Error -Message "Es konnte kein passendes Script fuer die ANX Utilities Powershell am angegebenen Pfad gefunden werden. ( $scriptPath )" -Verbose
}