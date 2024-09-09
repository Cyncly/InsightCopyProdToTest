# SQL Server instance of source (PROD environment):
[string]$SourceServer		= "DBSRV1\PROD"

# Name of the source Insight database:	
[string]$SourceInsightDb 	= "Insight"

# Name of the source Construct database (optional):
[string]$SourceIMOSDb 		= "Insight_imos"

# path of folder for temporary backup (must be reachable from both SQL Servers!):
[string]$TempBackupPath	= "\\DBSRV2\backup_tmp"

# path of existing backup of Insight resp. IMOS database (optional)
# If these parameters are set, no new backup will be taken.
# Instead, the script will start with restoring from these backups:
[string]$ExistingInsightDBBackupFile = ""	# e.g. "\\DBSRV2\backup_tmp\insight.bak"
[string]$ExistingIMOSDBBackupFile = ""		# e.g. "\\DBSRV2\backup_tmp\insight_imos.bak"

# Check existence of Backup path resp. file. This must be set to false in case that the backup path
# is not accessible by the account and computer where the script runs:
[boolean]$CheckBackupPath=$true

# SQL Server instance of target (TEST environment)
[string]$TargetServer 		= "DBSRV2\TEST"	

# Name of the target Insight database:	
[string]$TargetInsightDb 	= "insight_test"

# Name of the target Construct database (optional):
[string]$TargetIMOSDb 		= "inSight_imos_test"
[string]$TargetIMOSDbXB		= ""											 

# Recovery Model of the target databases ("full" or "simple"):
[string]$TargetRecoveryModel 	= "simple"

# Skip Backup and Restore and run only modification scripts:
[boolean]$SkipBackupAndRestore=$false

# Take backup of target database(s) before overriding them (optional):
[boolean]$BackupTargetDBBeforeDrop=$false

# Check if target database has same Insight version as source:
[boolean]$CheckInsightVersionBeforeCopy=$true

# Domain users and groups or SQL Logins with db_owner rights for Insight database (comma-separated list)
[string]$DBOwners		= ""	# e.g. "MYDOMAIN\insightusers,MYDOMAIN\inresponse1"	

# Domain users and groups or SQL Logins with db_owner rights for IMOS/Construct database (comma-separated list)
[string]$DBOwnersIMOS	= $DBOwners	# by default use the same value as for Insight database

# Inresponse Windows Services to be restarted in Test environment (optional, comma-separated list)
# Syntax : HOSTNAME:SERVICENAME[,HOSTNAME:SERVICENAME]...
[string]$InresponseServicesToRestart	= ""	# e.g. "APPSRV:IRtest"	

# Inresponse Workstations to be rebooted in Test environment (e.g. for 2020 Construct) (optional, comma-separated list)
# Syntax : HOSTNAME[,HOSTNAME]...											
[string]$InresponseHostsToRestart	= ""	# e.g. "TESTWORKSTATION"	

# Inresponse User Mapping from Prod to Test environment (optional)
# This is only required if different Inresponse users are used in Test and Prod.
# Syntax : ('INRESPONSE_PROD1','INRESPONSE_TEST1')[,('INRESPONSE_PROD2','INRESPONSE_TEST2')]...
[string]$InResponseUserMapping		= "('','')" # empty mapping
# Example:
#$InResponseUserMapping		= "(N'DOMAIN\inresponse1',	N'DOMAIN\inresponse_test'),(N'DOMAIN\inresponse2',N'DOMAIN\inresponse_test')"

# Inresponse Users to Delete in Test environment (optional, comma-separated list)
# This is only required if different Inresponse users are used in Test and Prod.
# Syntax : (INRESPONSE_PROD1)[,(INRESPONSE_PROD2)]...
[string]$InresponseUsersToDelete	= "('')" # empty list
# Example:
#$InresponseUsersToDelete="(N'DOMAIN\inresponse1'),(N'DOMAIN\inresponse2')"

# Disable all Inresponse Monitors:
[boolean]$DisableAllMonitors = $true

# Restore entries in Inresponse.Services for Webservice Host services:
[boolean]$RestoreWebservices=$true

# Global replacements of file/directory paths in:
#	dbo.settings.setvalue
#	inResponse.ActionActionParameters.actpDefaultValue
#	inResponse.Trees.trFixedParameters
#	dbo.WorkCenter.wrcOutputPath
#  inResponse.Monitors.monConfiguration
#  inResponse.ActionEMails.AttachMaskSQL
#  inResponse.ActionReportServices.arsFileNameSQL
#  dbo.Machines.mcnOutputPath (Insight 12 and higher)
[string]$PathMappings	= "
	('\\srv-sql-01\ShareProd\',		'\\srv-sql01\ShareTest\')
	,('C:\ConstructData\',			'T:\ConstructData\')
	,('C:\InsightData\',				'C:\InsightDataTest\')
"



# Set specific Insight settings to fix values in Test:
# Syntax : (SETCATEGORY, SETSUBCATEGORY, SETNAME, SETVALUE),...
[string]$SpecificInsightSettings = "
	('inResponse', 	'Email',	'SMTPHost',	'smtp.nomail.local') 
	,('Interfacing', 	'2020FactoryNetwork',	'FNEnvironment',	'test')
	,('inResponse', 	'CSSeGeckoConnector',	'Port',	'8005')	-- Port 8004 is usually prod, 8005 test
	,('Interfacing', 	'CSSeGecko', 'WebServiceUrl', 'http://MYCSSSERVER:8005/egecko/egeckointerface') -- NEW version
	,('Insight',	'Global',	'Skin',	'13')  -- Skin 13 = 'Money Twins' (blue)
"

# Insert "X." in all Email Addresses to avoid sending emails from the test environment:
[string]$EmailAddressDomainPrefix="X."

# Set ALL Email addresses in the Insight database to a specific test email address:
# If this parameter is not empty, the parameter "$EmailAddressDomainPrefix" has no effect!
[string]$ReplaceAllEmailAddressesBy=""   # e.g. "InsightTest@mycompany.com" 

# 2020 Construct database modifications
#
# Replace CNC output directory in Machine attributes by new value of Insight setting for "IMORDER" folder ("inResponse.ImosSettings.BldrLstPath")
[boolean]$ReplaceCNCOutputDirectory=$true


##### Reporting Services (RS) parameters
#
# RS Webservices URL of source (PROD) and target environment (TEST):
[string]$ReportServerURISource="" # e.g. "http://DBSRV1/ReportServer"
[string]$ReportServerURITarget="" # e.g. "http://DBSRV2/ReportServer"

# RS Subfolder (optional):
[string]$ReportServerSubfolderSource=""		# e.g. "PROD"
[string]$ReportServerSubfolderTarget=""		# e.g. "TEST"

# Copy all Reports from Source to Target ?  $true/$false
[boolean]$CopyReportServerSubfolder=$false
# Delete all Reports from Target Subfolder before copying? (only relevant if $CopyReportServerSubfolder = $true) # $true/$false
[boolean]$DeleteReportServerSubfolderTarget=$false

# Printer mapping.
# Printer names that are 'like' the left value are set to the right value.
# By using wildcards in the left value it is possible to map many printers to one.
[string]$PrinterMapping = "
('\\srv-prt01\IM350_Lager', '\\srv-dev\Lager') --Map specific printer 1:1
,('\\srv-prt01\%', '\\srv-prt01\Testprinter') -- Map all printers to a specific test printer
"

##### Options to reduce size of the Target Insight DB:
#
# Run "Purge System Master" procedure (reduce ApplicationLog, ActionQueueLog,...):
[boolean]$PurgeSystemMaster=$false

# Reduce "BOM Log" tables (BOMLogHeader, BOMLogDetails):
[boolean]$PurgeBOMLog=$false

# Run "Purge Inventory Transactions Master" procedure:
[boolean]$PurgeInventoryTransactionsMaster=$false

# Run "Purge Engineering Datamaster" procedure:
[boolean]$PurgeEngineeringDataMaster=$false

# Maximum age of data to keep in purged tables (only applies to the above Purge operations):
[int]$PurgeDaysToKeep=7 

# List of tables to be emptied completely:
# [string]$TruncateTableList="dbo.ItemAttachments
		# ,dbo.ItemCNCProgramAttachments
		# ,dbo.OrderAttachments
		# ,dbo.OrderitemCNCProgramAttachments
		# ,dbo.OrderLineAttachments
		# ,dbo.PurchaseOrderAttachments
		# ,dbo.PurchaseOrderLineAttachments
		# ,dbo.VendorInvoiceAttachments
		# ,inResponse.ActionQueueAttachments
		# ,inResponse.ActionQueue
		# ,Install.InstallOrderAttachments
		# ,Install.InstallOrderJobAttachments"

# Delete all transactional data (if this option is used, it overrides all above "purge" parameters):
[boolean]$PurgeAllTransactionalData=$false
# SP to be used for deleting transactional data (if empty, the Standard SP dbo.spDBA_utlCleanupTransactionalData is used.)
[string]$StoredProcCleanupTransactionalData="" # e.g. "Sha2020.spDBA_utlCleanupTransactionalData" in case that custom tables need to be handled also.

# Shrink target database. Only valid if any "truncate" or "purge" options are provided
[boolean]$ShrinkTargetInsightDB=$false

# Create backup(s) after modifications
[boolean]$BackupTargetDBAfterModifications=$false

# Timeout for Restore and other SQL scripts (in seconds)
[int]$SQLTimeoutSec	= 14400

######## SMTP settings for sending logfile to an Administrator
#
# Get SMTP server, port, authentication settings from Insight Source DB:
[boolean]$UseSMTPSettingFromSourceDB=$false

# Alternatively, set SMTP server settings here:
# SMTP Server name or IP address (optional):
[string]$SMTPHost	= ""	
# SMTP Port:
[int]$SMTPPort		= 25
# Use SSL for SMTP ($true/$false):
[boolean]$SMTPUseSSL	= $false
# Username for SMTP authentication (optional):
[string]$SMTPUsername	= ""
# Password for SMTP authentication (optional):
[string]$SMTPPassword	= ""

# Sender address. Usually this must match the customer's mail domain.
# In case of authentication, this usually must match the user's mail address:
[string]$SMTPMailFrom		= "CopyProdToTest@mydomain.com"
# Mail recipient(s) - separated by comma:
[string]$SMTPMailTo		= "My.Admin@mydomain.com,MyBoss@mydomain.com"

												
												



