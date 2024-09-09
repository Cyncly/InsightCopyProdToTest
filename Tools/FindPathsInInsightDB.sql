DECLARE @SearchStringValues TABLE ( SearchStr NVARCHAR(30))
INSERT INTO @SearchStringValues VALUES
('%@%')	-- email address?
,('_:/%')		-- Local path?
,('_:\%')		-- Local path?
,('%:/%')		-- URL?
,('\\%')		-- UNC path
,('//%'	)	-- UNC path
,('%.%.%')	-- Full qualified hostname or IP-address

DECLARE @SearchStringSetnames TABLE ( SearchStr NVARCHAR(30))
INSERT INTO @SearchStringSetnames VALUES
('%URL%')
,('%path%')
,('%host%')
,('%database%')
,('%environment%')

select s.setCategory,s.setSubCategory,s.setName,s.setDescription,s.setValue from dbo.settings s
JOIN  @SearchStringValues v ON s.setValue LIKE v.SearchStr
WHERE s.setValue NOT LIKE 'http://www.nationsonline.org/%'
AND s.setValue NOT LIKE 'http://unicode.org/%'
UNION
select s.setCategory,s.setSubCategory,s.setName,s.setDescription,s.setValue from dbo.settings s
JOIN  @SearchStringSetnames v ON s.setName LIKE v.SearchStr
WHERE s.setValue NOT LIKE 'http://www.nationsonline.org/%'
AND s.setValue NOT LIKE 'http://unicode.org/%'
ORDER BY s.setCategory,s.setSubCategory,s.setName

select actp.orgid, actp.actID, a.actDescription ,actp.actpDefaultValue from inResponse.ActionActionParameters actp
JOIN inresponse.Actions a ON a.orgID = actp.orgID AND a.actID = actp.actID
JOIN  @SearchStringValues v ON actp.actpDefaultValue LIKE v.SearchStr
WHERE actp.actpDefaultValue NOT LIKE '//2020technologies.com/SSB/%'
AND actp.actpDefaultValue NOT LIKE 'https://wwwcie.ups.com/%'
AND actp.actpDefaultValue NOT LIKE 'C:\Program Files\20 20 Technologies\%'
AND actp.actpDefaultValue NOT LIKE 'C:\'
AND actp.actpDefaultValue NOT LIKE 'C:\tmp%'
AND actp.actpDefaultValue NOT LIKE 'C:\temp%'
AND actp.actpDefaultValue NOT LIKE 'C:\CVSRoot\%'
order by actp.orgid, actp.actID

select tr.orgID, tr.atrId, tr.actID, tr.actIDInstance, tr.trDescription, tr.trFixedParameters
FROM inResponse.Trees tr
JOIN @SearchStringValues v ON CAST(tr.trFixedParameters AS NVARCHAR(MAX)) LIKE '%'+v.SearchStr+'%' 
WHERE CAST(tr.trFixedParameters AS NVARCHAR(MAX)) NOT LIKE '%D:\imosData8%'

select wrc.wrcId,wrc.wrcShortDesc,wrc.wrcDescription, wrc.wrcOutputPath
FROM dbo.WorkCenter wrc
JOIN @SearchStringValues v ON wrc.wrcOutputPath LIKE '%'+v.SearchStr+'%' 

select mon.monId,mon.monCode,mon.monDescription, mon.monConfiguration
FROM inResponse.Monitors mon
JOIN @SearchStringValues v ON mon.monConfiguration LIKE '%'+v.SearchStr+'%'

select act.actID, ac.actDescription,act.AttachMaskSQL
FROM inResponse.ActionEMails act
JOIN inResponse.Actions ac ON ac.actID=act.actID
JOIN @SearchStringValues v ON act.AttachMaskSQL LIKE '%'+v.SearchStr+'%'

select act.actID, ac.actDescription,act.arsFileNameSQL
FROM inResponse.ActionReportServices act
JOIN inResponse.Actions ac ON ac.actID=act.actID
JOIN @SearchStringValues v ON act.arsFileNameSQL LIKE '%'+v.SearchStr+'%'

SELECT DISTINCT wrcOutputPath FROM dbo.WorkCenter wrc
SELECT DISTINCT itmpCNCProgOutputPath FROM dbo.ItemCNCPrograms cnc




