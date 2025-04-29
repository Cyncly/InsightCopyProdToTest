--Delete Database Users

-- Parameters are defined in config.ps1!
DECLARE @Principalname nvarchar(max)
DECLARE @DeleteDBUsers TABLE (OldUser NVARCHAR(MAX))
INSERT INTO @DeleteDBUsers VALUES 
	$DBUsersToDelete

DECLARE @SchemaName nvarchar(100)
		,@SqlStm nvarchar(MAX)
		,@Servicename nvarchar(MAX)

DECLARE schema_c CURSOR LOCAL FOR 
SELECT s.name FROM sys.schemas s
JOIN sys.database_principals p ON p.principal_id=s.principal_id
JOIN @DeleteDBUsers d ON d.OldUser = p.name

OPEN schema_c;
FETCH NEXT FROM schema_c INTO @SchemaName;
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @SqlStm = N'ALTER AUTHORIZATION ON SCHEMA::['+ @SchemaName +'] TO [dbo]'
	exec sp_executesql @SqlStm
	FETCH NEXT FROM schema_c INTO @SchemaName;
END

DECLARE service_c CURSOR LOCAL FOR 
SELECT s.name FROM sys.services s
JOIN sys.database_principals p ON p.principal_id=s.principal_id
JOIN @DeleteDBUsers d ON d.OldUser = p.name

OPEN service_c;
FETCH NEXT FROM service_c INTO @Servicename;
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @SqlStm = N'ALTER AUTHORIZATION ON SERVICE::['+ @Servicename +'] TO [dbo]'
	exec sp_executesql @SqlStm
	FETCH NEXT FROM service_c INTO @Servicename;
END

DECLARE OldUser_c CURSOR LOCAL FOR
SELECT OldUser FROM @DeleteDBUsers

OPEN OldUser_c;
FETCH NEXT FROM OldUser_c INTO @PrincipalName
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @SqlStm=N'DROP SCHEMA IF EXISTS ['+@PrincipalName+']'
	SELECT @SqlStm
	exec sp_executesql @SqlStm

	SET @SqlStm=N'DROP USER IF EXISTS ['+@PrincipalName+']'
	exec sp_executesql @SqlStm
	FETCH NEXT FROM OldUser_c INTO @PrincipalName;
END

