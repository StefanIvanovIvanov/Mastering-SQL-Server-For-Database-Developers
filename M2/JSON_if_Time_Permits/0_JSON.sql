--SQL Server 2016 provides the capability to extract values from JSON text and use them in queries. 
--If you have JSON text that's stored in database tables, 
--you can use built-in functions to read or modify values in the JSON text.

--Use the JSON_VALUE function to extract a scalar value from a JSON string
--Use JSON_QUERY to extract an object or an array
--Use the ISJSON function to test whether a string contains valid JSON

USE AdventureWorks2016CTP3
GO

SELECT FirstName, LastName,   
       JSON_VALUE(AdditionalContactInfo, '$.info.address.town') AS Town ,
	   JSON_QUERY(AdditionalContactInfo,'$.info.address') as Address
FROM Person.Person_json  
WHERE ISJSON(AdditionalContactInfo) > 0   
ORDER BY JSON_VALUE(AdditionalContactInfo, '$.info.address.town') desc

--Change JSON values. If you need to modify parts of JSON text, 
--you can use the JSON_MODIFY function to update the value of a property in a JSON string 
--and return the updated JSON string. 

DECLARE @jsonInfo VARCHAR(MAX)  

SET @jsonInfo =N'{  
    "info":{    
      "type":1,  
      "address":{    
        "town":"Bristol",  
        "country":"England"  
      },  
      "tags":["Sport", "Water polo"]  
   },  
   "type":"Basic"  
}'  
SET @jsonInfo = JSON_MODIFY(@jsonInfo, '$.info.address.town', 'London')  

SELECT @jsonInfo

--Convert JSON collections to a rowset. If you need to create some query or report on JSON data, 
--you can easily convert JSON data to rows and columns by calling the OPENJSON rowset function. 
--OPENJSON transforms the array of JSON objects into a table, in which each object is represented as one row, 
--and key/value pairs are returned as cells. OPENJSON converts JSON values to specified types. 
--OPENJSON can handle both flat key/value pairs and nested, hierarchically organized objects. 
--You don't have to return all the fields contained in the JSON text. OPENJSON returns NULL values if JSON values don't exist. 

DECLARE @json VARCHAR(MAX)

SET @json =  
N'[  
      { "id" : 2,"info": { "name": "John", "surname": "Smith" }, "age": 25 },  
      { "id" : 5,"info": { "name": "Jane", "surname": "Smith" }, "dob": "2005-11-04T12:00:00" }  
]'  

SELECT *  
FROM OPENJSON(@json)  
 WITH (id int 'strict $.id',  
       firstName nvarchar(50) '$.info.name', lastName nvarchar(50) '$.info.surname',  
       age int, dateOfBirth datetime2 '$.dob') 

--Convert SQL Server data to JSON or export JSON. Format SQL Server data or the results of SQL queries as JSON 
--by adding the FOR JSON clause to a SELECT statement. Use FOR JSON to delegate the formatting of JSON output 
--from your client applications to SQL Server.

--FOR JSON PATH clause will use column alias or column name to determine key name in JSON output. 
--If some alias contains dots, FOR JSON PATH clause will create nested object. 
--Note that cells with NULL values will not be generated in the output.

SELECT hre.BusinessEntityID, pp.FirstName AS "info.name", 
pp.LastName AS "info.surname", hre.BirthDate as dob  
FROM [HumanResources].[Employee] hre
JOIN [Person].[Person] pp 
ON  hre.BusinessEntityID = pp.BusinessEntityID
FOR JSON PATH 

-- FOR JSON AUTO
--To format the JSON output automatically based on the structure of the SELECT statement, 
--specify the AUTO option with the FOR JSON clause. With the AUTO option, the format of the JSON output 
--is automatically determined based on the order of columns in the SELECT list and their source tables. 
--You can't change this format. A query that uses the FOR JSON AUTO option must have a FROM clause.

SELECT hre.BusinessEntityID, pp.FirstName AS "info.name", 
pp.LastName AS "info.surname", hre.BirthDate as dob  
FROM [HumanResources].[Employee] hre
JOIN [Person].[Person] pp 
ON  hre.BusinessEntityID = pp.BusinessEntityID
FOR JSON AUTO 

