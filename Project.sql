use gdb023 ;

-- 1.Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

select * from dim_customer ;

SELECT DISTINCT market 
FROM dim_customer
WHERE customer="Atliq Exclusive" AND region="APAC";

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
-- unique_products_2020
-- unique_products_2021
-- percentage_chg.

select * from fact_sales_monthly ;

WITH CTE AS(
			SELECT count(DISTINCT fs.product_code) AS unique_product_2020
		FROM fact_sales_monthly fs
		JOIN dim_product dp
        ON fs.product_code=dp.product_code
		WHERE fiscal_year=2020),
	CTE2 AS(
		SELECT count(DISTINCT fs.product_code) AS unique_product_2021 
		FROM fact_sales_monthly fs
		JOIN dim_product dp
        ON fs.product_code=dp.product_code
		WHERE fiscal_year=2021)
	SELECT *,
		round(((unique_product_2021-unique_product_2020)/unique_product_2020)*100,2) as percentage_chg 
	    FROM CTE,CTE2 ;
        
-- 3.Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
-- The final output contains 2 fields,
-- segment
-- product_count.

select * from dim_product ;

SELECT segment, count(DISTINCT product_code) AS product_count 
	FROM dim_product
	GROUP BY segment
	ORDER BY product_count DESC ;

-- Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, 
-- segment
-- product_count_2020
-- product_count_2021
-- difference.

select * from dim_product ;
select * from fact_sales_monthly ;

WITH CTE AS(
		SELECT dp.segment,count(DISTINCT dp.product_code) AS product_count_2020
		FROM dim_product dp
		JOIN fact_sales_monthly fs
		ON dp.product_code=fs.product_code
		WHERE fiscal_year=2020
		GROUP BY segment
		ORDER BY product_count_2020 DESC),
	CTE2 AS(
		SELECT dp.segment,count(DISTINCT dp.product_code) AS product_count_2021
		FROM dim_product dp
		JOIN fact_sales_monthly fs
		ON dp.product_code=fs.product_code
		WHERE fiscal_year=2021
		GROUP BY segment
		ORDER BY product_count_2021 DESC)
	SELECT a.segment,
		   a.product_count_2020,
	       	b.product_count_2021,
		   b.product_count_2021-a.product_count_2020 AS diff,
	round(((b.product_count_2021-a.product_count_2020)/a.product_count_2020)*100,2) 
	FROM CTE a 
	JOIN CTE2 b
	ON a.segment=b.segment ;
    
-- 5.Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields,
-- product_code
-- product
-- manufacturing_cost.

select * from fact_manufacturing_cost ;
select * from dim_product ;

SELECT dp.product,
		   dp.product_code,
	       manufacturing_cost
	FROM fact_manufacturing_cost fm 
	JOIN dim_product dp
	ON fm.product_code=dp.product_code
	WHERE manufacturing_cost= ( SELECT max(manufacturing_cost) FROM fact_manufacturing_cost)
	UNION
	SELECT dp.product,
		   dp.product_code,
		   manufacturing_cost
	FROM fact_manufacturing_cost fm 
	JOIN dim_product dp
	ON fm.product_code=dp.product_code
	WHERE manufacturing_cost=(SELECT min(manufacturing_cost) FROM fact_manufacturing_cost) ;

-- 6.Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- customer_code
-- customer
-- average_discount_percentage.

select * from fact_pre_invoice_deductions ;
select * from dim_customer ;

SELECT dc.customer_code,
		   dc.customer,
		   round(AVG(fp.pre_invoice_discount_pct)*100,2) AS average_discount_pct
	FROM fact_sales_monthly fs
	JOIN dim_customer dc
	ON fs.customer_code= dc.customer_code
	JOIN fact_pre_invoice_deductions fp
	ON fs.customer_code=fp.customer_code 
	AND fs.fiscal_year=fp.fiscal_year
	WHERE fs.fiscal_year=2021 AND dc.market="India"
	GROUP BY dc.customer, dc.customer_code
	ORDER BY  average_discount_pct DESC
	LIMIT 5 ;
    
-- 7.Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
-- Month
-- Year
-- Gross sales Amount.


select * from fact_sales_monthly ;
select * from dim_customer ;
select * from fact_gross_price ;

SELECT  month(date) as month,
			year(date) as year,
			sum(sold_quantity * gross_price) AS gross_sales_amount
FROM fact_sales_monthly fs 
JOIN dim_customer dc
ON fs.customer_code= dc.customer_code
JOIN fact_gross_price fg
ON fg.fiscal_year= fs.fiscal_year AND
fg.product_code=fs.product_code
WHERE dc.customer="Atliq Exclusive"
GROUP BY month,year
ORDER BY year ;

-- 8.In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity,
-- Quarter
-- total_sold_quantity.

select * from fact_sales_monthly ;
    
SELECT CASE
	WHEN MONTH(date) IN(9,10,11) THEN 'Q1'
	 WHEN MONTH(date) IN(12,1,2) THEN 'Q2'
     WHEN MONTH(date) IN(3,4,5) THEN 'Q3'
     WHEN MONTH(date) IN(6,7,8) THEN 'Q4'
END AS quarter,
SUM(sold_quantity) AS total_sold_quantity FROM fact_sales_monthly
WHERE fiscal_year= 2020
GROUP BY quarter
ORDER BY total_sold_quantity DESC; 

-- 9.Which channel helped to bring more gross sales in the fiscal year 2021 
-- and the percentage of contribution? The final output contains these fields,
-- channel
-- gross_sales_mln
-- percentage.

select * from fact_sales_monthly ;
select * from fact_gross_price ;
select * from dim_customer ;

WITH CTE AS
(
SELECT channel,SUM(gross_price*sold_quantity) AS gross_sales 
FROM fact_sales_monthly fs
JOIN fact_gross_price fg
ON fs.product_code = fg.product_code
JOIN dim_customer dm
ON fs.customer_code = dm.customer_code
WHERE fs.fiscal_year = 2021 
GROUP BY channel
ORDER BY gross_sales DESC
)
SELECT channel, 
ROUND(gross_sales/1000000,2) AS gross_sales_mln, 
ROUND(gross_sales/(SELECT SUM(gross_sales) FROM CTE)*100,2) AS percentage_of_contribution 
FROM CTE ;


-- 10.Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these
-- fields,
-- division
-- product_code
-- product
-- total_sold_quantity
-- rank_order

select * from fact_sales_monthly ;
select * from dim_product ;

WITH sales AS (
SELECT division,
	   fs.product_code,product,
	   sum(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly AS fs
LEFT JOIN  dim_product AS dp
ON fs.product_code = dp.product_code
WHERE fiscal_year = 2021
GROUP BY fs.product_code, division,product),
rank_ov AS(
SELECT product_code,
       total_sold_quantity,
	   DENSE_RANK () OVER(PARTITION BY division ORDER BY total_sold_quantity desc) AS Rank_order
FROM sales AS S)
SELECT division,
       S.product_code, 
       product ,
       S.total_sold_quantity, 
       Rank_order
FROM sales AS S
INNER JOIN rank_ov AS R
ON R.product_code = S.product_code
WHERE Rank_order BETWEEN 1 AND 3 ;

