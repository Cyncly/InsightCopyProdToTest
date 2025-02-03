-- Replacement of Physical printer names
--
-- Parameters are defined in config.ps1!

DECLARE @ReplacePrinters TABLE (OldStr NVARCHAR(MAX), NewStr NVARCHAR(MAX))
INSERT INTO @ReplacePrinters VALUES 
$PrinterMapping

------------------------------------------------------
-- Do Updates

-- Inresponse Printers
UPDATE p SET prnSystemPrinter = a.NewStr
OUTPUT DELETED.prnSystemPrinter prnSystemPrinter_OLD, INSERTED.prnSystemPrinter prnSystemPrinter_NEW
FROM @ReplacePrinters a
JOIN inResponse.Printers p ON p.prnSystemPrinter LIKE a.OldStr



