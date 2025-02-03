-- Delete Services of Type 1=Standard and 5=Backend and their child services:

IF OBJECT_ID(N'inresponse.ServiceServiceNotifications', N'U') IS NOT NULL
	DELETE FROM inResponse.ServiceServiceNotifications WHERE svcID IN (SELECT svcID FROM inresponse.Services WHERE istID IN (1,5))
DELETE FROM inresponse.Services WHERE svcIDParent IN (SELECT svcID FROM inresponse.Services WHERE istID IN (1,5))
DELETE FROM inresponse.Services WHERE istID IN (1,5)

