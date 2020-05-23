--SET v/s SELECT when assigning a variable value
--drop table if exists dbo.Customers
--  Creating the Customers table, with a UNIQUE constraint on the PhoneNumber column
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

go
--  Unpredictable variable assignment, using SELECT
DECLARE @CustomerId INT ;

SELECT  @CustomerId = CustomerId
FROM    dbo.Customers
WHERE   PhoneNumber = '(123)456-7890' ;

SELECT  @CustomerId AS CustomerId ;
go


-- Do something with CustomerId
-- Listing 3-3: Adding a CountryCode column to the table and to the unique constraint
ALTER TABLE dbo.Customers
   ADD CountryCode CHAR(2)  NOT NULL
     CONSTRAINT DF_Customers_CountryCode
        DEFAULT('US') ;
GO

ALTER TABLE dbo.Customers DROP CONSTRAINT UNQ_Customers;
GO

ALTER TABLE dbo.Customers 
   ADD CONSTRAINT UNQ_Customers 
      UNIQUE(PhoneNumber, CountryCode) ;

-- Listing 3-4: Wayne Miller has the same phone number as Darrell Ling, but with a different county code.
UPDATE  dbo.Customers
SET     Status = 'Regular' ;

INSERT  INTO dbo.Customers
        ( CustomerId ,
          FirstName ,
          LastName ,
          Status ,
          PhoneNumber ,
          CountryCode
        )
        SELECT  3 ,
                'Wayne' ,
                'Miller' ,
                'Regular' ,
                '(123)456-7890' ,
                'UK' ;

select * from  dbo.Customers

-- Whereas SELECT ignores the ambiguity, SET detects it and raises an error
DECLARE @CustomerId INT ;

-- this assignment will succeed,
-- because in this case there is no ambiguity
SET @CustomerId = ( SELECT CustomerId
                    FROM   dbo.Customers
                    WHERE  PhoneNumber = '(234)123-4567'
                  ) ;

SELECT  @CustomerId AS CustomerId ;

-- this assignment will fail,
-- because there is ambiguity,
-- two customers have the same phone number
DECLARE @CustomerId INT ;

SET @CustomerId = ( SELECT CustomerId
                    FROM   dbo.Customers
                    WHERE  PhoneNumber = '(123)456-7890'
                  ) ;

-- the above error must be intercepted and handled
-- See Chapter 8
-- the variable is left unchanged
SELECT  @CustomerId AS CustomerId ;


