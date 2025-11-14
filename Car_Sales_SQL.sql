SELECT * FROM car_sales.car_sales;
USE car_sales;

SET SQL_SAFE_UPDATES = 0;

CREATE TABLE SALES_FACT AS
SELECT
    Sales_Order_ID,
    Customer_Name_ID,
    Dealer_Name_ID,
    Brand_Name_ID,
    Model
FROM car_sales;

SHOW INDEX FROM car_sales;


CREATE TABLE CUSTOMER_DIM_CLEAN AS
SELECT 
    CAST(Customer_Name_ID AS CHAR(100)) AS Customer_Name_ID,  -- convert BLOB to VARCHAR
    MIN(Gender) AS Gender,
    MIN(`Annual Income`) AS Annual_Income,
    MIN(`Income Level`) AS Income_Level
FROM car_sales
WHERE Customer_Name_ID IS NOT NULL
GROUP BY CAST(Customer_Name_ID AS CHAR(100));
ALTER TABLE CUSTOMER_DIM_CLEAN RENAME TO CUSTOMER_DIM;


CREATE TABLE DEALER_DIM AS
SELECT 
    CAST(TRIM(Dealer_Name_ID) AS CHAR(100)) AS Dealer_Name_ID,
    ROW_NUMBER() OVER (
        ORDER BY CAST(TRIM(Dealer_Name_ID) AS CHAR(100))
    ) AS `Index`
FROM car_sales
WHERE Dealer_Name_ID IS NOT NULL
GROUP BY CAST(TRIM(Dealer_Name_ID) AS CHAR(100));


CREATE TABLE BRAND_DIM AS
SELECT
    Brand_Name_ID,
    ROW_NUMBER() OVER (
        ORDER BY Brand_Name_ID
    ) AS `Index`
FROM car_sales
WHERE Brand_Name_ID IS NOT NULL
GROUP BY Brand_Name_ID;



CREATE TABLE MODEL_DIM AS
SELECT
    Model,
    MIN("Car Category") AS Car_Category,
    MIN(Engine) AS Engine,
    MIN(Transmission) AS Transmission,
    MIN(Brand_Name_ID) AS Brand_Name_ID,
    MIN(`Body Style`) AS Body_Style,
    MIN("Price ($)") AS Price,
    MIN(Color) AS Color
FROM car_sales
WHERE Model IS NOT NULL
GROUP BY Model;




CREATE TABLE DATE_DIM AS
WITH UniqueDates AS (
    SELECT DISTINCT
        Date,           -- keep the Date column first
        Day_Name,
        Month_Name,
        Quarter_Number,
        Year_Number,
        Day_Type
    FROM car_sales
    WHERE Date IS NOT NULL
)
SELECT *
FROM UniqueDates
ORDER BY Date;




-- check if there are duplicates
    SELECT sales_order_id
    FROM car_sales
    GROUP BY sales_order_id
    HAVING COUNT(*) > 1;
-- No duplicates

-- Replace missing gender
UPDATE car_sales
SET Gender = 'UNKNOWN'
WHERE Gender IS NULL OR Gender = '';


-- Replace missing colors
UPDATE car_sales
SET Color = 'Unknown'
WHERE Color IS NULL OR Color = '';

-- Replace missing transmission
UPDATE car_sales
SET Transmission = 'Unknown'
WHERE Transmission IS NULL OR Transmission = '';


-- modify Date Colunm type
ALTER TABLE car_sales
MODIFY COLUMN Date DATE;

-- Add date details
ALTER TABLE car_sales
ADD COLUMN Day_Name VARCHAR(20),
ADD COLUMN Month_Name VARCHAR(20),
ADD COLUMN Quarter_Number INT,
ADD COLUMN Year_Number INT,
ADD COLUMN Day_Type VARCHAR(10);


UPDATE car_sales
SET 
    Day_Name = DAYNAME(`Date`),
    Month_Name = MONTHNAME(`Date`),
    Quarter_Number = QUARTER(`Date`),
    Year_Number = YEAR(`Date`),
    Day_Type = CASE 
                   WHEN DAYOFWEEK(`Date`) IN (1,7) THEN 'Weekend'
                   ELSE 'Weekday'
               END;



SET SQL_SAFE_UPDATES = 0;

ALTER TABLE car_sales
ADD COLUMN Date_converted DATE;

UPDATE car_sales
SET Date_converted = STR_TO_DATE(`Date`, '%m/%d/%Y');

ALTER TABLE car_sales
DROP COLUMN `Date`,
CHANGE COLUMN Date_converted `Date` DATE;

ALTER TABLE car_sales
DROP COLUMN Dealer_No,
DROP COLUMN Phone;

DESC car_sales;

-- insert income levels column
ALTER TABLE car_sales
ADD COLUMN `Income Level` VARCHAR(20);

UPDATE car_sales
SET `Income Level` = CASE
    WHEN `Annual Income` < 385000 THEN 'low income'
    WHEN `Annual Income` >= 385000 AND `Annual Income` < 1175000 THEN 'middle income'
    WHEN `Annual Income` >= 1175000 THEN 'high income'
END;


-- insert Car category column
ALTER TABLE car_sales
ADD COLUMN `Car Category` VARCHAR(20);

UPDATE car_sales
SET `Car Category` = CASE
    WHEN `Price ($)` < 25000 THEN 'Economy'
    WHEN `Price ($)` >= 25000 AND `Price ($)` < 50000 THEN 'Medium'
    WHEN `Price ($)` >= 50000 THEN 'Luxury'
END;


SELECT * FROM car_sales.car_sales;

-- Count distinct dealers and brands
SELECT COUNT(DISTINCT Dealer_Name_ID) AS unique_dealers,
       COUNT(DISTINCT Brand_name_id) AS unique_brands
FROM car_sales;


-- Which category of cars are most sold?
SELECT 
    `Car Category`,
    COUNT(*) AS total_sold
FROM car_sales
GROUP BY `Car Category`
ORDER BY total_sold DESC;
-- economy then meduim then luxury


SELECT 
    `Car Category`,
    COUNT(*) AS total_cars_sold,

    -- Convert to millions, round to 1 decimal, then remove trailing .0
    CONCAT(
        TRIM(TRAILING '.0' FROM FORMAT(ROUND(SUM(`Price ($)`) / 1000000, 1), 1)),
        'M'
    ) AS total_revenue,

    -- Percent with % sign
    CONCAT(
        ROUND(
            SUM(`Price ($)`) * 100 / (SELECT SUM(`Price ($)`) FROM car_sales)
        , 2),
        '%'
    ) AS revenue_percentage

FROM car_sales
GROUP BY `Car Category`
ORDER BY SUM(`Price ($)`) DESC;

-- Meduim cars are the greatest part of our revenue then economy then luxury


-- what is the most income levels buy cars?
SELECT 
    `Income Level`,
    COUNT(*) AS total_cars_sold
FROM car_sales
GROUP BY `Income Level`
ORDER BY total_cars_sold DESC;

-- Middle income with huge distanse then high  then low


-- What is the type of cars that each income level buy more?
SELECT 
    `Income Level`,
    `Car Category`,
    COUNT(*) AS total_cars_sold,

    -- Percentage within income + % sign
    CONCAT(
        ROUND(
            COUNT(*) * 100.0 / 
            SUM(COUNT(*)) OVER (PARTITION BY `Income Level`)
        , 2),
        '%'
    ) AS percentage_within_income

FROM car_sales
GROUP BY `Income Level`, `Car Category`
ORDER BY `Income Level`, percentage_within_income DESC;
-- Economy are the most demanded by all income levels
-- Middle income are the most buyers of luxury cars



-- Who are the dealers that sell more cars?

SELECT 
    `Dealer_Name_ID`,
    COUNT(*) AS total_cars_sold,

    -- Revenue in millions
    CONCAT(
        TRIM(TRAILING '.0' FROM FORMAT(ROUND(SUM(`Price ($)`) / 1000000, 1), 1)),
        'M'
    ) AS total_revenue,

    -- Revenue % with % sign
    CONCAT(
        ROUND(
            SUM(`Price ($)`) * 100.0 / (SELECT SUM(`Price ($)`) FROM car_sales)
        , 2),
        '%'
    ) AS revenue_percentage

FROM car_sales
GROUP BY `Dealer_Name_ID`
ORDER BY SUM(`Price ($)`) DESC;



-- What is region that makes the highest sales ?

SELECT 
    `Dealer_Region`,
    COUNT(*) AS total_cars_sold,

    -- Revenue in millions 
    CONCAT(
        TRIM(TRAILING '.0' FROM FORMAT(ROUND(SUM(`Price ($)`) / 1000000, 1), 1)),
        'M'
    ) AS total_revenue,

    -- Revenue % with % sign
    CONCAT(
        ROUND(
            SUM(`Price ($)`) * 100.0 /
            (SELECT SUM(`Price ($)`) FROM car_sales)
        , 2),
        '%'
    ) AS revenue_percentage

FROM car_sales
GROUP BY `Dealer_Region`
ORDER BY SUM(`Price ($)`) DESC;


-- what is the month that makes highest sales?

SELECT  
    YEAR(`Date`) AS year,
    MONTHNAME(`Date`) AS month_name,

    -- Revenue in millions 
    CONCAT(
        TRIM(TRAILING '.0' FROM FORMAT(ROUND(SUM(`Price ($)`) / 1000000, 1), 1)),
        'M'
    ) AS total_revenue,

    -- Revenue % with % sign
    CONCAT(
        ROUND(
            SUM(`Price ($)`) * 100.0 /
            (SELECT SUM(`Price ($)`) FROM car_sales)
        , 2),
        '%'
    ) AS revenue_percentage

FROM car_sales
GROUP BY YEAR(`Date`), MONTHNAME(`Date`)
ORDER BY SUM(`Price ($)`) DESC;


-- what are the 10 most profitable sold models?

SELECT 
    `Model`,
    COUNT(*) AS total_cars_sold,

    -- Revenue in millions
    CONCAT(
        TRIM(TRAILING '.0' FROM FORMAT(ROUND(SUM(`Price ($)`) / 1000000, 1), 1)),
        'M'
    ) AS total_revenue,

    -- Revenue % with % sign
    CONCAT(
        ROUND(
            SUM(`Price ($)`) * 100.0 / 
            (SELECT SUM(`Price ($)`) FROM car_sales)
        , 2),
        '%'
    ) AS revenue_percentage

FROM car_sales
GROUP BY `Model`
ORDER BY SUM(`Price ($)`) DESC
LIMIT 10;


--  what is 10 models that makes most sales orders ?
SELECT 
    `Model`,
    COUNT(*) AS total_cars_sold
FROM car_sales
GROUP BY `Model`
ORDER BY total_cars_sold DESC limit 10;



-- what is the brand that makes more sales?

SELECT 
    `Brand_Name_ID`,
    COUNT(*) AS total_cars_sold,

    -- Cars sold percentage + % sign
    CONCAT(
        ROUND(
            COUNT(*) * 100.0 / (SELECT COUNT(*) FROM car_sales)
        , 2),
        '%'
    ) AS cars_sold_percentage,

    -- Revenue in millions 
    CONCAT(
        TRIM(TRAILING '.0' FROM FORMAT(ROUND(SUM(`Price ($)`) / 1000000, 1), 1)),
        'M'
    ) AS total_revenue,

    -- Revenue % with % sign
    CONCAT(
        ROUND(
            SUM(`Price ($)`) * 100.0 /
            (SELECT SUM(`Price ($)`) FROM car_sales)
        , 2),
        '%'
    ) AS revenue_percentage

FROM car_sales
GROUP BY `Brand_Name_ID`
ORDER BY SUM(`Price ($)`) DESC;






