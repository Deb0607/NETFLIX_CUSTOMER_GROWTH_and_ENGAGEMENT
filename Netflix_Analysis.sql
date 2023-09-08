CREATE SCHEMA Netflix DEFAULT CHARSET utf8mb4;

USE Netflix;

CREATE TABLE ds_customer (
Customer_ID BIGINT NOT NULL,
Customer_Name VARCHAR(25),
Plan VARCHAR(25),
Signup_Date DATE,
First_Charge_Date DATE,
Cancel_Date DATE,
`Channel` VARCHAR(10),
PRIMARY KEY (Customer_ID)
);

CREATE TABLE ds_usage (
Customer_ID BIGINT NOT NULL,
Movie_Name VARCHAR(25),
Movie_Genre VARCHAR(25),
Movie_Length DECIMAL(3,2),
Start_Time DATETIME,
End_Time DATETIME,
FOREIGN KEY (Customer_ID) REFERENCES ds_customer(Customer_ID)
);


LOAD DATA INFILE 'D:/Concentrix Assignment/Craft Demo- Netflix- Customer table.csv'
INTO TABLE ds_customer
FIELDS TERMINATED BY ","
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


LOAD DATA INFILE 'D:/Concentrix Assignment/Craft Demo- Netflix- Usage table.csv'
INTO TABLE ds_usage
FIELDS TERMINATED BY ","
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- Total Customer Count: 18
SELECT COUNT(DISTINCT Customer_ID) AS Total_Customers
FROM ds_customer
WHERE Signup_Date BETWEEN '2013-01-01' AND '2014-12-31';

-- Conversion Rate To Subscription: 55.56%
SELECT 
COUNT(DISTINCT c.Customer_ID) AS Total_Customer,
COUNT(CASE WHEN First_Charge_Date IS NOT NULL THEN c.Customer_ID ELSE NULL END) AS Converted_Customer,
ROUND(COUNT(CASE WHEN First_Charge_Date IS NOT NULL THEN c.Customer_ID ELSE NULL END)/COUNT(DISTINCT c.Customer_ID)*100,2)
AS Converstion_Rate
FROM ds_customer c
WHERE c.Signup_Date BETWEEN '2013-12-01' AND '2014-12-31';

-- Churn Rate: 28%
WITH Cancelled_Subscription_Customer AS(
SELECT 
COUNT(DISTINCT c.Customer_ID) AS Total_Customer,
COUNT(CASE WHEN First_Charge_Date IS NOT NULL THEN c.Customer_ID ELSE NULL END) AS Converted_Customer,
ROUND(COUNT(CASE WHEN First_Charge_Date IS NOT NULL THEN c.Customer_ID ELSE NULL END)/COUNT(DISTINCT c.Customer_ID)*100,2)
AS Converstion_Rate,
COUNT(CASE WHEN Cancel_Date IS NOT NULL THEN c.Customer_ID ELSE NULL END) AS Cancelled_Subscription_Customer
FROM ds_customer c
WHERE c.Signup_Date BETWEEN '2013-12-01' AND '2014-12-31')
SELECT ROUND((Cancelled_Subscription_Customer/Total_Customer)*100,2) AS Churn_Rate
FROM Cancelled_Subscription_Customer;

-- Retention Rate: 72%
WITH Customer_Growth AS(
SELECT
COUNT(DISTINCT c1.Customer_ID) AS Total_Customer,
(COUNT(DISTINCT c1.Customer_ID) - COUNT(DISTINCT c2.Customer_ID)) AS Customer_Available_After_Churn
FROM ds_customer c1
LEFT JOIN ds_customer c2 ON c1.Customer_ID = c2.Customer_ID AND c2.Cancel_Date BETWEEN '2013-01-01' AND '2014-12-31'
WHERE c1.Signup_Date BETWEEN '2013-01-01' AND '2014-12-31')
SELECT 
Total_Customer,
Customer_Available_After_Churn,
ROUND((Customer_Available_After_Churn/Total_Customer)*100,2) AS Net_Customer_Growth_Rate
FROM Customer_Growth;

-- Customer Acquisition by Channel: Direct-39%, PPC-33%, SEO-28%
SELECT Channel,
COUNT(DISTINCT Customer_ID) AS New_Customers,
ROUND(COUNT(DISTINCT Customer_ID) * 100.0 / (SELECT COUNT(DISTINCT Customer_ID) FROM ds_customer),2) AS Acquisition_Percentage
FROM ds_customer
WHERE Signup_Date BETWEEN '2013-01-01' AND '2014-12-31'
GROUP BY Channel;

-- Average Time to Conversion:

SELECT
Plan,
ROUND(AVG(DATEDIFF(First_Charge_Date, Signup_Date)),0) AS Avg_Time_to_Conversion
FROM ds_customer
WHERE First_Charge_Date IS NOT NULL
Group BY Plan;


-- Conversion Rate by Plan:
SELECT Plan,
COUNT(DISTINCT Customer_ID) AS Converted_Customers,
ROUND(COUNT(DISTINCT Customer_ID) * 100.0 / (SELECT COUNT(DISTINCT Customer_ID) FROM ds_customer),0
) AS Conversion_Rate
FROM ds_customer
WHERE First_Charge_Date IS NOT NULL
AND Signup_Date BETWEEN '2013-01-01' AND '2014-12-31'
GROUP BY Plan;

-- Churn Rate by Plan:
SELECT Plan,
COUNT(DISTINCT Customer_ID) AS Churned_Customers,
ROUND(COUNT(DISTINCT Customer_ID) * 100.0 / (SELECT COUNT(DISTINCT Customer_ID) FROM ds_customer),0) AS Churn_Rate
FROM ds_customer
WHERE Cancel_Date BETWEEN '2013-01-01' AND '2014-12-31'
GROUP BY Plan;

-- Customer Engagement by Genre:
SELECT u.Movie_Genre,
ROUND(AVG(u.Movie_Length),2) AS Avg_Movie_Length,
COUNT(u.Movie_Name) AS Movies_Watched
FROM ds_usage u
JOIN ds_customer c ON u.Customer_ID = c.Customer_ID
WHERE c.Signup_Date BETWEEN '2013-01-01' AND '2014-12-31'
GROUP BY u.Movie_Genre;	

-- Usage Patterns over Time:
SELECT 
CONCAT(LEFT(MONTHNAME(u.Start_Time),3),'-',RIGHT(YEAR(u.Start_Time),2)) AS Month_Year,
COUNT(u.Movie_Name) AS Movies_Watched,
ROUND(AVG(u.Movie_Length),2) AS Avg_Movie_Length
FROM ds_usage u
JOIN ds_customer c ON u.Customer_ID = c.Customer_ID
WHERE c.Signup_Date BETWEEN '2013-01-01' AND '2014-12-31'
GROUP BY Month_Year
ORDER BY Month_Year;

-- Usage Patterns and Movie Genres:
SELECT
    u.Movie_Genre,
    COUNT(u.Movie_Genre) AS Genre_Count
FROM ds_customer c
JOIN ds_usage u ON c.Customer_ID = u.Customer_ID
WHERE  c.First_Charge_Date IS NOT NULL
GROUP BY u.Movie_Genre
ORDER BY Genre_Count DESC;

-- Plan Preferences of Retained Customers:
SELECT
    c.Plan,
    COUNT(c.Plan) AS Plan_Count
FROM ds_customer c
WHERE c.Cancel_Date IS NULL
GROUP BY c.Plan
ORDER BY Plan_Count DESC;

-- Analyze Movie Length and Frequency
SELECT
    ROUND(AVG(TIME_TO_SEC(TIMEDIFF(u.End_Time, u.Start_Time)) / 3600),2) AS Avg_Movie_Length_Viewed
FROM ds_customer c
JOIN ds_usage u ON c.Customer_ID = u.Customer_ID
WHERE c.Cancel_Date IS NULL;

-- Average Number of Movies Watched by Retained Customers:
SELECT
COUNT(u.Movie_Name) / COUNT(DISTINCT c.Customer_ID) AS Avg_Movies_Watched
FROM ds_customer c
JOIN ds_usage u ON c.Customer_ID = u.Customer_ID
WHERE c.Cancel_Date IS NULL;

-- Average Number of Movies Watched in a Day by Retained Customers:
SELECT
    ROUND(AVG(Movies_Watched_Per_Day),1) AS Avg_Movies_Watched_Per_Day
FROM (
    SELECT
        c.Customer_ID,
        DATEDIFF(u.End_Time, u.Start_Time) AS Days_Watched,
        COUNT(u.Movie_Name) AS Movies_Watched_Per_Day
    FROM ds_customer c
    JOIN ds_usage u ON c.Customer_ID = u.Customer_ID
    WHERE c.Cancel_Date IS NULL
    GROUP BY c.Customer_ID, Days_Watched
) AS subquery;

-- Usage Frequency:
SELECT
    Customer_ID,
    COUNT(*) AS Total_Views,
    ROUND(AVG(TIME_TO_SEC(TIMEDIFF(u.End_Time, u.Start_Time)) / 3600),2) AS Avg_Movie_Length
FROM ds_usage  u
GROUP BY Customer_ID
ORDER BY Avg_Movie_Length;

-- Plan Preference by Signup Customer
SELECT
    Plan,
    COUNT(*) AS Customer_Count
FROM ds_customer
GROUP BY Plan;

-- Cancellation Rate and Reasons:
SELECT
    COUNT(DISTINCT CASE WHEN Cancel_Date IS NULL AND First_Charge_Date IS NOT NULL THEN Customer_ID END) AS Canceled_Customers,
    COUNT(DISTINCT CASE WHEN Cancel_Date IS NOT NULL AND Plan = 'Streaming' THEN Customer_ID END) AS Canceled_Streaming_Customers,
    COUNT(DISTINCT CASE WHEN Cancel_Date IS NOT NULL AND Plan = 'Mail' THEN Customer_ID END) AS Canceled_Mail_Customers,
    COUNT(DISTINCT CASE WHEN Cancel_Date IS NOT NULL AND Plan = 'Both' THEN Customer_ID END) AS Canceled_Both_Customers
FROM ds_customer;

-- Channel Performance:
SELECT
    Channel,
    COUNT(*) AS Customer_Count,
    COUNT(DISTINCT CASE WHEN First_Charge_Date IS NOT NULL THEN Customer_ID END) AS Converted_Customers
FROM ds_customer
GROUP BY Channel;


-- Customer Growth by Date
SELECT
CONCAT(RIGHT(Signup_Date,2),"th ",LEFT(MONTHNAME(Signup_Date),3)) AS By_Date,
COUNT(*) AS Number_Of_Customer_Signup,
ROUND((COUNT(*) / COUNT(*) OVER (ORDER BY Signup_Date))*100,0) AS Acquisition_Rate
FROM ds_customer
GROUP BY Signup_Date
ORDER BY Signup_Date;

