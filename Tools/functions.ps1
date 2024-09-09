
function Write-Msg {
     [CmdletBinding()]
     param(
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [string]$Message,
 
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [ValidateSet('INFO','WARNING','ERROR')]
         [string]$Severity = 'INFO'
     )

	$myMessage=(date -Format "yyyy-MM-dd HH:mm:ss") + ":" + $Severity + ": " + $Message
	Write-Host $myMessage
 }

function Import-SQLServerModule {

	try { 
		#import-module -Name SQLPS -EA Stop -DisableNameChecking #-Verbose
		import-module -Name SQLServer -EA Stop
	} 
	catch {
			Write-Msg -Message "SQLServer Module not loaded!" -Severity ERROR
			Write-Msg -Message "Install the Powershell module SQLServer first! See 'Insight_CopyProdToTest_InstallationGuide.pdf' for instructions."
			exit 1
	}
}


function BackupDatabase {
	[CmdletBinding()]
	param(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ServerInstance,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Backupfile
	)
	
	Write-msg -Message "Starting Backup Database $ServerInstance.$Database to $Backupfile..."
	try {
		Backup-SqlDatabase -ServerInstance $ServerInstance -Database $Database -BackupFile $Backupfile -Initialize -CopyOnly -CompressionOption "On" -TrustServerCertificate #-Verbose
	}
	catch {
		$err = $_.Exception
		$errmsg = $err.Message
		while( $err.InnerException ) {
			$err = $err.InnerException
			$errmsg = $errmsg + "|" + $err.Message
		}
		Write-Msg -Message $errmsg -Severity ERROR
		Write-msg -Message "Backup aborted!"-Severity ERROR
		exit 1
	}
	Write-msg -Message "Backup completed."
}

