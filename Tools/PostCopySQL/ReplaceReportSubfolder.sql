-- Replacement of Reporting Services subfolders in actions
--
-- Parameters are defined in config.ps1!
DECLARE @ReplacePaths TABLE (OldStr NVARCHAR(MAX), NewStr NVARCHAR(MAX))
INSERT INTO @ReplacePaths VALUES 
	('/$ReportServerSubfolderSource',		'/$ReportServerSubfolderTarget')

------------------------------------------------------
-- Do Updates

-- Inresponse ActionReportServiceDefinitions
UPDATE arsd SET arsdPath = REPLACE(arsdPath,a.OldStr,a.NewStr)
OUTPUT DELETED.arsdPath arsdPath_OLD, INSERTED.arsdPath arsdPath_NEW, INSERTED.arsdFileName
FROM @ReplacePaths a
JOIN inResponse.ActionReportServiceDefinitions arsd ON arsd.arsdPath LIKE '%'+a.OldStr+'%'
WHERE a.OldStr <> a.NewStr


