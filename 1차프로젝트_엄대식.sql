
# PRODUCT SIZE 전처리 View 생성 (사이즈 통합)
create OR replace view product_v3 as
select product_id, product_group, product_category, product_type,
case when product like '%Lg' then rtrim(replace(product, 'Lg', ''))
when product like '%Rg' then rtrim(replace(product, 'Rg', ''))
when product like '%Sm' THEN rtrim(replace(product, 'Sm', ''))
else product
end as product
, product_description,
unit_of_measure, current_wholesale_price, current_retail_price, tax_exempt_yn, promo_yn, new_product_yn
from product;


# Outlet별 카테고리 매출 view 생성
create or replace view product_v4 as
select 
	a.sales_outlet_id,
	b.product_group,
	ROUND(sum(a.line_item_amount),0) as total_amount
from 
 `201904 sales reciepts` a 
INNER JOIN 
    `product` b
ON 
	a.product_id = b.product_id
GROUP BY
	a.sales_outlet_id,
    b.product_group
ORDER BY
	a.sales_outlet_id,
    b.product_group;
    
    
# Sales_Outlet 별 위치
# 1.1 Outlet 지역 조사
-- Sales_outlet
select sales_outlet_id, Store_address, sales_outlet_type, store_city, store_state_province, Neighorhood
from sales_outlet
where sales_outlet_id in (3,5,8);
 

 # 카테고리 별 상품 종류
 # 1.3.2 매장 별 판매 목표 및 카테고리 별 달성도 분석
 select product_id, product_group, product
 from product
 order by product_group
 
 
 # 매장 별 판매 목표 및 카테고리 별 달성도 분석
 # 1.3.2 매장 별 판매 목표 및 카테고리 별 달성도 분석
select 
	a. sales_outlet_id,
    b. product_group,
    b. product,
    SUM(a. quantity) as total_quantity
from 
	`201904 sales reciepts` a 
inner join
	product_v2 b 
on
	a. product_id = b. product_id
where
	b. product_group in ('Beverages','Food','Merchandise','Whole Bean/Teas')
group by 
	a. sales_outlet_id,
    b. product_group,
    b. product


# Outlet 별 평수 대비 매출 수준
# 1.4.1 추가분석 
SELECT 
    a.sales_outlet_id,
    SUM(a.quantity) AS qty,
    SUM(a.line_item_amount) as total_amount,
    b.store_square_feet AS square_feet,
    ROUND(SUM(a.line_item_amount) / b.store_square_feet, 2) as result
FROM 
    `201904 sales reciepts` a 
INNER JOIN 
    `sales_outlet` b
ON 
    a.sales_outlet_id = b.sales_outlet_id
GROUP BY 
    a.sales_outlet_id, b.store_square_feet
ORDER BY 
    result DESC;
    
    
# Outlet 별로 In store or not 분석
# 1.4.2 추가분석 
SELECT a.sales_outlet_id,
    COUNT(CASE WHEN a.instore_yn = 'Y' THEN 1 END) AS in_store_count,
    COUNT(CASE WHEN a.instore_yn = 'N' THEN 1 END) AS to_go_count
FROM 
    `201904 sales reciepts` a 
INNER JOIN 
    `product_v2` b 
ON 
    a.product_id = b.product_id
group by a.sales_outlet_id;


# 테이크아웃 순위 분석
# 1.4.3 추가분석 
SELECT 
	b.product_group, 
    b.product_category, 
    b.product_type,
    COUNT(CASE WHEN a.instore_yn = 'N' THEN 1 END) AS to_go_count
FROM 
    `201904 sales reciepts` a 
INNER JOIN 
    `product_v2` b 
ON 
    a.product_id = b.product_id
group by 
	b.product_group, 
    b.product_category, 
    b.product_type
Order by to_go_count desc;
