
$primaryInst = "SQL2.contoso.local"
$secondaryInst = "SQL1.contoso.local"
$MyAgPrimaryPath = "SQLSERVER:\SQL\SQL2.contoso.local\Default\AvailabilityGroups\alwayson-ag"  
$MyAgSecondaryPath = "SQLSERVER:\SQL\SQL1.contoso.local\Default\AvailabilityGroups\alwayson-ag"  

#Add-Type -AssemblyName "Microsoft.SqlServer.Smo"
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo");
import-module SQLps;
# Connect to the specified instance
$srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') $primaryInst
New-Item "f:\backup" –type directory

New-SMBShare –Name "Backup" –Path "f:\backup"  –FullAccess contoso\sqlservicetestuser,contoso\testuser

# Cycle through the databases
foreach ($db in $srv.Databases) {
    if ($db.IsSystemObject -ne $True -and $db.Name -notlike "AutoHa*") 
    {
        $dbname = $db.Name
        #"Changing database $dbname to set Recovery Model to Full"
        $db.RecoveryModel = 'Full'
        $db.Alter()
        $DatabaseBackupFile = "\\" + $primaryInst + "\Backup\" + $dbname +".bak"
        $LogBackupFile =   "\\" + $primaryInst + "\Backup\"  + $dbname +"_log.trn"

        Backup-SqlDatabase -Database $dbname -BackupFile $DatabaseBackupFile -ServerInstance $primaryInst  
        Backup-SqlDatabase -Database $dbname -BackupFile $LogBackupFile -ServerInstance $primaryInst  -BackupAction Log
        
        Restore-SqlDatabase -Database $dbname -BackupFile $DatabaseBackupFile -ServerInstance $secondaryInst -NoRecovery 
        Restore-SqlDatabase -Database $dbname -BackupFile $LogBackupFile -ServerInstance $secondaryInst -RestoreAction 'Log'   -NoRecovery

        Add-SqlAvailabilityDatabase -Path $MyAgPrimaryPath -Database $dbname  
        Add-SqlAvailabilityDatabase -Path $MyAgSecondaryPath -Database $dbname  
        
    }
}

# Check to insure f:\UsageLogs directory exist
$ComputerNameApp1 = "app1.contoso.local"
$ComputerNameApp2 = "app2.contoso.local"

$stageSvrs | %{
         Invoke-Command -ComputerName $ComputerNameApp1 -ScriptBlock { 
            $TARGETDIR = 'f:\UsageLogs'
            if(!(Test-Path -Path $TARGETDIR )){
                Write-Output "Doesn't exist create f:\UsageLogs directory"
                New-Item -Path $TARGETDIR -type directory -Force 
            } else 
            { 
                Write-Output "Directory exist: don't create"
            } 
         }
}

$stageSvrs | %{
         Invoke-Command -ComputerName $ComputerNameApp2 -ScriptBlock { 
            $TARGETDIR = 'f:\UsageLogs'
            if(!(Test-Path -Path $TARGETDIR )){
                Write-Output "Doesn't exist create f:\UsageLogs directory"
                New-Item -Path $TARGETDIR -type directory -Force 
            } else 
            { 
                Write-Output "Directory exist: don't create"
            } 
         }
}


