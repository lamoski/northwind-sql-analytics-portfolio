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

WITH LineItemPrice AS (
    SELECT 
        O.OrderID, O.CustomerID, C.CompanyName, C.Country,
        OD.UnitPrice, OD.Quantity, OD.Discount,
        (OD.UnitPrice * OD.Quantity) AS Price
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
    JOIN Customers C ON O.CustomerID = C.CustomerID
),
LineItemDiscount AS (
    SELECT 
        OrderID, CustomerID, CompanyName, Country, Price,
        (Discount * Price) AS DiscountAmount
    FROM LineItemPrice
),
LineItemNetCost AS (
    SELECT 
        OrderID, CustomerID, CompanyName, Country,
        (Price - DiscountAmount) AS NetCost
    FROM LineItemDiscount
),
CustomersTotalSpending AS (
    SELECT 
        CustomerID, CompanyName, Country,
        ROUND(SUM(NetCost), 2) AS TotalSpending
    FROM LineItemNetCost
    GROUP BY CustomerID, CompanyName, Country
),
RankedCustomers AS (
    SELECT 
        CustomerID, CompanyName, Country, TotalSpending,
        DENSE_RANK() OVER (PARTITION BY Country ORDER BY TotalSpending DESC) AS CustomerRank
    FROM CustomersTotalSpending
)
SELECT CustomerID, CompanyName, Country, TotalSpending, CustomerRank
FROM RankedCustomers
WHERE CustomerRank <= 3;
----------------------------------------------------------------------------------------------------------------------------------------------------------
--Question 2 : What is the cumulative revenue trend within each year, month by month?
WITH LineItemGrossRevenue AS (
    SELECT 
        O.OrderDate,
        (OD.UnitPrice * OD.Quantity) AS GrossRevenue
    FROM [Order Details] OD
    JOIN Orders O ON OD.OrderID = O.OrderID
),
LineYearMonth AS (
    SELECT 
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        GrossRevenue
    FROM LineItemGrossRevenue
),
GrossRevenueYearMonth AS (
    SELECT 
        Year, Month,
        SUM(GrossRevenue) AS GrossRevenue
    FROM LineYearMonth
    GROUP BY Year, Month
)
SELECT 
    Year, Month, GrossRevenue,
    SUM(GrossRevenue) OVER (PARTITION BY Year ORDER BY Month) AS GrossRevenueTrend
FROM GrossRevenueYearMonth
ORDER BY Year, Month;
----------------------------------------------------------------------------------------------------------------------------------------------------------
--Question 3 : How is our month-over-month revenue growing or declining, and by what percentage?

WITH LineItemGrossRevenue AS (
    SELECT 
        O.OrderDate,
        (OD.UnitPrice * OD.Quantity) AS GrossRevenue
    FROM [Order Details] OD
    JOIN Orders O ON OD.OrderID = O.OrderID
),
LineYearMonth AS (
    SELECT 
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        GrossRevenue
    FROM LineItemGrossRevenue
),
GrossRevenueYearMonth AS (
    SELECT 
        Year, Month,
        SUM(GrossRevenue) AS GrossRevenue
    FROM LineYearMonth
    GROUP BY Year, Month
),
WithPrevMonth AS (
    SELECT 
        Year, Month, GrossRevenue,
        LAG(GrossRevenue) OVER (ORDER BY Year, Month) AS PrevMonthGrossRevenue
    FROM GrossRevenueYearMonth
),
WithMonthlyChange AS (
    SELECT 
        Year, Month, GrossRevenue, PrevMonthGrossRevenue,
        (GrossRevenue - PrevMonthGrossRevenue) AS MonthlyChange
    FROM WithPrevMonth
),
WithPercentageChange AS (
    SELECT 
        Year, Month, GrossRevenue, PrevMonthGrossRevenue, MonthlyChange,
        ROUND((MonthlyChange * 100 / PrevMonthGrossRevenue), 2) AS PercentageChange
    FROM WithMonthlyChange
)
SELECT Year, Month, GrossRevenue, PrevMonthGrossRevenue, MonthlyChange, PercentageChange
FROM WithPercentageChange
ORDER BY Year, Month;
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------





SELECT * FROM Orders
SELECT * FROM [Order Details]



SELECT * FROM Customers