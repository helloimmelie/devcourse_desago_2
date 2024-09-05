#전처리 View 코드 
ALTER VIEW `salesData_View` AS 
 #customer 데이터와 함께 JOIN을 건 뒤, product 테이블과 JOIN 
SELECT salesData.transaction_id, 
salesData.transaction_date,
 HOUR(salesData.transaction_time) AS `HOUR`,
 MINUTE(salesData.transaction_time) AS `MINUTE`, 
 SECOND(salesData.transaction_time) AS `SECOND`,
 salesData.sales_outlet_id,
 product.product_category,
 product.product_type,
 product.product, 
 salesData.quantity,
 COALESCE(customer.customer_since,'not Member') AS `customer_since`, 
 CASE WHEN customer.birth_year >= 2000 THEN '10'
		WHEN customer.birth_year >=1990 THEN '20'
       WHEN customer.birth_year >=1980 THEN '30'
        WHEN customer.birth_year >=1970 THEN '40'
        WHEN customer.birth_year >=1960 THEN '50' 
        WHEN customer.birth_year >=1950 THEN '60'
        WHEN customer.birth_year IS NULL THEN 'not Member'
        ELSE 'over 70 year' END AS age, 
 COALESCE(customer.gender, 'not Member') AS `customer_gender` 
 FROM devcourse_p.sales_reciepts AS salesData 
 LEFT OUTER JOIN devcourse_p.product AS product ON salesData.product_id = product.product_id 
LEFT OUTER JOIN devcourse_p.customer AS customer ON salesData.customer_id = customer.customer_id

#회원별 데이터 분석 
#1. 회원 데이터 분석 개요 
SELECT 
transaction_date,
sales_outlet_id, 
SUM(CASE WHEN customer_id > 0 THEN 1 ELSE 0 END) AS `memberCount`,
SUM(CASE WHEN customer_id = 0 THEN 1 ELSE 0 END) AS `nonMemberCount`
FROM 
(SELECT DISTINCT transaction_date, transaction_id, sales_outlet_id, customer_id 
FROM  devcourse_p.sales_reciepts) AS `result`
GROUP BY transaction_date, sales_outlet_id
ORDER BY sales_outlet_id ASC
 
#2. 회원 데이터에 대한 가설 검증 
#2.1 회원 혜택 존재 여부 확인 

#2.1.1 회원 할인 적용 여부 확인 
SELECT DISTINCT p.product_id, p.product, salesData.transaction_date, salesData.promo_item_yn, salesData.customer_id, unit_price, current_retail_price
FROM devcourse_p.sales_reciepts AS salesData
LEFT OUTER JOIN product AS p ON salesData.product_id = p.product_id 
WHERE  salesData.promo_item_yn = 'Y' AND p.product_id IN (87, 89)

#무료 음료 혜택 확인 
SELECT * FROM devcourse_p.sales_reciepts 
WHERE unit_price = 0 

SELECT DISTINCT p.product_id, p.product, salesData.transaction_date, salesData.promo_item_yn, salesData.customer_id, unit_price, current_retail_price
FROM devcourse_p.sales_reciepts AS salesData
LEFT OUTER JOIN product AS p ON salesData.product_id = p.product_id 
WHERE  unit_price != REPLACE(current_retail_price,'$','')

#2. 매출을 발생 시킨 회원들이 최근에 가입을 한 회원들인지에 대한 확인 

#WITH customer_result 
AS (
	SELECT YEAR(c.customer_since) AS since_year, c.customer_id, COUNT(DISTINCT r.transaction_id) AS salesCount
    FROM devcourse_p.sales_reciepts AS r 
    LEFT OUTER JOIN devcourse_p.customer AS c ON r.customer_id = c.customer_id 
    WHERE c.customer_id IS NOT NULL
    GROUP BY YEAR(c.customer_since),c.customer_id
)
SELECT since_year, ROUND(AVG(salesCount),2) AS salesMedian
FROM customer_result 
GROUP BY since_year

## 단골 고객 

#2. 단골 고객 차지 비중 계산 
WITH customer_result 
AS (
	SELECT YEAR(c.customer_since) AS since_year, c.customer_id, COUNT(DISTINCT r.transaction_id) AS salesCount
    FROM devcourse_p.sales_reciepts AS r 
    LEFT OUTER JOIN devcourse_p.customer AS c ON r.customer_id = c.customer_id 
    WHERE c.customer_id IS NOT NULL
    GROUP BY YEAR(c.customer_since),c.customer_id
),
overCount AS 
(SELECT since_year, 
(CASE WHEN salesCount>=18 THEN 1 ELSE 0 END) AS overCount_Flag
FROM customer_result ) 
SELECT since_year,SUM(overCount_Flag),COUNT(*), ROUND((SUM(overCount_Flag)/COUNT(*) )*100,2) AS royaltyPercentage 
FROM overCount
GROUP BY since_year 


# 2.1 단골 고객들의 연령대, 성별 분석 
WITH customer_result 
AS (
	SELECT YEAR(c.customer_since) AS since_year, c.customer_id, COUNT(DISTINCT r.transaction_id) AS salesCount
    FROM devcourse_p.sales_reciepts AS r 
    LEFT OUTER JOIN devcourse_p.customer AS c ON r.customer_id = c.customer_id 
    WHERE c.customer_id IS NOT NULL
    GROUP BY YEAR(c.customer_since),c.customer_id
),
 manyBoughtCustomerList AS
(SELECT since_year, customer_id 
FROM customer_result 
WHERE salesCount >=18)
SELECT customer_gender, 
age,
(CASE WHEN customer_id END ) 
COUNT(DISTINCT customer_id) AS customerCount 
FROM devcourse_p.`salesdata_view`  
WHERE customer_id IN (SELECT customer_id FROM manyBoughtCustomerList )
GROUP BY customer_gender, age

# 2.2/2.3 단골 고객들이 자주 마시는 음료, 시간대 분석 
WITH customer_result 
AS (
	SELECT YEAR(c.customer_since) AS since_year, c.customer_id, COUNT(DISTINCT r.transaction_id) AS salesCount
    FROM devcourse_p.sales_reciepts AS r 
    LEFT OUTER JOIN devcourse_p.customer AS c ON r.customer_id = c.customer_id 
    WHERE c.customer_id IS NOT NULL
    GROUP BY YEAR(c.customer_since),c.customer_id
),
 manyBoughtCustomerList AS
(SELECT since_year, customer_id 
FROM customer_result 
WHERE salesCount >=18)
SELECT age,  timeNum, `Time`, product_type, buyCount
FROM (SELECT age, lp.timeNum, `Time`, product_type, SUM(quantity) AS buyCount, DENSE_RANK() OVER(PARTITION BY  age, `Time` ORDER BY SUM(quantity)  DESC) AS `rank_number`
FROM devcourse_p.`salesdata_view` AS s  
INNER JOIN timeLookup AS lp ON s.`Time` = lp.timeName
WHERE customer_id IN (SELECT customer_id FROM manyBoughtCustomerList ) 
GROUP BY  age, lp.timeNum,`Time`, product_type
ORDER BY lp.timeNum ASC
) AS `result`
WHERE `rank_number` = 1
ORDER BY age ASC


## 2.4 비단골 고객 매출 데이터 분석 

# 2.4 비단골 회원들이 선호하는 시간대 


WITH customer_result 
AS (
	SELECT YEAR(c.customer_since) AS since_year, c.customer_id, COUNT(DISTINCT r.transaction_id) AS salesCount
    FROM devcourse_p.sales_reciepts AS r 
    LEFT OUTER JOIN devcourse_p.customer AS c ON r.customer_id = c.customer_id 
    WHERE c.customer_id IS NOT NULL
    GROUP BY YEAR(c.customer_since),c.customer_id
),
 manyBoughtCustomerList AS
(SELECT since_year, customer_id 
FROM customer_result 
WHERE salesCount BETWEEN 6 AND 11 )
SELECT age, `weekName`,  weekDayNum, timeNum, product_type, buyCount
FROM (SELECT age, CONCAT(DAYNAME(transaction_date),' ',`Time`) AS WeekName, WEEKDAY(transaction_date) AS weekDayNum, lp.timeNum,  product_type, SUM(quantity) AS buyCount, DENSE_RANK() OVER(PARTITION BY  age ORDER BY SUM(quantity)  DESC) AS `rank_number`
FROM devcourse_p.`salesdata_view` AS s  
INNER JOIN timeLookup AS lp ON s.`Time` = lp.timeName
WHERE customer_id IN (SELECT customer_id FROM manyBoughtCustomerList ) 
GROUP BY  age, CONCAT(DAYNAME(transaction_date),' ',`Time`), WEEKDAY(transaction_date), lp.timeNum, product_type
ORDER BY  WEEKDAY(transaction_date) ASC, lp.timeNum ASC
) AS `result`
WHERE `rank_number` = 1
ORDER BY age ASC



# 비단골 고객들이 자주 마시는 음료 분석 

WITH customer_result 
AS (
	SELECT YEAR(c.customer_since) AS since_year, c.customer_id, COUNT(DISTINCT r.transaction_id) AS salesCount
    FROM devcourse_p.sales_reciepts AS r 
    LEFT OUTER JOIN devcourse_p.customer AS c ON r.customer_id = c.customer_id 
    WHERE c.customer_id IS NOT NULL
    GROUP BY YEAR(c.customer_since),c.customer_id
),
 manyBoughtCustomerList AS
(SELECT since_year, customer_id 
FROM customer_result 
WHERE salesCount BETWEEN 6 AND 11 )
SELECT age, `weekName`,  weekDayNum, timeNum, product_type, buyCount
FROM (SELECT age, CONCAT(DAYNAME(transaction_date),' ',`Time`) AS WeekName, WEEKDAY(transaction_date) AS weekDayNum, lp.timeNum,  product_type, SUM(quantity) AS buyCount, DENSE_RANK() OVER(PARTITION BY  age ORDER BY SUM(quantity)  DESC) AS `rank_number`
FROM devcourse_p.`salesdata_view` AS s  
INNER JOIN timeLookup AS lp ON s.`Time` = lp.timeName
WHERE customer_id IN (SELECT customer_id FROM manyBoughtCustomerList ) 
GROUP BY  age, CONCAT(DAYNAME(transaction_date),' ',`Time`), WEEKDAY(transaction_date), lp.timeNum, product_type
ORDER BY  WEEKDAY(transaction_date) ASC, lp.timeNum ASC
) AS `result`
WHERE `rank_number` = 1
ORDER BY age ASC

## 2.5 비회원 매출 분석 

# 2.5.1 시간대별 선호 메뉴 

SELECT   `Time`,  product_type, quantity 
FROM (SELECT `Time`, product_type, SUM(quantity) AS quantity, DENSE_RANK() OVER (PARTITION BY  `Time` ORDER BY SUM(quantity) DESC) AS `rank`
FROM salesdata_view as s 
INNER JOIN timelookup as tl ON s.`Time` = tl.timeName 
WHERE customer_id > 0
GROUP BY `Time`, product_type) AS `result` 
WHERE `result`.rank = 1  

# 2.5.2 테이크아웃 선호 여부  
 
SELECT 
SUM(CASE WHEN instore_yn = 'Y' THEN 1 ELSE 0 END) AS `instoreY`,
SUM(CASE WHEN instore_yn = 'N' THEN 1 ELSE 0 END) AS `instoreN`
FROM `sales_reciepts` as s 
WHERE customer_id = 0






