-- Inset flat file with import option from local desktop \ silver_cafe_sales contains the raw data of our project

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


  --------- EDA ---------------

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
 


  
  --------- ADVANCED ANALYTICS ---------------

  SELECT * FROM gold_cafe_sales

-- Investigate Monthly Transactions - Revenue and Running Total 

SELECT 
  Transaction_Date,
  DATENAME(MONTH, Transaction_Date) AS Month_Name,
  SUM(Total_Spent) OVER(PARTITION BY(Month_Name)) ORDER BY Transaction_Date ) AS Running_Total
FROM gold_cafe_sales
WHERE Transaction_Date IS NOT NULL





SELECT 
    DATENAME(MONTH, Transaction_Date) AS Month_Name,
    COUNT(Total_Spent) AS Total_Revenue
FROM gold_cafe_sales
WHERE DATENAME(MONTH, Transaction_Date) IS NOT NULL
GROUP BY DATENAME(MONTH, Transaction_Date)
ORDER BY MIN(MONTH(Transaction_Date));


SELECT DATENAME(MONTH,Transaction_Date) FROM gold_cafe_sales


-- Inspect Mom Change (abs %)

-- Which day raises the highest revenue and transactions?

-- Spikes


-- Part-to-whole EDA % Revenue by item location payment method 

--How much revenue comes from rows with missing location?

--Does excluding 'NA' change results significantly?

-- How much data would be lost if filtering strict rows?




