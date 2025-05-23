-- Insert a prefix in all Email Addresses to avoid sending emails from the test environment
-- OR replace all "To" addresses by a specific test mail address and "CC" addresses to NULL.

DECLARE @EmailAddressDomainPrefix NVARCHAR(20) = N'$EmailAddressDomainPrefix'
DECLARE @ReplaceAllEmailAddressesBy NVARCHAR(100) = N'$ReplaceAllEmailAddressesBy'

-- Parameters are defined in config.ps1!

IF ( LEN(@EmailAddressDomainPrefix) > 0 )
BEGIN
	UPDATE oct
	SET octValue = LEFT(REPLACE(octValue,N'@', N'@'+ @EmailAddressDomainPrefix),100)
	OUTPUT INSERTED.venID, DELETED.octValue octValue_OLD, INSERTED.octValue octValue_NEW
	FROM dbo.OrganizationCommunicationTypes oct
	WHERE (octValue like N'%@%') AND (octValue NOT like N'%@'+ @EmailAddressDomainPrefix + '%')

	UPDATE act
	SET [To] = REPLACE([to],N'@', N'@'+ @EmailAddressDomainPrefix) 
	OUTPUT INSERTED.actID, ac.actDescription, DELETED.[To] To_OLD, INSERTED.[To] To_NEW
	FROM inresponse.ActionEmails act
	JOIN inresponse.Actions ac ON ac.actID=act.actID
	WHERE (act.[To] like N'%@%') AND (act.[To] NOT like N'%@'+ @EmailAddressDomainPrefix + '%')

	UPDATE act
	SET [CC] = REPLACE([CC],N'@', N'@'+ @EmailAddressDomainPrefix) 
	OUTPUT INSERTED.actID, ac.actDescription, DELETED.[CC] Cc_OLD, INSERTED.[CC] Cc_NEW
	FROM inresponse.ActionEmails act
	JOIN inresponse.Actions ac ON ac.actID=act.actID
	WHERE (act.[CC] like N'%@%') AND (act.[CC] NOT like N'%@'+ @EmailAddressDomainPrefix + '%')

	UPDATE act
	SET [BCC] = REPLACE([BCC],N'@', N'@'+ @EmailAddressDomainPrefix) 
	OUTPUT INSERTED.actID, ac.actDescription, DELETED.[BCC] Bcc_OLD, INSERTED.[BCC] Bcc_NEW
	FROM inresponse.ActionEmails act
	JOIN inresponse.Actions ac ON ac.actID=act.actID
	WHERE (act.[BCC] like N'%@%') AND (act.[BCC] NOT like N'%@'+ @EmailAddressDomainPrefix + '%')

END

IF ( LEN(@ReplaceAllEmailAddressesBy) > 0 )
BEGIN
	UPDATE oct
	SET octValue = @ReplaceAllEmailAddressesBy
	OUTPUT INSERTED.venID, DELETED.octValue octValue_OLD, INSERTED.octValue octValue_NEW
	FROM dbo.OrganizationCommunicationTypes oct
	WHERE (octValue like N'%@%')

	UPDATE act
	SET [To] = @ReplaceAllEmailAddressesBy
	OUTPUT INSERTED.actID, ac.actDescription, DELETED.[To] To_OLD, INSERTED.[To] To_NEW
	FROM inresponse.ActionEmails act
	JOIN inresponse.Actions ac ON ac.actID=act.actID
	WHERE (act.[To] <> '')

	UPDATE act
	SET [CC] = NULL
	OUTPUT INSERTED.actID, ac.actDescription, DELETED.[CC] Cc_OLD, INSERTED.[CC] Cc_NEW
	FROM inresponse.ActionEmails act
	JOIN inresponse.Actions ac ON ac.actID=act.actID
	WHERE (act.[CC] <> '')

	UPDATE act
	SET [BCC] = NULL
	OUTPUT INSERTED.actID, ac.actDescription, DELETED.[BCC] Bcc_OLD, INSERTED.[BCC] Bcc_NEW
	FROM inresponse.ActionEmails act
	JOIN inresponse.Actions ac ON ac.actID=act.actID
	WHERE (act.[BCC] <> '')
END


