--session 1
USE AdventureWorks2008;

--show in default isolation level first
set transaction isolation level read committed

BEGIN TRAN;

SELECT DepartmentID, Name, ModifiedDate FROM HumanResources.Department
where GroupName='Research and Development'

SELECT * FROM Sales.SalesPerson;

--show locks
--try to update Departments and commit tran

SELECT DepartmentID, Name, ModifiedDate FROM HumanResources.Department
where GroupName='Research and Development'

rollback tran


--session 2

USE AdventureWorks2008;

begin tran

SELECT DepartmentID, Name, ModifiedDate FROM HumanResources.Department
where GroupName='Research and Development'

SELECT * FROM Sales.SalesPerson;

UPDATE HumanResources.Department
SET GroupName = 'Manufactoring'
WHERE DepartmentID = 2

commit tran

--return records state
UPDATE HumanResources.Department
SET GroupName = 'Research and Development'
WHERE DepartmentID = 2



---case 2 RR
set transaction isolation level repeatable read

BEGIN TRAN;

SELECT DepartmentID, Name, ModifiedDate FROM HumanResources.Department
where GroupName='Research and Development'

SELECT * FROM Sales.SalesPerson;

--show locks
--try to update Departments - session 2

SELECT DepartmentID, Name, ModifiedDate FROM HumanResources.Department
where GroupName='Research and Development'

--but insert a new dept - session 3

SELECT DepartmentID, Name, ModifiedDate FROM HumanResources.Department
where GroupName='Research and Development'

--session 2
--try to update
UPDATE HumanResources.Department
SET GroupName = 'Sales and Marketing'
WHERE GroupName='Research and Development'

rollback tran


--session 3

USE AdventureWorks2008;

insert HumanResources.Department
values('NewTech', 'Research and Development', getdate())


--return row state
delete HumanResources.Department
where name='NewTech'



