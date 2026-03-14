
-- ** This is the 2nd Project in SQL (SSMS) with Joins, CTEs, windows functions, data transformation and advanced analysis. **
--  Info about the datasets: https://www.kaggle.com/datasets/geethasagarbonthu/marketing-and-e-commerce-analytics-dataset?select=transactions.csv


------------------------------------------------------------------------- BEGINNING ----------------------------------------------------------------------------


--############## PART 1: Get Data on SSMS #######################################

-- GO TO DATABASE

USE [Github.Projects]

-- Create Project (ecommerce_silver) Schema


CREATE SCHEMA ecommerce_silver


/* 
DATA MODEL DESIGN

Fact and dimension tables are used to structure the database for analytical queries.

Fact tables store transactional or event-level records
They  contain measurable metrics and foreign keys referencing to the dimension tables.
BRA
Dimension tables store descriptive attributes about entities such as customers, products, 
and campaigns and provide context for analysis. Fact tables are usually larger and grow 
over time, while dimension tables are smaller and more stable.

Based on the reasoning above, we organize our datasets and tables accordingly.

STAGING TABLES

In some cases below, Staging tables were used when raw CSV data required some cleaning or data type conversion 
before loading into the final tables. That happened because some datasets stored dates as text 
or contained placeholder values such as 0 for missing campaign IDs. 

The staging layer allowed raw data to be loaded first and then transformed 
(ex. converting text dates to DATETIME or replacing invalid values with NULL) 
before inserting the cleaned data into the final tables.

When the raw data already matched the required SQL data types, it can be loaded 
directly into the final tables without using a staging table.

FOREIGN KEYS

Foreign keys are used as the primary mechanism for linking fact and dimension tables within the dataset. 
While it would have been possible to filter the data by focusing on a single dimension table, we intentionally retained all dimension-related data to support a broader analytical scope. 
Additionally, we purposely loaded all records where the foreign key equals 0, ensuring that these rows can still participate in joins and provide relevant contextual information for different dimension-level analyses.

In an ideal scenario, the analysis would be structured per schema, joining the appropriate dimension tables with their corresponding rows in the fact tables. 
This approach would maintain a consistent, scalable, and accurate data structure while enabling flexible analytical exploration.

*/

--------------------------- Dataset campaings (7 Columns) 


--#Create Staging table (ST) for campaigns
CREATE TABLE ecommerce_silver.campaigns_stage (
campaign_id INT PRIMARY KEY NOT NULL,
channel VARCHAR(50),
objective VARCHAR(50),
start_date VARCHAR(50),
end_date VARCHAR(50),
target_segment VARCHAR(50),
expected_uplift FLOAT)

--#Insert data to ST
BULK INSERT ecommerce_silver.campaigns_stage
FROM 'C:\Users\lefte\SQL SSMS\sqldatasets\marketing_ecommerce\campaigns.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0A')


--#Create main campaigns table DIMENSION
CREATE TABLE ecommerce_silver.campaigns_dim (
campaign_id INT PRIMARY KEY,
channel VARCHAR(50),
objective VARCHAR(255),
start_date DATE,
end_date DATE,
target_segment VARCHAR(100),
expected_uplift DECIMAL(5,2))


--#Insert from ST to main DIMENSION table data + convert DATE Format to DD-MM-YYYY
INSERT INTO ecommerce_silver.campaigns_dim (campaign_id, channel, objective, start_date, end_date, target_segment, expected_uplift)
SELECT
    campaign_id,
    channel,
    objective,
    CONVERT(DATE, start_date, 103),
    CONVERT(DATE, end_date, 103),
    target_segment, 
    expected_uplift
FROM ecommerce_silver.campaigns_stage

--#Drop ST campaigns
DROP TABLE ecommerce_silver.campaigns_stage


--------------------------------------- Dataset Customers (7 Columns)

--#Create  DIMENSION table for customers
CREATE TABLE ecommerce_silver.customers_dim (
customer_id INT PRIMARY KEY NOT NULL,
signup_date DATE,
country VARCHAR(50),
age INT,
gender VARCHAR(20),
loyalty_tier VARCHAR(30),
acquisition_channel VARCHAR(30))


--#Insert data to DIMENSION table
BULK INSERT ecommerce_silver.customers_dim
FROM 'C:\Users\lefte\SQL SSMS\sqldatasets\marketing_ecommerce\customers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0A')




------------------------------------------- Dataset Products (6 Columns)

--#Create DIMENSION table for products
CREATE TABLE ecommerce_silver.products_dim (
product_id INT PRIMARY KEY NOT NULL,
category VARCHAR(20),
brand VARCHAR(20),
base_price FLOAT,
launch_date DATE,
is_premium INT)

--#Insert data to  DIMENSION table
BULK INSERT ecommerce_silver.products_dim
FROM 'C:\Users\lefte\SQL SSMS\sqldatasets\marketing_ecommerce\products.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0A')




--------------------------------------------- Dataset Events (12 Columns)


--#Create FACT Staging table (ST) for events
CREATE TABLE ecommerce_silver.events_fact_stage (
event_id INT PRIMARY KEY NOT NULL,
events_timestamp VARCHAR(50),
customer_id INT,
session_id INT,
event_type VARCHAR(20),
product_id INT,
device_type VARCHAR(30),
traffic_source VARCHAR(30),
campaign_id INT,
page_category VARCHAR(20),
session_duration_sec FLOAT,
experiment_group VARCHAR(20),
FOREIGN KEY (customer_id) REFERENCES ecommerce_silver.customers_dim(customer_id),
FOREIGN KEY (product_id) REFERENCES ecommerce_silver.products_dim(product_id),
FOREIGN KEY (campaign_id) REFERENCES ecommerce_silver.campaigns_dim(campaign_id))

--#Insert data to  FACT ST table
BULK INSERT ecommerce_silver.events_fact_stage
FROM 'C:\Users\lefte\SQL SSMS\sqldatasets\marketing_ecommerce\events.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0A')



--#Create main events FACT table
CREATE TABLE ecommerce_silver.events_fact (
event_id INT PRIMARY KEY NOT NULL,
events_timestamp DATETIME ,
customer_id INT,
session_id INT,
event_type VARCHAR(20),
product_id INT,
device_type VARCHAR(30),
traffic_source VARCHAR(30),
campaign_id INT,
page_category VARCHAR(20),
session_duration_sec FLOAT,
experiment_group VARCHAR(20),
FOREIGN KEY (customer_id) REFERENCES ecommerce_silver.customers_dim(customer_id),
FOREIGN KEY (product_id) REFERENCES ecommerce_silver.products_dim(product_id),
FOREIGN KEY (campaign_id) REFERENCES ecommerce_silver.campaigns_dim(campaign_id))



--# Insert from FACT ST to main FACT table + convert timestamp + clean FK values
INSERT INTO ecommerce_silver.events_fact (
    event_id,
    events_timestamp,
    customer_id,
    session_id,
    event_type,
    product_id,
    device_type,
    traffic_source,
    campaign_id,
    page_category,
    session_duration_sec,
    experiment_group
)
SELECT
    event_id,
    CONVERT(DATETIME2, events_timestamp, 103),
    customer_id,
    session_id,
    event_type,
    NULLIF(product_id, ''),
    device_type,
    traffic_source,
    NULLIF(campaign_id, 0),
    page_category,
    session_duration_sec,
    experiment_group
FROM ecommerce_silver.events_fact_stage;

--#DROP events FACT ST
DROP TABLE ecommerce_silver.events_fact_stage



-------------------------------------- Dataset Transactions (9 Columns)
--# CREATE FACT ST Table
CREATE TABLE ecommerce_silver.transactions_fact_stage (
transaction_id INT PRIMARY KEY NOT NULL,
transaction_timestamp VARCHAR(50),
customer_id INT,
product_id INT,
quantity INT,
discount_applied FLOAT,
gross_revenue FLOAT,
campaign_id INT,
refund_flag INT,
FOREIGN KEY (customer_id) REFERENCES ecommerce_silver.customers_dim(customer_id),
FOREIGN KEY (product_id) REFERENCES ecommerce_silver.products_dim(product_id),
FOREIGN KEY (campaign_id) REFERENCES ecommerce_silver.campaigns_dim(campaign_id))




--#Insert data to table
BULK INSERT ecommerce_silver.transactions_fact_stage
FROM 'C:\Users\lefte\SQL SSMS\sqldatasets\marketing_ecommerce\transactions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0A')




--#Create main transaction FACT table
CREATE TABLE ecommerce_silver.transaction_fact (
transaction_id INT PRIMARY KEY NOT NULL,
transaction_timestamp DATETIME,
customer_id INT,
product_id INT,
quantity INT,
discount_applied FLOAT,
gross_revenue FLOAT,
campaign_id INT,
refund_flag INT,
FOREIGN KEY (customer_id) REFERENCES ecommerce_silver.customers_dim(customer_id),
FOREIGN KEY (product_id) REFERENCES ecommerce_silver.products_dim(product_id),
FOREIGN KEY (campaign_id) REFERENCES ecommerce_silver.campaigns_dim(campaign_id))

  
--# Insert from FACT ST to  FACT main table + convert timestamp + clean FK values
INSERT INTO ecommerce_silver.transaction_fact (
    transaction_id,
    transaction_timestamp,
    customer_id,
    product_id,
    quantity,
    discount_applied,
    gross_revenue,
    campaign_id,
    refund_flag
)
SELECT
    transaction_id,
    CONVERT(DATETIME2, transaction_timestamp, 103),
    customer_id,
    NULLIF(product_id, ''),
    quantity,
    discount_applied,
    gross_revenue,
    NULLIF(campaign_id, 0),
    refund_flag
FROM ecommerce_silver.transactions_fact_stage


--#DROP transactions  FACT ST
DROP TABLE ecommerce_silver.transactions_fact_stage

--- In case we had created schemas per dim table / analysis we would have left ST in our database as well for scalable solutions and data flow.
---- We end up having 3 dimension Tables (campaigns, customers, products) and 2 fact tables (events, transactions).


--######################## PART 2: Initial EDA #######################################




-------------- ecommerce_silver.campaigns_dim | First Exploration

-- Check number of rows
SELECT COUNT(*) FROM ecommerce_silver.campaigns_dim -- 50 rows

-- Quick check of top 10 rows - data - col
SELECT TOP 10 * FROM ecommerce_silver.campaigns_dim  

-- Check Primary Key is Unique
SELECT campaign_id, COUNT(*)
FROM ecommerce_silver.campaigns_dim 
GROUP BY campaign_id
HAVING COUNT(*) > 1  -- Result 0 -> PK is unique.


-- Check missing values

SELECT
COUNT(*) AS total_rows,
COUNT(campaign_id) AS campaign_id,
COUNT(channel) AS channel,
COUNT(objective) AS objective,
COUNT(start_date) AS start_date,
COUNT(end_date) AS end_date,
COUNT(target_segment) AS target_segment,
COUNT(expected_uplift) AS expected_uplift
FROM ecommerce_silver.campaigns_dim                  -- no missing values

-- Check Date Col: Min Start Date and Max End Date | we check the date ranges for campaigns

SELECT min(start_date) AS first_day_of_campaigns , max(end_date) AS last_day_of_campaigns 
FROM ecommerce_silver.campaigns_dim                                                                  -- first: 2021-01-21 , last: 2024 - 01 - 06. Campaings lasted for almost 3.5 years.


-- We can extract campaigns duration and MIN/MAX/AVG  campaign days using WINDOWS FUNCTIONS.

SELECT 
      campaign_id,
      start_date,
      DATEDIFF(DAY, start_date ,end_date) AS campaigns_duration, -- colUMN creation for later on -> views gold layer.
      end_date,
      AVG(DATEDIFF(DAY,start_date,end_date)) OVER() AS avg_campaigns_duration, -- 50 adys
      MIN(DATEDIFF(DAY,start_date,end_date)) OVER() AS min_campaigns_duration, -- 8 days
      MAX(DATEDIFF(DAY,start_date,end_date)) OVER() AS max_campaigns_duration -- 89 days
FROM ecommerce_silver.campaigns_dim
ORDER BY start_date ASC 



-- Now we check our ** categorican variables **


--# Check Channel 
SELECT channel, COUNT(*) AS total_campaigns_per_channel
FROM ecommerce_silver.campaigns_dim
GROUP BY channel
ORDER BY total_campaigns_per_channel DESC  -- 5 channels (Top: Affilaite, Low: Social)

--# Check objectives = Purpose of the campaign
SELECT objective, COUNT(*) AS campaings_number
FROM ecommerce_silver.campaigns_dim
GROUP BY objective
ORDER BY campaings_number DESC -- 4 objective (Top: Reactivation, Low: Acquisition)

--# Check Target Segments -> Customer Segments
SELECT target_segment, COUNT(*) AS total_target_segments
FROM ecommerce_silver.campaigns_dim
GROUP BY target_segment
ORDER BY total_target_segments DESC -- 5 Segments (Top: New Customers, Low: All)



-- Check Expected Uplift Distribution -> Expected rise in sales probability from campaigns

SELECT
    MIN(expected_uplift) AS min_uplift,
    MAX(expected_uplift) AS max_uplift,
    AVG(expected_uplift) AS avg_uplift
FROM ecommerce_silver.campaigns_dim



-------------- ecommerce_silver.customers_dim | First Exploration

--Check first 10 rows
SELECT TOP 10 * FROM ecommerce_silver.customers_dim  

-- Get total number of records
SELECT COUNT(*) FROM ecommerce_silver.customers_dim --100k rows

-- Check missing data
SELECT
COUNT(*) AS total_rows,
COUNT(customer_id) AS customer_id,
COUNT(signup_date) AS signup_date,
COUNT(country) AS country,
COUNT(age) AS age,
COUNT(gender) AS gender,
COUNT(loyalty_tier) AS loyalty_tier,
COUNT(acquisition_channel) AS acquisition_channel
FROM ecommerce_silver.customers_dim    -- no missing data

-- Check Uniquenesss of customer_id

SELECT customer_id, duplicate_count
FROM (
SELECT
    customer_id,
    COUNT(*) OVER (PARTITION BY customer_id) AS duplicate_count
FROM ecommerce_silver.customers_dim ) t
WHERE duplicate_count > 1  -- Unique PK 


--#Check min-max signupdate

SELECT min(signup_date) AS min_signup_date, max(signup_date) AS max_signup_date 
FROM ecommerce_silver.customers_dim -- Data spans from 2021-01-01 to 2023-12-31 , 3 full years 2021-2022-2023

--#Check age 

SELECT min(age) AS min_age, max(age) AS max_age, avg(age) AS avg_age
FROM ecommerce_silver.customers_dim  -- min: 18, max: 70, avg: 35

-- Let's check our "categorical columns"


--# Check country 

SELECT DISTINCT(country) 
FROM ecommerce_silver.customers_dim -- 7 countries 

SELECT country, COUNT(*) AS country_records
FROM ecommerce_silver.customers_dim
GROUP BY country
ORDER BY country_records DESC  -- 7 Countries (Top: US, Low: AU) 


--# Check gender
SELECT gender, COUNT(*) AS gender_counts
FROM ecommerce_silver.customers_dim
GROUP BY gender
ORDER BY gender_counts DESC -- 3 Genders(Male-Female-Other) (Top: Male, Low: Other)


--# Check loyalty_tier -> Loyalty status
SELECT loyalty_tier, COUNT(*) AS loyalty_tier_counts
FROM ecommerce_silver.customers_dim
GROUP BY loyalty_tier
ORDER BY loyalty_tier_counts DESC -- 4 Loyalty Levels (Top: Bronze, Low: Platinum) [Also  Silver & Gold]

--# Check acquisition_channel categories and counts

SELECT acquisition_channel, COUNT(*) AS acquisition_channel_number
FROM ecommerce_silver.customers_dim
GROUP BY acquisition_channel
ORDER BY acquisition_channel_number DESC -- 5 Channels (Top: Organic, Low: Referral) [Also, Paid Search, Social, Email]



-------------- ecommerce_silver.products_dim | First Exploration

--Check top 10 col - table inspection
SELECT TOP 10 * FROM ecommerce_silver.products_dim

--#Check total records/rows
SELECT COUNT(*) FROM ecommerce_silver.products_dim -- 2000 rows.


-- Check missing data
SELECT
COUNT(*) AS total_rows,
COUNT(product_id) AS product_id,
COUNT(category) AS category,
COUNT(brand) AS brand,
COUNT(base_price) AS base_price,
COUNT(launch_date) AS launch_date,
COUNT(is_premium) AS is_premium
FROM ecommerce_silver.products_dim   -- no missing data

--#Check uniqueness of product ID
SELECT product_id, duplicate_count
FROM (
SELECT
    product_id,
    COUNT(*) OVER (PARTITION BY product_id) AS duplicate_count
FROM ecommerce_silver.products_dim ) t
WHERE duplicate_count > 1  -- Unique PK !

--#Check Date Range for launch_date

SELECT min(launch_date) AS first_product_launch_date, max(launch_date) AS last_product_launch_date 
FROM ecommerce_silver.products_dim -- first: 2021-01-01 , -- last 2023-12-31 , 3 full years -> 2021-2022-2023


--#Let's check price , min, max, avg

SELECT MIN(base_price) AS min_price, MAX(base_price) AS max_price, AVG(base_price) AS avg_price
FROM ecommerce_silver.products_dim -- price ranges from 5.11 to 464.58 with avg to be 72.16 

--#Check how many products are premium
SELECT is_premium, COUNT (*) AS count_premium_products
FROM ecommerce_silver.products_dim
GROUP BY is_premium
ORDER BY count_premium_products -- is_premium: 0(no), 1(yes) - There are 1000 products which are premium and another 1000 which are not. (Balanced outcome)


--#Investigate how many product brands there are
SELECT COUNT(DISTINCT(brand)) FROM ecommerce_silver.products_dim -- 100

SELECT brand, COUNT (*) AS count_brand
FROM ecommerce_silver.products_dim
GROUP BY brand
ORDER BY count_brand DESC --there are 100 (Top: Brand 7 with 32 products and Low: bRAND 37 with 10 products) - ##Comment: We see that in each col "brand" word exists. That captures extra memory in our storage. Ideally we will think to keep only the number per cell afterwards.

--#Check how many categories there are

SELECT COUNT(DISTINCT(category)) FROM ecommerce_silver.products_dim -- 6

SELECT category, COUNT (*) AS category_numbers
FROM ecommerce_silver.products_dim
GROUP BY category
ORDER BY category_numbers DESC -- Top: Electronics with 455 and Low: Beauty with 201 [Extra Cat: Fashion-home-Grocery-Sports]



-------------- ecommerce_silver.transaction_fact | First Exploration

--#check top 10 rows
SELECT TOP 10 * FROM ecommerce_silver.transaction_fact -- I already see a missing campaing_id VALUE

--#check total numbers of records
SELECT COUNT(*) FROM ecommerce_silver.transaction_fact --- 103.127

--#Let's check how many NULL values we have per columns

SELECT
COUNT(*) AS total_rows,
COUNT(*) - COUNT(transaction_timestamp) AS transaction_timestamp,
COUNT(*) - COUNT(customer_id) AS customer_id,
COUNT(*) - COUNT(product_id) AS product_id, -- 10.449 missing values
COUNT(*) - COUNT(quantity) AS quantity,
COUNT(*) - COUNT(discount_applied) AS discount_applied,
COUNT(*) - COUNT(gross_revenue) AS gross_revenue, -- 10.449 missing values
COUNT(*) - COUNT(campaign_id) AS campaign_id, -- 20.995 NULL  values -> NULL indicates 0 campaings and will be replaced later on.
COUNT(*) - COUNT(refund_flag) AS refund_flag
FROM ecommerce_silver.transaction_fact    ---------------- We notice that we have 10.449 missing values for "product_id", 10.449 for "gross_revenue" [We checked and are on the same exact records]
                                   

--#Lets check the first and last transaction data point we have 

SELECT MIN(transaction_timestamp) AS first_transaction , MAX(transaction_timestamp) FROM ecommerce_silver.transaction_fact -- F: 2021-01-01 00:12 and L: 2023-12-31 22:37


--# Count the customers that proceed to a transaction and their records

SELECT COUNT(DISTINCT customer_id) FROM ecommerce_silver.transaction_fact -- 64035 UNIQUE customer_ids


SELECT customer_id, COUNT(*) AS customers_transactions
FROM ecommerce_silver.transaction_fact
GROUP BY customer_id
ORDER BY customers_transactions DESC -- TOP Customer 54521 with 9 transactions


--# Count the unique products that were sold and the count of them
SELECT COUNT(DISTINCT product_id) FROM ecommerce_silver.transaction_fact -- 2000 = All products were sold at least once


SELECT 
    product_id,
    COUNT(*) AS products_count,
    MAX(COUNT(*)) OVER () AS max_products_count,
    MIN(COUNT(*)) OVER () AS min_products_count
FROM ecommerce_silver.transaction_fact
WHERE product_id IS NOT NULL
GROUP BY product_id
ORDER BY products_count DESC -- NULL: 10.449 As we saw before.  Top product 1162 - sold 72 times \ Least popular product 1821 -> 26 times was sold

--#Count max - min quantities were sold 

SELECT quantity, COUNT(*) AS count_quantities 
FROM ecommerce_silver.transaction_fact
GROUP BY quantity
ORDER BY count_quantities DESC -- Max Quantity per transaction: 1  . That means that usually customers buy 1 quantity per product.  Min quantity ; 4 . 



--#Check the count and measure of discounts
SELECT discount_applied, COUNT(*) AS count_discounts 
FROM ecommerce_silver.transaction_fact
GROUP BY discount_applied
ORDER BY count_discounts DESC -- We have discounts from 0 to 0.20 with a step of 0.05. Half of our transactions did not have any discount (61.923) While 20% discount was applied opn 5050 transactions.


--Check Campaign ID / How many transactions did we have per campaign? (exclude NULL)

SELECT COUNT (DISTINCT campaign_id) FROM ecommerce_silver.transaction_fact --50 we have all campaigns

SELECT campaign_id, COUNT(*) AS count_campaings 
FROM ecommerce_silver.transaction_fact
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id
ORDER BY count_campaings DESC -- TOP: Campaign 44 created 2271 transactions , LOW: Campaign 1 946



--#Investigate gross revenue , MIN,MAX, AVG

SELECT
    MIN(gross_revenue) AS min_gross_revenue,
    MAX(gross_revenue) AS max_gross_revenue,
    AVG(gross_revenue) AS avg_gross_revenue
FROM ecommerce_silver.transaction_fact  -- Min: -873.04 (transaction canceled / product returned), Max: 1858.32 and AVG: 90.36




--#Check how many transactions were cancelled  // count the refunds

SELECT refund_flag, COUNT(*) AS refund_counts
FROM ecommerce_silver.transaction_fact
GROUP BY refund_flag
ORDER BY refund_counts DESC  -- Refund flag = 1 -> 3029 times the was a refund to a customer.






-------------- ecommerce_silver.events_fact | First Exploration --------- Event:  Customer Online Website Session 

--#Quick inspections top 10 rows
SELECT TOP 10 * FROM ecommerce_silver.events_fact

--#Check number of records
SELECT COUNT(*) FROM ecommerce_silver.events_fact -- Sth more than 1 million.

--#Check Uniqur Event_IDs

SELECT event_id, COUNT(*) count_events
FROM ecommerce_silver.events_fact
GROUP BY event_id
HAVING COUNT(*) > 1 -- Unique

--#Check Missing Data
SELECT 
COUNT(*) AS total_rows,
COUNT(*) - COUNT(events_timestamp) AS events_timestamp,
COUNT(*) - COUNT(customer_id) AS customer_id,
COUNT(*) - COUNT(session_id) AS session_id,
COUNT(*) - COUNT(event_type) AS event_type,
COUNT(*) - COUNT(product_id) AS product_id, -- 104.845 missing values
COUNT(*) - COUNT(device_type) AS device_type, -- 21.169 missing values
COUNT(*) - COUNT(traffic_source) AS traffic_source,
COUNT(*) - COUNT(campaign_id) AS campaign_id, -- 524.252 NULL values -> Actually, NULL indicate no campaign and will be replaced with 0 later on.
COUNT(*) - COUNT(page_category) AS page_category,
COUNT(*) - COUNT(session_duration_sec) AS session_duration_sec,
COUNT(*) - COUNT(experiment_group) AS experiment_group
FROM ecommerce_silver.events_fact


--#Let's check first and last timestamp event
SELECT MIN(events_timestamp) AS first_event , MAX(events_timestamp)  AS last_event FROM ecommerce_silver.events_fact -- F: 21-01-01 00:01 and L: 2023-12-31 23:57


--#Check number of customers from the events table
SELECT count(DISTINCT customer_id) FROM ecommerce_silver.events_fact --# 99.998  Unique customers In contrast to 100k from customers_dim table


--#Check events per customer
SELECT customer_id, COUNT(*) AS customers_events
FROM ecommerce_silver.events_fact
GROUP BY customer_id
ORDER BY customers_events DESC --#Top customer with the most events , customer 22709 with 30

--# How many actions/events happened in each visit/session? Session Groups events.
SELECT session_id, COUNT(*) AS session_counts
FROM ecommerce_silver.events_fact
GROUP BY session_id
ORDER BY session_counts DESC -- Not that informative yet

--#Unique session_ids
SELECT COUNT(DISTINCT session_id) AS count_sessions FROM ecommerce_silver.events_fact --#528098


--# Check the levels per event_type
SELECT event_type, COUNT(*) AS event_type_counts
FROM ecommerce_silver.events_fact
GROUP BY event_type
ORDER BY event_type_counts DESC -- Top: VIEW with more than 500k records, Low: PURCHASE with Less than 54k records [More levels: Click,  add_to_cart, bounce]


--# Check unique and number of  product_id in events table
SELECT COUNT(DISTINCT product_id) FROM ecommerce_silver.events_fact -- all products are included in the events table

--#Count product_idS Most Popular
SELECT product_id, COUNT(*) AS products_events_count
FROM ecommerce_silver.events_fact
WHERE product_id IS  NOT NULL
GROUP BY product_id
ORDER BY products_events_count DESC --# Most Popular product_id = 1023, with event_counts 548 times. That does not mean that it was the top sold item though.

--# Top sold product
SELECT product_id, COUNT(*) AS products_events_count
FROM ecommerce_silver.events_fact
WHERE product_id IS  NOT NULL AND event_type = 'purchase'
GROUP BY product_id
ORDER BY products_events_count DESC -- Product 4 was top sold product.

--#Check from which device do people usually create events
SELECT device_type, COUNT(*) AS device_type_events_counts
FROM ecommerce_silver.events_fact
GROUP BY device_type
ORDER BY device_type_events_counts DESC -- Top: Mobile, Low: tablet [Also, Desktop]

--#Check how users land to the website
SELECT traffic_source, COUNT(*) AS traffic_source_count
FROM ecommerce_silver.events_fact
GROUP BY traffic_source
ORDER BY traffic_source_count DESC  -- Most of the users come from Orhabic research and Paid Search while the minority comes from  "Direct" approach. [Also, Social and Email.] 


--#Check the number of events per campaign_id
SELECT campaign_id, COUNT(*) AS campaigm_id_count
FROM ecommerce_silver.events_fact
GROUP BY campaign_id
ORDER BY campaigm_id_count DESC -- Most events where created from no campaign. But the top campaign that created the most events is 20-14-25. 

--#Top campaign (QUICK CHECK)
SELECT campaign_id, COUNT(*) AS campaigm_id_count
FROM ecommerce_silver.events_fact
WHERE event_type = 'purchase'
GROUP BY campaign_id
ORDER BY campaigm_id_count DESC -- Campaign_id 44 Lead to 1211 Purchases ! 

--#Check the number of the pages where the event occured
SELECT page_category, COUNT(*) AS page_category_counts
FROM ecommerce_silver.events_fact
GROUP BY page_category
ORDER BY page_category_counts DESC -- Top Page PLP and PDP with more than 300k events while least visited page is "Cart" [Also, Home n Checkout].



--#Lets check now the min, max and avg duration per session.
SELECT MIN(session_duration_sec) AS min_sess_dur_seconds , MAX(session_duration_sec)/60 AS max_sess_dur_minutes, AVG(session_duration_sec)/60 AS avg_sess_dur_minutes FROM ecommerce_silver.events_fact 
-- min 0.1 sec, max 122 Minutes and AVERAGE 2.2 minutes.


--#Lastly, lets see how many experiment groups we have and the distribution of the number of events within it.
SELECT experiment_group, COUNT(*) AS experiment_group_counts
FROM ecommerce_silver.events_fact
GROUP BY experiment_group
ORDER BY experiment_group_counts DESC -- Control with more than 625k cases , Variant_A n Variant_B with around 210k cases.




--######################## PART 3: DATA CLEANING & TRANSFORMATION #######################################

---COMMENT: Ideally we would have kept the raw data (bronze layer) and then transform the dim and fact tables that we have currently (silver layer) (ETL) but for storage purposes we load directly the data and transform them. (ELT)


--#Quik inspection of our tables | Decide for the necessary cleaning/transformation


--# Check Table ecommerce_silver.campaigns_dim
SELECT * FROM ecommerce_silver.campaigns_dim -- expected_uplift: we will convert it to % for better understanding and business logic and we will create a new col for the duration of the campaign in days.

--## Transform Table ecommerce_silver.campaigns_dim
--# 1) Change col name for expected_uplift
EXEC sp_rename 
'ecommerce_silver.campaigns_dim.expected_uplift', 
'expected_uplift_pct', 
'COLUMN'

--# 2) convert expected_uplift's numbers to %

UPDATE ecommerce_silver.campaigns_dim
SET expected_uplift_pct = ROUND(expected_uplift_pct * 100,2)

--ALTER TABLE ecommerce_silver.campaigns_dim
--ALTER COLUMN expected_uplift_pct DECIMAL(5,2) -- for 2 decimal points.


--# 3) Create new Col "campaigns_duration_days"

ALTER TABLE ecommerce_silver.campaigns_dim
ADD campaigns_duration_days INT 

UPDATE  ecommerce_silver.campaigns_dim
SET campaigns_duration_days = DATEDIFF(DAY,start_date,end_date)




--## Check Table ecommerce_silver.products_dim 
SELECT * FROM ecommerce_silver.products_dim -- brand: we will keep only the numbers and we exclude the "Brand_" from each cell.

--# 1) Remove "Brand_" characters from brand column
UPDATE ecommerce_silver.products_dim
SET brand = SUBSTRING(brand,CHARINDEX('_',brand) + 1, LEN(brand))


--## Check Table ecommerce_silver.customers_dim
SELECT * FROM ecommerce_silver.customers_dim --  age: Create  age groups - segments, for easier analysis. Individual ages are harder to analyze.

--# 1) create new col  "age-group"
ALTER TABLE ecommerce_silver.customers_dim
ADD age_group VARCHAR(20)


--# 2) Create "age-group" levels
UPDATE ecommerce_silver.customers_dim
SET age_group = 
    CASE 
       WHEN age < 25 THEN '18-24'
       WHEN age BETWEEN 25 AND 34 THEN '25-34'
       WHEN age BETWEEN 35 AND 44 THEN '35-44'
       WHEN age BETWEEN 45 AND 54 THEN '45-54'
       ELSE '55+'
    END



--## Check Table  ecommerce_silver.events_fact 
SELECT * FROM ecommerce_silver.events_fact -- event_type: from the level "add_to_cart" we will keep the word "cart" to increase the memory capacity of our storage. [more data engineering logic]. 
                                    -- campaign_id : We replace the NULL values with 0 as this means that there was no campaign. [Based on the dataset's documentation]
                                    -- We will keep the timestamp as it is for now and we might alter it later.

--# 1) transform "add_to_cart" to "cart"
UPDATE ecommerce_silver.events_fact
SET event_type = 
CASE 
    WHEN CHARINDEX('_', event_type) > 0 
    THEN RIGHT(event_type, CHARINDEX('_', REVERSE(event_type)) - 1)
    ELSE event_type
END

--# 2) Replace NULL values of campaign_id with 0 

UPDATE ecommerce_silver.events_fact
SET campaign_id = ISNULL(campaign_id,0)  --## FAILED
WHERE campaign_id IS NULL                --## FAILED

--The reason of failure for the above query is because "campaing_id" is a foreign key of the "ecommerce_silver.campaign_dim" and there is no campaing_id = 0 in that table.
-- For that reason, we are going to create an unknown campaign record, in the dimension table and map the null foreign keys to 0.
INSERT INTO ecommerce_silver.campaigns_dim (campaign_id, channel, objective, start_date, end_date, target_segment, expected_uplift_pct, campaigns_duration_days)
VALUES (0, 'Unknown', 'Unknown', NULL, NULL, 'Unknown', 0.00, 0) --The extra row that was created on campaign_dim table will be ingonred later on for our analysis

-- Next we run the above query again.
UPDATE ecommerce_silver.events_fact
SET campaign_id = 0
WHERE campaign_id IS NULL -- around 500k rows affected - no campaign ;)

--# Check NULL values from campaing_id col have been converted to 0.
SELECT * FROM ecommerce_silver.events_fact
WHERE campaign_id IS NULL -- 0.




--## Check Table ecommerce_silver.transaction_fact
SELECT * FROM ecommerce_silver.transaction_fact -- campaign_id : We replace the NULL values with 0 as this means that there was no campaign. [Based on the dataset's documentation]

--# 1) Replace NULL Values with 0 on campaign_id column

UPDATE ecommerce_silver.transaction_fact
SET campaign_id = 0
WHERE campaign_id IS NULL -- 20.995 rows affected


--# 2) As we saw before, product_id and gross_revenue have 10.449 NULL values on the same records.- Data quality issue
--#    We will treat these rows as incomplete transaction records. Thus, we will flag them as invalid.

ALTER TABLE ecommerce_silver.transaction_fact
ADD valid_transaction_flag BIT

UPDATE ecommerce_silver.transaction_fact
SET valid_transaction_flag = 
    CASE 
        WHEN product_id IS NULL AND gross_revenue IS NULL THEN 0
        ELSE 1
    END

-----------------------------------------     Define gold_layer_views for our Analysis    ----------------------------------------
/*
Here, we are going to create the following views in the gold layer.

VIEWS:
1) ecommerce_gold.sales_base
2) ecommerce_gold.product_performance
3) ecommerce_gold.campaign_performance 
4) ecommerce_gold.time_sales  
5) ecommerce_gold.customer_behavior
6) ecommerce_gold.event_behavior

The above datasets will help us proceed with

- product analysis
- transaction analysis
- campaign analysis
- discount analysis
- customer behavior insights/analysis
- time-series analysis
- A/B Testing
- KPI Analysis/Reporting

*/


--# CREATE THE GOLD SCHEMA for VIEWS

CREATE SCHEMA ecommerce_gold


--# Create View 1) ecommerce_gold.sales_base

CREATE VIEW ecommerce_gold.sales_base AS
SELECT CAST(t.transaction_timestamp AS DATE) AS transaction_date,
       t.customer_id,
       t.product_id,
       t.quantity,
       t.discount_applied,
       t.gross_revenue,
       t.campaign_id,
       camp.objective
FROM ecommerce_silver.transaction_fact AS t
LEFT JOIN ecommerce_silver.customers_dim AS c
ON t.customer_id = c.customer_id
LEFT JOIN ecommerce_silver.products_dim AS p
ON t.product_id = p.product_id
LEFT JOIN ecommerce_silver.campaigns_dim AS camp
ON t.campaign_id = camp.campaign_id
WHERE p.product_id IS NOT NULL 



--# Create View 2) ecommerce_gold.product_performance


CREATE VIEW ecommerce_gold.product_performance AS
SELECT
    p.product_id,
    p.base_price,
    p.category,
    SUM(t.quantity) AS total_units_sold,
    ROUND(SUM(t.gross_revenue),1) AS total_revenue
FROM ecommerce_silver.products_dim AS p
LEFT JOIN ecommerce_silver.transaction_fact AS t
    ON p.product_id = t.product_id
WHERE t.product_id IS NOT NULL
  AND t.gross_revenue IS NOT NULL
 GROUP BY
   p.product_id,
   p.category,
   p.base_price

--# Create View 3) ecommerce_gold.campaign_performance 

CREATE  VIEW ecommerce_gold.campaign_performance AS
    SELECT
    cam.campaign_id,
    cam.channel,
    cam.target_segment,
    t.quantity,
    t.gross_revenue,
    cam.campaigns_duration_days
FROM ecommerce_silver.campaigns_dim AS cam
LEFT JOIN ecommerce_silver.transaction_fact AS t
    ON cam.campaign_id = t.campaign_id
WHERE t.gross_revenue IS NOT NULL AND channel <> 'Unknown'




--# Create View 4) ecommerce_gold.time_sales  

CREATE VIEW ecommerce_gold.time_sales AS
SELECT
    CAST(t.transaction_timestamp AS DATE) AS transaction_date,
    YEAR(t.transaction_timestamp) AS sales_year,
    MONTH(t.transaction_timestamp) AS sales_month,
    COUNT(t.transaction_id) AS total_transactions,
    SUM(t.quantity) AS total_units_sold,
    SUM(t.gross_revenue) AS total_revenue
FROM ecommerce_silver.transaction_fact AS t
WHERE t.gross_revenue IS NOT NULL
GROUP BY
    CAST(t.transaction_timestamp AS DATE),
    YEAR(t.transaction_timestamp),
    MONTH(t.transaction_timestamp)

--# Create View 5) ecommerce_gold.customer_behavior

CREATE VIEW ecommerce_gold.customer_behavior AS
SELECT
    c.customer_id,
    c.country,
    c.age_group,
    COUNT(t.transaction_id) AS total_orders,
    SUM(t.gross_revenue) AS total_spent,
    ROUND(AVG(t.gross_revenue),2) AS avg_order_value
FROM ecommerce_silver.customers_dim AS c
LEFT JOIN ecommerce_silver.transaction_fact AS t
    ON c.customer_id = t.customer_id
WHERE t.gross_revenue IS NOT NULL
GROUP BY
    c.customer_id,
    c.country,
    c.age_group


--# Create View 6) ecommerce_gold.event_behavior

CREATE VIEW ecommerce_gold.event_behavior AS
SELECT
    e.event_id,
    c.customer_id,
    cam.campaign_id,
    c.age_group,
    cam.channel,
    e.session_duration_sec,
    e.event_type
FROM ecommerce_silver.events_fact AS e
LEFT JOIN ecommerce_silver.customers_dim AS c
    ON e.customer_id = c.customer_id
LEFT JOIN ecommerce_silver.products_dim AS p
    ON e.product_id = p.product_id
LEFT JOIN ecommerce_silver.campaigns_dim AS cam
    ON e.campaign_id = cam.campaign_id
WHERE e.product_id IS NOT NULL



--######################## PART 4: DATA ANALYSIS #######################################

--######## VIEW: 1 Ecommerce_gold.sales_base

--# 1️.1 Top transactions ranking (TOP 10)

WITH ranked_transactions AS (
    SELECT
        transaction_date,
        customer_id,
        product_id,
        quantity,
        gross_revenue,
        RANK() OVER (ORDER BY gross_revenue DESC) AS revenue_rank
    FROM ecommerce_gold.sales_base
)
SELECT *
FROM ranked_transactions
WHERE revenue_rank <= 10
ORDER BY revenue_rank    -- Top 1: 1858.32  -- Product_id 496 most common product as a top driver to generate the highest gross revenue (appears 5 times within top 10 transactions).

--# Quick check of product_id 496
SELECT base_price,product_id 
FROM ecommerce_gold.product_performance -- 496 product_id most expensive ! -> costs 464.58
ORDER BY base_price  DESC



--# 1.2 Discount impact on revenue - 
WITH discount_analysis AS (
   SELECT
        discount_applied,
        gross_revenue,
        quantity
    FROM ecommerce_gold.sales_base
)
SELECT
     CASE 
        WHEN discount_applied = 0 THEN 'Yes'
        ELSE 'No'
     END AS discount_status,
     COUNT(*) AS Total_transactions,
     SUM(quantity) AS total_quantity,
     ROUND(SUM(gross_revenue),2) AS total_revenue,
     ROUND(AVG(gross_revenue),2) AS avg_order_revenue
FROM discount_analysis
GROUP BY
      CASE 
        WHEN discount_applied = 0 THEN 'Yes'  -- Transactions were increased by 50% when there was a discount. Discount increase purchase frequency. Also, customers buy more products.
        ELSE 'No'                            -- Discounts are driving more than 65% of the total revenue.
     END 

 


--# 1.3 Discount bucket analysis

WITH discount_buckets AS (
    SELECT
        gross_revenue,
        quantity,
        discount_applied
    FROM ecommerce_gold.sales_base
)
SELECT
    discount_applied,
    COUNT(*) AS total_transactions,
    SUM(quantity) AS total_units_sold,
    ROUND(SUM(gross_revenue),2) AS total_revenue,
    ROUND(AVG(gross_revenue),2) AS avg_order_value -- We notice that the higher the discount the least the transactions the units sold and the total revenue. 
FROM discount_buckets                              -- Out of all discounts -  the 5% generated the most revenue.
GROUP BY discount_applied                          -- Top revenue is reached without discounts.
ORDER BY total_revenue DESC



--# 1.4 Campaign vs non-campaign A/B comparison with and without Discount

WITH campaign_ab_test AS (
     SELECT 
         CASE   
             WHEN campaign_id = 0 THEN 'Control - No Campaing'
             ELSE 'Treatment - Campaing'
         END AS campaign_group_test,
         gross_revenue,
         CASE   
             WHEN discount_applied = 0 THEN 'No Discount'
             ELSE 'Yes Discount'
         END AS discount_status,
         quantity
     FROM ecommerce_gold.sales_base
)
    SELECT                                               -- Campaign occurance increases significantly the transaction volume and revenue
         campaign_group_test,                            -- On the other hand, discounts generate lower average order value and revenue in contrast to full price.
         discount_status,                                
         COUNT(*) AS total_transactions,                 -- Lastly, the most revenue is generated with campaign and without a discount.
         SUM(quantity) AS total_units_sold,
         SUM(gross_revenue) AS total_revenue,
         ROUND(AVG(gross_revenue),2) AS avg_order_value    
    FROM campaign_ab_test
    GROUP BY campaign_group_test, discount_status

   


--# 1.5 KPI dashboard query

WITH kpi_base AS (
    SELECT
        customer_id,
        quantity,
        gross_revenue,
        discount_applied
    FROM ecommerce_gold.sales_base
)
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(quantity) AS total_units_sold,
    ROUND(SUM(gross_revenue),2) AS total_revenue,
    ROUND(AVG(gross_revenue),2) AS avg_order_value,
    AVG(quantity * 1.0) AS avg_units_per_order,
    SUM(CASE WHEN discount_applied > 0 THEN 1 ELSE 0 END) AS discounted_orders,
    CAST(
        100.0 * SUM(CASE WHEN discount_applied > 0 THEN 1 ELSE 0 END) / COUNT(*)
        AS DECIMAL(5,2)
    ) AS discount_penetration_pct
FROM kpi_base                        -- Total transactions ~ 92k , Total Customers: ~ 60k , Total Units sold ~ 128k , AOV ~ 90. Total revenue ~ 8.4 m . Almost 40% of the products were sold under a discount.

-- General Performance Evaluation.



--######## VIEW: 2 ecommerce_gold.product_performance


--# 2.1 Top 10 Performing Products by Revenue


WITH top_10_products AS (
SELECT
    product_id,
    category,
    total_revenue,
    total_units_sold,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM ecommerce_gold.product_performance
)
  SELECT TOP 10 * 
  FROM top_10_products

  -- As we saw earlier product_id = 496 generates the most revenue. In addition, 9/10 top products that produce the highest revenue belong to Electronics category.


  --# 2.2 Category Performance Analysis

  SELECT
    category,
    COUNT(product_id) AS number_of_products,
    SUM(total_units_sold) AS units_sold,
    SUM(total_revenue) AS total_revenue,
    ROUND(AVG(total_revenue),2) AS avg_product_revenue    -- Top 3: Electronics , Home, Fashion based on revenue generation.
FROM ecommerce_gold.product_performance
GROUP BY category
ORDER BY total_revenue DESC

 --# 2.2.1 Category Performance Analysis in %

SELECT
    category,
    SUM(total_revenue) AS total_revenue,
    ROUND(
        100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (),
        2
    ) AS revenue_share_pct
FROM ecommerce_gold.product_performance
GROUP BY category
ORDER BY total_revenue DESC




--# 2.3 Price vs Sales Performance
SELECT
    CASE
        WHEN base_price < 50 THEN 'Low Price'
        WHEN base_price BETWEEN 50 AND 100 THEN 'Mid Price'
        WHEN base_price BETWEEN 100 AND 200 THEN 'High Price'
        ELSE 'Extreme High Price'
    END AS price_segment,
    COUNT(product_id) AS products,
    SUM(total_units_sold) AS units_sold,
    SUM(total_revenue) AS total_revenue
FROM ecommerce_gold.product_performance                   -- The most revenue is generated from the "High Price" level while the least from the "Extreme High Price".
GROUP BY
    CASE
        WHEN base_price < 50 THEN 'Low Price'
        WHEN base_price BETWEEN 50 AND 100 THEN 'Mid Price'
        WHEN base_price BETWEEN 100 AND 200 THEN 'High Price'
        ELSE 'Extreme High Price'
    END
ORDER BY total_revenue DESC


--######## VIEW: 3 ecommerce_gold.campaign_performance 

--# We have already done some first analysis from the sales_base view so we proceed with other type of analysis here


--# 3.1 Best Campaigns by Revenue (TOP 10)

WITH TOP_10_campaigns AS(
 SELECT 
    campaign_id,
    SUM(gross_revenue) AS total_revenue,
    RANK() OVER (ORDER BY SUM(gross_revenue) DESC) AS revenue_rank  -- TOP 10: 18,5,29 etc etc etc...
FROM ecommerce_gold.campaign_performance
GROUP BY campaign_id
)
SELECT TOP 10 *
FROM TOP_10_campaigns



--# 3.2 Channels by Campaigns performance and revenue in % 
SELECT
    channel,
    COUNT(*) AS campaigns,
    SUM(gross_revenue) AS total_revenue,
    100.0 * SUM(gross_revenue) / SUM(SUM(gross_revenue)) OVER () AS revenue_share_pct  -- "Affiliate" channel raises the most campaings ~18k and 24% of the total revenue.
FROM ecommerce_gold.campaign_performance                                               -- Followed by "Paid Search" and "Email" with 22% and 20$ of revenue, respectively.
GROUP BY channel
ORDER BY total_revenue DESC



--# 3.3 Campaign Objective Performance
SELECT
    objective,
    COUNT(*) AS transactions,
    SUM(quantity) AS units_sold,
    ROUND(SUM(gross_revenue),2) AS total_revenue,                                      -- "Reactivation" & "Retention" objectives perform best holding a 23% adn 21% of revenue, respectively.
    100.0 * SUM(gross_revenue) / SUM(SUM(gross_revenue)) OVER () AS revenue_share_pct, 
    ROUND(AVG(gross_revenue),2) AS avg_order_value
FROM ecommerce_gold.sales_base
GROUP BY objective
ORDER BY total_revenue DESC



--# 3.4 Target Segment Performance - Which segments generates the most revenue

SELECT
    target_segment,
    COUNT(*) AS transactions,
    SUM(quantity) AS units_sold,
    SUM(gross_revenue) AS total_revenue,    -- New Customers and Deal Seekers generates the most value while the smallest value is generated by "all".
    AVG(gross_revenue) AS avg_order_value
FROM ecommerce_gold.campaign_performance
gROUP BY target_segment
ORDER BY total_revenue DESC

--# 3.5 Top 3 Most Efficient Campaigns per Channel (Revenue per Campaign Day)

WITH campaign_revenue AS (
    SELECT
        campaign_id,
        channel,
        campaigns_duration_days,
        SUM(gross_revenue) AS total_revenue
    FROM ecommerce_gold.campaign_performance
    GROUP BY
        campaign_id,
        channel,     
        campaigns_duration_days
),
campaigns_ranked AS (                                                  -- Overall, We see that the most effective days of duration_days is 8-9 which drives the most revenue per day
SELECT
    campaign_id,
    channel,
    campaigns_duration_days,
    total_revenue,
    ROUND(total_revenue * 1.0 / campaigns_duration_days, 2) AS revenue_per_day,
    RANK() OVER (
        PARTITION BY channel
        ORDER BY total_revenue * 1.0 / campaigns_duration_days DESC
    ) AS channel_rank
FROM campaign_revenue
)

SELECT * FROM campaigns_ranked
WHERE channel_rank < = 3



--######## VIEW: 4 ecommerce_gold.time_sales  

--# 4.1 Monthly Revenue Trend in % for all months across 2021-2022-2023
SELECT
    sales_month,
    SUM(total_revenue) AS monthly_revenue,
    SUM(total_transactions) AS monthly_transactions,
    SUM(total_units_sold) AS monthly_units,
    ROUND(
        100.0 * SUM(total_revenue) /
        SUM(SUM(total_revenue)) OVER (),    -- As it seems, November and December were the months with the most transactions, units sold and highest percentage over 10%.
        2
    ) AS revenue_pct
FROM ecommerce_gold.time_sales
GROUP BY sales_month
ORDER BY sales_month


--# 4.2 Yearly Revenue Trend for 2021-2022-2023
SELECT
    sales_year,
    SUM(total_revenue) AS yearly_revenue,
    SUM(total_transactions) AS yearly_transactions,
    SUM(total_units_sold) AS yearly_units,
    ROUND(
        100.0 * SUM(total_revenue) /
        SUM(SUM(total_revenue)) OVER (),    -- We see that across all years, transactions-units-revenue remain on the same number levels without significant changes.
        2                                   --* Only the first year it is noticeable a minor increase into these 3 measures.
    ) AS revenue_pct
FROM ecommerce_gold.time_sales
GROUP BY sales_year
ORDER BY sales_year



--# 4.3 Month over Month Revenue Growth

WITH monthly_sales AS (
    SELECT
        sales_year,
        sales_month,
        SUM(total_revenue) AS monthly_revenue
    FROM ecommerce_gold.time_sales
    GROUP BY sales_year, sales_month            -- Every Year, We see the highest revenue changes in November (20%+) while the bighest drop to happen in January (~20%).
),
monthly_lag AS (
    SELECT
        sales_year,
        sales_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            ORDER BY sales_year, sales_month
        ) AS previous_month_revenue
    FROM monthly_sales
)

SELECT
    sales_year,
    sales_month,
    monthly_revenue,
    previous_month_revenue,
    ROUND(
        100.0 * (monthly_revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0),
        2
    ) AS revenue_change_pct
FROM monthly_lag
ORDER BY sales_year, sales_month


--# 4.4 Demand Trend per Quarter per Year

SELECT
    sales_year,
    DATEPART(QUARTER, transaction_date) AS sales_quarter,
    SUM(total_transactions) AS quarterly_transactions,
    SUM(total_units_sold) AS quarterly_units
FROM ecommerce_gold.time_sales                              -- We see that the last Quarter of each year the transactions and units sold reach their highest number while the lost one is reached the 1st quarter.
GROUP BY                                                    -- Q2 & Q3 seems to be more or less on the same levels.
    sales_year,
    DATEPART(QUARTER, transaction_date)
ORDER BY
    sales_year,
    sales_quarter



--######## VIEW: 5 ecommerce_gold.customer_behavior

--# 5.1 Customer Spending Segmentation

SELECT
    CASE
        WHEN total_spent < 100 THEN 'Low Value'
        WHEN total_spent BETWEEN 100 AND 300 THEN 'Medium Value'
        ELSE 'High Value'
    END AS customer_segment,
    COUNT(*) AS customers,                                             -- Most customers belong to the "low value" segment with the lowest avg_spending.
    ROUND(AVG(total_spent),2) AS avg_spending,                         -- "Medium Value" customers spents the most out of all segments.
    ROUND(SUM(total_spent),2) AS total_spent                           -- "High Value" customers generate the 2nd highest spent but they have the 1st highest avg_spending.
FROM ecommerce_gold.customer_behavior
WHERE total_spent > 0
GROUP BY
    CASE
        WHEN total_spent < 100 THEN 'Low Value'
        WHEN total_spent BETWEEN 100 AND 300 THEN 'Medium Value'
        ELSE 'High Value'
    END
ORDER BY avg_spending DESC

--# 5.2 Top Customers by Total Spending
WITH top_10_customers AS(
SELECT
    customer_id,
    country,
    age_group,
    total_spent,
    RANK() OVER (ORDER BY total_spent DESC) AS spending_rank  -- Check Top 10 customers with the highest spent. IDs 11800 n' 72115 Top 2!
FROM ecommerce_gold.customer_behavior  
)
SELECT TOP  10 *
FROM top_10_customers                                  


--# 5.3 Customer Performance per Region

SELECT
    country,
    COUNT(*) AS customers,
    SUM(total_orders) AS total_orders,
    ROUND(SUM(total_spent),2) AS total_revenue,             --- USA and India has the highest number of orders and revenue while Germany(DE) and Austria has the lowest numbers.
    ROUND(AVG(avg_order_value),2) AS avg_order_value        --- It is worth to be mentioned that in UK the AOV is higher than than of USA despite the fact that UK comes on the 3rd place in terms of total_revenue.
FROM ecommerce_gold.customer_behavior
GROUP BY country
ORDER BY total_revenue DESC


--# 5.4 Spending Behavior per Age_Group

SELECT
    age_group,
    COUNT(*) AS customers,
    ROUND(SUM(total_spent),2) AS total_revenue,          -- Most of the customers belong to the age groups "25-34" & "35-44", Overally [25-44 y.o.].
    ROUND(AVG(avg_order_value),2) AS avg_order_value     -- The "35-44" age groups reach brings the highest revenue at ~ 3m followed by "25-34" with 2.8m
FROM ecommerce_gold.customer_behavior                    -- The age_group "55+" creates the lowest revenue.
GROUP BY age_group                                       -- Noticeable the fact that within the age group "18-24" the AOV is higher in contrast to the rest. That shows a trend for young people to buy more.
ORDER BY total_revenue DESC



--######## VIEW: 6 ecommerce_gold.event_behavior

--# 6.1 Event Funnel Analysis

SELECT
    event_type,                                                                   -- Here we check how events are distributed across the event_type
    COUNT(*) AS total_events,                                                     -- More than 55% of the event_type = view
    CAST(ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),2 ) AS FLOAT) AS event_pct   -- Around ~16% of the events_type = cart which means times people added products in their cart
FROM ecommerce_gold.event_behavior                                                   -- Only 5% of the events is a purchase. So, 1/20 times of the people's actions within the website is a purchase.
GROUP BY event_type
ORDER BY total_events DESC



--# 6.2 Conversion Funnel by Channel - Let's check how many evens occur at each stage of the funnel for channels

SELECT
    channel,
    event_type,
    COUNT(*) AS events
FROM ecommerce_gold.event_behavior                                                  -- Channels "Paid Search" and "Affiliate" have the highest numbers of events_types = 'Purchase'.
GROUP BY channel, event_type                                                        -- These channels lead more times customers to purchase products.
ORDER BY channel, event_type                                                        -- "Socia" n "Display" channels tracked the lowest numbers of "purchase" event types.



--# 6.3 Conversion Rate Between Funnel Stages

WITH funnel_counts AS (
    SELECT
        COUNT(CASE WHEN event_type = 'view' THEN 1 END) AS views,                  -- We see that Only 36% of views convert to clicks (64% drop - off / Big), while 75% of clicks lead to carts, indicating strong engagement after interaction.
        COUNT(CASE WHEN event_type = 'click' THEN 1 END) AS clicks,                -- However, only 32% of carts convert to purchases, suggesting the main drop-off occurs at checkout.
        COUNT(CASE WHEN event_type = 'cart' THEN 1 END) AS carts,
        COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchases
    FROM ecommerce_gold.event_behavior
)

SELECT
    views,
    clicks,
    carts,
    purchases,

    CAST(ROUND(100.0 * clicks / views, 2) AS FLOAT) AS view_to_click_rate_pct,
    CAST(ROUND(100.0 * carts / clicks, 2) AS FLOAT) AS click_to_cart_rate_pct,
    CAST(ROUND(100.0 * purchases / carts, 2) AS FLOAT) AS cart_to_purchase_rate_pct
FROM funnel_counts

--# 6.4 Average Session Duration by Event Type 

SELECT
    event_type,
    COUNT(*) AS events,
    CAST(ROUND(AVG(session_duration_sec),2) AS FLOAT) AS avg_session_duration_sec  -- In all of event_types avg session duration is 129-130 sec.
FROM ecommerce_gold.event_behavior
GROUP BY event_type
ORDER BY avg_session_duration_sec DESC


--# 6.5 Engagement by Marketing Channel
SELECT
    channel,
    COUNT(*) AS events,                                                               -- "Display" channel captures the highest avg session duration with 131.05 while "Social" comes last with 129.66
     CAST(ROUND(AVG(session_duration_sec),2) AS FLOAT) AS avg_session_duration_sec    -- As we can see avg_session_duration is more or less spread almost equally across all channels.
FROM ecommerce_gold.event_behavior
GROUP BY channel
ORDER BY avg_session_duration_sec DESC

--# 6.6 Session Duration by Age Group


SELECT
    age_group,
    CAST(ROUND(AVG(session_duration_sec),2) AS FLOAT) AS avg_session_duration        -- Age group "55+" tends to spend a bit more time on the website while "45-54" age group spends the least time.
FROM ecommerce_gold.event_behavior
GROUP BY age_group
ORDER BY avg_session_duration DESC






--######################## PART 5: SUMMARY & COMMENTS #######################################

/*

In this project, the raw CSV files were loaded into SQL Server and transformed into a structured analytical model.
The data was organized into a Silver layer with 3 dimension tables:
- ecommerce_silver.campaigns_dim
- ecommerce_silver.customers_dim
- ecommerce_silver.products_dim

and 2 fact tables:
- ecommerce_silver.transaction_fact
- ecommerce_silver.events_fact

The approach included:
- staging tables where needed
- data type conversion
- missing value handling
- foreign key cleaning
- column transformations
- creation of business-friendly fields such as age groups, campaign duration, and expected uplift percentage

After that, a Gold layer was created with analytical views:
- ecommerce_gold.sales_base
- ecommerce_gold.product_performance
- ecommerce_gold.campaign_performance
- ecommerce_gold.time_sales
- ecommerce_gold.customer_behavior
- ecommerce_gold.event_behavior

These views were used to perform:
- transaction and sales analysis
- discount analysis
- A/B style campaign vs non-campaign comparisons
- KPI and performance metrics reporting
- product and category analysis
- campaign and channel performance analysis
- customer segmentation and behavior analysis
- time-series sales trend analysis
- funnel and event engagement analysis

The project also demonstrates the use of joins, CTEs, window functions, aggregations, and business-oriented SQL analysis.

Important note:
The datasets were synthetically generated with Python, so some relationships, patterns, and results may not be fully realistic or highly informative from a real business perspective. Therefore, the analysis should be interpreted mainly as a technical SQL analytics project and not as a fully representative real-world business case.

*/



------------------------------------------------------------------------- END ----------------------------------------------------------------------------






