-- Create partition function and scheme
USE DemoDW;
CREATE PARTITION FUNCTION PF (int) AS RANGE RIGHT FOR VALUES (20140101, 20150101, 20160101);
CREATE PARTITION SCHEME PS AS PARTITION PF TO (FG0000, FG2014, FG2015, FG2016);

-- Create a partitioned table
CREATE TABLE fact_table
 (datekey int, measure int)
ON PS(datekey);
GO

-- Insert data into the partitioned table
INSERT fact_table VALUES (20140101, 100);
INSERT fact_table VALUES (20141231, 100);
INSERT fact_table VALUES (20150101, 100);
INSERT fact_table VALUES (20150403, 100);
GO

select * from fact_table
where measure=5



--datekey=20140101
--and 

create nonclustered index NClIdx1 on fact_table(measure)


create clustered index ClIdx1 on fact_table(datekey)
ON PS(datekey)

create table T1 (a1 int null)
ON FG0000

-- Query the table
SELECT datekey, measure, $PARTITION.PF(datekey) PartitionNo
FROM fact_table;

-- View filegroups, partitions, and rows
SELECT OBJECT_NAME(p.object_id) as obj_name, f.name, p.partition_number, p.rows
FROM sys.system_internals_allocation_units a
JOIN sys.partitions p
ON p.partition_id = a.container_id
JOIN sys.filegroups f ON a.filegroup_id = f.data_space_id
WHERE p.object_id = OBJECT_ID(N'dbo.fact_table')
ORDER BY obj_name, p.index_id, p.partition_number;
GO

select * from sys.system_internals_allocation_units

-- Add a new filegroup and make it the next used
ALTER DATABASE DemoDW ADD FILEGROUP FG2017
GO
ALTER DATABASE DemoDW 
ADD FILE (NAME = F2017, FILENAME = 'D:\Demofiles\Mod03\F2017.ndf', 
SIZE = 3MB, FILEGROWTH = 50%) TO FILEGROUP FG2017;
GO

ALTER PARTITION SCHEME PS
NEXT USED FG2017;
GO

-- Split the empty partition at the end
ALTER PARTITION FUNCTION PF() SPLIT RANGE(20170101);
GO

-- Insert new data
INSERT fact_table VALUES (20160101, 100);
INSERT fact_table VALUES (20161005, 100);
GO

-- View partition metadata
SELECT DISTINCT OBJECT_NAME(p.object_id) as obj_name, f.name, p.partition_number, p.rows
FROM sys.system_internals_allocation_units a
JOIN sys.partitions p
ON p.partition_id = a.container_id
JOIN sys.filegroups f ON a.filegroup_id = f.data_space_id
WHERE p.object_id = OBJECT_ID(N'dbo.fact_table')
ORDER BY obj_name, p.partition_number;
GO

-- Merge the 2014 and 2015 partitions
ALTER PARTITION FUNCTION PF() MERGE RANGE(20150101);
GO

-- View partition metadata
SELECT DISTINCT OBJECT_NAME(p.object_id) as obj_name, f.name, p.partition_number, p.rows
FROM sys.system_internals_allocation_units a
JOIN sys.partitions p
ON p.partition_id = a.container_id
JOIN sys.filegroups f ON a.filegroup_id = f.data_space_id
WHERE p.object_id = OBJECT_ID(N'dbo.fact_table')
ORDER BY obj_name, p.partition_number;
GO