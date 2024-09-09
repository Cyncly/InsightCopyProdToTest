SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS ( SELECT 1 FROM sys.schemas s WHERE s.name = N'Sha2020')
BEGIN
	EXEC ('CREATE SCHEMA Sha2020')
END
GO

CREATE OR ALTER PROCEDURE [Sha2020].[spDBA_utlDeleteTableInBatches]
	@TableName nvarchar(255)
    -- failsafe variable to prevent casual execution of this procedure from destroying data unintentionally
    ,@DoDataPurge bit = 0  -- 0 - disabled, 1 - enabled - all transactional data will be deleted with no transaction, no ability to rollback.
	,@BatchSize int = 100000 -- size of batches for DELETE Transactions, 0 = all in one batch
	,@WhereClause nvarchar(max) = NULL -- optional: WHERE clause for DELETE
AS
SET NOCOUNT ON

BEGIN TRY

    IF @DoDataPurge = 0 OR @DoDataPurge IS NULL
        THROW 50000, 'Purge is disabled to prevent accidental deletion of data. You must call the procedure with @DoDataPurge = 1 parameter value to enable data removal.', 1;
		
	DECLARE @RowCount INT = 1;
	DECLARE @sql nvarchar(max)

	IF ( @BatchSize = 0 )
		SET @sql = CONCAT('DELETE FROM ',@TableName)
	ELSE
		SET @sql = CONCAT('DELETE TOP (',@BatchSize,') FROM ',@TableName)

	SET @sql = CONCAT(@sql, ' ',@WhereClause)

	WHILE @RowCount > 0
	BEGIN
		BEGIN TRANSACTION;
		EXECUTE (@sql)
		SET @RowCount = @@ROWCOUNT;
		COMMIT TRANSACTION;
	END

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
