--Using complex statements to check for and avoid ambiguity in incoming data 

-- 3: Creating the Codes and CodesStaging tables
CREATE TABLE dbo.Codes
    (
      Code VARCHAR(5) NOT NULL ,
      Description VARCHAR(40) NOT NULL ,
      CONSTRAINT PK_Codes PRIMARY KEY ( Code )
    ) ;
GO

CREATE TABLE dbo.CodesStaging
    (
      Code VARCHAR(10) NOT NULL ,
      Description VARCHAR(40) NOT NULL
    ) ; 
GO

-- 4: Populating the Codes and CodesStaging tables
DELETE  FROM dbo.Codes ;
INSERT  INTO dbo.Codes
        ( Code ,
          Description
        )
        SELECT  'AR' ,
                'Old description for Arkansas'
        UNION ALL
        SELECT  'IN' ,
                'Old description for Indiana' ;

DELETE  FROM dbo.CodesStaging ;
INSERT  INTO dbo.CodesStaging
        ( Code ,
          Description
        )
        SELECT  'AR' ,
                'description for Argentina'
        UNION ALL
        SELECT  'AR' ,
                'new description for Arkansas'
        UNION ALL
        SELECT  'IN' ,
                'new description for Indiana ' ;

-- 5: An ambiguous UPDATE…FROM
UPDATE  dbo.Codes
SET Description = s.Description
FROM    dbo.Codes AS c INNER JOIN dbo.CodesStaging AS s
           ON c.Code = s.Code ;

SELECT  Code ,
        Description
FROM    dbo.Codes ;


-- 6: An ambiguous update of an inline view
WITH    c AS ( SELECT   c.Code ,
                        c.Description ,
                        s.Description AS NewDescription
               FROM     dbo.Codes AS c
                        INNER JOIN dbo.CodesStaging AS s
                             ON c.Code = s.Code
             )
    UPDATE  c
    SET     Description = NewDescription ;

SELECT  Code ,
        Description
FROM    dbo.Codes ;

-- 7: MERGE detects an ambiguity in incoming data
MERGE INTO dbo.Codes AS c
    USING dbo.CodesStaging AS s
    ON c.Code = s.Code
    WHEN MATCHED 
        THEN UPDATE
          SET       c.Description = s.Description ;

-- 8: An ANSI Standard UPDATE command, which raises an error when there is an ambiguity

-- rerun the code from Listing 1-22 
-- before executing this code
UPDATE  dbo.Codes 
SET     Description =
            ( SELECT  Description
              FROM    dbo.CodesStaging 
              WHERE   Codes.Code = CodesStaging.Code
            )
WHERE   EXISTS ( SELECT *
                 FROM   dbo.CodesStaging AS s
                 WHERE   Codes.Code = s.Code
               ) ;


-- 9: Using a subquery to ignore ambiguities when updating an inline view

-- rerun the code from Listing 1-22 
-- before executing this code
BEGIN TRAN ;

WITH  c AS ( SELECT c.Code ,
                    c.Description ,
                    s.Description AS NewDescription
             FROM   dbo.Codes AS c
                    INNER JOIN dbo.CodesStaging AS s
                        ON c.Code = s.Code
                            AND ( SELECT COUNT(*)
                            FROM  dbo.CodesStaging AS s1
                            WHERE c.Code = s1.Code
                                 ) = 1
           )
  UPDATE  c
  SET     Description = NewDescription ;

ROLLBACK ;

-- 10: Using PARTITION BY to ignore ambiguities when updating an inline view

-- rerun the code from Listing 1-22 
-- before executing this code
BEGIN TRAN ;

WITH c AS ( SELECT c.Code ,
                   c.Description ,
                   s.Description AS NewDescription ,
                   COUNT(*) OVER ( PARTITION BY s.Code )
                                       AS NumVersions
             FROM   dbo.Codes AS c
                    INNER JOIN dbo.CodesStaging AS s
                         ON c.Code = s.Code
           )
  UPDATE  c
  SET     Description = NewDescription
  WHERE   NumVersions = 1 ;

ROLLBACK ;

-- 11: An UPDATE command using an inline view and raising a divide by zero error when there is an ambiguity

-- rerun the code from Listing 1-22 
-- before executing this code
DECLARE @ambiguityDetector INT ;
WITH c AS ( SELECT c.Code ,
                   c.Description ,
                   s.Description AS NewDescription ,
                   COUNT(*) OVER ( PARTITION BY s.Code )
                                        AS NumVersions
             FROM   dbo.Codes AS c
                    INNER JOIN dbo.CodesStaging AS s
                         ON c.Code = s.Code
           )
  UPDATE  c
  SET     Description = NewDescription ,
          @ambiguityDetector = CASE WHEN NumVersions = 1
                                    THEN 1
-- if we have ambiguities, the following branch executes
-- and raises the following error:
-- Divide by zero error encountered. 
                                    ELSE 1 / 0
                               END ;

-- 12: Using a subquery to ignore ambiguities when using UPDATE…FROM

-- rerun the code from Listing 1-22
-- before executing this code
BEGIN TRAN ;
UPDATE  dbo.Codes
SET     Description = 'Old Description' ;

UPDATE  dbo.Codes
SET     Description = s.Description
FROM    dbo.Codes AS c
        INNER JOIN dbo.CodesStaging AS s
             ON c.Code = s.Code
                AND ( SELECT COUNT(*)
                      FROM   dbo.CodesStaging AS s1
                      WHERE  s.Code = s1.Code
                     ) = 1 ;
SELECT  Code ,
        Description
FROM    dbo.Codes ;
ROLLBACK ;

-- 13: Using an analytical function to detect and ignore ambiguities when using UPDATE…FROM

-- rerun the code from Listing 1-22 
-- before executing this code
BEGIN TRAN ;
UPDATE  dbo.Codes
SET     Description = 'Old Description' ;

UPDATE dbo.Codes
SET    Description = s.Description
FROM   dbo.Codes AS c
       INNER JOIN ( SELECT Code ,
                     Description ,
                     COUNT(*) OVER ( PARTITION BY Code )
                                        AS NumValues
              FROM   dbo.CodesStaging
            ) AS s
                   ON c.Code = s.Code
                      AND NumValues = 1 ;
SELECT  Code ,
        Description
FROM    dbo.Codes ;
ROLLBACK ;
