-- $Id: ReplaceReportURLs.sql 12 2022-02-14 14:00:03Z beckma $ --
-- Global replacements of Reporting Services URLs
--
-- Parameters are defined in config.ps1!
DECLARE @ReplaceURLs TABLE (OldUrl NVARCHAR(MAX), NewUrl NVARCHAR(MAX))
INSERT INTO @ReplaceURLs VALUES 
	('$ReportServerURISource',		'$ReportServerURITarget')


------------------------------------------------------
-- Do Updates

UPDATE r SET arsServerURL = REPLACE(arsServerURL,u.OldUrl,u.NewUrl)
OUTPUT INSERTED.orgID, INSERTED.actID, a.actDescription, DELETED.arsServerURL arsServerURL_OLD, INSERTED.arsServerURL arsServerURL_NEW
FROM @ReplaceURLs u
JOIN inresponse.ActionReportServices r ON r.arsServerURL LIKE '%'+u.OldUrl+'%'
JOIN inresponse.Actions a ON a.actID = r.actID
WHERE LEN(u.OldUrl) > 0
AND u.OldUrl <> u.NewUrl

-- Setting
UPDATE s SET setValue = REPLACE(setValue,u.OldUrl,u.NewUrl)
OUTPUT INSERTED.setCategory,INSERTED.setsubcategory,INSERTED.setname,DELETED.setvalue setValue_OLD,INSERTED.setvalue setValue_NEW
FROM @ReplaceURLs u
JOIN dbo.Settings s ON s.setValue LIKE '%'+u.OldUrl+'%'
WHERE LEN(u.OldUrl) > 0
AND u.OldUrl <> u.NewUrl
