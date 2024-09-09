
INSERT INTO [master].[dbo].[TempServices] (
[svcDbname]
,[svcHostName]
,[svcServiceName]
,[usrLogin]
,[istID]
,[svcDeploymentConfiguration]
) SELECT
	DB_NAME()
	,s.svcHostname
	,s.svcServicename
	,u.usrLogin
	,s.istID
	,s.svcDeploymentConfiguration
FROM inresponse.Services s
JOIN dbo.UserList u ON u.usrID=s.usrID
WHERE s.istID=2

