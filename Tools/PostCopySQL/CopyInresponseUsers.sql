-- creates logins as inSight user
-- creates logins as inResponse user
-- copies all action types from a reference inResponse user to the respective user
--
-- Parameters are defined in config.ps1!
DECLARE @CopyInResponseUsers TABLE (OldUser NVARCHAR(MAX), NewUser NVARCHAR(MAX))
INSERT INTO @CopyInResponseUsers VALUES 
	$InResponseUserMapping

------------------------------------------------------
-- Do Updates
DECLARE @UserList table (usrName0 nvarchar(50), usrID integer)
IF EXISTS ( SELECT 1 FROM @CopyInResponseUsers WHERE LEN(OldUser) > 0 )
BEGIN
	MERGE dbo.Userlist AS trg
	USING
		( SELECT DISTINCT NewUser FROM @CopyInresponseUsers
		  WHERE LEN(NewUser) > 0
		) AS src
	ON (trg.usrLogin = src.NewUser)
	WHEN NOT MATCHED
	THEN
		INSERT 
		(usrName, usrLogin) 
		
		VALUES
		(src.NewUser , src.NewUser)
	OUTPUT inserted.usrName, inserted.usrID INTO @userList
	OUTPUT inserted.usrName, inserted.usrID;

	IF EXISTS (SELECT * from @UserList)
	BEGIN
		MERGE dbo.UserGroupUserList as trg
		USING
			(SELECT  usrID FROM @userList) AS src (usrid)
		ON (trg.usrid = src.usrid)
		WHEN NOT MATCHED
		THEN
			INSERT 
			(usrID, ugrID,IsTeamLeader) 
			VALUES
			(src.usrID , 6,1);
	END

	MERGE inResponse.ServiceUsers trg
	USING(
		SELECT DISTINCT usrID FROM dbo.UserList usr
		JOIN @CopyInresponseUsers ciu ON usr.usrLogin =  ciu.NewUser
	)src
	ON (trg.usrID = src.usrID)
	WHEN NOT MATCHED BY TARGET THEN
		INSERT VALUES (src.usrID);

	MERGE inResponse.ServiceUserActionTypes trg
	USING
	(
		SELECT   su.acttID
				,usr_new.usrID usrID
				,su.[Enabled]
				,usr.usrLogin
				,act.acttDescription
		FROM inResponse.ServiceUserActionTypes su
		JOIN dbo.UserList usr ON usr.usrID = su.usrID
		JOIN @CopyInresponseUsers ciu ON usr.usrLogin = ciu.OldUser
		JOIN dbo.UserList usr_new ON usr_new.usrLogin = ciu.NewUser
		JOIN inResponse.ActionTypes act ON act.acttID = su.acttID
	)src
	ON (	trg.acttID = src.acttID
		AND trg.usrID = src.usrID)	
	WHEN NOT MATCHED BY TARGET THEN
		INSERT VALUES( src.usrID, src.acttID, src.[Enabled])
		OUTPUT src.usrlogin,src.acttDescription,src.[enabled];

	MERGE inResponse.ServiceUserMonitors trg
	USING
	(
		SELECT   usr_new.usrID usrID
				,su.[monID]
				,su.[Enabled]
				,usr.usrLogin
				,mon.monDescription
		FROM inResponse.ServiceUserMonitors su
		JOIN dbo.UserList usr ON usr.usrID = su.usrID
		JOIN @CopyInresponseUsers ciu ON usr.usrLogin = ciu.OldUser
		JOIN dbo.UserList usr_new ON usr_new.usrLogin = ciu.NewUser
		JOIN inResponse.Monitors mon ON mon.monID = su.monID
	)src
	ON (	trg.monID = src.monID
		AND trg.usrID = src.usrID)	
	WHEN NOT MATCHED BY TARGET THEN
		INSERT VALUES( src.usrID, src.monID, src.[Enabled])
		OUTPUT src.usrlogin,src.monDescription,src.[enabled];
		
END
