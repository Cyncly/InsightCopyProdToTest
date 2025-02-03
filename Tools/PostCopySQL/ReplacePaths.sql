-- Global replacements of file/directory paths in:
--	dbo.settings.setvalue
--  inResponse.Actions.actFixedParameters
--	inResponse.ActionActionParameters.actpDefaultValue
--	inResponse.Trees.trFixedParameters
--	dbo.WorkCenter.wrcOutputPath
--	dbo.OrderItemCNCPrograms
--	dbo.OrderItemCNCProgramAttachments
--	dbo.ItemCNCPrograms
--	dbo.ItemCNCProgramAttachments
--  inResponse.Monitors.monConfiguration
--  inResponse.ActionEMails.AttachMaskSQL
--  inResponse.ActionReportServices.arsFileNameSQL
--  dbo.Machines.mcnOutputPath (Insight 12 and higher)
--  dbo.MachinePostSettings.mpssettings (Insight 13 and higher)
--
-- Parameters are defined in config.ps1!
DECLARE @ReplacePaths TABLE (OldStr NVARCHAR(MAX), NewStr NVARCHAR(MAX))
INSERT INTO @ReplacePaths VALUES 
	$PathMappings
------------------------------------------------------
-- Do Updates

-- Settings
UPDATE s SET setValue = REPLACE(setValue,a.OldStr,a.NewStr)
OUTPUT INSERTED.setCategory,INSERTED.setsubcategory,INSERTED.setname,DELETED.setvalue setValue_OLD,INSERTED.setvalue setValue_NEW
FROM @ReplacePaths a
JOIN dbo.Settings s ON s.setValue LIKE '%'+a.OldStr+'%'

-- Default Action parameters
UPDATE actp SET actpDefaultValue = REPLACE(actpDefaultValue,a.OldStr,a.NewStr)
OUTPUT INSERTED.orgid,INSERTED.actid,INSERTED.parId,DELETED.actpDefaultValue actpDefaultValue_OLD,INSERTED.actpDefaultValue actpDefaultValue_NEW
FROM @ReplacePaths a
JOIN inResponse.ActionActionParameters actp ON actp.actpDefaultValue LIKE '%'+a.OldStr+'%'

-- Action Fixed Parameters
UPDATE act SET actFixedParameters = REPLACE(CAST(actFixedParameters AS NVARCHAR(MAX)),a.OldStr,a.NewStr)
OUTPUT INSERTED.actid,INSERTED.actDescription,DELETED.actFixedParameters actFixedParameters_OLD,INSERTED.actFixedParameters actFixedParameters_NEW
FROM @ReplacePaths a
JOIN inResponse.Actions act ON CAST( act.actFixedParameters AS NVARCHAR(max)) LIKE '%'+a.OldStr+'%'

--FAP in action trees / status rules
UPDATE tr SET
trFixedParameters=CAST(REPLACE(CAST(tr.trFixedParameters AS NVARCHAR(MAX)),a.OldStr,a.NewStr) AS XML)
OUTPUT 
INSERTED.orgID
,INSERTED.atrID
,INSERTED.actID
,INSERTED.actIDInstance
,INSERTED.trDescription
,DELETED.trFixedParameters trFixedParameters_OLD
,INSERTED.trFixedParameters trFixedParameters_NEW
FROM @ReplacePaths a
JOIN inResponse.Trees tr ON CAST(tr.trFixedParameters AS NVARCHAR(MAX)) LIKE '%'+a.OldStr+'%' 

-- Workcenter Output Paths
UPDATE wrc SET wrcOutputPath = REPLACE(wrcOutputPath,a.OldStr,a.NewStr)
OUTPUT INSERTED.wrcID, INSERTED.wrcShortDesc, INSERTED.wrcDescription, DELETED.wrcOutputPath wrcOutputPath_OLD, INSERTED.wrcOutputPath wrcOutputPath_NEW
FROM @ReplacePaths a
JOIN dbo.WorkCenter wrc ON wrc.wrcOutputPath LIKE '%'+a.OldStr+'%'

-- OrderItem CNC Programs
UPDATE cnc SET oriCNCProgOutputPath = REPLACE(oriCNCProgOutputPath,a.OldStr,a.NewStr)
FROM @ReplacePaths a
JOIN dbo.OrderItemCNCPrograms cnc ON cnc.oriCNCProgOutputPath LIKE '%'+a.OldStr+'%'

-- OrderItem CNC Program Attachments
UPDATE cnc SET oriCNCFileName = REPLACE(oriCNCFileName,a.OldStr,a.NewStr)
FROM @ReplacePaths a
JOIN [dbo].[OrderItemCNCProgramAttachments] cnc ON cnc.oriCNCFileName LIKE '%'+a.OldStr+'%'

-- Item CNC Programs
UPDATE cnc SET itmpCNCProgOutputPath = REPLACE(itmpCNCProgOutputPath,a.OldStr,a.NewStr)
FROM @ReplacePaths a
JOIN dbo.ItemCNCPrograms cnc ON cnc.itmpCNCProgOutputPath LIKE '%'+a.OldStr+'%'

-- Item CNC Program Attachments
UPDATE cnc SET itmCNCFileName = REPLACE(itmCNCFileName,a.OldStr,a.NewStr)
FROM @ReplacePaths a
JOIN [dbo].[ItemCNCProgramAttachments] cnc ON cnc.itmCNCFileName LIKE '%'+a.OldStr+'%'

-- Inresponse Monitors
UPDATE mon SET monConfiguration = REPLACE(monConfiguration,a.OldStr,a.NewStr)
OUTPUT INSERTED.monCode, DELETED.monConfiguration monConfiguration_OLD, INSERTED.monConfiguration monConfiguration_NEW
FROM @ReplacePaths a
JOIN inResponse.Monitors mon ON mon.monConfiguration LIKE '%'+a.OldStr+'%'

-- Inresponse ActionEMails
UPDATE act SET AttachMaskSQL = REPLACE(AttachMaskSQL,a.OldStr,a.NewStr)
OUTPUT DELETED.AttachMaskSQL AttachMaskSQL_OLD, INSERTED.AttachMaskSQL AttachMaskSQL_NEW
FROM @ReplacePaths a
JOIN inResponse.ActionEMails act ON act.AttachMaskSQL LIKE '%'+a.OldStr+'%'


-- Inresponse ActionReportServices
UPDATE act SET arsFileNameSQL = REPLACE(arsFileNameSQL,a.OldStr,a.NewStr)
OUTPUT DELETED.arsFileNameSQL arsFileNameSQL_OLD, INSERTED.arsFileNameSQL arsFileNameSQL_NEW
FROM @ReplacePaths a
JOIN inResponse.ActionReportServices act ON act.arsFileNameSQL LIKE '%'+a.OldStr+'%'

-- CNC Machine output paths
IF EXISTS (SELECT * FROM sys.all_columns WHERE OBJECT_NAME(object_id)=N'Machines' AND name=N'mcnOutputPath')
	UPDATE m SET mcnOutputPath = REPLACE(mcnOutputPath, a.OldStr, a.NewStr)
	OUTPUT DELETED.mcnOutputPath mcnOutputPath_OLD, INSERTED.mcnOutputPath mcnOutputPath_NEW
	FROM @ReplacePaths a
	JOIN dbo.Machines m ON m.mcnOutputPath LIKE '%'+a.OldStr+'%'
	
-- CNC Machine Post settings
IF EXISTS (SELECT * FROM sys.all_columns WHERE OBJECT_NAME(object_id)=N'MachinePostSettings' AND name=N'mpssettings')
	UPDATE m SET mpssettings = REPLACE(mpssettings, a.OldStr, a.NewStr)
	OUTPUT DELETED.mpssettings mpssettings_OLD, INSERTED.mpssettings mpssettings_NEW
	FROM @ReplacePaths a
	JOIN dbo.MachinePostSettings m ON m.mpssettings LIKE '%'+a.OldStr+'%'
	


