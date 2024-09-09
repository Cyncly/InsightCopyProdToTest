-- $Id: ModifySpecificSettings.sql 12 2022-02-14 14:00:03Z beckma $ --
-- Set specific Insight settings to fix values.

-- Parameters are defined in config.ps1!
DECLARE @settings TABLE (setCategory nvarchar(25) NOT NULL, setSubCategory nvarchar(128) NOT NULL, setName nvarchar(128) NOT NULL, setValueNew nvarchar(255))
INSERT INTO @settings VALUES 
	$SpecificInsightSettings


------------------------------------------------------
-- Do Updates

-- Set global setting
UPDATE s SET setValue = sn.setValueNew
OUTPUT INSERTED.setCategory, INSERTED.setSubCategory, INSERTED.setName, DELETED.setValue setValue_OLD, INSERTED.setValue setValue_NEW
FROM @settings sn
JOIN dbo.Settings s ON s.setCategory = sn.setCategory
	AND s.setSubCategory = sn.setSubCategory
	AND s.setName = sn.setName
	AND (s.setValue <> sn.setValueNew OR s.setValue IS NULL)
	
-- Remove User overrides
DELETE u
output deleted.ustId, s.setCategory, s.setSubCategory, s.setName , DELETED.ustValue ustValue_REMOVED, DELETED.ustBigvalue ustBigvalue_REMOVED
FROM dbo.Usersettings u
JOIN dbo.Settings s ON s.setId = u.setID
JOIN @settings p ON p.setCategory = s.setCategory AND p.setSubCategory = s.setSubCategory AND p.setName = s.setName

