
Param(
    [string]$DatabaseServer
	,[string]$DatabaseName
    ,[string]$SchemaName
    ,[string]$TableName
	);


function GenerateCreateFKForTable ([string]$TableSchema, [string]$TableName)
{
    [string]$SQLCodeLocal=""
    [string]$SQLCodeSub=""

    $FullTablename="$TableSchema.$TableName"
    $FullTablename=$FullTablename.tolower()
    if ( ! $TableList.Contains($FullTablename) ) {
        $TableList.Add($FullTablename)
        $table= $tables|where { $_.schema -eq $TableSchema -and $_.name -eq $TableName }
        if ( $table ){
            $ReferencingForeignKeys=$table.EnumForeignKeys()
            if ( $ReferencingForeignKeys.Rows.Count -gt 0) {
                # Other tables refering to this table!
                foreach ($row in $ReferencingForeignKeys.Rows) {
                    $reftable= $tables|where { $_.schema -eq $row.table_schema -and $_.name -eq $row.table_name }
                    $fk=$reftable.ForeignKeys|where { $_.name -eq $row.name }
                    $scriptingCreateOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
				    $scriptingCreateOptions.IncludeDatabaseContext = $false
				    $scriptingCreateOptions.IncludeHeaders = $false
				    $scriptingCreateOptions.IncludeIfNotExists = $true
				    $scriptingCreateOptions.DriForeignKeys = $true
				    $SQLCodeLocal+=($fk.Script($scriptingCreateOptions) -join "`nGO`n`n")+"`nGO`n`n"
                    $SQLCodeTemp=GenerateCreateFKForTable $row.table_schema $row.table_name
                    $SQLCodeSub+="`n"+$SQLCodeTemp
                }
            }

            $SQLCodeTotal=$SQLCodeSub+"`n"+$SQLCodeLocal
        } else {
            Write-Host "Table $FullTablename not found!"
        }
    }
    return $SQLCodeTotal
}

function GenerateDropFKForTable ([string]$TableSchema, [string]$TableName)
{
    [string]$SQLCodeLocal=""
    [string]$SQLCodeSub=""

    $FullTablename="$TableSchema.$TableName"
    $FullTablename=$FullTablename.tolower()
    if ( ! $TableList.Contains($FullTablename) ) {
        $TableList.Add($FullTablename)
        $table= $tables|where { $_.schema -eq $TableSchema -and $_.name -eq $TableName }
        if ( $table ){
            $ReferencingForeignKeys=$table.EnumForeignKeys()
            if ( $ReferencingForeignKeys.Rows.Count -gt 0) {
                # Other tables refering to this table!
                foreach ($row in $ReferencingForeignKeys.Rows) {
                    $reftable= $tables|where { $_.schema -eq $row.table_schema -and $_.name -eq $row.table_name }
                    $fk=$reftable.ForeignKeys|where { $_.name -eq $row.name }
                    $scriptingDropOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
				    $scriptingDropOptions.IncludeIfNotExists = $true
				    $scriptingDropOptions.IncludeHeaders = $false
				    $scriptingDropOptions.ScriptDrops = $true
				    $SQLCodeLocal+=($fk.Script($scriptingDropOptions) -join "`nGO`n`n")+"`nGO`n`n"
                    $SQLCodeTemp=GenerateDropFKForTable $row.table_schema $row.table_name
                    $SQLCodeSub+="`n"+$SQLCodeTemp
                }
            }
            $SQLCodeTotal=$SQLCodeSub+"`n"+$SQLCodeLocal
        } else {
            Write-Host "Table $FullTablename not found!"
        }
    }
    return $SQLCodeTotal
}

function GenerateTruncateForTable ([string]$TableSchema, [string]$TableName)
{
    [string]$SQLCodeLocal=""
    [string]$SQLCodeSub=""

    $FullTablename="$TableSchema.$TableName"
    $FullTablename=$FullTablename.tolower()
    if ( ! $TableList.Contains($FullTablename) ) {
        $TableList.Add($FullTablename)
        $table= $tables|where { $_.schema -eq $TableSchema -and $_.name -eq $TableName }
        if ( $table ){
            $ReferencingForeignKeys=$table.EnumForeignKeys()
            if ( $ReferencingForeignKeys.Rows.Count -gt 0) {
                # Other tables refering to this table! -> Delete those first!
                foreach ($row in $ReferencingForeignKeys.Rows) {
                    $SQLCodeTemp=GenerateTruncateForTable $row.table_schema $row.table_name
                    $SQLCodeSub+="`n"+$SQLCodeTemp
                }
            }
            $SQLCodeLocal="TRUNCATE TABLE ["+$TableSchema+"].["+$TableName+"]`nGO`n"
            $SQLCodeTotal=$SQLCodeSub+"`n"+$SQLCodeLocal
        } else {
            Write-Host "Table $FullTablename not found!"
        }
    }
    return $SQLCodeTotal
}


$database=Get-SqlDatabase -name $DatabaseName -ServerInstance $DatabaseServer
$tables=$database.tables

$TableList = New-Object System.Collections.Generic.List[System.Object]   # List of tables for recursion check
$SQLCodeBefore=GenerateDropFKForTable $schemaname $tablename
$TableList = New-Object System.Collections.Generic.List[System.Object]   # reset list
$SQLCode=GenerateTruncateForTable $schemaname $tablename
$TableList = New-Object System.Collections.Generic.List[System.Object]   # reset list
$SQLCodeAfter=GenerateCreateFKForTable $schemaname $tablename

$SQLCodeBefore
$SQLCode
$SQLCodeAfter

