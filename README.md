# Northwind SQL Analytics Portfolio

Advanced SQL queries built on the Northwind sample database, demonstrating proficiency in window functions, CTEs, complex joins, aggregations, and business-driven problem solving. Each query answers a real business question, with documented reasoning behind every design decision.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Objective](#objective)
- [Data Description](#data-description)
- [Data Quality Notes](#data-quality-notes)
- [Business Questions](#business-questions)
  - [Window Functions](#window-functions)
  - [CTEs](#ctes)
  - [Complex JOINs](#complex-joins)
  - [Aggregations](#aggregations)
  - [Business Problem Solving](#business-problem-solving)
- [Queries](#queries)
  - [Query 1: Top-Spending Customers by Country](#query-1-top-spending-customers-by-country)

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

**Category:** Window Functions

**Business Context:** Sales leadership wants to identify the highest-value customers within each country to inform account management and retention priorities.

**Approach:** Calculated true spend per order line (accounting for discounts), aggregated to customer level, then ranked customers within their own country using `DENSE_RANK()`, returning the top 3 per country.

**Assumption:** "Rank against each other" was interpreted as ranking within the same country, since the question establishes country as the comparison group. Cross-country revenue comparison is addressed separately in Query 10.

**Design Note:** `DENSE_RANK()` was chosen over `RANK()` so tied spending amounts receive the same rank without skipping subsequent rank numbers.

**SQL:**
```sql
WITH CTE1 AS (
    SELECT O.OrderID, O.CustomerID, C.CompanyName, C.Country,
           OD.UnitPrice, OD.Quantity, OD.Discount,
           (OD.UnitPrice * OD.Quantity) AS Price
    FROM Orders O
    JOIN [Order Details] OD ON O.OrderID = OD.OrderID
    JOIN Customers C ON O.CustomerID = C.CustomerID
),
CTE2 AS (
    SELECT OrderID, CustomerID, CompanyName, Country, Price,
           (Discount * Price) AS DiscountAmount
    FROM CTE1
),
CTE3 AS (
    SELECT OrderID, CustomerID, CompanyName, Country,
           (Price - DiscountAmount) AS TotalCost
    FROM CTE2
),
CTE4 AS (
    SELECT CustomerID, CompanyName, Country,
           ROUND(SUM(TotalCost), 2) AS TotalSpending
    FROM CTE3
    GROUP BY CustomerID, CompanyName, Country
),
CTE5 AS (
    SELECT CustomerID, CompanyName, Country, TotalSpending,
           DENSE_RANK() OVER (PARTITION BY Country ORDER BY TotalSpending DESC) AS CustomerRank
    FROM CTE4
)
SELECT CustomerID, CompanyName, Country, TotalSpending, CustomerRank
FROM CTE5
WHERE CustomerRank <= 3
```

**Key Insight:** QUICK-Stop (Germany, $110,277) and Ernst Handel (Austria, $104,874) are the two highest individual customers globally — ahead of Save-a-lot Markets, the top USA customer ($104,362). Several countries (notably Germany and Austria) also show high customer concentration, where the top customer contributes significantly more than the next-ranked customer — a potential revenue risk if that single account is lost.

---

*Additional queries to be added as completed.*
