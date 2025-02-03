-- deletes Inresponse User
--
-- Parameters are defined in config.ps1!

DECLARE @DeleteInResponseUsers TABLE (OldUser NVARCHAR(MAX))
INSERT INTO @DeleteInResponseUsers VALUES 
	$InresponseUsersToDelete


------------------------------------------------------
-- Do Updates
DECLARE @UserList table (usrName0 nvarchar(50), usrID integer)
IF EXISTS ( SELECT 1 FROM @DeleteInResponseUsers WHERE LEN(OldUser) > 0 )
BEGIN
	DELETE trg
	FROM inResponse.ServiceUserActionTypes trg
		JOIN dbo.UserList usr ON usr.usrID = trg.usrID
		JOIN @DeleteInresponseUsers ciu ON usr.usrLogin = ciu.OldUser

	DELETE trg
	FROM inResponse.ServiceUserMonitors trg
		JOIN dbo.UserList usr ON usr.usrID = trg.usrID
		JOIN @DeleteInresponseUsers ciu ON usr.usrLogin = ciu.OldUser

	DELETE trg
	FROM inResponse.Services trg
		JOIN dbo.UserList usr ON usr.usrID = trg.usrID
		JOIN @DeleteInresponseUsers ciu ON usr.usrLogin = ciu.OldUser

	DELETE trg
	FROM inResponse.ServiceUsers trg
		JOIN dbo.UserList usr ON usr.usrID = trg.usrID
		JOIN @DeleteInresponseUsers ciu ON usr.usrLogin = ciu.OldUser
END
