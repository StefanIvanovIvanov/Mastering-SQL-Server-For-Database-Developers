-- Create a graph demo database
CREATE DATABASE graphdemo;
go
USE graphdemo;
go
-- Create NODE tables
CREATE TABLE Person (
ID INTEGER PRIMARY KEY,
name VARCHAR(100)
) AS NODE;

CREATE TABLE Restaurant (
ID INTEGER NOT NULL,
name VARCHAR(100),
city VARCHAR(100)
) AS NODE;

CREATE TABLE City (
ID INTEGER PRIMARY KEY,
name VARCHAR(100),
stateName VARCHAR(100)
) AS NODE;

-- Create EDGE tables.
CREATE TABLE likes (rating INTEGER) AS EDGE;
CREATE TABLE friendOf AS EDGE;
CREATE TABLE livesIn AS EDGE;
CREATE TABLE locatedIn AS EDGE;

-- Insert data into node tables. Inserting into a node table is same as inserting into a regular table
INSERT INTO Person VALUES (1,'John');
INSERT INTO Person VALUES (2,'Mary');
INSERT INTO Person VALUES (3,'Alice');
INSERT INTO Person VALUES (4,'Jacob');
INSERT INTO Person VALUES (5,'Julie');

INSERT INTO Restaurant VALUES (1,'Taco Dell','Bellevue');
INSERT INTO Restaurant VALUES (2,'Ginger and Spice','Seattle');
INSERT INTO Restaurant VALUES (3,'Noodle Land', 'Redmond');

INSERT INTO City VALUES (1,'Bellevue','wa');
INSERT INTO City VALUES (2,'Seattle','wa');
INSERT INTO City VALUES (3,'Redmond','wa');

select * from Person

select name, object_id, type, create_date, is_node, is_edge from sys.tables

select object_id, name, column_id, user_type_id, max_length, precision,
is_hidden, graph_type, graph_type_desc
from sys.columns
where object_id>100 and graph_type_desc is not null

-- Insert into edge table. While inserting into an edge table,
-- you need to provide the $node_id from $from_id and $to_id columns.
INSERT INTO likes VALUES ((SELECT $node_id FROM Person WHERE id = 1),
(SELECT $node_id FROM Restaurant WHERE id = 1),9);

INSERT INTO likes VALUES ((SELECT $node_id FROM Person WHERE id = 2),
(SELECT $node_id FROM Restaurant WHERE id = 2),9);

INSERT INTO likes VALUES ((SELECT $node_id FROM Person WHERE id = 3),
(SELECT $node_id FROM Restaurant WHERE id = 3),9);

INSERT INTO likes VALUES ((SELECT $node_id FROM Person WHERE id = 4),
(SELECT $node_id FROM Restaurant WHERE id = 3),9);
INSERT INTO likes VALUES ((SELECT $node_id FROM Person WHERE id = 5),
(SELECT $node_id FROM Restaurant WHERE id = 3),9);

INSERT INTO livesIn VALUES ((SELECT $node_id FROM Person WHERE id = 1),
(SELECT $node_id FROM City WHERE id = 1));
INSERT INTO livesIn VALUES ((SELECT $node_id FROM Person WHERE id = 2),
(SELECT $node_id FROM City WHERE id = 2));
INSERT INTO livesIn VALUES ((SELECT $node_id FROM Person WHERE id = 3),
(SELECT $node_id FROM City WHERE id = 3));
INSERT INTO livesIn VALUES ((SELECT $node_id FROM Person WHERE id = 4),
(SELECT $node_id FROM City WHERE id = 3));
INSERT INTO livesIn VALUES ((SELECT $node_id FROM Person WHERE id = 5),
(SELECT $node_id FROM City WHERE id = 1));

INSERT INTO locatedIn VALUES ((SELECT $node_id FROM Restaurant WHERE id = 1),
(SELECT $node_id FROM City WHERE id =1));
INSERT INTO locatedIn VALUES ((SELECT $node_id FROM Restaurant WHERE id = 2),
(SELECT $node_id FROM City WHERE id =2));
INSERT INTO locatedIn VALUES ((SELECT $node_id FROM Restaurant WHERE id = 3),
(SELECT $node_id FROM City WHERE id =3));

-- Insert data into the friendof edge.
INSERT INTO friendof VALUES ((SELECT $NODE_ID FROM person WHERE ID = 1), (SELECT $NODE_ID FROM person WHERE ID
= 2));
INSERT INTO friendof VALUES ((SELECT $NODE_ID FROM person WHERE ID = 2), (SELECT $NODE_ID FROM person WHERE ID
= 3));
INSERT INTO friendof VALUES ((SELECT $NODE_ID FROM person WHERE ID = 3), (SELECT $NODE_ID FROM person WHERE ID
= 1));
INSERT INTO friendof VALUES ((SELECT $NODE_ID FROM person WHERE ID = 4), (SELECT $NODE_ID FROM person WHERE ID
= 2));
INSERT INTO friendof VALUES ((SELECT $NODE_ID FROM person WHERE ID = 5), (SELECT $NODE_ID FROM person WHERE ID
= 4));

--System functions on graph
--1
select * from Person

select OBJECT_ID_FROM_NODE_ID('{"type":"node","schema":"dbo","table":"Person","id":0}')

 select object_name(901578250)

 --2.
 select GRAPH_ID_FROM_NODE_ID('{"type":"node","schema":"dbo","table":"Person","id":3}')

 --3
 select NODE_ID_FROM_PARTS(901578250,2)

 --4
 select * from friendof

 select OBJECT_ID_FROM_EDGE_ID('{"type":"edge","schema":"dbo","table":"friendOf","id":1}')

select OBJECT_NAME(997578592)


---CQL
-- Find Restaurants that John likes
SELECT Restaurant.name
FROM Person, likes, Restaurant
WHERE MATCH (Person-(likes)->Restaurant)
AND Person.name = 'John';

-- Find Restaurants that John's friends like
SELECT Restaurant.name
FROM Person person1, Person person2, likes, friendOf, Restaurant
WHERE MATCH(person1-(friendOf)->person2-(likes)->Restaurant)
AND person1.name='John';

-- Find people who like a restaurant in the same city they live in
SELECT Person.name
FROM Person, likes, Restaurant, livesIn, City, locatedIn
WHERE MATCH (Person-(likes)->Restaurant-(locatedIn)->City AND Person-(livesIn)->City);

--Find friend of a friend of Alice.
SELECT Person3.name AS FriendName 
FROM Person Person1, friendof friend1, Person Person2, friendof friend2, Person Person3
WHERE MATCH(Person1-(friend1)->Person2-(friend2)->Person3)
AND Person1.name = 'Alice';

--Find 2 people who are both friends with same person
SELECT Person1.name AS Friend1, Person2.name AS Friend2
FROM Person Person1, friendof friend1, Person Person2, 
    friendof friend2, Person Person0
WHERE MATCH(Person1-(friend1)->Person0<-(friend2)-Person2);



USE graphdemo;
go
DROP TABLE IF EXISTS likes;
DROP TABLE IF EXISTS Person;
DROP TABLE IF EXISTS Restaurant;
DROP TABLE IF EXISTS City;
DROP TABLE IF EXISTS friendOf;
DROP TABLE IF EXISTS livesIn;
DROP TABLE IF EXISTS locatedIn;
USE master;
go
DROP DATABASE graphdemo;
go

