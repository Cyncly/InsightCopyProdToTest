##### $Id: CopyProdToTest.ps1 37 2023-08-22 14:57:56Z beckma $

Param(
	[string]$Config		# subdirectory containing config file and custom SQL Scripts
	);

################### main #################
Set-Location $PSHOME
$ScriptFullPath = Split-Path $MyInvocation.MyCommand.Path
$BasePath = Split-Path -Path $ScriptFullPath
$FunctionsScript= $ScriptFullPath + "\functions.ps1"
. $FunctionsScript

Write-Msg -Message "Starting Copy Prod to Test $Config"
Import-SQLServerModule

# Check config subdirectory
$Configdir=$BasePath + "\" + $Config
if ( Test-Path $Configdir ){
	# OK!
} else {
	Write-msg -Message "Directory $Configdir not found!" -Severity ERROR
	exit 1
}
# Check config file:
$Configfile=$Configdir + "\config.ps1"
if ( Test-Path $Configfile ){
	# OK!
} else {
	Write-msg -Message "File $Configfile not found!" -Severity ERROR
	exit 1
}

# Initialize some parameters, that might not be present in the config file:
[boolean]$SkipBackupAndRestore=$false  # this can be set to true in order to just run the modification scripts.
[string]$PrinterMapping="('X','X')"
[boolean]$ReplaceCNCOutputDirectory=$true
[boolean]$PurgeSystemMaster=$false
[boolean]$PurgeBOMLog=$false
[boolean]$PurgeInventoryTransactionsMaster=$false
[boolean]$PurgeEngineeringDataMaster=$false
[int]$PurgeDaysToKeep=7 
[string]$TruncateTableList=""
[boolean]$ShrinkTargetInsightDB=$false
[boolean]$BackupTargetDBAfterModifications=$false
[boolean]$RestoreWebservices=$false
[boolean]$CopyReportServerSubfolder=$false
[boolean]$DeleteReportServerSubfolderTarget=$false
[boolean]$PurgeAllTransactionalData=$false
[string]$StoredProcCleanupTransactionalData=""
[boolean]$CheckBackupPath=$true
[string]$NewInstallationScriptsBasedir=$BasePath + "\tools\NewInstallationScripts"
# Read config file:
. $Configfile
# Check/Input Parameter
if ( ! $SQLTimeoutSec) {
	$SQLTimeoutSec=7200
}
if ( $ReplaceAllEmailAddressesBy.Length -gt 0 ) {
	$EmailAddressDomainPrefix=""
}

# Check utilities directory:
if ( Test-Path $NewInstallationScriptsBasedir ){
	# OK!
} else {
	if ( Test-Path "$BasePath\$NewInstallationScriptsBasedir" ){
		# OK! - relative path:
		$NewInstallationScriptsBasedir="$BasePath\$NewInstallationScriptsBasedir"
	} else {
		Write-msg -Message "Directory $NewInstallationScriptsBasedir not found!" -Severity ERROR
		exit 1
	}
}

# Check Standard SQL Scripts directory:
$StandardSQLScriptsDir = $BasePath + "\tools\PostCopySQL"
if ( Test-Path $StandardSQLScriptsDir ){
	# OK!
} else {
	Write-msg -Message "Directory $StandardSQLScriptsDir not found!" -Severity ERROR
	exit 1
}

# Check Custom SQL Scripts directory:
$CustomSQLScriptsDir = $Configdir + "\LocalPostCopySQL"
if ( Test-Path $CustomSQLScriptsDir ){
	# OK!
} else {
	Write-msg -Message "Directory $CustomSQLScriptsDir not found!" -Severity ERROR
	exit 1
}

# Check old style SQL Scripts directory:
$OldSQLScriptsDir = $Configdir + "\PostCopySQL"
if ( Test-Path $OldSQLScriptsDir ){
	Write-msg -Message "Directory $OldSQLScriptsDir found! This is not used any more! Put Custom SQL scripts into the subfolder $CustomSQLScriptsDir now!" -Severity WARNING
} else {
	# OK!
}

if ( $SkipBackupAndRestore ){
	$do_insight_backup=$false
	$do_insight_restore=$false
	$do_imos_backup=$false
	$do_imos_restore=$false
	$RestoreWebservices=$false
} else {
	$do_insight_backup=$true
	$do_insight_restore=$true
	if ( $SourceInsightDB.Length -eq 0 ){
		$do_insight_backup=$false
	}									 
	if ( $ExistingInsightDBBackupFile ){
		$InsightBackupFile=$ExistingInsightDBBackupFile
		$do_insight_backup=$false
		$CheckInsightVersionBeforeCopy=$false
		if ( $CheckBackupPath ) {
			if (  ! (Test-Path $ExistingInsightDBBackupFile) ){
				Write-msg -Message "Backupfile $ExistingInsightDBBackupFile not found!" -Severity ERROR
				exit 1
			}
		}
	}
	$do_imos_backup=$true
	$do_imos_restore=$true
	if ( $SourceIMOSDB.Length -eq 0 ){
		$do_imos_backup=$false
	}									 
	if ( $ExistingIMOSDBBackupFile ){
		$IMOSBackupFile=$ExistingIMOSDBBackupFile
		$do_imos_backup=$false
		if ( $CheckBackupPath ) {
			if ( ! (Test-Path $ExistingIMOSDBBackupFile) ){
				Write-msg -Message "Backupfile $ExistingIMOSDBBackupFile not found!" -Severity ERROR
				exit 1
			}
		}
	}
}


if ( $do_insight_backup -or $do_imos_backup ){
	$SServer=New-Object Microsoft.SQLserver.Management.Smo.Server $SourceServer
	$Sserver.ConnectionContext.StatementTimeout=$SQLTimeoutSec
}

if ( $do_insight_backup ){
	# Check if source Insight database  exists:
	try{
		$x=$SServer.databases|where-object { $_.name -eq $SourceInsightDB }
		if ( ! $x ) {
			Write-msg -Message "Source Insight Database ${SourceServer}.${SourceInsightDb} not found!" -Severity ERROR
			exit 1
		}
	}
	catch{
		Write-msg -Message "Cannot connect to $SourceServer !" -Severity ERROR
		exit 1
	}
}

if ( $do_imos_backup ){
	# Check if source IMOS database  exists:
	if ( $SourceIMOSDb.Length -gt 0 ) {
		try{
			$x=$SServer.databases|where-object { $_.name -eq $SourceIMOSDB }
			if ( ! $x ) {
				Write-msg -Message "Source Construct Database $SourceServer.$SourceIMOSDb not found!" -Severity ERROR
				exit 1
			}
		}
		catch{
			Write-msg -Message "Cannot connect to $SourceServer!" -Severity ERROR
			exit 1
		}
	}
	if ( $SourceIMOSDbXB.Length -gt 0 ) {
		try{
			$x=$SServer.databases|where-object { $_.name -eq $SourceIMOSDbXB }
			if ( ! $x ) {
				Write-msg -Message "Source Construct XB Database $SourceServer.$SourceIMOSDbXB not found!" -Severity ERROR
				exit 1
			}
		}
		catch{
			Write-msg -Message "Cannot connect to $SourceServer!" -Severity ERROR
			exit 1
		}
	}
}

# Check if target instance can be connected:
try{
	$srvconn= New-Object "Microsoft.SqlServer.Management.Common.ServerConnection" $TargetServer
	$srvconn.StatementTimeout=$SQLTimeoutSec   # default timeout is 600 seconds - too short for restore!
	$TServer=New-Object "Microsoft.SqlServer.Management.Smo.Server" $srvconn
}
catch{
	Write-msg -Message "Cannot connect to $TargetServer!" -Severity ERROR
	exit 1
}

if ( $do_insight_backup -or $do_imos_backup ){
	# Check backup directory:
	if ( $CheckBackupPath ){
		if ( ! (Test-Path $TempBackupPath) ){
			Write-msg -Message "Directory $TempBackupPath not found!" -Severity ERROR
			exit 1
		}
	}
}

if ( $do_insight_backup -and $SourceInsightDB.Length -gt 0 ){
	# Retrieve inSight Version from Source DB:
	Write-Msg -Message "Determine inSight version from Source database..."
	$Query="DECLARE @MajorVersion int, @MinorVersion int, @PatchVersion int, @BuildNo int
		EXEC dbo.spAPP_utlValidateApplicationSchemaMatch 
			 @MajorVersion = @MajorVersion OUTPUT
			,@MinorVersion = @MinorVersion OUTPUT
			,@PatchVersion = @PatchVersion OUTPUT
			,@BuildNo = @BuildNo OUTPUT
			,@ReturnVersionOnly = 1
		select  rtrim(cast(@MajorVersion as CHAR)) + '.' + rtrim(cast(@MinorVersion as char)) + '.' + rtrim(cast(@PatchVersion as char))
	"
	$result=Invoke-sqlcmd -TrustServerCertificate -ServerInstance $SourceServer -Database $SourceInsightDB -Query $Query
	$inSightVersion=$result[0].trimend()
	$inSightVersion
	$NewInstallationScriptsDir=$NewInstallationScriptsBasedir + "\" + $inSightVersion
	# Check New installation subdirectory:
	if ( Test-Path $NewInstallationScriptsDir ){
		# OK!
	} else {
		Write-msg -Message "Directory $NewInstallationScriptsDir not found!" -Severity ERROR
		exit 1
	}
}

if ( $do_insight_restore -and $TargetInsightDb.Length -gt 0 -and $CheckInsightVersionBeforeCopy -eq $true){
	# Check if target Insight DB exists and has same version as source:
	$x=$TServer.databases|where-object { $_.name -eq $TargetInsightDB }
	if ( $x ) {
		# Retrieve inSight Version from Target DB:
		Write-Msg -Message "Determine inSight version from existing Target database..."
		$Query="DECLARE @MajorVersion int, @MinorVersion int, @PatchVersion int, @BuildNo int
			EXEC dbo.spAPP_utlValidateApplicationSchemaMatch 
				 @MajorVersion = @MajorVersion OUTPUT
				,@MinorVersion = @MinorVersion OUTPUT
				,@PatchVersion = @PatchVersion OUTPUT
				,@BuildNo = @BuildNo OUTPUT
				,@ReturnVersionOnly = 1
			select  rtrim(cast(@MajorVersion as CHAR)) + '.' + rtrim(cast(@MinorVersion as char)) + '.' + rtrim(cast(@PatchVersion as char))
		"
		$result=Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query
		$inSightVersionTarget=$result[0].trimend()
		$inSightVersionTarget
		if ( ! ($inSightVersionTarget -eq $inSightVersion) ) {
			Write-msg -Message "Insight version of source and target database is different!!" -Severity ERROR
			exit 1
		}
	}
}

if ( $do_insight_backup ){
	# Backup Insight database
	$InsightBackupFile=$TempBackupPath + "\" + $SourceServer.Replace("\","_") + "_" + $SourceInsightDb + "_CopyProdToTest_temp.bak"
	if ( Test-Path $InsightBackupFile ){
		Remove-item -Path $InsightBackupFile
	}
	BackupDatabase -ServerInstance $SourceServer -Database $SourceInsightDb -BackupFile $InsightBackupFile
}

if ( $do_imos_backup ){
	# Backup IMOS database
	if ( $SourceIMOSDb.Length -gt 0 ) {
		$IMOSBackupFile=$TempBackupPath + "\" + $SourceServer.Replace("\","_") + "_" + $SourceIMOSDb + "_CopyProdToTest_temp.bak"
		if ( Test-Path $IMOSBackupFile ){
			Remove-item -Path $IMOSBackupFile
		}
		BackupDatabase -ServerInstance $SourceServer -Database $SourceIMOSDb -BackupFile $IMOSBackupFile
	}
	if ( $SourceIMOSDbXB.Length -gt 0 ) {
		$IMOSBackupFileXB=$TempBackupPath + "\" + $SourceServer.Replace("\","_") + "_" + $SourceIMOSDbXB + "_CopyProdToTest_temp.bak"
		if ( Test-Path $IMOSBackupFileXB ){
			Remove-item -Path $IMOSBackupFileXB
		}
		BackupDatabase -ServerInstance $SourceServer -Database $SourceIMOSDbXB -BackupFile $IMOSBackupFileXB
	}
}

# Stop Inresponse (and other) Services
$InresponseServicesToRestart.split(",")|foreach{
	$hostname=$_.split(":")[0]
	$servicename=$_.split(":")[1]
	if ( ($hostname.Length -gt 0) -and ($servicename.Length -gt 0) ){
		Write-msg -Message "Stopping Service $servicename on host $hostname..." 
		set-service -ComputerName $hostname -name $servicename -Status Stopped
	}
}

if ( $do_insight_restore -and $TargetInsightDb.Length -gt 0 ) {
	# Restore Insight database
	$TargetRecoveryModel=$TargetRecoveryModel.tolower()
	if ( $TargetRecoveryModel -ne "full" ) {
		$TargetRecoveryModel="simple"
	}

	# Check if Insight database already exists:
	$x=$TServer.databases|where-object { $_.name -eq $TargetInsightDB }
	if ( $x ) {
		if ( $BackupTargetDBBeforeDrop -eq $true ){
			$BackupFile=$TempBackupPath + "\" + $TargetServer.Replace("\","_") + "_" + $TargetInsightDB + "_CopyProdToTest_temp.bak"
			if ( Test-Path $BackupFile ){
				Remove-item -Path $BackupFile
			}
			BackupDatabase -ServerInstance $TargetServer -Database $TargetInsightDB -BackupFile $BackupFile
		}
		if ( $RestoreWebservices -eq $true ){
			Write-msg -Message "Save Inresponse Webservice definitions to Master DB..."
			Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database "Master" -InputFile "$StandardSQLScriptsDir\DropCreateTempServices.sql" -QueryTimeout $SQLTimeoutSec -Verbose
			Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDb -InputFile "$StandardSQLScriptsDir\SaveInresponseServices.sql" -QueryTimeout $SQLTimeoutSec -Verbose
		}
		Write-msg -Message "Drop Database $TargetServer.$TargetInsightDb ..." 
		$TServer.KillAllProcesses($TargetInsightDb)
		$Query="ALTER DATABASE [" + $TargetInsightDb + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database master -Query $Query #-Verbose
			
		$Query="DROP DATABASE [" + $TargetInsightDb + "];"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database master -Query $Query #-Verbose	
	} else {
		$RestoreWebservices=$false	# there is nothing to restore!
	}

	Write-msg -Message "Restore Insight database $TargetServer.$TargetInsightDB from $InsightBackupFile..." 

	$device = new-object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $InsightBackupFile,"File";
	$restore= new-object Microsoft.SqlServer.Management.Smo.Restore -Property @{
		Action = 'database'
		Database = $TargetInsightDB
		NoRecovery = $false
	}
	$restore.Devices.Add($device)

	$dataPath = $TServer.Settings.Defaultfile
	$logPath = $TServer.Settings.DefaultLog

	foreach ($file in $restore.ReadFileList($TServer)) 
	{
		$FileExtension=[system.io.path]::GetExtension("$($file.PhysicalName)")
		$relocateFile = new-object 'Microsoft.SqlServer.Management.Smo.RelocateFile';
		$relocateFile.LogicalFileName = $file.LogicalName;
		if ($file.Type -eq 'D'){
			$relocateFile.PhysicalFileName = "$dataPath\${TargetInsightDB}_"+$file.LogicalName+$FileExtension;
		} else {
			$relocateFile.PhysicalFileName = "$logPath\${TargetInsightDB}_"+$file.LogicalName+$FileExtension;
		}
		$restore.RelocateFiles.Add($relocateFile) | out-null;
	}
	try {
		$restore.SqlRestore($TServer)
	}
	catch {
		$err = $_.Exception
		$errmsg = $err.Message
		while( $err.InnerException ) {
			$err = $err.InnerException
			$errmsg = $errmsg + "|" + $err.Message
		}
		Write-Msg -Message $errmsg -Severity ERROR
		exit 1
	}

	$Query = "ALTER DATABASE [" + $TargetInsightDB + "] SET RECOVERY " + $TargetRecoveryModel + " WITH NO_WAIT"
	Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query

	# DBOWNER rights:
	$DBOwners.split(",")|foreach{
		$DbOwner=$_
		if ( $DbOwner.Length -gt 0 ) {
			if ( $DbOwner -match "\\" ) {
				# Windows Login -> Create user if not exists!
				Write-Msg -Message "Create Database User $DBOwner..."
				$Query="IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE name = N'" + $DBOwner + "') CREATE USER [" + $DbOwner + "] FOR LOGIN [" + $DbOwner + "]"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -verbose
			} else {
				# SQL Login -> DROP and CREATE User!
				Write-Msg -Message "Drop Database User $DBOwner..."
				$Query="DROP USER IF EXISTS [" + $DbOwner + "]"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -verbose
				Write-Msg -Message "Create Database User $DBOwner..."
				$Query="CREATE USER [" + $DbOwner + "] FOR LOGIN [" + $DbOwner + "]"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -verbose
			}
			Write-Msg -Message "Grant DB_OWNER rights to $DbOwner..." 
			$Query="ALTER ROLE [db_owner] ADD MEMBER [" + $DbOwner + "]"
			Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -verbose
		}
	}
}	
# Restore IMOS database
if ( $do_imos_restore -and ($SourceIMOSDb.Length -gt 0) -and ($TargetIMOSDb.Length -gt 0) ) {
	# Check if IMOS database already exists:
	$x=$TServer.databases|where-object { $_.name -eq $TargetIMOSDB }
	if ( $x ) {
		if ( $BackupTargetDBBeforeDrop -eq $true ){
			$BackupFile=$TempBackupPath + "\" + $TargetServer.Replace("\","_") + "_" + $TargetIMOSDB + "_CopyProdToTest_temp.bak"
			if ( Test-Path $BackupFile ){
				Remove-item -Path $BackupFile
			}
			$dbBackup = new-Object ("Microsoft.SqlServer.Management.Smo.Backup");
			$dbBackup.Database = $TargetIMOSDB;
			$dbBackup.Devices.AddDevice($BackupFile, "File" );
			$dbBackup.Action="Database";
			$dbBackup.Initialize = $TRUE;
			$dbbackup.CopyOnly=$TRUE
			$dbBackup.CompressionOption="On"
			#Perform Backup:
			Write-msg -Message "Starting Backup existing target Database $TargetServer.$TargetIMOSDB to $BackupFile..." 
			$dbBackup.SqlBackup($Tserver);
			Write-msg -Message "Backup completed."
			if ( $CheckBackupPath ){
				Start-Sleep -seconds 5
				if ( ! (Test-Path $BackupFile )) {
					Write-msg -Message "Backup aborted!!" -Severity ERROR
					exit 1
				}
			}
		}
	
		Write-Msg -Message "Drop Database $TargetServer.$TargetIMOSDb ..."
		$TServer.KillAllProcesses($TargetIMOSDB)
		$Query="ALTER DATABASE [" + $TargetIMOSDB + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database master -Query $Query #-Verbose
			
		$Query="DROP DATABASE [" + $TargetIMOSDB + "];"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database master -Query $Query #-Verbose	
	}

	Write-Msg -Message "Restore IMOS database $TargetServer.$TargetIMOSDB from $IMOSBackupFile..."
	$device = new-object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $IMOSBackupFile,"File";
	$restore= new-object Microsoft.SqlServer.Management.Smo.Restore -Property @{
		Action = 'database'
		Database = $TargetIMOSDB
		NoRecovery = $false
	}
	$restore.Devices.Add($device)

	$dataPath = $TServer.Settings.Defaultfile
	$logPath = $TServer.Settings.DefaultLog

	foreach ($file in $restore.ReadFileList($TServer)) 
	{
		$FileExtension=[system.io.path]::GetExtension("$($file.PhysicalName)")
		$relocateFile = new-object 'Microsoft.SqlServer.Management.Smo.RelocateFile';
		$relocateFile.LogicalFileName = $file.LogicalName;
		if ($file.Type -eq 'D'){
			$relocateFile.PhysicalFileName = "$dataPath\${TargetIMOSDB}_"+$file.LogicalName+$FileExtension;
		} else {
			$relocateFile.PhysicalFileName = "$logPath\${TargetIMOSDB}_"+$file.LogicalName+$FileExtension;
		}
		$restore.RelocateFiles.Add($relocateFile) | out-null;
	}
	try {
		$restore.SqlRestore($TServer)
	}
	catch {
		$err = $_.Exception
		$errmsg = $err.Message
		while( $err.InnerException ) {
			$err = $err.InnerException
			$errmsg = $errmsg + "|" + $err.Message
		}
		Write-Msg -Message $errmsg -Severity ERROR
		exit 1
	}

	$Query = "ALTER DATABASE [" + $TargetIMOSDB + "] SET RECOVERY " + $TargetRecoveryModel + " WITH NO_WAIT"
	Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetIMOSDB -Query $Query
	
	# DBOWNER rights:
	$DBOwnersIMOS.split(",")|foreach{
		$DbOwner=$_
		if ( $DbOwner.Length -gt 0 ) {
			Write-Msg -Message "Grant DB_OWNER rights to $DbOwner..."
			$Query="EXEC sp_addrolemember N'db_owner', N'" + $DbOwner + "'"
			Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetIMOSDB -Query $Query -verbose
		}
	}

	if ( $TargetInsightDb.Length -gt 0 ) {
		# Adjust IMOS database name in Insight settings:
		$Query = "UPDATE s SET setValue = '" + $TargetIMOSDB + "' FROM dbo.Settings s WHERE s.setCategory = 'inSight' AND s.setSubCategory = 'IMOS'	AND s.setName = 'IMOSDatabase'"
		Write-Msg -Message "Update Insight setting 'IMOSDatabase'..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -verbose
		
		# Adjust IMOS database name in Action tree parameters:
		$LikeStr='%IMOSDatabase="'+$SourceIMOSDb+'"%'
		$Query = "UPDATE tr SET trFixedParameters =
		CAST(REPLACE(CAST(tr.trFixedParameters AS NVARCHAR(MAX)),N'"+$SourceIMOSDb+"',N'"+$TargetIMOSDb+"') AS XML)
		OUTPUT 
		INSERTED.orgID
		,INSERTED.atrID
		,INSERTED.actID
		,INSERTED.actIDInstance
		,INSERTED.trDescription
		,DELETED.trFixedParameters trFixedParameters_OLD
		,INSERTED.trFixedParameters trFixedParameters_NEW
		FROM inResponse.Trees tr WHERE CAST(tr.trFixedParameters AS NVARCHAR(MAX)) LIKE '"+$LikeStr+"'"
		Write-Msg -Message "Update Action tree parameter 'IMOSDatabase'..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -verbose
	}
}
# Restore IMOS XB database
if ( $do_imos_restore -and ($SourceIMOSDbXB.Length -gt 0) -and ($TargetIMOSDbXB.Length -gt 0) ) {
	# Check if IMOS database already exists:
	$x=$TServer.databases|where-object { $_.name -eq $TargetIMOSDbXB }
	if ( $x ) {
		if ( $BackupTargetDBBeforeDrop -eq $true ){
			$BackupFile=$TempBackupPath + "\" + $TargetServer.Replace("\","_") + "_" + $TargetIMOSDbXB + "_CopyProdToTest_temp.bak"
			if ( Test-Path $BackupFile ){
				Remove-item -Path $BackupFile
			}
			BackupDatabase -ServerInstance $TargetServer -Database $TargetIMOSDbXB -BackupFile $BackupFile
		}
	
		Write-Msg -Message "Drop Database $TargetServer.$TargetIMOSDbXB ..."
		$TServer.KillAllProcesses($TargetIMOSDbXB)
		$Query="ALTER DATABASE [" + $TargetIMOSDbXB + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database master -Query $Query #-Verbose
			
		$Query="DROP DATABASE [" + $TargetIMOSDbXB + "];"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database master -Query $Query #-Verbose	
	}

	Write-Msg -Message "Restore IMOS XB database $TargetServer.$TargetIMOSDbXB from $IMOSBackupFileXB..."
	$device = new-object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $IMOSBackupFileXB,"File";
	$restore= new-object Microsoft.SqlServer.Management.Smo.Restore -Property @{
		Action = 'database'
		Database = $TargetIMOSDbXB
		NoRecovery = $false
	}
	$restore.Devices.Add($device)

	$dataPath = $TServer.Settings.Defaultfile
	$logPath = $TServer.Settings.DefaultLog

	foreach ($file in $restore.ReadFileList($TServer)) 
	{
		$FileExtension=[system.io.path]::GetExtension("$($file.PhysicalName)")
		$relocateFile = new-object 'Microsoft.SqlServer.Management.Smo.RelocateFile';
		$relocateFile.LogicalFileName = $file.LogicalName;
		if ($file.Type -eq 'D'){
			$relocateFile.PhysicalFileName = "$dataPath\${TargetIMOSDbXB}_"+$file.LogicalName+$FileExtension;
		} else {
			$relocateFile.PhysicalFileName = "$logPath\${TargetIMOSDbXB}_"+$file.LogicalName+$FileExtension;
		}
		$restore.RelocateFiles.Add($relocateFile) | out-null;
	}
	try {
		$restore.SqlRestore($TServer)
	}
	catch {
		$err = $_.Exception
		$errmsg = $err.Message
		while( $err.InnerException ) {
			$err = $err.InnerException
			$errmsg = $errmsg + "|" + $err.Message
		}
		Write-Msg -Message $errmsg -Severity ERROR
		exit 1
	}

	$Query = "ALTER DATABASE [" + $TargetIMOSDbXB + "] SET RECOVERY " + $TargetRecoveryModel + " WITH NO_WAIT"
	Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetIMOSDbXB -Query $Query
	
	# DBOWNER rights:
	$DBOwnersIMOS.split(",")|foreach{
		$DbOwner=$_
		Write-Msg -Message "Grant DB_OWNER rights to $DbOwner..."
		$Query="EXEC sp_addrolemember N'db_owner', N'" + $DbOwner + "'"
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetIMOSDbXB -Query $Query -verbose
	}
}

if ( $TargetInsightDb.Length -gt 0 ) {
	$TServer=New-Object "Microsoft.SqlServer.Management.Smo.Server" $srvconn 
	$x=$TServer.databases|where-object { $_.name -eq $TargetInsightDB }
	if ( ! $x ) {
		Write-msg -Message "Database $TargetInsightDb not found!" -Severity ERROR
		exit 1		
	}
	
	# Run "New installation scripts:"
	# Retrieve inSight Version from Target DB:
	Write-Msg -Message "Determine inSight version from Target database..."
	$Query="DECLARE @MajorVersion int, @MinorVersion int, @PatchVersion int, @BuildNo int
		EXEC dbo.spAPP_utlValidateApplicationSchemaMatch 
			 @MajorVersion = @MajorVersion OUTPUT
			,@MinorVersion = @MinorVersion OUTPUT
			,@PatchVersion = @PatchVersion OUTPUT
			,@BuildNo = @BuildNo OUTPUT
			,@ReturnVersionOnly = 1
		select  rtrim(cast(@MajorVersion as CHAR)) + '.' + rtrim(cast(@MinorVersion as char)) + '.' + rtrim(cast(@PatchVersion as char))
	"
	$result=Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query
	$inSightVersion=$result[0].trimend()
	$inSightVersion
	$NewInstallationScriptsDir=$NewInstallationScriptsBasedir + "\" + $inSightVersion
	# Check New installation subdirectory:
	if ( Test-Path $NewInstallationScriptsDir ){
		# OK!
	} else {
		Write-msg -Message "Directory $NewInstallationScriptsDir not found!" -Severity ERROR
		exit 1
	}
	
	Write-Msg -Message "Run inSight new installation scripts from $NewInstallationScriptsDir..."
	Start-Sleep 5
	if ( Test-Path $NewInstallationScriptsDir ){
		if ( Test-Path "$NewInstallationScriptsDir\A00 Object Sequence.txt" ){
			foreach ( $SqlFile in get-content "$NewInstallationScriptsDir\A00 Object Sequence.txt" ) {
				Write-msg -Message "$SqlFile"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -InputFile $NewInstallationScriptsDir\$SqlFile -QueryTimeout $SQLTimeoutSec
				Start-Sleep 5
			}
		}  else {
			foreach ( $SqlFile in get-childItem $NewInstallationScriptsDir | Where-Object {$_.Name -Like "*.sql"}  ) {
				Write-msg -Message "$SqlFile"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -InputFile $NewInstallationScriptsDir\$SqlFile -QueryTimeout $SQLTimeoutSec
				Start-Sleep 5
			}
		}
			
	} else {
		Write-Msg -Message "Directory $NewInstallationScriptsDir not found!" -Severity ERROR
	}

	# Run Standard SQL Scripts
	Write-Msg -Message "=== Run Standard modification SQL scripts from $StandardSQLScriptsDir ..."
	if ( Test-Path $StandardSQLScriptsDir ){
		$TServer.KillAllProcesses($TargetInsightDB)
		if ( Test-Path "$StandardSQLScriptsDir\A00 TriggerTableList.txt" ){
			foreach ( $Tablename in get-content "$StandardSQLScriptsDir\A00 TriggerTableList.txt" ) {
				Write-msg -Message "Disable triggers on $Tablename"
				$Query="IF OBJECT_ID(N'"+$Tablename+"', N'U') IS NOT NULL ALTER TABLE "+$Tablename+" DISABLE TRIGGER all"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
			}
		}
		if ( Test-Path "$StandardSQLScriptsDir\A00 Object Sequence.txt" ){
			foreach ( $SqlFile in get-content "$StandardSQLScriptsDir\A00 Object Sequence.txt" ) {
				Write-msg -Message "$SqlFile"
				$SqlFileTmp=$env:TMP + "\" + $SqlFile
				# Replace Powershell variables in SQL File with their values
				$f=(get-content "$StandardSQLScriptsDir\$SqlFile")
				if ( $f ){
					$f=$f.replace('$InResponseUserMapping',$InResponseUserMapping)
					$f=$f.replace('$InresponseUsersToDelete',$InresponseUsersToDelete)
					$f=$f.replace('$PathMappings',$PathMappings)
					$f=$f.replace('$SpecificInsightSettings',$SpecificInsightSettings)
					$f=$f.replace('$EmailAddressDomainPrefix',$EmailAddressDomainPrefix)
					$f=$f.replace('$ReplaceAllEmailAddressesBy',$ReplaceAllEmailAddressesBy)
					$f=$f.replace('$ReportServerURISource',$ReportServerURISource)
					$f=$f.replace('$ReportServerURITarget',$ReportServerURITarget)
					$f=$f.replace('$ReportServerSubfolderSource',$ReportServerSubfolderSource)
					$f=$f.replace('$ReportServerSubfolderTarget',$ReportServerSubfolderTarget)
					$f=$f.replace('$PrinterMapping',$PrinterMapping)
					$f=$f.replace('$DisableAllMonitors',[int]$DisableAllMonitors)
					$f=$f.replace('$RestoreWebservices',[int]$RestoreWebservices)
					$f|set-content $SqlFileTmp
					Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -InputFile $SqlFileTmp -QueryTimeout $SQLTimeoutSec -Verbose
				}
			}
		}
		if ( Test-Path "$StandardSQLScriptsDir\A00 TriggerTableList.txt" ){
			foreach ( $Tablename in get-content "$StandardSQLScriptsDir\A00 TriggerTableList.txt" ) {
				Write-msg -Message "Enable triggers on $Tablename"
				$Query="IF OBJECT_ID(N'"+$Tablename+"', N'U') IS NOT NULL ALTER TABLE "+$Tablename+" ENABLE TRIGGER all"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
			}
		}
	} else {
		Write-Msg -Message "Directory $StandardSQLScriptsDir not found!" -Severity ERROR
	}


	# Run custom SQL Scripts
	Write-Msg -Message "=== Run custom modification SQL scripts from $CustomSQLScriptsDir ..."
	if ( Test-Path $CustomSQLScriptsDir ){
		$TServer.KillAllProcesses($TargetInsightDB)
		if ( Test-Path "$CustomSQLScriptsDir\A00 TriggerTableList.txt" ){
			foreach ( $Tablename in get-content "$CustomSQLScriptsDir\A00 TriggerTableList.txt" ) {
				Write-msg -Message "Disable triggers on $Tablename"
				$Query="IF OBJECT_ID(N'"+$Tablename+"', N'U') IS NOT NULL ALTER TABLE "+$Tablename+" DISABLE TRIGGER all"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
			}
		}
		if ( Test-Path "$CustomSQLScriptsDir\A00 Object Sequence.txt" ){
			foreach ( $SqlFile in get-content "$CustomSQLScriptsDir\A00 Object Sequence.txt" ) {
				Write-msg -Message "$SqlFile"
				$SqlFileFullpath="$CustomSQLScriptsDir\$SqlFile"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -InputFile $SqlFileFullpath -QueryTimeout $SQLTimeoutSec -Verbose
			}
		}
		if ( Test-Path "$CustomSQLScriptsDir\A00 TriggerTableList.txt" ){
			foreach ( $Tablename in get-content "$CustomSQLScriptsDir\A00 TriggerTableList.txt" ) {
				Write-msg -Message "Enable triggers on $Tablename"
				$Query="IF OBJECT_ID(N'"+$Tablename+"', N'U') IS NOT NULL ALTER TABLE "+$Tablename+" ENABLE TRIGGER all"
				Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
			}
		}
	} else {
		Write-Msg -Message "Directory $CustomSQLScriptsDir not found!" -Severity ERROR
	}
}

if ($TargetIMOSDb.Length -gt 0) {
	# Modifications within IMOS/Construct database:
	$TServer=New-Object "Microsoft.SqlServer.Management.Smo.Server" $srvconn 
	$x=$TServer.databases|where-object { $_.name -eq $TargetIMOSDb }
	if ( $x ) {
		if ( $ReplaceCNCOutputDirectory ){
			Write-Msg -Message "Determine IMORDER folder from Insight target DB..."
			$Query="SELECT setValue FROM dbo.settings WHERE setCategory=N'inResponse' AND setSubCategory=N'ImosSettings' AND setName=N'BldrLstPath'"
			$result=Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query
			$BldrLstPath=$result[0]
			$BldrLstPath
			Write-Msg -Message "Update CNC Output directory in Construct target DB..."
			$Query="UPDATE av  SET ATTRVALUE='" + $BldrLstPath + "'
				OUTPUT INSERTED.MACHINE, INSERTED.ATTRIBUTE, DELETED.ATTRVALUE ATTRVALUE_OLD, INSERTED.ATTRVALUE ATTRVALUE_NEW
				FROM dbo.CAMDLMACHINEATTRVALUE av WHERE av.ATTRIBUTE='cnc output directory'"
			Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetIMOSDB -Query $Query
		}
	} else {
		Write-msg -Message "Database $TargetIMOSDb not found!" -Severity ERROR
	}
}

# Copy Reporting Services Reports (optional)
if ( $CopyReportServerSubfolder -and $ReportServerURISource.Length -gt 0 -and $ReportServerURITarget -gt 0 ){
	Write-Msg -Message "=== Copy Reporting Services Reports ..."
	$x=get-installedmodule -Name "ReportingServicesTools" -ErrorAction SilentlyContinue
	if ( ! $x ) {
		Write-Msg -Message "ReportingServicesTools Module not loaded! - Run 'Install-Module -Name ReportingServicesTools -AllowClobber -Force' as administrator first!" -Severity ERROR
	} else {
		$ReportTmpdir=$env:TMP + "\ReportTmpdir"
		remove-item -Recurse -Force -ErrorAction Ignore $ReportTmpdir
		$d=New-Item -Type Directory -Path $ReportTmpdir

		$ReportServerSubfolderSource_withSlash="/"+$ReportServerSubfolderSource
		$ReportServerSubfolderTarget_withSlash="/"+$ReportServerSubfolderTarget

		$msg=" Downloading folder "+$ReportServerSubfolderSource_withSlash+" from "+$ReportServerURISource+" ..."
		Write-Msg $msg
		Out-RsFolderContent -ReportServerUri $ReportServerURISource -RsFolder $ReportServerSubfolderSource_withSlash -Recurse -Destination $ReportTmpdir

		$Proxy = New-RSWebServiceProxy -ReportServerUri $ReportServerURITarget
		if ( $DeleteReportServerSubfolderTarget ) {
			$msg=" Deleting folder "+$ReportServerSubfolderTarget_withSlash+" from "+$ReportServerURITarget+" ..."
			Write-Msg $msg
			$d=Get-RsFolderContent -proxy $Proxy -RsFolder "/" | where-object { $_.Name -eq $ReportServerSubfolderTarget }
			if ( $d ) {
				$Proxy.DeleteItem($ReportServerSubfolderTarget_withSlash)
			}
		}
		
		$msg=" Uploading folder "+$ReportServerSubfolderTarget_withSlash+" to "+$ReportServerURITarget+" ..."
		Write-Msg $msg
		New-RsFolder -proxy $Proxy -RsFolder "/" -FolderName $ReportServerSubfolderTarget -ErrorAction SilentlyContinue
		$ret=Write-RsFolderContent -proxy $Proxy -RsFolder $ReportServerSubfolderTarget_withSlash -Recurse -Overwrite -Path $ReportTmpdir
	}
} # Reporting Services



# Purge and Truncate:
if ( $PurgeAllTransactionalData) {
	if ( $StoredProcCleanupTransactionalData.Length -eq 0 ) {
		$StoredProcCleanupTransactionalData="dbo.spDBA_utlCleanupTransactionalData"	# Standard SP
	}
	$Query = "exec " + $StoredProcCleanupTransactionalData + " @DoDataPurge=1"
	Write-Msg -Message "Purge all Transactional Data..."
	Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec
} else {
	# other Purge options:
	if ( $PurgeBOMLog) {
		$Query = "DELETE bld
	FROM BOM.ProcessBOMLogHeader blh
	JOIN BOM.ProcessBOMLogDetails bld ON 
	bld.[olnID]=blh.olnID 
	AND bld.[olnIDInstance]=blh.olnIDInstance 
	AND bld.[callID]=blh.callID 
	AND bld.[Iteration]=blh.Iteration 
	AND bld.[Step]=blh.Step 
	AND bld.[InstanceID]=blh.InstanceID
	WHERE pblhCreatedon < DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE()) -"  + $PurgeDaysToKeep + ") "
		Write-Msg -Message "Purge BOM Log Details..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec
		$Query = "DELETE FROM BOM.ProcessBOMLogHeader WHERE pblhCreatedOn < DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE()) - " + $PurgeDaysToKeep + ") "
		Write-Msg -Message "Purge BOM Log Header..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
	}
	if ( $PurgeInventoryTransactionsMaster) {
		$Query = "exec spAPP_utlPurgeInventoryTransactionsMaster @DaysToKeep=" + $PurgeDaysToKeep + ",@Archive=0"
		Write-Msg -Message "Purge Inventory Transactions..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
	}
	if ( $PurgeEngineeringDataMaster) {
		$Query = "exec spAPP_utlPurgeEngineeringDataMaster @DaysToKeep=" + $PurgeDaysToKeep + ",@Archive=0"
		Write-Msg -Message "Purge Engineering Datamaster..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
	}
	if ( $PurgeSystemMaster) {
		$Query = "exec spAPP_utlPurgeSystemMaster @DaysToKeep=" + $PurgeDaysToKeep + ",@DeleteBatchSize=100000"
		Write-Msg -Message "Purge System Master..."
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
	}
	if ( $TruncateTableList.Length -gt 0) {
		# create procedure to DELETE table in batches:
		Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -InputFile "$StandardSQLScriptsDir\Sha2020_spDBA_utlDeleteTableInBatches.sql" -QueryTimeout $SQLTimeoutSec -Verbose
	}
	$TruncateTableList.split(",")|foreach{
		$Tablename=$_.trim()
		if ( $Tablename.Length -gt 0) {
			Write-Msg -Message "Truncate table $Tablename including referencing tables..." # functions
            $SchemaName=$Tablename.Split(".")[0]
            $TablenameWoSchema=$Tablename.Split(".")[1]
            $GenerateScript= $ScriptFullPath + "\GenerateTruncateRecursive.ps1"
            $SqlFileTmp=$env:TMP + "\TruncateRecursive.sql"
            & $GenerateScript -DatabaseServer $TargetServer -DatabaseName $TargetInsightDB -SchemaName $SchemaName -Tablename $TableNameWoSchema >$SQLFileTmp
			Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -InputFile $SqlFileTmp -IncludeSqlUserErrors -OutputSqlErrors -QueryTimeout $SQLTimeoutSec -Verbose
		}
	}
}
if ( $ShrinkTargetInsightDB ) {
	$Query = "DBCC SHRINKDATABASE (0) WITH NO_INFOMSGS"
	Write-Msg -Message "Shrink Database $TargetInsightDB..."
	Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose
}
Write-Msg -Message "Shrink Transaction Log $TargetInsightDB..."
$Query = "SELECT name FROM sys.database_files WHERE type_desc = N'LOG'"
$result=Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query
$logfilename=$result[0]
$Query = "DBCC SHRINKFILE (N'" + $logfilename + "', 0, TRUNCATEONLY);"
$result=Invoke-sqlcmd -TrustServerCertificate -ServerInstance $TargetServer -Database $TargetInsightDB -Query $Query -QueryTimeout $SQLTimeoutSec -Verbose

if ( $BackupTargetDBAfterModifications ) {
	$BackupFile=$TempBackupPath + "\" + $TargetServer.Replace("\","_") + "_" + $TargetInsightDB + "_AfterCopyProdToTest.bak"
	if ( Test-Path $BackupFile ){
		Remove-item -Path $BackupFile
	}
	BackupDatabase -ServerInstance $TargetServer -Database $TargetInsightDB -BackupFile $BackupFile
	
	if ( $TargetIMOSDb.Length -gt 0 ) {
		$BackupFile=$TempBackupPath + "\" + $TargetServer.Replace("\","_") + "_" + $TargetIMOSDB + "_AfterCopyProdToTest.bak"
		if ( Test-Path $BackupFile ){
			Remove-item -Path $BackupFile
		}
		BackupDatabase -ServerInstance $TargetServer -Database $TargetIMOSDB -BackupFile $BackupFile
	}
}

# Start Inresponse (and other) Services
$InresponseServicesToRestart.split(",")|foreach{
	$hostname=$_.split(":")[0]
	$servicename=$_.split(":")[1]
	if ( ($hostname.Length -gt 0) -and ($servicename.Length -gt 0) ){
		Write-Msg -Message "Starting Service $servicename on host $hostname..."
		set-service -ComputerName $hostname -name $servicename -Status Running
	}
}

# Restart Inresponse Workstations:
$InresponseHostsToRestart.split(",")|foreach{
	$hostname=$_
	if ( ($hostname.Length -gt 0) ){
		Write-Msg -Message "Restarting host $hostname..."
		Restart-Computer -ComputerName $hostname -Force
	}
}

Write-Msg -Message "Copy Prod to Test Completed!"


