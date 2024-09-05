## 옥예진
## 1. 시간대별 분석

-- 시간대 전처리 (line_item_id, line_item_amount 제외) 
create view sales_reciepts_v2 as 
select transaction_id, transaction_date,
hour(transaction_time) as transaction_hour,
minute(transaction_time) as transaction_min,
second(transaction_time) as trnasaction_sec,
sales_outlet_id, staff_id,
customer_id, instore_yn, 
product_id, quantity, unit_price, promo_item_yn
from sales_reciepts;

## 1-1. 가장 매출이 높은 시간대
-- 시간대별 매출 (전체 지점)
select transaction_hour, sum(quantity*unit_price) 
from sales_reciepts_v2
group by 1
order by 2 desc;
-- 시간대별 매출 (각 지점) 
select transaction_hour, sales_outlet_id, sum(quantity*unit_price) 
from sales_reciepts_v2
group by 1,2
order by 3 desc;

## 1-2. 가장 판매량이 많은 시간대
-- 시간대별 판매량 (전 지점)  
select transaction_hour, sum(quantity) 
from sales_reciepts_v2
group by 1
order by 2 desc;

-- 시간대별 판매량 (각 지점) 
select transaction_hour, sales_outlet_id, sum(quantity) 
from sales_reciepts_v2
group by 1,2
order by 3 desc;

## 1-3. 시간대별 선호 상품 카테고리 
with hour_product_rank as (
select a.transaction_hour, b.product_category, sum(a.quantity) as qty,
rank() over (partition by a.transaction_hour order by sum(a.quantity) desc) as ranking 
from sales_reciepts_v2 a inner join product b
on a.product_id = b.product_id 
group by 1,2
order by 1, 4)
select transaction_hour, product_category, qty, ranking
from hour_product_rank
where ranking <= 3
group by 1,2
order by 1,4;

## 1-3-1. 시간대별 선호 상품 타입 (커피 아님 티) 
with hour_product_rank as (
select a.transaction_hour, b.product_type, sum(a.quantity) as qty,
rank() over (partition by a.transaction_hour order by sum(a.quantity) desc) as ranking 
from sales_reciepts_v2 a inner join product b
on a.product_id = b.product_id 
group by 1,2
order by 1, 4)
select transaction_hour, product_type, qty, ranking
from hour_product_rank
where ranking <= 3
group by 1,2
order by 1,4;

## 시간대별 시럽 판매 추이 
select a.transaction_hour, b.product_type, b.product, sum(a.quantity) 
from sales_reciepts_v2 a join product_v3 b
on a.product_id = b.product_id
where product_category = 'Flavours'
group by 1,2,3
order by 1, 4 desc;
-- 오전 시간대 top: 10시 chocolate syrup / 오후 시간대 top: 16시 Sugar Free Vanilla syrup 

## 시간대별 커피 판매 추이
select a.transaction_hour, b.product_type, b.product, sum(a.quantity) 
from sales_reciepts_v2 a join product_v3 b
on a.product_id = b.product_id
where product_category = 'Coffee'
group by 1,2,3
order by 1, 4 desc;
-- 오전 시간대 top: 10시 Ethipoia / 오후 시간대 top: 16시 Columbian Medium Roast 

## 시간대별 Tea 판매 추이 
select a.transaction_hour, b.product_type, b.product, sum(a.quantity) 
from sales_reciepts_v2 a join product_v3 b
on a.product_id = b.product_id
where product_category = 'Tea'
group by 1,2,3
order by 1,4 desc;
-- 오전 시간대 top: 10시 Traditional Blend Chai / 오후 시간대 top: 17시 Lemon Grass 

## 시간대별 Bakery 판매 추이 
select a.transaction_hour, b.product_type, b.product, sum(a.quantity) 
from sales_reciepts_v2 a join product_v3 b
on a.product_id = b.product_id
where product_category = 'Bakery'
group by 1,2,3
order by 1,4 desc;
-- 오전 시간대 top: 10시 Chocolate Croissant / 오후 시간대 top: 14시 Ginger Scone(프로모션 때문임을 가정하면) -> 13시 Chocolate chip Biscotti 


## 2. 디저트류 분석 

## 2-1. 가장 매출이 높은 디저트 
select b.product_category, b.product_type, b.product, sum(a.line_item_amount)
from sales_reciepts a inner join product b
on a.product_id = b.product_id
where b.product_category = 'Bakery'
group by 1,2,3
order by 4 desc;

## 2-2. 가장 판매량이 많은 디저트 
select b.product_category, b.product_type, b.product, sum(a.quantity)
from sales_reciepts a inner join product b
on a.product_id = b.product_id
where b.product_category = 'Bakery'
group by 1,2,3
order by 4 desc;

## 2-3. 재고 버려지는 비율 확인 
with percent as (
select product_id, count(transaction_date) as cnt, sum(start_of_day) as inventory, sum(waste) as waste,
concat(round((sum(waste)/sum(start_of_day))*100),'%') as waste_percent 
from pastry_inventory
group by product_id)
select a.product_id, a.cnt, a.inventory, a.waste, a.waste_percent, b.product_category, b.product_type, b.product
from percent a inner join product b
on a.product_id = b.product_id
order by product_id;

## 2-4. 수요 예측 오류 분석 
SELECT a.sales_outlet_id, b.product, avg(a.daily_sales) as avg_daily_sales  
FROM (
SELECT sales_outlet_id, product_id, transaction_date, SUM(quantity) AS daily_sales
FROM sales_reciepts
where product_id in (69,70,71,72,73)
GROUP BY 1,2,3
) a
left join product b 
on a.product_id = b.product_id 
GROUP BY 1,2;

## product 사이즈 전처리 
select * from product;
create view product_v3 as
select product_id, product_group, product_category, product_type, 
case when product like '%Lg' then rtrim(replace(product, 'Lg', ''))
when product like '%Rg' then rtrim(replace(product, 'Rg', ''))
when product like '%Sm' THEN rtrim(replace(product, 'Sm', ''))
else product
end as product
, product_description,
unit_of_measure, current_wholesale_price, current_retail_price, tax_exempt_yn, promo_yn, new_product_yn
from product;

## 3. 음료와 함께 잘 팔리는 조합? 
## 동시조합 확인_v1
create view concurrent as  
WITH conCurrentBuy AS 
(SELECT transaction_id, transaction_date, transaction_time, sales_outlet_id
FROM sales_reciepts
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1)
SELECT 
DENSE_RANK() OVER (PARTITION BY A.sales_outlet_id 
ORDER BY A.transaction_date, A.transaction_time ASC) AS row_num, 
A.transaction_id, A.transaction_date, A.transaction_time, A.sales_outlet_id,
A.product_id, C.product_category, C.product_type, C.product, A.quantity
FROM sales_reciepts AS A 
INNER JOIN conCurrentBuy AS B 
ON A.transaction_date = B.transaction_date 
AND A.transaction_time = B.transaction_time
AND A.transaction_id = B.transaction_id
AND A.sales_outlet_id = B.sales_outlet_id 
INNER JOIN product AS C
ON A.product_id = C.product_id;

SELECT * FROM 
(SELECT row_num, sales_outlet_id
FROM  concurrent 
GROUP BY 1,2
HAVING COUNT(row_num)>2) AS RESULT;  

select *
from concurrent;

## 동시조합 확인_v2
CREATE VIEW salesData_View_v3 AS 
select a.transaction_id, a.transaction_date, a.transaction_time, a.sales_outlet_id, a.staff_id,
a.customer_Id, a.instore_yn, a.quantity, a.line_item_amount, a.unit_price, a.promo_item_yn,
b.product_id, b.product_group, b.product_category, b.product_type, b.product, b.unit_of_measure,
b.current_wholesale_price, b.current_retail_price, b.tax_exempt_yn, b.promo_yn, b.new_product_yn 
from sales_reciepts a  
join product_v3 b
on a.product_id = b.product_id;

CREATE VIEW summarizedCombinedItems_v2 AS 
WITH CombinedItems AS 
(SELECT transaction_date, transaction_time, sales_outlet_id,
        GROUP_CONCAT(product ORDER BY product ASC SEPARATOR '&') AS item_combination
    FROM salesData_View_v3
	GROUP BY 1, 2, 3
		HAVING COUNT(*) > 1)
SELECT transaction_date, transaction_time, sales_outlet_id, item_combination,
COUNT(*) AS total_Sales
FROM CombinedItems
GROUP BY transaction_date, transaction_time, sales_outlet_id;

## 동시구매 조합 많은 순 조회
select item_combination, sum(total_sales) as tot from summarizedCombinedItems_v2
group by 1
order by 2 desc;

## 4. promo 효과 분석 
## 비프로모션 기간 대비 프로모션 기간 판매량 증가율 (프로모션 기간과 비프로모션 기간의 평균 일일 판매량을 비교)
WITH daily_sales AS (
    SELECT 
        product_id,
        promo_item_yn,
        COUNT(DISTINCT transaction_date) AS days,  -- 판매가 일어난 날의 수 (프로모션 또는 비프로모션 기간)
        SUM(quantity) AS total_sales
    FROM 
        sales_reciepts
    WHERE 
        product_id IN (72,87)
    GROUP BY 
        1,2
),
average_sales AS (
    SELECT 
        product_id,
        promo_item_yn,
        total_sales / days AS avg_daily_sales  -- 하루 평균 판매량 계산
    FROM 
        daily_sales
)
SELECT 
    a.product_id, c.product,
    a.avg_daily_sales AS promo_avg_daily_sales,
    b.avg_daily_sales AS non_promo_avg_daily_sales,
    CASE 
        WHEN b.avg_daily_sales = 0 THEN NULL
        ELSE a.avg_daily_sales / b.avg_daily_sales
    END AS sales_increase_ratio  -- 프로모션 대비 비프로모션 판매 증가율
FROM 
    average_sales a
JOIN 
    average_sales b
ON 
    a.product_id = b.product_id 
    AND a.promo_item_yn = 'Y'
    AND b.promo_item_yn = 'N'
join product c
on b.product_id = c.product_id;
    
## 정리
## 가설 - 프로모션을 하면 판매량이 증가할 것이다? 오른 것도 있고 안 오른 것도 있음
## 하지만 프로모션을 하기 떄문에 두개를 함께 사는 사람이 많았음 (동시간대 조합 랭킹에서 두 조합이 디저트-음료 조합 중 1위)  
## 이를 통해 음료와 디저트를 함께 사면 할인해주는 전략을 세운다면 두 상품 모두의 판매량 증대를 기대할 수 있을 것임 

## 프로모션 분석 (피드백 수정)
## 프로모션은 sales_outlet_id가 5, 8인 지점에서만 진행되고 있었다. 
## 프로모션 기간의 프로모션 상품임에도 불구하고 프로모션이 적용된 판매도 있고, 적용되지 않은 판매도 있었다.

## 프로모션 전후의 판매 패턴 비교
## 보다 정확한 판단을 위해 프로모션을 하지 않은 지점 3은 배제 
SELECT
transaction_date, product_id, SUM(quantity) AS daily_sales,
CASE WHEN promo_item_yn = 'Y' THEN 'Promotion Applied'
        ELSE 'No Promotion'
    END AS promo_status
FROM sales_reciepts 
WHERE product_id IN (72, 87)
and sales_outlet_id in (5,8) 
GROUP BY transaction_date, promo_status, product_id 
ORDER BY transaction_date;

## 프로모션 여부 적용하지 않은 total 판매량 
select transaction_date, product_id, sum(quantity) as daily_sales_total
from sales_reciepts 
where product_id in (72,87)
and sales_outlet_id in (5,8)
group by transaction_date, product_id 
order by transaction_date;
