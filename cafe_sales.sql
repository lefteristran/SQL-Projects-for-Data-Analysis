-- Insert flat file with import option from local desktop \ silver_cafe_sales contains the raw data of our project

-- ************************* DATA EXPLORATION - CLEANING - TRANSFORMATION ***********************************

-- This part includes the data quality check and the understanding of the structure

-- Check that all rows have been imported in SSMS (yes - 10k) - we can also see it on the right down corner in SSMS
SELECT COUNT(*) FROM silver_cafe_sales


-- Inspect our table columns and first 50 rows
SELECT TOP 50  * FROM silver_cafe_sales

-- No dupicates
SELECT  COUNT(Transaction_ID)
FROM silver_cafe_sales
GROUP BY Transaction_ID
HAVING COUNT(Transaction_ID) >1

-- We  already see some NULL, Unknown and ERROR values that will be treated properly based on the business logic and our goal

-- Originally, we almost NEVER change the ID (Primary Key)[That is how we get it from the data source sustem] but ONLY for the puprose of this project we do it.
-- 'Transaction_ID' column remove TXN_ , less characters, decreasy memory load, increase capacity. 

SELECT COUNT(*)
FROM silver_cafe_sales
WHERE LEFT(Transaction_ID,3) <> 'TXN' OR LEN(Transaction_ID) > 11 -- checking that all IDs starts with TXN or has the same length in order to transform it.

UPDATE silver_cafe_sales
  SET Transaction_ID = SUBSTRING(Transaction_ID,5,8) -- Removing TXT_
  


-- Checking if 'ITEM' column has NULL - UNKNOWN - ERROR and if so we replace it with NA.
SELECT 
COUNT(*)
FROM silver_cafe_sales
WHERE ITEM IS NULL OR ITEM = 'ERROR' OR ITEM = 'UNKNOWN' -- 969 ROWS

UPDATE silver_cafe_sales
  SET ITEM = 'NA' -- Total_Spent
  WHERE ITEM IS NULL 
   OR ITEM  = 'UNKNOWN'
   OR ITEM  = 'ERROR'
   
   
   -- Check Unique ITEMS | Its item has a unique and standard value. For that purpose we can fill in the NULL values with the corresponding values. This is not applicable to every project but rather on this as we know that prices are fixed per unit.

   SELECT DISTINCT(ITEM)
   FROM silver_cafe_sales -- 8 Unique ITEM excluding NA value

   SELECT DISTINCT(ITEM), Price_Per_Unit,Quantity, Total_Spent
   FROM silver_cafe_sales  -- salad = 5, Juice = 3, Tea = 1.5, Cookie = 1, Smoothie = 4, Coffee = 2, Sandwich = 4, Cake = 3

    UPDATE silver_cafe_sales
    SET Price_Per_Unit = 
     CASE Item
        WHEN 'Salad' THEN 5
        WHEN 'Juice' THEN 3
        WHEN 'Tea' THEN 1.5
        WHEN 'Cookie' THEN 1
        WHEN 'Smoothie' THEN 4
        WHEN 'Coffee' THEN 2
        WHEN 'Sandwich' THEN 4
        WHEN 'Cake' THEN 3
        ELSE Price_Per_Unit
     END
    WHERE Price_Per_Unit IS NULL


  -- As item's prices are fixed we can derive some values for NA items but not for all as the relationship is not 1-1.
     UPDATE silver_cafe_sales
    SET Item = 
     CASE Price_Per_Unit
        WHEN 5 THEN 'Salad'
        WHEN 1.5 THEN 'Salad'
        WHEN 1 THEN 'Cookie' 
        WHEN 2 THEN 'Coffee' 
        ELSE Item
     END
    WHERE ITEM = 'NA' 



    -- We cannot derive ITEM values from Price_Per_Unit as the relationship is not 1-1



-- 'Quantity - Price_Per_Unit - Total_Spent' Columns include NULLs. However, we can get the missing values from the multiplication of these numbers. No value found to be 0 (zero).

 UPDATE silver_cafe_sales
  SET Total_Spent = Quantity * Price_Per_Unit -- Total_Spent
  WHERE Total_Spent IS NULL
   AND Quantity IS NOT NULL
   AND Price_Per_Unit IS NOT NULL


  UPDATE silver_cafe_sales
  SET Price_Per_Unit = Total_Spent / Quantity-- Price_Per_Unit
  WHERE Price_Per_Unit IS NULL
   AND Total_Spent IS NOT NULL
   AND Quantity IS NOT NULL

  UPDATE silver_cafe_sales
  SET Quantity = CAST(ROUND(Total_Spent / Price_Per_Unit, 0) AS INT) -- Quantity
  WHERE Quantity IS NULL
   AND Total_Spent IS NOT NULL
   AND Price_Per_Unit IS NOT NULL

   -- After completing some missing values we noticed that there are still some NULLs on the same records. Unfortunately, we cannot derive the missing info from the multiplication. 
   -- We keep the rest NULLs, as it is  better for numeric values. In addition, later on the advanced analysis we will use SUM() and AVG() Functions which work correctly with NULL.


   -- Checking if 'Payment_Method' and 'Location' columns have NULL - UNKNOWN - ERROR and if so we replace it with NA.
   SELECT 
   COUNT(*)
   FROM silver_cafe_sales 
   WHERE Payment_Method IS NULL OR Payment_Method = 'ERROR' OR Payment_Method = 'UNKNOWN' -- 3178 ROWS 'Payment_Method'

   UPDATE silver_cafe_sales
   SET Payment_Method = 'NA'  -- Replacing NULL with NA for Payment_Method
   WHERE Payment_Method IS NULL OR Payment_Method = 'ERROR' OR Payment_Method = 'UNKNOWN'

   
   SELECT 
   COUNT(*)
   FROM silver_cafe_sales 
   WHERE Location IS NULL OR Location = 'ERROR' OR Location = 'UNKNOWN' -- 3961 ROWS 'Location'

   UPDATE silver_cafe_sales
   SET Location = 'NA'  -- Replacing NULL with NA for Location
   WHERE Location IS NULL OR Location = 'ERROR' OR Location = 'UNKNOWN'



   -- Checking the Transaction_Date

   SELECT * FROM silver_cafe_sales
   ORDER BY Transaction_Date DESC  -- Year 2023 / All months - Daily Data

   SELECT COUNT(*) FROM silver_cafe_sales
   WHERE Transaction_Date IS NULL --460 NULL cases


   -- Creating the gold layer of our project -> gold_cafe_sales

   
   
CREATE VIEW gold_cafe_sales AS
   SELECT 
        Transaction_ID,
        Item,
        Quantity,
        Price_Per_Unit,
        Total_Spent,
        Payment_Method,
        Location,
        Transaction_Date
   FROM silver_cafe_sales


  -- ******************************************************* EDA AND ADVANCED ANALYTICS *******************************************************************


  --------------------- EDA ------------------------------

  SELECT * FROM gold_cafe_sales


  -- Check MAX, MIN Price and Total Spent

 SELECT 
    ITEM,
    MAX(Price_Per_Unit) AS Max_Price, -- Salad = 5
    MIN(Price_Per_Unit) AS Min_Price -- Cookie = 1
 FROM gold_cafe_sales
 GROUP BY ITEM

 SELECT 
    ITEM,
    MAX(Total_Spent) AS Max_Price, --Salad
    MIN(Total_Spent) AS Min_Price  -- Cookie
 FROM gold_cafe_sales
 GROUP BY ITEM



 -- Check AVG Price, Total Spent

  SELECT 
    ROUND(AVG(Price_Per_Unit), 2) AS Avg_Price
 FROM gold_cafe_sales -- 2.95

 SELECT 
    ROUND(AVG(Total_Spent), 2) AS Avg_Price
 FROM gold_cafe_sales -- 8.93  AVERAGE ORDER 


 -- Check top 3 popular products

    SELECT TOP 3
       ITEM,
       SUM(Quantity) AS Total_Quantity_Sold, -- 1) Salad 2) Coffee 3) Cookie 
       SUM(Total_Spent) AS Total_Spent_all
    FROM gold_cafe_sales
    GROUP BY ITEM
    ORDER BY Total_Quantity_Sold DESC

   -- Check down 3 not popular products

    SELECT TOP 3
       ITEM,
       SUM(Quantity) AS Total_Quantity_Sold, -- 1) Tea 2) Smoothie 3) Sandwich 
       SUM(Total_Spent) AS Total_Spent_all
    FROM gold_cafe_sales
    GROUP BY ITEM
    ORDER BY Total_Quantity_Sold ASC

  -- Check the most in common payment method

  SELECT 
       COUNT(*) AS num_of_orders,
       Payment_Method  -- Excluding NA values, the most popular payment method is 'Digital Wallet'
  FROM gold_cafe_sales
  GROUP BY Payment_Method

  -- Customer preference for Takeaway or in-store

  SELECT 
       COUNT(*)  AS num_of_orders,
       Location  -- Excluding NA values, customers prefer "Takeaway"
  FROM gold_cafe_sales
  GROUP BY Location

  -- Payment preference per location

    SELECT 
       COUNT(*) AS number_of_orders,
       Payment_Method,
       Location  -- Takeaway: Digital Wallet , In-store = Cash
  FROM gold_cafe_sales
  WHERE Payment_Method <> 'NA' AND Location <> 'NA'
  GROUP BY Payment_Method,Location
  ORDER BY Location

  -- TOP 3 Products with the highest revenue
  SELECT TOP 3
       SUM(Total_Spent) AS total_spent_sum,
       ITEM
         -- Salad - Sandwich - Smoothie
  FROM gold_cafe_sales
  WHERE ITEM <> 'NA'
  GROUP BY ITEM
  ORDER BY total_spent_sum DESC
 


  
  ---------------------------------- ADVANCED ANALYTICS --------------------------------[CTEs and Window Functions]

  

  SELECT * FROM gold_cafe_sales

-- Investigate Monthly Transactions - Revenue and Running Total 


WITH monthly AS (
    SELECT 
        DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1) AS Sales_Month,
        SUM(Total_Spent) AS Monthly_Revenue,
        COUNT(*) AS Transactions
    FROM gold_cafe_sales
    WHERE Transaction_Date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1)
)

SELECT
    FORMAT(Sales_Month, 'MMM') Month_Name,
    Monthly_Revenue,
    Transactions, -- Most transactions: Oct
    SUM(Monthly_Revenue) OVER (ORDER BY Sales_Month) AS Running_Total
FROM monthly
ORDER BY Sales_Month -- Top Month: Jun 

-- Inspect Mom Change and Cumulative Analysis %


WITH month_change AS (
    SELECT DISTINCT
        DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1) AS Sales_Month,
        SUM(Total_Spent) OVER (PARTITION BY DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1)) AS Monthly_Revenue
    FROM gold_cafe_sales
    WHERE Transaction_Date IS NOT NULL
)
SELECT
    Sales_Month,
    FORMAT(100.0 * Monthly_Revenue / NULLIF(SUM(Monthly_Revenue) OVER (), 0),'N2') + ' %' AS Monthly_Cont_Pct, -- Feb was the month with the lowest sales
    FORMAT(100.0 * SUM(Monthly_Revenue) OVER (ORDER BY Sales_Month)/ NULLIF(SUM(Monthly_Revenue) OVER (), 0),'N2') + ' %' AS Running_Cont_Pct -- 50% of sales was achieved on June which was also the best Month for sales!
FROM month_change
ORDER BY Sales_Month




-- Which day raises the highest revenue and transactions?


WITH Weekday_sales AS (
SELECT
    DATENAME(WEEKDAY,Transaction_Date) AS Days_of_week,
    SUM(Total_Spent) OVER (PARTITION BY DATENAME(WEEKDAY,Transaction_Date)) AS Total_Spent,
    COUNT(*) OVER (PARTITION BY DATENAME(WEEKDAY,Transaction_Date)) AS Total_Transactions
FROM gold_cafe_sales
WHERE Total_Spent IS NOT NULL AND DATENAME(WEEKDAY,Transaction_Date) IS NOT NULL

)
SELECT DISTINCT
    Days_of_week, 
    Total_Spent, 
    Total_Transactions -- Friday has the highest orders but Thursday raises the highest revenue. Average Order Value (AOV) is slightly higher on Thursday.
FROM Weekday_sales
ORDER BY Total_Spent DESC 


------ AOV Comparisons -----



-- Overall AOV

SELECT 
    ROUND(SUM(Total_Spent) / COUNT(*),1) AS AOV   -- AOV = 8.9
FROM gold_cafe_sales
WHERE Total_Spent IS NOT NULL 

-- Monthly AOV

SELECT 
    DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1) AS Sales_Month,
    Round(SUM(Total_Spent) * 1.0 / COUNT(*),2) AS Monthly_AOV
FROM gold_cafe_sales
WHERE Total_Spent IS NOT NULL
  AND Transaction_Date IS NOT NULL                                               -- Top Rev Month: Jun, Top AOV Month: April. So, High revenue does not mean also high AOV.
GROUP BY DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1)
ORDER BY Sales_Month

-- Location AOV

SELECT 
    Location AS Channel,
    ROUND(SUM(Total_Spent) * 1.0 / COUNT(*),2) AS AOV
FROM gold_cafe_sales                                                       
WHERE Total_Spent IS NOT NULL  AND Location <> 'NA'  -- The "In-store" location has slightly higher basket size.
GROUP BY Location
ORDER BY AOV DESC

-- Payment Method AOV

SELECT 
    Payment_Method,
    ROUND(SUM(Total_Spent) * 1.0 / COUNT(*),2) AS AOV
FROM gold_cafe_sales
WHERE Total_Spent IS NOT NULL  AND Payment_Method <> 'NA' -- Bakket size is slightly higher when payment method is cash.
GROUP BY Payment_Method
ORDER BY AOV DESC


---- Revenue by Item and Cumulative Analysis ----

WITH item_rev AS (
    SELECT
        Item,
        SUM(Total_Spent) AS Total_Item_Revenue
    FROM dbo.gold_cafe_sales
    WHERE Total_Spent IS NOT NULL  AND Item <> 'NA'
    GROUP BY Item
),
calc AS (
    SELECT
        Item,
        Total_Item_Revenue,
        SUM(Total_Item_Revenue) OVER () AS Total_Revenue,
        SUM(Total_Item_Revenue) OVER (ORDER BY Total_Item_Revenue DESC) AS Running_Revenue -- As we have seen already the highest revenue is generated by salad
    FROM item_rev
)                                                                                          -- Coffee Tea and Cookie has the lowest contribution
SELECT
    Item,
    Total_Item_Revenue,
    ROUND(100.0 * Total_Item_Revenue / Total_Revenue,2) AS Item_Revenue_Pct,
    ROUND(100.0 * Running_Revenue / Total_Revenue ,2) AS Cumulative_Revenue_Pct
FROM calc
ORDER BY Total_Item_Revenue DESC


----- Payment Revenue % -----

WITH payment_rev AS (
    SELECT
        Payment_Method,
        SUM(Total_Spent) AS Payment_Revenue
    FROM gold_cafe_sales
    WHERE Total_Spent IS NOT NULL  AND Payment_Method <> 'NA'
    GROUP BY Payment_Method
),
calc AS (
    SELECT                                                   --- Revenue Distribution is balanced.
                                                             --- Top payment revenue: Credit Card - Highest AOV (cash) does not mean top payment method
        Payment_Method,
        Payment_Revenue,
        SUM(Payment_Revenue) OVER () AS Total_Revenue
    FROM payment_rev
)
SELECT
    Payment_Method,
    Payment_Revenue,
    Round(100.0 * Payment_Revenue / Total_Revenue,2) AS Revenue_Pct
FROM calc
ORDER BY Payment_Revenue DESC

----- Spend Basket Segmentation -----




WITH spend_bucket AS (
    SELECT
        CASE
            WHEN Total_Spent < 5 THEN 'Low'
            WHEN Total_Spent BETWEEN 5 AND 15 THEN 'Medium'
            ELSE 'High'
        END AS Spend_Category,
        Total_Spent
    FROM gold_cafe_sales
    WHERE Total_Spent IS NOT NULL
),
calc AS (
    SELECT
        Spend_Category,
        COUNT(*) AS Transactions,
        SUM(Total_Spent) AS Revenue,
        SUM(COUNT(*)) OVER () AS Total_Transactions,
        SUM(SUM(Total_Spent)) OVER () AS Total_Revenue
    FROM spend_bucket
    GROUP BY Spend_Category
)

SELECT
    Spend_Category,
    Transactions,
    Revenue,
    ROUND((100.0 * Transactions / Total_Transactions) , 2) AS Transaction_Pct, --The medium spend category has the highest revenue (55%) and the most transactions. 
    ROUND((100.0 * Revenue / Total_Revenue) , 2) AS Revenue_Pct                -- High spend category has only 15% of transactions but comes 2nd in terms of tevenue
FROM calc                                                                      -- Despite the fact that low spend category  comes 2nd in terms of transactions, its in the last position in terms of revenue.
ORDER BY Revenue DESC             --- Bussiness Logic: Order volume and revenue comes from medium spend category ! & 



----- Pareto 80/20 ----

WITH item_rev AS (
    SELECT
        Item,
        SUM(Total_Spent) AS Item_Revenue
    FROM gold_cafe_sales
    WHERE Total_Spent IS NOT NULL
      AND Item <> 'NA'
    GROUP BY Item
),
calc AS (
    SELECT
        Item,
        Item_Revenue,
        SUM(Item_Revenue) OVER () AS Total_Revenue,
        SUM(Item_Revenue) OVER (ORDER BY Item_Revenue DESC) AS Running_Revenue
    FROM item_rev
)

SELECT
    Item,
    Item_Revenue,
    ROUND(100.0 * Item_Revenue / Total_Revenue ,2) AS Revenue_Pct,
    ROUND(100.0 * Running_Revenue / Total_Revenue,2) AS Cumulative_Revenue_Pct --- We need 5/8 items to reach the 80% of the revenue | Portfolio Items are relatively stable as the revenue is spread across multiple products.
FROM calc                                                                      --- Weak contributors cookie - tea - coffee
ORDER BY Item_Revenue DESC


--------------------------------------------------------------------------------------------------- END OF ANALYSIS -----------------------------------------------------------------------------------------------------

--******************** SUMMARY **************************************

/* 
===========================================
FINAL PROJECT SUMMARY – CAFE SALES ANALYSIS
===========================================

Dataset:
~10,000 daily transactions (Year 2023).
Data was cleaned, standardized and transformed into a Gold layer for analysis.

Key Insights:

• Average Order Value (AOV): ~8.9
  High revenue months do not necessarily mean high basket size.

• Revenue Drivers:
  Medium spend segment (5–15) drives the business:
  - 53% of transactions
  - 56% of total revenue

• High Spend Segment:
  - Only 15% of transactions
  - Generates 34% of revenue
  → Strong upselling potential.

• Product Concentration (Pareto Analysis):
  5 out of 8 products generate 80% of revenue.
  → Revenue is moderately diversified.
  → Business is not dependent on a single product.

• Channel Insights:
  In-store transactions have slightly higher AOV than Takeaway.

• Payment Insights:
  Revenue distribution across payment methods is balanced.
  Highest AOV does not necessarily equal highest total revenue.

• Time Analysis:
  Revenue is stable across months and weekdays.
  No extreme volatility observed.

Conclusion:
The café demonstrates balanced revenue distribution,
stable demand patterns, and healthy diversification
across products, payment methods, and sales channel (location).
*/


--******************** COMMENTS **************************************

-- We are aware that we could have done a deeper analysis and use more options like subqueries and CTAS but we will leave these for our next project where we will have more data.
-- Lastly, we kept the NULL values in our dataset but we did not take them into consideration. Ideally we could have done a Gap analysis to estimate for ex revenue with and without Total_Spent = NULL to see
-- the difference. Deeper analysis will be presence on the next project.

-- Every data save and push was accomplished with bash to git -> github.


--------------------------------------------------------------------------------------------------- END OF Project -----------------------------------------------------------------------------------------------------
