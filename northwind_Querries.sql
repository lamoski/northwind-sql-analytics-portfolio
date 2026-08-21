-- ==============================
-- 1. Database Exploration
-- ==============================

--Explore all table
SELECT * FROM INFORMATION_SCHEMA.TABLES

--Explore all columns needed 
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('Orders','Order Details','Products','Customers','Employees','Categories','Shippers')
ORDER BY TABLE_NAME,ORDINAL_POSITION

--Explore tables and row counts
SELECT 'Orders' as Table_Name, COUNT(*) as Row_Count FROM Orders
UNION ALL SELECT 'Order Details',COUNT(*) FROM [Order Details]
UNION ALL SELECT 'Products',COUNT(*) FROM Products
UNION ALL SELECT 'Customers',COUNT(*) FROM Customers
UNION ALL SELECT 'Employees', COUNT(*) FROM Employees
UNION ALL SELECT 'Categories', COUNT(*) FROM Categories
UNION ALL SELECT 'Shippers', COUNT(*) FROM Shippers


--Explore data
SELECT MIN(orderdate) AS StartDate,MAX(orderdate) AS EndDate from Orders
SELECT COUNT(DISTINCT contactname) AS TotalCustomers from Customers
SELECT COUNT(DISTINCT CategoryID) AS TotalCategory from Products
SELECT COUNT(DISTINCT ProductID) AS TotalProduct from Products


-- ==============================
-- 2. Business Questions
-- ==============================
--------------------------------------------------------------------------------------------------------------------------------------------------------
--Question 1 : Who are  are the  top-spending customers in each country, and how do they rank against each other?

SELECT * FROM Customers

WITH CTE1 AS (SELECT O.OrderID,O.CustomerID,C.CompanyName,C.Country,OD.UnitPrice,OD.Quantity,OD.Discount,(OD.UnitPrice * OD.Quantity)as Price
FROM Orders O
JOIN [Order Details] OD ON O.OrderID = OD.OrderID
JOIN Customers C ON O.CustomerID = C.CustomerID),
CTE2 AS (SELECT OrderID,CustomerID,CompanyName,Country,Price,(Discount * Price) AS DiscountAmount FROM CTE1),
CTE3 AS (SELECT OrderID,CustomerID,CompanyName,Country,(Price- DiscountAmount) AS TotalCost FROM CTE2),
CTE4 AS (SELECT CustomerID,CompanyName,Country,ROUND(SUM(TotalCost),2) AS TotalSpending FROM CTE3
GROUP BY CustomerID,CompanyName,Country),
CTE5 AS (SELECT CustomerID,CompanyName,Country,TotalSpending, 
DENSE_RANK() OVER (PARTITION BY Country ORDER BY TotalSpending DESC) AS CustomerRank FROM CTE4)
SELECT CustomerID,CompanyName,Country,TotalSpending,CustomerRank FROM CTE5
WHERE CustomerRank <= 3
----------------------------------------------------------------------------------------------------------------------------------------------------------



RANK() OVER (PARTITION BY Country ORDER BY TotalSpending DESC)AS RankPosition FROM CTE3
GROUP BY CustomerID



RANK() OVER (PARTITION BY Country ORDER BY TotalSpending DESC) FROM CTE2



SELECT CustomerID,Country,TotalSpending,
RANK() OVER (PARTITION BY CustomerID ORDER BY TotalSpending DESC) AS CustomerRank FROM CTE1

SELECT * FROM [Order Details]
SELECT * FROM Customers