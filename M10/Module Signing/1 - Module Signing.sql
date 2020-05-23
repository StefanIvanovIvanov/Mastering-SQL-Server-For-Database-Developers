USE Signing;
GO

CREATE CERTIFICATE AccessCert
  ENCRYPTION BY PASSWORD = 'P@ssw0rd' 
  WITH SUBJECT = 'Test Cert', 
  EXPIRY_DATE = '20200101'; 
GO 

CREATE PROCEDURE dbo.TestProc
AS 
BEGIN 
  SELECT SYSTEM_USER AS SystemUser,
         USER AS DatabaseUser,
         NAME AS ExecutionContext,
         TYPE AS Type, 
         USAGE AS Usage
  FROM sys.user_token; 

  SELECT * FROM dbo.WorkOrderRouting
    ORDER BY ActualCost;
END;
GO 

ADD SIGNATURE TO dbo.TestProc 
  BY CERTIFICATE AccessCert
  WITH PASSWORD = 'P@ssw0rd';
GO 

-- let's look at the digital signature

DECLARE @ThumbPrint VARBINARY(32);

SELECT @ThumbPrint = thumbprint 
  FROM sys.certificates 
  WHERE name = 'AccessCert';

SELECT OBJECT_NAME(major_id) AS ObjectName,
       crypt_property AS Signature
  FROM sys.crypt_properties 
  WHERE thumbprint = @ThumbPrint;
GO

CREATE USER CertUser 
  FROM CERTIFICATE AccessCert;
GO 

-- Note no login for this user

GRANT SELECT ON dbo.WorkOrderRouting
  TO CertUser;
GO

GRANT EXECUTE ON dbo.TestProc
  TO Test1;
GO

-- so who am i?

EXEC dbo.TestProc;
GO 

EXECUTE AS LOGIN = 'Test1';
GO 

EXEC dbo.TestProc;
GO 

REVERT; 
GO 

-- what happens if we modify the proc?
ALTER PROC dbo.TestProc
AS
  PRINT 'Do something evil instead';
GO

-- signature is gone !
DECLARE @ThumbPrint VARBINARY(32);

SELECT @ThumbPrint = thumbprint 
  FROM sys.certificates 
  WHERE name = 'AccessCert';

SELECT OBJECT_NAME(major_id) AS ObjectName,
       crypt_property AS Signature
  FROM sys.crypt_properties 
  WHERE thumbprint = @ThumbPrint;
GO

USE master;
GO
