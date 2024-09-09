IF EXISTS( SELECT 1 FROM sys.tables WHERE SCHEMA_NAME(schema_id) LIKE 'dbo' AND name LIKE 'TempServices')
	DROP TABLE [dbo].[TempServices];
GO

CREATE TABLE [dbo].[TempServices](
	[svcDbname] [nvarchar](100) NOT NULL,
	[svcHostName] [nvarchar](50) NOT NULL,
	[svcServiceName] [nvarchar](256) NOT NULL,
	[usrLogin] [nvarchar](100) NOT NULL,
	[istID] [tinyint] NOT NULL,
	[svcDeploymentConfiguration] [xml] NULL 
)
GO
