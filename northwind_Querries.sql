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
--Question 4 : What are the top 3 best-selling products within each product category?

WITH QuantityByCategory AS (
    SELECT 
        P.CategoryID, C.CategoryName, 
        OD.ProductID, P.ProductName, 
        OD.Quantity
    FROM [Order Details] OD
    JOIN Products P ON OD.ProductID = P.ProductID
    JOIN Categories C ON C.CategoryID = P.CategoryID
),
CategoryQuantitySold AS (
    SELECT 
        CategoryID, CategoryName, ProductID, ProductName,
        SUM(Quantity) AS TotalQuantitySold
    FROM QuantityByCategory
    GROUP BY CategoryID, CategoryName, ProductID, ProductName
),
RankedProducts AS (
    SELECT 
        CategoryName, ProductName, TotalQuantitySold,
        DENSE_RANK() OVER (PARTITION BY CategoryName ORDER BY TotalQuantitySold DESC) AS QuantityRank
    FROM CategoryQuantitySold
)
SELECT CategoryName, ProductName, TotalQuantitySold, QuantityRank
FROM RankedProducts
WHERE QuantityRank <= 3;
----------------------------------------------------------------------------------------------------------------------------------------
--Question 5 : Which customers have reduced their ordering frequency compared to the previous year — early churn signals?
WITH OrderFrequency AS (
    SELECT 
        O.CustomerID, C.CompanyName, 
        YEAR(O.OrderDate) AS Year,
        COUNT(O.OrderDate) AS TotalOrders,
        LAG(COUNT(O.OrderDate)) OVER (PARTITION BY O.CustomerID ORDER BY YEAR(O.OrderDate)) AS PreviousYearOrders
    FROM Orders O
    JOIN Customers C ON C.CustomerID = O.CustomerID
    GROUP BY O.CustomerID, C.CompanyName, YEAR(O.OrderDate)
),
FrequencyChange AS (
    SELECT 
        CustomerID, CompanyName, Year, TotalOrders, PreviousYearOrders,
        (TotalOrders - PreviousYearOrders) AS OrderChange
    FROM OrderFrequency
)
SELECT CustomerID, CompanyName, Year, TotalOrders, PreviousYearOrders, OrderChange
FROM FrequencyChange
WHERE OrderChange < 0
ORDER BY OrderChange ASC;
---------------------------------------------------------------------------------------------------------------------------------------
--Question 6 : Which employees are outperforming or underperforming the company's average sales?

WITH LineItemPrice AS (
    SELECT 
        O.OrderID, O.EmployeeID, 
        CONCAT(E.LastName, ' ', E.FirstName) AS FullName,
        OD.UnitPrice, OD.Quantity, OD.Discount,
        (OD.UnitPrice * OD.Quantity) AS Price
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
    JOIN Employees E ON E.EmployeeID = O.EmployeeID
),
LineItemDiscount AS (
    SELECT 
        OrderID, EmployeeID, FullName, Price,
        (Discount * Price) AS DiscountAmount
    FROM LineItemPrice
),
LineItemNetCost AS (
    SELECT 
        OrderID, EmployeeID, FullName,
        (Price - DiscountAmount) AS NetCost
    FROM LineItemDiscount
),
SalesByEmployee AS (
    SELECT 
        EmployeeID, FullName, 
        ROUND(SUM(NetCost), 2) AS TotalSales
    FROM LineItemNetCost
    GROUP BY EmployeeID, FullName
),
AverageSales AS (
    SELECT 
        EmployeeID, FullName, TotalSales,
        ROUND(AVG(TotalSales) OVER (),2) AS CompanyAverageSales
    FROM SalesByEmployee
)
SELECT 
    EmployeeID, FullName, TotalSales, CompanyAverageSales,
    CASE 
        WHEN TotalSales > CompanyAverageSales THEN 'Outperforming'
        WHEN TotalSales = CompanyAverageSales THEN 'Average'
        ELSE 'Underperforming'
    END AS PerformanceStatus
FROM AverageSales
ORDER BY TotalSales DESC;
----------------------------------------------------------------------------------------------------------------------------------------
--Question 7 : Which products in our catalog have never been ordered by a single customer?

SELECT 
    P.ProductID, 
    P.ProductName,
    COUNT(OD.OrderID) AS TotalOrders
FROM Products P
LEFT JOIN [Order Details] OD ON P.ProductID = OD.ProductID
GROUP BY P.ProductID, P.ProductName
HAVING COUNT(OD.OrderID) = 0
ORDER BY P.ProductID;
--------------------------------------------------------------------------------------------------------------------------------------
--Question 8: Which customers have purchased every single product within a given category?
WITH CustomerCategoryProduct AS (
    SELECT 
        O.CustomerID, C.CompanyName, 
        P.CategoryID, CA.CategoryName,
        COUNT(DISTINCT OD.ProductID) AS ProductsPurchased
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
    JOIN Products P ON OD.ProductID = P.ProductID
    JOIN Categories CA ON P.CategoryID = CA.CategoryID
    JOIN Customers C ON C.CustomerID = O.CustomerID
    GROUP BY O.CustomerID, C.CompanyName, P.CategoryID, CA.CategoryName
),
CategoryProduct AS (
    SELECT 
        CategoryID, 
        COUNT(DISTINCT ProductID) AS CategoryProductCount
    FROM Products
    GROUP BY CategoryID
)
SELECT 
    CCP.CustomerID, CCP.CompanyName, CCP.CategoryName,
    CCP.ProductsPurchased, CP.CategoryProductCount
FROM CustomerCategoryProduct CCP
JOIN CategoryProduct CP ON CCP.CategoryID = CP.CategoryID
WHERE CCP.ProductsPurchased = CP.CategoryProductCount
ORDER BY CCP.CategoryName, CCP.CustomerID;
--------------------------------------------------------------------------------------------------------------------------------------
--Question 9: Which employee/shipper combinations are associated with the most late deliveries?

WITH LateDelivery AS (
    SELECT 
        O.EmployeeID,
        CONCAT(E.LastName, ' ', E.FirstName) AS FullName,
        S.ShipperID,
        S.CompanyName,
        COUNT(*) AS LateDeliveryCount
    FROM Orders O
    JOIN Shippers S ON O.ShipVia = S.ShipperID
    JOIN Employees E ON E.EmployeeID = O.EmployeeID
    WHERE O.ShippedDate > O.RequiredDate
    GROUP BY 
        O.EmployeeID, E.LastName, E.FirstName, 
        S.ShipperID, S.CompanyName
),
TotalOrderPerPair AS (
    SELECT 
        O.EmployeeID,
        S.ShipperID,
        COUNT(*) AS TotalOrders
    FROM Orders O
    JOIN Shippers S ON O.ShipVia = S.ShipperID
    GROUP BY O.EmployeeID, S.ShipperID
)
SELECT 
    LD.EmployeeID, LD.FullName, LD.ShipperID, LD.CompanyName, 
    TP.TotalOrders, LD.LateDeliveryCount,
    CAST(ROUND((LD.LateDeliveryCount * 1.0 / TP.TotalOrders) * 100, 2) AS DECIMAL(5,2)) AS LateDeliveryRatePct
FROM LateDelivery LD
JOIN TotalOrderPerPair TP 
    ON LD.EmployeeID = TP.EmployeeID 
    AND LD.ShipperID = TP.ShipperID
ORDER BY LateDeliveryRatePct DESC;
--------------------------------------------------------------------------------------------------------------------------------------
--Question 10: Which countries generate the highest total revenue and highest average order value?
WITH LineItemPrice AS (
    SELECT 
        O.OrderID,  C.Country,
        OD.UnitPrice, OD.Quantity, OD.Discount,
        (OD.UnitPrice * OD.Quantity) AS Price
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
    JOIN Customers C ON O.CustomerID = C.CustomerID
),
LineItemDiscount AS (
    SELECT 
        OrderID,  Country, Price,
        (Discount * Price) AS DiscountAmount
    FROM LineItemPrice
),
LineItemNetCost AS (
    SELECT 
        OrderID,  Country,
        (Price - DiscountAmount) AS NetCost
    FROM LineItemDiscount
),
OrderValue AS (SELECT OrderID,  Country,
        ROUND(SUM(NetCost),2) AS OrderNetCost FROM LineItemNetCost
        GROUP BY OrderID,  Country)
SELECT Country,ROUND(SUM(OrderNetCost),2) AS Revenue,ROUND(AVG(OrderNetCost),2) AS AvgOrderValue FROM OrderValue
GROUP BY Country
ORDER BY Revenue DESC ,AvgOrderValue 
--------------------------------------------------------------------------------------------------------------------------------------
--Question 11: How much revenue are we losing to discounts, broken down by product category?
WITH LineItemPrice AS (
    SELECT 
        P.ProductID, P.CategoryID, C.CategoryName,
        OD.UnitPrice, OD.Quantity, OD.Discount,
        (OD.UnitPrice * OD.Quantity) AS GrossRevenue
    FROM [Order Details] OD
    JOIN Products P ON P.ProductID = OD.ProductID
    JOIN Categories C ON P.CategoryID = C.CategoryID
),
LineItemDiscount AS (
    SELECT 
        ProductID, CategoryID, CategoryName, GrossRevenue,
        (Discount * GrossRevenue) AS DiscountAmount
    FROM LineItemPrice
),
CategoryDiscount AS (
    SELECT 
        CategoryID, CategoryName,
        ROUND(SUM(GrossRevenue), 2) AS GrossRevenue,
        ROUND(SUM(DiscountAmount), 2) AS Discount
    FROM LineItemDiscount
    GROUP BY CategoryID, CategoryName
)
SELECT 
    CategoryID, CategoryName, GrossRevenue, Discount,
    ROUND((Discount * 1.0 / GrossRevenue) * 100, 2) AS DiscountRatePct
FROM CategoryDiscount
ORDER BY DiscountRatePct DESC;
--------------------------------------------------------------------------------------------------------------------------------------
--Question 12: Do we see seasonal demand patterns across multiple years?
WITH LineItemPrice AS (
    SELECT 
        O.OrderDate,  
        OD.UnitPrice, OD.Quantity, OD.Discount,
        (OD.UnitPrice * OD.Quantity) AS Price
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
),
LineItemDiscount AS (
    SELECT 
        OrderDate, Price,
        (Discount * Price) AS DiscountAmount
    FROM LineItemPrice
),
LineItemNetCost AS (
    SELECT 
        OrderDate, 
        (Price - DiscountAmount) AS Net
    FROM LineItemDiscount
)
SELECT 
    DATEPART(QUARTER, OrderDate) AS Quarter, 
    DATEPART(YEAR, OrderDate) AS Year,
    ROUND(SUM(Net), 2) AS Revenue 
FROM LineItemNetCost
GROUP BY DATEPART(QUARTER, OrderDate), DATEPART(YEAR, OrderDate)
ORDER BY Quarter, Year;
--------------------------------------------------------------------------------------------------------------------------------------
--Question 13: Which customers are at risk of churning based on inactivity relative to their historical ordering pattern?
WITH PreviousCustomerOrder AS (
    SELECT 
        O.CustomerID, C.CompanyName, O.OrderDate,
        LAG(O.OrderDate) OVER (PARTITION BY O.CustomerID ORDER BY O.OrderDate) AS PreviousOrderDate
    FROM Orders O
    JOIN Customers C ON C.CustomerID = O.CustomerID
),
CustomerOrderInterval AS (
    SELECT 
        CustomerID, CompanyName, OrderDate, PreviousOrderDate,
        DATEDIFF(DAY, PreviousOrderDate, OrderDate) AS OrderInterval
    FROM PreviousCustomerOrder
),
CustomerOrderAverage AS (
    SELECT 
        CustomerID, CompanyName, 
        AVG(OrderInterval) AS AvgOrderInterval
    FROM CustomerOrderInterval
    GROUP BY CustomerID, CompanyName
),
CustomerLastOrder AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(OrderDate), (SELECT MAX(OrderDate) FROM Orders)) AS OrderToDate
    FROM Orders
    GROUP BY CustomerID
),
CustomerPattern AS (
    SELECT 
        CLO.CustomerID, COA.CompanyName, COA.AvgOrderInterval, CLO.OrderToDate,
        CASE 
            WHEN CLO.OrderToDate > COA.AvgOrderInterval * 2 THEN 'At Risk'
            ELSE 'No Risk'
        END AS Pattern
    FROM CustomerOrderAverage COA 
    JOIN CustomerLastOrder CLO ON COA.CustomerID = CLO.CustomerID
)
SELECT CustomerID, CompanyName, AvgOrderInterval, OrderToDate, Pattern 
FROM CustomerPattern 
WHERE Pattern = 'At Risk';
--------------------------------------------------------------------------------------------------------------------------------------
--Question 14: Are there sales territories with weak or no employee coverage?

WITH TerritoryCoverage AS (
    SELECT 
        T.TerritoryID, T.TerritoryDescription, 
        COUNT(ET.EmployeeID) AS Employee
    FROM Territories T
    LEFT JOIN EmployeeTerritories ET ON T.TerritoryID = ET.TerritoryID
    GROUP BY T.TerritoryID, T.TerritoryDescription
)
SELECT 
    TerritoryID, TerritoryDescription, Employee,
    CASE 
        WHEN Employee = 0 THEN 'No Coverage'
        WHEN Employee = 1 THEN 'Weak Coverage'
        ELSE 'Adequate Coverage'
    END AS CoverageStatus
FROM TerritoryCoverage
ORDER BY Employee;
--------------------------------------------------------------------------------------------------------------------------------------
--Question 15: Which products are at risk of stockout based on current sales velocity vs. units in stock?
WITH QuantityByProduct AS (
    SELECT 
        OD.ProductID, SUM(OD.Quantity) AS Quantity 
    FROM [Order Details] OD 
    JOIN Orders O ON OD.OrderID = O.OrderID
    GROUP BY ProductID
),
OrderDateRange AS (
    SELECT 
        OD.ProductID, MIN(O.OrderDate) AS Earliest, MAX(O.OrderDate) AS Latest 
    FROM [Order Details] OD 
    JOIN Orders O ON OD.OrderID = O.OrderID
    GROUP BY OD.ProductID
),
DateInterval AS (
    SELECT 
        QP.ProductID, QP.Quantity, ODR.Earliest, ODR.Latest, 
        DATEDIFF(MONTH, ODR.Earliest, ODR.Latest) AS MonthDuration 
    FROM QuantityByProduct QP 
    JOIN OrderDateRange ODR ON QP.ProductID = ODR.ProductID
),
MonthlyQuantity AS (
    SELECT 
        DI.ProductID, DI.Earliest, DI.Latest, DI.Quantity, DI.MonthDuration,
        CAST((DI.Quantity * 1.0 / DI.MonthDuration) AS DECIMAL(5,2)) AS MonthlyQuantity, 
        P.UnitsInStock
    FROM DateInterval DI
    JOIN Products P ON P.ProductID = DI.ProductID
),
StockCapacity AS (
    SELECT *, 
        CAST((UnitsInStock / MonthlyQuantity) AS DECIMAL(5,2)) AS MonthRemaining 
    FROM MonthlyQuantity
)
SELECT *,
    CASE
        WHEN MonthRemaining <= 0 THEN 'Out of Stock'
        WHEN MonthRemaining <= 1 THEN 'At Risk'
        ELSE 'Sufficient'
    END AS Status
FROM StockCapacity;
-----------------------------------------------------------------------------------------------------------------------------------------



