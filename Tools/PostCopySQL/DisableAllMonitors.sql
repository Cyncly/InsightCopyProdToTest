-- Disable All Monitors

IF $DisableAllMonitors = 1
BEGIN
	UPDATE sum SET Enabled=0
	OUTPUT m.monDescription, DELETED.Enabled Enabled_OLD, INSERTED.Enabled Enabled_NEW
	FROM  [inResponse].[ServiceUserMonitors] sum
	JOIN [inResponse].[Monitors] m ON m.monID=sum.monID
	WHERE 1=1
END





