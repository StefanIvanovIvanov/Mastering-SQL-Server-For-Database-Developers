--Calling a store proc

CREATE TABLE dbo.Customers
  (
    CustomerId INT NOT NULL ,
    FirstName VARCHAR(50) NOT NULL ,
    LastName VARCHAR(50) NOT NULL ,
    Status VARCHAR(50) NOT NULL ,
    PhoneNumber VARCHAR(50) NOT NULL ,
    CONSTRAINT PK_Customers PRIMARY KEY ( CustomerId ) ,
    CONSTRAINT UNQ_Customers UNIQUE ( PhoneNumber )
  ) ; 
GO
INSERT  INTO dbo.Customers
        ( CustomerId ,
          FirstName ,
          LastName ,
          Status ,
          PhoneNumber
        )
        SELECT  1 ,
                'Darrel' ,
                'Ling' ,
                'Regular' ,
                '(123)456-7890'
        UNION ALL
        SELECT  2 ,
                'Peter' ,
                'Hansen' ,
                'Regular' ,
                '(234)123-4567' ;

-- The SelectCustomersByName stored procedure
CREATE PROCEDURE dbo.SelectCustomersByName
  @LastName VARCHAR(50) = NULL ,
  @PhoneNumber VARCHAR(50) = NULL
AS 
  BEGIN ;
    SELECT  CustomerId ,
            FirstName ,
            LastName ,
            PhoneNumber ,
            Status
    FROM    dbo.Customers
    WHERE   LastName = COALESCE(@LastName, LastName)
            AND PhoneNumber = COALESCE(@PhoneNumber,
                                         PhoneNumber) ;
  END ;

--  Two ways to invoke the SelectCustomersByName stored procedure 
EXEC dbo.SelectCustomersByName
    'Hansen',         -- @LastName
    '(234)123-4567' ; -- @PhoneNumber

EXEC dbo.SelectCustomersByName
    @LastName = 'Hansen',
    @PhoneNumber = '(234)123-4567' ;

--  The modified SelectCustomersByName stored procedure
ALTER PROCEDURE dbo.SelectCustomersByName
  @FirstName VARCHAR(50) = NULL ,
  @LastName VARCHAR(50) = NULL ,
  @PhoneNumber VARCHAR(50) = NULL
AS 
  BEGIN ;
    SELECT  CustomerId ,
      FirstName ,
      LastName ,
      PhoneNumber ,
      Status
    FROM    dbo.Customers
    WHERE   FirstName = COALESCE (@FirstName, FirstName)
            AND LastName = COALESCE (@LastName,LastName)
            AND PhoneNumber = COALESCE (@PhoneNumber, 
                                          PhoneNumber) ;
  END ;
GO

-- Effect of change in stored procedure signature
-- in the new context this call is interpreted 
-- differently. It will return no rows
EXEC dbo.SelectCustomersByName 
    'Hansen',         -- @FirstName
    '(234)123-4567' ; -- @LastName

-- this stored procedure call is equivalent
-- to the previous one
EXEC dbo.SelectCustomersByName
    @FirstName = 'Hansen',
    @LastName = '(234)123-4567' ;

-- this call returns the required row
EXEC dbo.SelectCustomersByName
    @LastName = 'Hansen',
    @PhoneNumber = '(234)123-4567' ;


--Surviving changes in the col lenght

	-- The Codes table and SelectCode stored procedure
DROP TABLE dbo.Codes -- if exists
GO

CREATE TABLE dbo.Codes
    (
      Code VARCHAR(5) NOT NULL ,
      Description VARCHAR(40) NOT NULL ,
      CONSTRAINT PK_Codes PRIMARY KEY ( Code )
    ) ;
GO

INSERT  INTO dbo.Codes
        ( Code ,
          Description
        )
VALUES  ( '12345' ,
          'Description for 12345'
        ) ;
INSERT  INTO dbo.Codes
        ( Code ,
          Description
        )
VALUES  ( '34567' ,
          'Description for 34567'
        ) ;
GO

CREATE PROCEDURE dbo.SelectCode
-- clearly the type and length of this parameter
-- must match  the type and length of Code column
-- in dbo.Codes table
    @Code VARCHAR(5)
AS 
    SELECT  Code ,
            Description
    FROM    dbo.Codes
    WHERE   Code = @Code ;
GO

-- Listing 3-29: The SelectCode stored procedure works as expected
EXEC dbo.SelectCode @Code = '12345' ;

-- Listing 3-30: Increasing the length of Code column and adding a row with maximum Code length:
ALTER TABLE dbo.Codes DROP CONSTRAINT PK_Codes ;
GO

ALTER TABLE dbo.Codes
  ALTER COLUMN Code VARCHAR(10) NOT NULL ; 
GO

ALTER TABLE dbo.Codes 
ADD CONSTRAINT PK_Codes 
PRIMARY KEY(Code) ;
GO

INSERT  INTO dbo.Codes
        ( Code ,
          Description
        )
VALUES  ( '1234567890' ,
          'Description for 1234567890'
        ) ;

-- Listing 3-31: The unchanged stored procedure retrieves the wrong row
EXEC dbo.SelectCode @Code = '1234567890' ;

