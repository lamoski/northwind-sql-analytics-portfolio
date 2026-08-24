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

*Additional queries added as completed.*
