
Param(
	[string]$Config		# subdirectory containing config file and custom SQL Scripts
	,[int]$KeepLogfileCount		# Number of versions for each logfile to keep.
	);

################### main #################
Set-Location $PSHOME
$ScriptFullPath = Split-Path $MyInvocation.MyCommand.Path
$BasePath = Split-Path -Path $ScriptFullPath
$FunctionsScript= $ScriptFullPath + "\functions.ps1"
. $FunctionsScript

# Check log subdirectory
$logdir=$BasePath + "\log"

if ( Test-Path $logdir ){
	# OK!
} else {
	Write-msg -Message "Directory $logdir not found!" -Severity ERROR
	exit 1
}

foreach ($logfileprefix in "CopyProdToTest_","SendLogfile_") {
	# Find *_XXXX.log and rename it by appending modification time to the name :
	$Filter=$logfileprefix+$Config+".log"
	Get-ChildItem -Path $logdir -Filter $Filter | select-Object name,LastWriteTime,Fullname | foreach{
		#$Filename=$_.name
		#$FileTimestamp=$_.LastWriteTime
		$TimeStr=$_.LastWriteTime.ToString("yyyyMMddHHmm")
		$NewFilename=$_.name + "." + $TimeStr
		Rename-Item -Path $_.Fullname -NewName $NewFilename
	}

	# Look for "too" old logfiles and delete them:

	$Filter=$logfileprefix+"*.log.*"
	Get-Childitem -Path $logdir -Filter $Filter | Sort-Object -Property LastWriteTime -Descending | Select-Object -Skip $KeepLogfileCount | Remove-Item
}

