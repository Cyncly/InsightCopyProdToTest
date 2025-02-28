-- Restore Inresponse Webservice entries

BEGIN
	DECLARE	@svcHostName [nvarchar](50)
	DECLARE	@svcServiceName [nvarchar](256)
	DECLARE	@usrLogin [nvarchar](100)
	DECLARE	@istID [tinyint]
	DECLARE	@svcDeploymentConfiguration [xml] 

	DECLARE cx CURSOR FOR
	SELECT
	[svcHostName]
	,[svcServiceName]
	,[usrLogin]
	,[istID]
	,[svcDeploymentConfiguration]
	FROM [master].[dbo].[TempServices]
	WHERE [svcDbname] = DB_NAME()

	OPEN cx
	FETCH NEXT FROM cx INTO 
	@svcHostName
	,@svcServiceName
	,@usrLogin
	,@istID
	,@svcDeploymentConfiguration

	WHILE @@FETCH_STATUS = 0
	BEGIN
		exec inResponse.spMrgServices @svcHostName=@svcHostName,@svcServiceName=@svcServiceName,@usrID=default,@usrLogin=@usrLogin,@istID=@istID,@svcDeploymentConfiguration=@svcDeploymentConfiguration output
		FETCH NEXT FROM cx INTO 
		@svcHostName
		,@svcServiceName
		,@usrLogin
		,@istID
		,@svcDeploymentConfiguration
	END

	CLOSE cx
	DEALLOCATE cx

END

