Create database bank_data_analytics;

use bank_data_analytics;

select * from BANK_TRANSACTIONS;

---TOTAL_NUM_OF_TRANSACTIONS, TOTAL DEBIT AMOUNT, TOTAL CREDIT AMOUNT

SELECT
COUNT(*) AS 'TOTAL NUM OF TRANSACTION',
ROUND(SUM(Debit_Amount),2) as 'TOTAL DEBIT AMOUNT',
ROUND(SUM(Credit_Amount),2) as 'TOTAL CREDIT AMOUNT'
FROM BANK_TRANSACTIONS;

---BRANCH WISE TRANSACTION VOLUME(COUNT) AND TRANSACTION VALUE

SELECT
Branch,
COUNT(*) AS 'TRANSACTION VOLUME',
ROUND(SUM(Debit_Amount),2) + ROUND(SUM(Credit_Amount),2) as 'TRANSACTION VALUE'
FROM BANK_TRANSACTIONS
GROUP BY Branch;

-- AVERAGE TRANSACTION AMOUNT PER TRANSACTION TYPE (DEBIT \ CREDIT)

SELECT
'DEBIT' AS 'DEBIT TYPE',
ROUND(AVG(Debit_Amount),2) as Avg_transaction_amount
FROM BANK_TRANSACTIONS
WHERE Debit_Amount is not Null

UNION ALL

SELECT
'CREDIT' AS 'CREDIT TYPE',
ROUND(AVG(Credit_Amount),2) AS Avg_transaction_amount
FROM BANK_TRANSACTIONS
WHERE Credit_Amount is not Null

-- MONTH ON MONTH GROWTH IN TOTAL_TRANSACTION_AMOUNT

WITH Monthly_transactions As(
select
YEAR(Transaction_Date) as Transaction_Year,
Month(Transaction_Date) as Transaction_Month,
(Sum(ISNULL(Debit_Amount,0)) + Sum(ISNULL(Credit_Amount,0)))as Total_Transaction_Amount
From BANK_TRANSACTIONS
Group By 
YEAR(Transaction_Date),
Month(Transaction_Date)
),
MOM_Calc AS(
Select
Transaction_Year,
Transaction_Month,
Total_Transaction_Amount,
Lag(Total_Transaction_Amount) over(order by Transaction_Year, Transaction_Month) as Previous_Month_Amount
FROM Monthly_transactions
)
Select
Transaction_Year,
Transaction_Month,
Total_Transaction_Amount,
Previous_Month_Amount,
Case
When Previous_Month_Amount = 0 Then NULL
Else
ROUND(((Total_Transaction_Amount - Previous_Month_Amount)*100 / Previous_Month_Amount),2) 
END AS MOM_Growth_Perc
From 
MOM_Calc 
Order by Transaction_Year, Transaction_Month

-- WEEKEND VS WEEKDAY TRANSACTION COMPARISON

SET DATEFIRST 1;
WITH DAY_CLASSIFICATION AS(
SELECT
CASE
WHEN DATEPART(WEEKDAY, Transaction_Date) IN (6,7)
THEN 'WEEKEND'
ELSE 'WEEKDAY'
END AS DAY_TYPE,
Debit_Amount,
Credit_Amount
from BANK_TRANSACTIONS
)
SELECT
DAY_TYPE,
COUNT(*) AS TRANSACTION_Volume,
ROUND(SUM(ISNULL(Debit_Amount,0) + ISNULL(Credit_Amount,0)),2) As Transaction_Value
FROM DAY_CLASSIFICATION
GROUP BY DAY_TYPE


-- IDENTIFY DAYS WHERE DEBIT_AMOUNT > CREDIT AMOUNT BY 20%
SELECT
CAST(Transaction_Date as date) as Transaction_Day,
Round(Sum(ISNULL(Debit_Amount,0)),2) as total_debit,
Round(Sum(ISNULL(Credit_Amount,0)),2) as total_credit,
CAST(
(Sum(ISNULL(Debit_Amount,0)) - Sum(ISNULL(Credit_Amount,0))) *100 /
nullif(Sum(ISNULL(Credit_Amount,0)),0) as decimal(10,2)) as debit_excess_amount
From BANK_TRANSACTIONS
GROUP BY CAST(Transaction_Date as date)
HAVING Sum(ISNULL(Debit_Amount,0)) > Sum(ISNULL(Credit_Amount,0)) * 1.20

--- branch wise top 5 customers by transaction amount

with customer_branch_transaction as(
select 
customer_id,
customer_name,
branch,
round(Sum(isnull(Debit_Amount,0) + isnull(Credit_Amount,0)),2) as total_transaction_amount
FROM BANK_TRANSACTIONS
group by 
customer_id,branch,customer_name
),
ranked_customer as(
select
customer_id,
customer_name,
branch,
total_transaction_amount,
DENSE_RANK() over(partition by branch order by total_transaction_amount desc) as branch_rank
FROM customer_branch_transaction
)
select
customer_id,
customer_name,
branch,
total_transaction_amount,
branch_rank
FROM ranked_customer
where branch_rank <=5
order by branch, branch_rank;

--accounts whose transactions is above all the overall average 

select
account_number,
round(sum(isnull(Debit_Amount,0) + isnull(Credit_Amount,0)),2) as transaction_amount
FROM BANK_TRANSACTIONS
GROUP BY account_number
having
round(sum(isnull(Debit_Amount,0) + isnull(Credit_Amount,0)),2) >
(Select
Avg(account_total)
from
(select
account_number,
sum(isnull(Debit_Amount,0) + isnull(Credit_Amount,0)) as account_total
FROM BANK_TRANSACTIONS
GROUP BY account_number ) T
)
