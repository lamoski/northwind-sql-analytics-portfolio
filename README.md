# Northwind SQL Analytics Portfolio

Advanced SQL queries on the Northwind sample database — window functions, CTEs, complex joins, aggregations, and business problem solving. Each query answers a real business question, with documented reasoning behind every design decision.

**Contents:** [Overview](#project-overview) · [Objective](#objective) · [Data](#data-description) · [Data Quality](#data-quality-notes) · [Business Questions](#business-questions) · [Queries](#queries)

---

## Project Overview

**Northwind SQL Analytics Portfolio** showcases 15 original SQL queries built on the Northwind sample database, demonstrating advanced proficiency in window functions, CTEs, complex joins, aggregations, and business-driven problem solving. Rather than isolated syntax exercises, each query is framed around a real business question — the kind a Sales Director, Operations Manager, or Category Lead would actually need answered — and paired with a clear explanation of the logic and the insight it delivers.

This project complements **RideMetrics**, my end-to-end analytics project (Python, MSSQL Medallion Architecture, Power BI, and ML models on ride-hailing data), by isolating pure SQL fluency: the foundational skill every data analytics role depends on, independent of any broader toolchain.

## Objective

To demonstrate the ability to translate open-ended business questions into efficient, well-structured SQL queries using intermediate-to-advanced techniques (window functions, CTEs, relational division, anti-joins, time-series aggregation), and to communicate query logic and business value clearly for a non-technical audience.

## Data Description

The **Northwind database** is a sample dataset originally released by Microsoft, simulating a small import/export trading company. Exploration and analysis in this project focus on the following tables:

| Table | Description | Key Columns |
|---|---|---|
| `Orders` | One row per customer order | OrderID, CustomerID, EmployeeID, OrderDate, ShippedDate, ShipCountry |
| `Order Details` | Line items per order (products, quantity, price, discount) | OrderID, ProductID, UnitPrice, Quantity, Discount |
| `Products` | Product catalog | ProductID, CategoryID, SupplierID, UnitPrice, UnitsInStock |
| `Categories` | Product category lookup | CategoryID, CategoryName |
| `Customers` | Customer master data | CustomerID, CompanyName, Country |
| `Employees` | Sales staff | EmployeeID, FirstName, LastName, HireDate |
| `Shippers` | Shipping companies used to deliver orders | ShipperID, CompanyName |
| `Territories` | Sales territories the company operates in | TerritoryID, TerritoryDescription |
| `EmployeeTerritories` | Bridge table linking employees to the territories they cover | EmployeeID, TerritoryID |

## Data Quality Notes

Exploration focused on the tables used in this project (`Orders`, `Order Details`, `Customers`, `Products`, `Employees`, `Categories`) rather than the full Northwind schema. The following null patterns were identified and evaluated to determine whether they reflect genuine data quality issues or expected structural gaps.

| Field | Table | Finding | Assessment | Impact on Analysis |
|---|---|---|---|---|
| `ShippedDate` | Orders | Some orders have no ship date | Expected — indicates orders pending or cancelled at time of data export | Handled explicitly in Query 9 (late shipment analysis); unshipped orders excluded from delay calculations |
| `ShipRegion` | Orders | Some orders have no ship region | Structural — not all countries use a "region/state" field | No impact; not used in current queries |
| `Region` | Customers | Some customers have no region | Structural — same reasoning as above | No impact; not used in current queries |
| `PostalCode` | Customers | One customer missing postal code | Likely data entry gap | No impact; not referenced in any query |
| `Fax` | Customers | Some customers missing fax number | Expected — fax was an optional/legacy contact field | No impact; not used in analysis |
| `Region` | Employees | Some employees have no region | Structural — same reasoning as Customers.Region | No impact; not used in current queries |

`Shippers`, `Territories`, and `EmployeeTerritories` were also reviewed and showed no nulls or structural anomalies.

**Key takeaway:** Most nulls in this dataset reflect legitimate structural gaps in international address formats rather than data quality problems. The one null pattern with real analytical relevance — missing `ShippedDate` — was accounted for directly in the relevant business question rather than treated as an error to clean.

---

## Business Questions

### Window Functions
1. Who are the top-spending customers in each country, and how do they rank against each other?
2. What is our cumulative revenue trend within each year, month by month?
3. How is our month-over-month revenue growing or declining, and by what percentage?

### CTEs
4. What are the top 3 best-selling products within each product category?
5. Which customers have reduced their ordering frequency compared to the previous year?
6. Which employees are outperforming or underperforming the company's average sales?

### Complex JOINs
7. Which products in our catalog have never been ordered by a single customer?
8. Which customers have purchased every single product within a given category?
9. Which employee/shipper combinations are associated with the most late deliveries?

### Aggregations
10. Which countries generate the highest total revenue and highest average order value?
11. How much revenue are we losing to discounts, broken down by product category?
12. Do we see seasonal demand patterns across multiple years?

### Business Problem Solving
13. Which customers are at risk of churning based on inactivity relative to their historical ordering pattern?
14. Are there sales territories with weak or no employee coverage?
15. Which products are at risk of stockout based on current sales velocity vs. units in stock?

---

## Queries

### Query 1: Top-Spending Customers by Country
*Window Functions*

| | |
|---|---|
| **Business Context** | Sales leadership wants to identify the highest-value customers within each country to inform account management and retention priorities. |
| **Approach** | Calculated true spend per order line (accounting for discounts), aggregated to customer level, then ranked customers within their own country using `DENSE_RANK()`, returning the top 3 per country. |
| **Assumption** | "Rank against each other" was interpreted as ranking within the same country, since the question establishes country as the comparison group. Cross-country comparison is addressed separately in Query 10. |
| **Design Note** | `DENSE_RANK()` chosen over `RANK()` so tied spending amounts share a rank without skipping subsequent numbers. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** QUICK-Stop (Germany, $110,277) and Ernst Handel (Austria, $104,874) are the two highest individual customers globally — ahead of Save-a-lot Markets, the top USA customer ($104,362). Germany and Austria also show high customer concentration, where the top customer far outspends the next-ranked one — a potential revenue risk if that single account is lost.

---

### Query 2: Cumulative Monthly Gross Revenue Trend
*Window Functions*

| | |
|---|---|
| **Business Context** | Leadership wants to track how revenue accumulates through each year to monitor progress against yearly targets and spot momentum shifts early. |
| **Approach** | Aggregated gross revenue (pre-discount) to the year-month level, then applied a running `SUM()` partitioned by year so the cumulative total resets each January and builds month by month. |
| **Assumption** | Revenue here is treated as **gross** (before discounts), distinct from Query 1's "Spending," which is net of discounts. Gross revenue reflects total sales value generated; net spending reflects what customers actually paid. Both are valid metrics measuring different things. |
| **Design Note** | Partitioning by `Year` was a deliberate choice so year-to-date totals are comparable across years, rather than one continuously accumulating total across the whole dataset. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Monthly gross revenue shows strong upward momentum from 1996 through early 1998, with 1998's first four months alone generating more revenue than any full prior year-to-date period at the same point. The apparent sharp drop in May 1998 reflects incomplete data (the dataset ends mid-month) rather than an actual decline — an important caveat for interpreting the final data point.

---

### Query 3: Month-over-Month Revenue Growth
*Window Functions*

| | |
|---|---|
| **Business Context** | Leadership wants to understand short-term revenue volatility and identify unusually strong or weak months to investigate their causes. |
| **Approach** | Aggregated gross revenue to the year-month level, used `LAG()` to bring the previous month's revenue into the same row, then calculated both the absolute change and percentage change against the prior month. |
| **Assumption** | `LAG()` is **not** partitioned by year — the comparison runs continuously across year boundaries (e.g. Dec 1996 vs. Jan 1997 is a valid comparison), since month-over-month growth is a continuous business metric, not one that should reset arbitrarily at each calendar year. This is a deliberate contrast to Query 2, where partitioning by year was appropriate for a year-to-date cumulative view. |
| **Design Note** | The earliest month in the dataset (July 1996) has no prior month, so `PrevMonthGrossRevenue`, `MonthlyChange`, and `PercentageChange` are correctly `NULL` for that row — expected behavior, not an error. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Revenue growth is highly volatile month-to-month, with swings exceeding ±30% common throughout the dataset. December 1997 stands out with the strongest growth (+68.7%), suggesting a possible year-end demand spike. The apparent −85.2% collapse in May 1998 is a data artifact from the dataset ending mid-month, not a genuine business decline.

---

### Query 4: Top 3 Best-Selling Products by Category
*CTEs*

| | |
|---|---|
| **Business Context** | Category Leads want to know which products drive the most sales volume within their category, to inform stocking, promotion, and supplier negotiation priorities. |
| **Approach** | Joined Order Details to Products and Categories, aggregated total quantity sold per product, then ranked products within their own category using `DENSE_RANK()`, returning the top 3 per category. |
| **Assumption** | "Best-selling" was interpreted as highest **quantity sold** (units), reflecting sales volume rather than revenue. A high-volume, lower-priced product can outrank a high-revenue, lower-volume product under this definition — a deliberate choice, since the question asks about *selling* activity, not profitability. |
| **Design Note** | Grouped by `CategoryID`/`ProductID` (not just names) to avoid any risk of two differently-keyed records colliding under the same display name. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Camembert Pierrot (Dairy Products) is the single best-selling product by volume across the entire catalog, and Dairy Products as a category shows the strongest and most consistent top-3 performance overall. Condiments, by contrast, has the lowest-selling #1 product of any category — suggesting comparatively weaker or more fragmented demand within that category.

---

### Query 5: Customers with Declining Order Frequency (Year-over-Year)
*CTEs*

| | |
|---|---|
| **Business Context** | Retention teams want an early warning signal for customers whose engagement is dropping, before a full churn event occurs. |
| **Approach** | Counted orders per customer per year, used `LAG()` partitioned by customer and ordered by year to bring the previous year's order count into the same row, then filtered to customers whose order count declined. |
| **Assumption** | A customer's first year of ordering has no prior year to compare against (`PreviousYearOrders` is `NULL`); these rows are automatically excluded by the `WHERE OrderChange < 0` filter, since any comparison against `NULL` evaluates to `UNKNOWN` rather than `TRUE`. |
| **Design Note / Caveat** | The dataset ends mid-May 1998, so 1998 is a partial year. Nearly all flagged declines occur in 1998 as a result — comparing ~4 months of activity against a full 12-month 1997 mechanically produces a "decline" for most customers regardless of actual behavior. The small number of declines flagged in 1997 (comparing two complete years) are more reliable churn signals. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Nearly all flagged declines occur in 1998, which is a partial year in this dataset (data ends mid-May 1998) — comparing a ~4-month year against a full 12-month 1997 will mechanically produce a "decline" for most customers, regardless of actual behavior. The small number of declines flagged in 1997 (e.g. VINET, TORTU, LILAS, DRACD, SPLIR) — comparing two complete years — represent more reliable churn signals and warrant closer investigation.

---

### Query 6: Employee Sales Performance vs. Company Average
*CTEs*

| | |
|---|---|
| **Business Context** | Sales management wants to identify which employees are exceeding or falling short of overall company sales performance, to inform coaching, recognition, or territory review. |
| **Approach** | Calculated each employee's total net sales (discount-adjusted), then used `AVG() OVER ()` with no partition to compute a single company-wide average shown on every row, and labeled each employee's status with a `CASE WHEN` comparison. |
| **Assumption** | Performance is measured by total net sales generated, not order count or average order value — the most direct read of "sales performance" for this question. |
| **Design Note** | `AVG(TotalSales) OVER ()` with empty parentheses (no `PARTITION BY`) was used deliberately so the average is computed once across all employees and repeated identically on every row, enabling a direct row-by-row comparison. A three-branch `CASE WHEN` (Outperforming / Average / Underperforming) handles the edge case of an employee sitting exactly at the average, even though it doesn't occur in this dataset. |

<details>
<summary>View SQL</summary>

```sql
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
        ROUND(AVG(TotalSales) OVER (), 2) AS CompanyAverageSales
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
```
</details>

**Key Insight:** 4 of 9 employees outperform the company average (~$140,644), with Peacock Margaret leading at $232,890 — over 3x the lowest performer, Buchanan Steven ($68,792). This wide spread suggests meaningful variation in individual sales performance worth investigating further (e.g. tenure, territory, or account assignment).

---

### Query 7: Products Never Ordered
*Complex JOINs*

| | |
|---|---|
| **Business Context** | Inventory and merchandising teams want to identify dead stock — products sitting in the catalog with zero sales history — to inform delisting, promotion, or clearance decisions. |
| **Approach** | Used a `LEFT JOIN` from Products to Order Details to preserve every product regardless of order history, then filtered to products with a `COUNT` of zero matching order lines. |
| **Result** | This query returns **zero rows** — every product in the Northwind catalog (all 77) has been ordered at least once. This was verified independently by comparing the count of distinct ProductIDs in Order Details against the total product count in Products, confirming a full match (77 = 77). |
| **Design Note** | While there's no dead stock to flag in this specific dataset, the query itself represents the exact technique a real business would use to catch unsold inventory — and would return meaningful results on a live, larger, or less-curated catalog. In practice, a check like this would typically run on a recurring basis (e.g. quarterly) against live sales data. |

<details>
<summary>View SQL</summary>

```sql
SELECT 
    P.ProductID, 
    P.ProductName,
    COUNT(OD.OrderID) AS TotalOrders
FROM Products P
LEFT JOIN [Order Details] OD ON P.ProductID = OD.ProductID
GROUP BY P.ProductID, P.ProductName
HAVING COUNT(OD.OrderID) = 0
ORDER BY P.ProductID;
```
</details>

---

### Query 8: Customers Who Purchased Every Product in a Category
*Complex JOINs*

| | |
|---|---|
| **Business Context** | Category leads want to identify their most category-loyal customers — those buying the full breadth of a category's catalog — as candidates for early access, loyalty programs, or category-specific outreach. |
| **Approach** | A relational division pattern: counted each customer's distinct products purchased per category, separately counted each category's total distinct products, then joined the two and filtered to rows where the counts match exactly. |
| **Design Note** | Used `COUNT(DISTINCT ...)` on both sides of the comparison so a customer repeatedly buying the same product isn't miscounted as covering more of the category than they actually have. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Only one customer — Ernst Handel (ERNSH) — has purchased every product within a category, and they've done so in two categories (Dairy Products and Produce). Notably, Ernst Handel also ranked among the top-spending customers in Query 1, reinforcing that this is a high-value, highly engaged account. Both completed categories are relatively small (5 and 10 products respectively), which is worth noting — full category coverage is mathematically easier to achieve in smaller categories.

---

### Query 9: Late Shipments by Employee and Shipper
*Complex JOINs*

| | |
|---|---|
| **Business Context** | Operations wants to identify which employee/shipper combinations are most associated with late deliveries, to investigate whether delays are employee-driven, shipper-driven, or both. |
| **Approach** | Defined a shipment as late when `ShippedDate` falls after `RequiredDate`. Calculated, per employee/shipper combination, both the raw count of late deliveries and the late-delivery *rate* (late orders ÷ total orders for that pair) — since raw count alone conflates delivery performance with order volume. |
| **Assumption** | Lateness is derived from `RequiredDate` vs. `ShippedDate`, since Northwind has no dedicated delivery-tracking table. Orders with a `NULL` ShippedDate (never shipped) are automatically excluded, since any comparison against `NULL` evaluates to `UNKNOWN` rather than `TRUE`. |
| **Design Note** | Joined on both `EmployeeID` and `ShipperID` together (a composite match), since matching on employee alone would incorrectly pair one employee's late orders with every shipper they've ever used, not just the relevant one. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Dodsworth Anne + Speedy Express has the highest late-delivery rate (20.00%), despite a low raw count (2 late out of just 10 total orders) — a pairing a raw-count view alone would miss entirely. Peacock Margaret + United Package has the highest *raw* count (4 late deliveries) but only a middling 5.71% rate once her much higher order volume (70 total orders) is factored in — her raw count reflects volume, not poor performance. King Robert + United Package is the one pairing that ranks high on both raw count (4) and rate (16.67%), making it the strongest candidate for a genuine delivery concern.

---

### Query 10: Revenue and Average Order Value by Country
*Aggregations*

| | |
|---|---|
| **Business Context** | Leadership wants to compare countries not just by total revenue, but by typical order size, to distinguish volume-driven markets from markets where fewer, larger orders drive value. |
| **Approach** | Calculated net revenue per order first (summing all line items within each order), then aggregated those order totals by country to get both total revenue (`SUM`) and average order value (`AVG`) — a two-stage aggregation, since averaging line items directly would understate true order value. |
| **Assumption** | Revenue here is treated as **net** (discount-adjusted), consistent with Query 1's "Spending" — this question is about actual financial contribution per country, not gross sales activity, so net was judged the better fit (unlike Query 2, where gross was appropriate for a sales-volume trend). |
| **Design Note** | Average order value is calculated by first collapsing each order's multiple line items into one order-level total, then averaging *those* totals — averaging raw line items directly would conflate "order size" with "how many products were in the order." |

<details>
<summary>View SQL</summary>

```sql
WITH LineItemPrice AS (
    SELECT 
        O.OrderID, C.Country,
        OD.UnitPrice, OD.Quantity, OD.Discount,
        (OD.UnitPrice * OD.Quantity) AS Price
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
    JOIN Customers C ON O.CustomerID = C.CustomerID
),
LineItemDiscount AS (
    SELECT 
        OrderID, Country, Price,
        (Discount * Price) AS DiscountAmount
    FROM LineItemPrice
),
LineItemNetCost AS (
    SELECT 
        OrderID, Country,
        (Price - DiscountAmount) AS NetCost
    FROM LineItemDiscount
),
OrderValue AS (
    SELECT 
        OrderID, Country,
        ROUND(SUM(NetCost), 2) AS OrderNetCost
    FROM LineItemNetCost
    GROUP BY OrderID, Country
)
SELECT 
    Country, 
    ROUND(SUM(OrderNetCost), 2) AS Revenue, 
    ROUND(AVG(OrderNetCost), 2) AS AvgOrderValue
FROM OrderValue
GROUP BY Country
ORDER BY Revenue DESC;
```
</details>

**Key Insight:** USA and Germany lead on total revenue, but neither leads on average order value — that distinction belongs to Austria ($3,200) and Ireland ($2,630), both of which generate solid business through fewer, larger orders rather than high order volume. This divergence suggests different market strategies could apply: USA/Germany as volume-driven markets, Austria/Ireland as markets where larger, less frequent orders (e.g. bulk or wholesale buyers) drive value.

---

### Query 11: Revenue Lost to Discounts by Category
*Aggregations*

| | |
|---|---|
| **Business Context** | Category leads and pricing teams want to know which categories are giving away the most revenue through discounts, both in absolute terms and relative to their own sales, to identify margin-protection opportunities. |
| **Approach** | Calculated gross revenue and total discount amount per category, then derived a discount rate (discount ÷ gross revenue × 100) so categories can be compared fairly regardless of size. |
| **Design Note** | The discount rate is calculated from category-level summed totals, not raw per-line-item discount ratios — averaging individual line-item discount percentages would misrepresent the category's true overall discount burden. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** Meat/Poultry has the highest discount rate (8.51% of its revenue given away), despite not being the top-grossing category — Beverages and Dairy Products both generate more total revenue but discount less aggressively (6.51% and 6.69% respectively). This suggests Meat/Poultry may be over-discounted relative to its actual sales performance, worth investigating as a margin-protection opportunity.

---

### Query 12: Seasonal Demand Patterns Across Years
*Aggregations*

| | |
|---|---|
| **Business Context** | Leadership wants to know whether demand follows a predictable seasonal cycle (e.g. a consistently strong Q4), to inform inventory planning and staffing ahead of peak periods. |
| **Approach** | Calculated net revenue grouped by quarter and year, ordered by quarter first so the same quarter across different years lines up for easy visual comparison. |
| **Result / Caveat** | The dataset only contains a full 4 quarters for **1997** — 1996 has data for Q3–Q4 only, and 1998 has data for Q1–Q2 only (consistent with the partial-year issue identified in Queries 2, 3, and 5). This means a genuine, repeating seasonal pattern **cannot be reliably confirmed** from this dataset — only one complete year exists to test for a within-year cycle. |
| **Design Note** | Within 1997 (the only complete year), revenue increased every quarter in sequence (Q1 → Q2 → Q3 → Q4), suggesting steady growth through the year rather than a specific "high season." Q1 1998 is more than double every other quarter in the dataset — this is better explained as an extension of the overall upward revenue trend already established in Query 2 than as evidence of Q1-specific seasonality. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** This dataset does not support a reliable seasonality conclusion — only 1997 has complete quarterly data across all four quarters, and within that single year, revenue increased steadily every quarter (Q1 → Q2 → Q3 → Q4), with no sign of a seasonal dip. The apparent Q1 1998 spike is better explained by the dataset's overall revenue growth trend (established in Query 2/3) than by genuine seasonality, since 1996 and 1998 are both partial years and cannot be fairly compared quarter-for-quarter against each other or against 1997.

---

### Query 13: Customer Churn Risk (Inactivity vs. Historical Pattern)
*Business Problem Solving*

| | |
|---|---|
| **Business Context** | Retention teams want to flag customers who have gone unusually quiet *relative to their own normal buying rhythm*, rather than using a single fixed inactivity window that ignores how often a given customer typically orders. |
| **Approach** | Calculated each customer's average interval between consecutive orders using `LAG()` and `DATEDIFF()`, then compared that to their current inactivity (days since their last order, measured against the dataset's overall last order date). Customers whose current gap exceeds **double** their historical average are flagged "At Risk." |
| **Assumption** | Since the dataset has no real "today," the dataset's own most recent order date `(SELECT MAX(OrderDate) FROM Orders)` was used as the reference point for "now" — calculated dynamically rather than hardcoded, so the query remains correct if run against an updated dataset. |
| **Design Note** | A plain "current gap > average gap" threshold flagged 16 customers, including several barely over their own average (e.g. a customer 3 days past a 58-day average) — too weak a signal to act on. Requiring the current gap to exceed **2x** the historical average narrowed this to 6 customers with genuinely significant, actionable inactivity. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** 6 customers are currently inactive for more than double their normal ordering rhythm, ranging from LACOR (typically orders every 18 days, now 43 days quiet — 2.4x) to LAZYK (typically every 62 days, now 349 days quiet — 5.6x). These represent the strongest, most individualized churn signals in the dataset — flagged relative to each customer's own behavior rather than a one-size-fits-all inactivity window.

---

### Query 14: Sales Territory Coverage Gaps
*Business Problem Solving*

| | |
|---|---|
| **Business Context** | Operations wants to identify territories with weak or no employee coverage, to assess staffing risk and prioritize hiring or reassignment. |
| **Approach** | Used a `LEFT JOIN` from Territories to the EmployeeTerritories bridge table to preserve every territory regardless of assignment, counted assigned employees per territory, then labeled each territory's coverage level with a `CASE WHEN`. |
| **Assumption** | Coverage thresholds were defined as: 0 employees = "No Coverage", 1 employee = "Weak Coverage" (a single point of failure with no backup), 2+ = "Adequate Coverage". |
| **Result** | No territory in the dataset has 2 or more assigned employees — the "Adequate Coverage" tier is never reached anywhere in the current structure. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** No territory in the entire dataset has more than one assigned employee — coverage is either exactly 1 (a single point of failure, with no backup if that employee is unavailable) or 0 (no coverage at all). Four territories have zero coverage: Columbia, Bentonville, Dallas, and Austin. This means the "Adequate Coverage" threshold (2+ employees) is never met anywhere in the current structure — every covered territory operates with zero redundancy.

---

### Query 15: Stockout Risk (Sales Velocity vs. Units in Stock)
*Business Problem Solving*

| | |
|---|---|
| **Business Context** | Inventory planning wants to flag products likely to run out soon, based on how fast they're actually selling right now — not just a static "low stock" count that ignores demand. |
| **Approach** | Calculated each product's sales velocity (total quantity sold ÷ number of months between its first and last order), then divided current `UnitsInStock` by that monthly rate to estimate months of stock remaining. |
| **Assumption** | Products with `UnitsInStock = 0` were separated into their own "Out of Stock" category rather than folded into "At Risk," since being already out is a current problem, not a forecasted one. Among products with remaining stock, less than 1 month of runway was set as the "At Risk" threshold, based on where the data showed a natural cluster of low values before a gap into the 1.5+ month range. |
| **Design Note** | Velocity (a rate over time) was used instead of raw total quantity sold, since two products with identical lifetime sales totals can have very different urgency depending on whether those sales happened over 2 months or 20. |

<details>
<summary>View SQL</summary>

```sql
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
```
</details>

**Key Insight:** 48% of the catalog (37 of 77 products) is At Risk of stockout within a month at current sales velocity, and 5 products are already Out of Stock — together, over half the catalog has an active inventory concern. The most urgent case is Product 21, which sells roughly 48 units/month against only 3 units currently in stock — under 3 days of runway. This velocity-based approach surfaces risk that a simple "low stock count" metric would miss: a product with 20 units in stock selling 40/month is in far more danger than one with 10 units selling 2/month, even though the raw stock number looks worse for the second product.

---


