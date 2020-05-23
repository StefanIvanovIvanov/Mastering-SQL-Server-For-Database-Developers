DECLARE @jsonInfo VARCHAR(MAX)  
SET @jsonInfo =N'{  
    "info":{    
      "type":1,  
      "address":{    
        "town":"Bristol",  
        "county":"Avon",  
        "country":"England"  
      },  
      "tags":["Sport", "Water polo"]  
   },  
   "type":"Basic"  
}'  

Update Person.Person_json
set AdditionalContactInfo = @jsonInfo
where PersonID between 1 and 2000
--GO
SET @jsonInfo =N'{  
    "info":{    
      "type":1,  
      "address":{    
        "town":"Sofia",  
        "county":"Avon",  
        "country":"Bulgaria"  
      },  
      "tags":["Sport", "Water polo"]  
   },  
   "type":"Basic"  
}'  

Update Person.Person_json
set AdditionalContactInfo = @jsonInfo
where PersonID between 2000 and 2200

SET @jsonInfo =N'{  
    "info":{    
      "type":1,  
      "address":{    
        "town":"Madrid",  
        "county":"Avon",  
        "country":"Spain"  
      },  
      "tags":["Sport", "Water polo"]  
   },  
   "type":"Basic"  
}'  

Update Person.Person_json
set AdditionalContactInfo = @jsonInfo
where PersonID between 3560 and 4000