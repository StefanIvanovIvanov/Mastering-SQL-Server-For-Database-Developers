--MERGE

--we want to update the quantities in our Stock table to reflect the trades of the day we recorded in the Trade table

CREATE TABLE Stock(Symbol varchar(10) PRIMARY KEY, Qty int CHECK (Qty > 0))
CREATE TABLE Trade(Symbol varchar(10) PRIMARY KEY, Delta int CHECK (Delta <> 0))

INSERT INTO Stock VALUES ('ADVW', 10)
INSERT INTO Stock VALUES ('BYA', 5)

INSERT INTO Trade VALUES('ADVW', 5)
INSERT INTO Trade VALUES('BYA', -5)
INSERT INTO Trade VALUES('NWT', 3)

--The target can be any table or updatable view - the recipient of changes
/*
The source is the provider of the data, which is the Trade table in our example, and is specified with the USING keyword right after the target. Anything you can reference in the FROM
clause of an ordinary SELECT statement is supported as the source for MERGE. This includes not only regular tables and views, but subqueries, text files accessed with
OPENROWSETBYTES, remote tables, CTEs, table variables, and TVPs as well.
The join defines which records are considered matching or
nonmatching between the source and target. This is the Symbol column relating stocks to trades in our current example. It tells SQL Server what stocks exist and don't exist in both
tables so that we can insert, update, and delete data in the target table accordingly. The type of join (inner, left outer, right outer, or full outer) is determined by which of the various merge
clauses are then applied next in the MERGE statement.

You are permitted to have one or two WHEN MATCHED clauses—but no more. If there are two
WHEN MATCHED clauses, the first one must be qualified with an AND condition. Furthermore, one clause must specify an UPDATE, and the other must specify a DELETE. As
demonstrated in our current example, MERGE will choose one of the two WHEN MATCHED clauses to execute based on whether the AND condition evaluates to true for any given
row.

*/

MERGE Stock
USING Trade
ON Stock.Symbol = Trade.Symbol
WHEN MATCHED AND (Stock.Qty + Trade.Delta = 0) THEN
-- delete stock if entirely sold
DELETE
WHEN MATCHED THEN
-- update stock quantity (delete takes precedence over update)
UPDATE SET Stock.Qty += Trade.Delta
WHEN NOT MATCHED BY TARGET THEN
-- add newly purchased stock
INSERT VALUES (Trade.Symbol, Trade.Delta);

------------------------------------
--Using MERGE for table replication
------------------------------------

CREATE TABLE Original(PK int primary key, FName varchar(10), Number int)
CREATE TABLE Replica(PK int primary key, FName varchar(10), Number int)
GO
CREATE PROCEDURE uspSyncReplica AS
MERGE Replica AS R
USING Original AS O ON O.PK = R.PK
WHEN MATCHED AND (O.FName != R.FName OR O.Number != R.Number) THEN
UPDATE SET R.FName = O.FName, R.Number = O.Number
WHEN NOT MATCHED THEN
INSERT VALUES(O.PK, O.FName, O.Number)
WHEN NOT MATCHED BY SOURCE THEN
DELETE;

INSERT Original VALUES(1, 'Sara', 10)
INSERT Original VALUES(2, 'Steven', 20)

EXEC uspSyncReplica
go

SELECT * FROM Original
SELECT * FROM Replica
GO

INSERT INTO Original VALUES(3, 'Andrew', 100)
UPDATE Original SET FName = 'Stephen', Number += 10 WHERE PK = 2
DELETE FROM Original WHERE PK = 1
GO
SELECT * FROM Original
SELECT * FROM Replica
GO

EXEC uspSyncReplica
GO

SELECT * FROM Original
SELECT * FROM Replica
GO

/*
The MERGE statement also supports the same OUTPUT clause introduced in SQL Server 2005 for the INSERT , UPDATE, and DELETE statements. This clause returns change
information from each row affected by DML operations in the same INSERTED and DELETED pseudo-tables exposed by triggers.

In addition to INSERTED and DELETED pseudo-table columns, a new virtual column named $action has been introduced for OUTPUT when used with the MERGE statement. The
$action column will return one of the three string values—'INSERT', 'UPDATE', or 'DELETE'—depending on the action taken for each row.
you can use OUTPUT...INTO just as you can with the INSERT , UPDATE,
and DELETE statements to send this information to another table or table variable for history logging or additional processing
*/

CREATE PROCEDURE uspSyncReplica AS
MERGE Replica AS R
USING Original AS O ON O.PK = R.PK
WHEN MATCHED AND (O.FName != R.FName OR O.Number != R.Number) THEN
UPDATE SET R.FName = O.FName, R.Number = O.Number
WHEN NOT MATCHED THEN
INSERT VALUES(O.PK, O.FName, O.Number)
WHEN NOT MATCHED BY SOURCE THEN
DELETE
OUTPUT $action, INSERTED.*, DELETED.* ;

