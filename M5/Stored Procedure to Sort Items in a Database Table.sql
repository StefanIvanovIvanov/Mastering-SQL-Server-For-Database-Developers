USE AdventureWorks2016CTP3
GO

--First we need to create the table and populate it with data
CREATE TABLE [dbo].[GridData](
 [Id] [int] IDENTITY(1,1) NOT NULL,
 [CreatedOnly] [bit] NOT NULL DEFAULT ((0)),
 [StringValue] [nvarchar](max) NULL,
 [SortOrder] [int] NULL
)

/* Add some data */
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 1',1)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 2',2)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0 ,'row 3',3)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 4',5)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 5',5)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 6',6)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 7',7)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 8',8)
INSERT INTO [dbo].[GridData] ([CreatedOnly],[StringValue],[SortOrder])
     VALUES (0,'row 9',9)
GO

--Then add needed function which will be used in the stored procedure for splitting the results passed by EF

CREATE FUNCTION [SPLIT]
    (
      @text VARCHAR(MAX) ,
      @delimiter VARCHAR(20) = ' '
    )
RETURNS @Strings TABLE
    (
      [position] INT IDENTITY
                     PRIMARY KEY ,
      [Value] VARCHAR(100)
    )
AS 
    BEGIN
        DECLARE @index INT
        SET @index = -1
        WHILE ( LEN(@text) > 0 ) 
            BEGIN-- Find the first delimiter
                SET @index = CHARINDEX(@delimiter, @text)
                IF ( @index = 0 )
                    AND ( LEN(@text) > 0 ) 
                    BEGIN
                        INSERT  INTO @Strings
                        VALUES  ( CAST(@text AS VARCHAR(100)) )
                        BREAK
                    END
                IF ( @index > 1 ) 
                    BEGIN
                        INSERT  INTO @Strings
                        VALUES  ( CAST(LEFT(@text, @index - 1) AS VARCHAR(100)) )
                        SET @text = RIGHT(@text, ( LEN(@text) - @index ))
                    END--Delimiter is 1st position = no @text to insert
                ELSE 
                    SET @text = CAST(RIGHT(@text, ( LEN(@text) - @index )) AS VARCHAR(100))
            END
        RETURN
    END
	GO

--The stored procedure has a paramter (ItemOrder) of string value. 
--We define a temp table which we use to store the current item order and the record ID. 
--Then we use the split function define above to get the sort order from the ItemOrder parameter based on the order 
--which the procedure have received the IDs of the records (note that we split them by comma - the second parameter 
--for the SPLIT function). Finally, we update the sort order in our table with the ItemOrder of our declared temp table.

CREATE PROCEDURE [dbo].[UpdateDataOrder]
@ItemOrder VARCHAR(255)
AS 
    BEGIN
   
        SET NOCOUNT ON      
        DECLARE @Temp TABLE
            (
              [ItemOrder] INT IDENTITY ,
              [ItemID] INT
            )
        INSERT  INTO @Temp
                SELECT  [Value]
                FROM    [dbo].SPLIT(@ItemOrder, ',')
        SET NOCOUNT OFF
        UPDATE  [GridData]
        SET     [GridData].[SortOrder] = [Temp].[ItemOrder]
        FROM    [GridData]
                INNER JOIN @Temp [Temp] ON [GridData].[Id] = [Temp].[ItemID]
    END