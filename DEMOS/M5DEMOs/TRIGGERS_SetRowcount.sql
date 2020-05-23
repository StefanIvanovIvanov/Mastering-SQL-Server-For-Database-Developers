-- TRIGGERS

--How SET ROWCOUNT can break a trigger

/*
Traditionally, developers have relied on the SET ROWCOUNT command to limit the number of rows returned 
to a client for a given query, or to limit the number of rows on which a data modification statement 
(UPDATE, DELETE, MERGE or INSERT) acts. In either case, SET ROWCOUNT works by instructing SQL Server 
to stop processing after a specified number of rows

SET ROWCOUNT is deprecated in SQL Server 2008… …
and (eventually), does has no effect on INSERT, UPDATE or DELETE statements. 
Microsoft advises rewriting any such statements that rely on ROWCOUNT to use TOP instead. 
As such, this example may be somewhat less relevant for future versions of SQL Server; 
the trigger might be less vulnerable to being broken, although still not immune.
*/

-- 9: Creating and populating the Objects table
CREATE TABLE dbo.Objects
    (
      ObjectID INT NOT NULL PRIMARY KEY ,
      SizeInInches FLOAT NOT NULL ,
      WeightInPounds FLOAT NOT NULL
    ) ;
GO
INSERT  INTO dbo.Objects
        ( ObjectID ,
          SizeInInches ,
          WeightInPounds
        )
        SELECT  1 ,
                10 ,
                10
        UNION ALL
        SELECT  2 ,
                12 ,
                12
        UNION ALL
        SELECT  3 ,
                20 ,
                22 ;
GO

-- 1-10: Logging updates to the Objects table
CREATE TABLE dbo.ObjectsChangeLog
  (
    ObjectsChangeLogID INT NOT NULL
                           IDENTITY ,
    ObjectID INT NOT NULL ,
    ChangedColumnName VARCHAR(20) NOT NULL ,
    ChangedAt DATETIME NOT NULL ,
    OldValue FLOAT NOT NULL ,
    CONSTRAINT PK_ObjectsChangeLog PRIMARY KEY 
                               ( ObjectsChangeLogID )
  ) ;
 GO

CREATE TRIGGER Objects_UpdTrigger ON dbo.Objects
  FOR UPDATE
AS
  BEGIN; 
    INSERT  INTO dbo.ObjectsChangeLog
            ( ObjectID ,
              ChangedColumnName ,
              ChangedAt ,
              OldValue
                
            )
            SELECT  i.ObjectID ,
                    'SizeInInches' ,
                    CURRENT_TIMESTAMP ,
                    d.SizeInInches
            FROM    inserted AS i
                    INNER JOIN deleted AS d ON 
                        i.ObjectID = d.ObjectID
            WHERE   i.SizeInInches <> d.SizeInInches
            UNION ALL
            SELECT  i.ObjectID ,
                    'WeightInPounds' ,
                    CURRENT_TIMESTAMP ,
                    d.WeightInPounds
            FROM    inserted AS i
                    INNER JOIN deleted AS d ON 
                        i.ObjectID = d.ObjectID
            WHERE i.WeightInPounds <> d.WeightInPounds ;
  END ; 

--   1-11: Testing the trigger
BEGIN TRAN ;

-- TRUNCATE TABLE can also be used here
DELETE  FROM dbo.ObjectsChangeLog ;
 
UPDATE  dbo.Objects
SET     SizeInInches = 12 ,
        WeightInPounds = 14
WHERE   ObjectID = 1 ;

-- we are selecting just enough columns 
-- to demonstrate that the trigger works

SELECT  ObjectID ,
        ChangedColumnName ,
        OldValue
FROM    dbo.ObjectsChangeLog ;

-- we do not want to change the data,
-- only to demonstrate how the trigger works
ROLLBACK ;
-- the data has not been modified by this script

--   1-12: Breaking the trigger by changing the value of ROWCOUNT
DELETE  FROM dbo.ObjectsChangeLog ;

SET ROWCOUNT 1 ;
-- do some other operation(s) 
-- for which we needed to set rowcount to 1
-- do not restore ROWCOUNT setting
-- to its default value
BEGIN TRAN ;

UPDATE  dbo.Objects
SET     SizeInInches = 12 ,
        WeightInPounds = 14
WHERE   ObjectID = 1 ;

-- make sure to restore ROWCOUNT setting
-- to its default value so that it does not affect the
-- following SELECT

SET ROWCOUNT 0 ;

SELECT  ObjectID ,
        ChangedColumnName ,
        OldValue
FROM    dbo.ObjectsChangeLog ;

ROLLBACK ;

--   1-13: Resetting ROWCOUNT at the start of the trigger
ALTER TRIGGER dbo.Objects_UpdTrigger ON dbo.Objects
    FOR UPDATE
AS
    BEGIN;
-- the scope of this setting is the body of the trigger
        SET ROWCOUNT 0 ;
        INSERT  INTO dbo.ObjectsChangeLog
                ( ObjectID ,
                  ChangedColumnName ,
                  ChangedAt ,
                  OldValue
                )
                SELECT  i.ObjectID ,
                        'SizeInInches' ,
                        CURRENT_TIMESTAMP ,
                        d.SizeInInches
                FROM    inserted AS i
                        INNER JOIN deleted AS d ON
                            i.ObjectID = d.ObjectID
                WHERE   i.SizeInInches <> d.SizeInInches
                UNION ALL
                SELECT  i.ObjectID ,
                        'WeightInPounds' ,
                        CURRENT_TIMESTAMP ,
                        d.WeightInPounds
                FROM    inserted AS i
                        INNER JOIN deleted AS d ON
                            i.ObjectID = d.ObjectID
                WHERE   i.WeightInPounds <> 
                            d.WeightInPounds ;
    END ;
-- after the body of the trigger completes,
-- the original value of ROWCOUNT is restored
-- by the database engine

--   1-14: SET ROWCOUNT can break a stored procedure
SET ROWCOUNT 1 ;
-- must return two rows
EXEC dbo.SelectMessagesBySubjectBeginning
    @SubjectBeginning = 'Ne' ;

--   1-15: Creating the SelectObjectsChangeLogForDateRange stored procedure
CREATE PROCEDURE dbo.SelectObjectsChangeLogForDateRange
    @DateFrom DATETIME ,
    @DateTo DATETIME = NULL
AS 
    SET ROWCOUNT 0 ;
    SELECT  ObjectID ,
            ChangedColumnName ,
            ChangedAt ,
            OldValue
    FROM    dbo.ObjectsChangeLog
    WHERE ChangedAt BETWEEN @DateFrom
                  AND  COALESCE(@DateTo, '12/31/2099') ;
GO

--   1-16: Our stored procedure breaks under Norwegian language settings

-- we can populate this table via our trigger, but
-- I used INSERTs,to keep the example simple
INSERT  INTO dbo.ObjectsChangeLog
        ( ObjectID ,
          ChangedColumnName ,
          ChangedAt ,
          OldValue
        )
        SELECT  1 ,
                'SizeInInches' ,
-- the safe way to provide July 7th, 2009 
                '20090707', 
                12.34 ;
 GO

SET LANGUAGE 'us_english' ;
-- this convertion always works in the same way,
-- regardless of the language settings,
-- because the format is explicitly specified
EXEC dbo.SelectObjectsChangeLogForDateRange
      @DateFrom = '20090101';

SET LANGUAGE 'Norsk' ;

EXEC dbo.SelectObjectsChangeLogForDateRange
       @DateFrom = '20090101';

-- your actual error message may be different from mine,
-- depending on the version of SQL Server


--   1-17: Our stored procedure call returns different results, depending on language settings
INSERT  INTO dbo.ObjectsChangeLog
        ( ObjectID ,
          ChangedColumnName ,
          ChangedAt ,
          OldValue
        )
        SELECT  1 ,
                'SizeInInches' ,
                 -- this means June 15th, 2009
                '20090615', 
                12.3
        UNION ALL
        SELECT  1 ,
                'SizeInInches' ,
                -- this means September 15th, 2009 
                '20090915', 
                12.5 

SET LANGUAGE 'us_english' ;

-- this call returns rows from Jul 6th to Sep 10th, 2009
-- one log entry meets the criteria
EXEC SelectObjectsChangeLogForDateRange 
  @DateFrom = '07/06/2009',
  @DateTo = '09/10/2009' ;

SET LANGUAGE 'Norsk' ;

-- this call returns rows from Jun 7th to Oct 9th, 2009
-- three log entries meet the criteria
EXEC SelectObjectsChangeLogForDateRange
  @DateFrom = '07/06/2009',
  @DateTo = '09/10/2009' ;

-- because the stored procedure does not have an ORDER BY
-- clause, your results may show up in a different
-- order

--   1-18: Fixing the stored procedure
ALTER PROCEDURE dbo.SelectObjectsChangeLogForDateRange
    @DateFrom DATETIME ,
    @DateTo DATETIME = NULL
AS 
    SET ROWCOUNT 0 ; 
    SELECT  ObjectID ,
            ChangedColumnName ,
            ChangedAt ,
            OldValue
    FROM    dbo.ObjectsChangeLog
    WHERE   ChangedAt BETWEEN @DateFrom
                      AND     COALESCE(@DateTo,
                              '20991231') ;

------------------
--Issues When Triggers Using @@ROWCOUNT Are Fired by MERGE
-------------------
--   4-22: The FrontPageArticles table, with test data
CREATE TABLE dbo.FrontPageArticles
    (
      ArticleID INT NOT NULL PRIMARY KEY ,
      Title VARCHAR(30) NOT NULL ,
      Author VARCHAR(30) NULL ,
      NumberOfViews INT NOT NULL
    ) ;
GO
INSERT  dbo.FrontPageArticles
        ( ArticleID ,
          Title ,
          Author ,
          NumberOfViews
        )
VALUES  ( 1 ,
          'Road Construction on Rt 59' ,
          'Lynn Lewis' ,
          0
        ) ;

--   4-23: Demonstrating the MERGE command (SQL 2008 and upwards)
MERGE dbo.FrontPageArticles AS target
    USING 
        ( SELECT  1 AS ArticleID ,
                  'Road Construction on Rt 53' AS Title
          UNION ALL
          SELECT  2 AS ArticleID ,
                  'Residents are reaching out' AS Title
        ) AS source ( ArticleID, Title )
    ON ( target.ArticleID = source.ArticleID )
    WHEN MATCHED 
        THEN  UPDATE
          SET  Title = source.Title
    WHEN NOT MATCHED 
        THEN INSERT
                     (
                      ArticleID ,
                      Title ,
                      NumberOfViews
                     )
             VALUES  ( source.ArticleID ,
                      source.Title ,
                      0
                     ) ;
SELECT  ArticleID ,
        Title ,
        NumberOfViews
FROM    dbo.FrontPageArticles ; 

--   4-24: Creating the CannotDeleteMoreThanOneRow trigger
CREATE TRIGGER CannotDeleteMoreThanOneArticle 
  ON dbo.FrontPageArticles
    FOR DELETE
AS
    BEGIN ;
        IF @@ROWCOUNT > 1 
            BEGIN ;
                RAISERROR ( 'Cannot Delete More Than One
                               Row', 16, 1 ) ; 
            END ; 
    END ; 

--   4-25: Our trigger allows us to delete one row, but prevents us from deleting two rows
-- this fails. We cannot delete more than one row:
BEGIN TRY ;
    BEGIN TRAN ;
    DELETE  FROM dbo.FrontPageArticles ;
    PRINT 'Previous command failed;this will not print';
    COMMIT ;
END TRY
BEGIN CATCH ;
    SELECT  ERROR_MESSAGE() ;
    ROLLBACK ;
END CATCH ;

-- this succeeds:  
BEGIN TRY ;
    BEGIN TRAN ;
    DELETE  FROM dbo.FrontPageArticles
    WHERE   ArticleID = 1 ;
    PRINT 'The second DELETE completed' ;
-- we are rolling back the change, because
-- we still need the original data in the next   
    ROLLBACK ; 
END TRY
BEGIN CATCH ;
    SELECT  ERROR_MESSAGE() ;
    ROLLBACK ;
END CATCH ;
--   4-26: The MERGE command intends to delete only one row (and to modify another one) but falls foul of our trigger.
BEGIN TRY ;
    BEGIN TRAN ;
    
    MERGE dbo.FrontPageArticles AS target
        USING 
            ( SELECT  2 AS ArticleID ,
                  'Residents are reaching out!' AS Title
            ) AS source ( ArticleID, Title )
        ON ( target.ArticleID = source.ArticleID )
        WHEN MATCHED 
            THEN UPDATE
            SET Title = source.Title
        WHEN NOT MATCHED BY SOURCE 
            THEN DELETE ;

    PRINT 'MERGE Completed' ;

    SELECT  ArticleID ,
            Title ,
            NumberOfViews
    FROM    dbo.FrontPageArticles ;

-- we are rolling back the change, because
-- we still need the original data in the next examples.
    ROLLBACK ; 
END TRY
BEGIN CATCH ;
    SELECT  ERROR_MESSAGE() ;
    ROLLBACK ;
END CATCH ;

--   4-27: Dropping the trigger before rerunning the MERGE command
DROP TRIGGER dbo.CannotDeleteMoreThanOneArticle ;

--   4-28: The improved trigger 
CREATE TRIGGER CannotDeleteMoreThanOneArticle
  ON dbo.FrontPageArticles
    FOR DELETE
AS
    BEGIN ;

-- these two queries are provided for better
-- understanding of the contents of inserted and deleted
-- virtual tables.
-- They should be removed before deploying!
        SELECT  ArticleID ,
                Title
        FROM    inserted ;
        
        SELECT  ArticleID ,
                Title
        FROM    deleted ;    

        IF ( SELECT COUNT(*)
             FROM   deleted 
           ) > 1 
            BEGIN ;
                RAISERROR ( 'Cannot Delete More Than One
                               Row', 16, 1 ) ; 
            END ; 
    END ; 
