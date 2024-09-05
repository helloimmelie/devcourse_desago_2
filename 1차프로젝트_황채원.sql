# 방문횟수분석

# 1.1 방문 횟수 집계 , 1.2 매장별 방문 고객의 id 확인
    
## 방문횟수별 고객수
    
SELECT
    sales_outlet_id,
    visit_count,
    COUNT(customer_id) AS customer_count
FROM (
    SELECT
        sr.sales_outlet_id,
        sr.customer_id,
        COUNT(DISTINCT CONCAT(sr.transaction_date, sr.transaction_time, sr.customer_id)) AS visit_count
    FROM
        receipts sr
    GROUP BY
        sr.sales_outlet_id, sr.customer_id
) AS VisitSummary
GROUP BY
    sales_outlet_id, visit_count
ORDER BY
    sales_outlet_id, visit_count;



#1.3 고객데이터 중복 확인
    
## 같은 메일을 가지고 있는 고객 확인
    
SELECT
    c1.customer_email,
    COUNT(DISTINCT c1.customer_id) AS different_ids_count
FROM
    customer c1
GROUP BY
    c1.customer_email
HAVING
    COUNT(DISTINCT c1.customer_id) > 1;
## 해당 메일을 갖고 있는 고객의 정보 확인 (동일인물인지 확인)
SELECT *
from customer
where customer_email = 'Porter@pellentesque.gov';





#매장별 고객 충성도 분석

#2.1 매장별 고객 행동
    
## 방문횟수 탑30 고객의 방문횟수 분석
    
WITH RankedCustomers AS (
    SELECT
        sr.sales_outlet_id,
        sr.customer_id,
        COUNT(DISTINCT CONCAT(sr.transaction_date, sr.transaction_time, sr.customer_id)) AS visit_count,
        ROW_NUMBER() OVER
        (PARTITION BY sr.sales_outlet_id ORDER BY COUNT(DISTINCT CONCAT(sr.transaction_date, sr.transaction_time, sr.customer_id)) DESC) AS rank1
    FROM
        receipts sr
    JOIN
        sales_outlet o ON sr.sales_outlet_id = o.sales_outlet_id
    GROUP BY
        sr.sales_outlet_id, sr.customer_id
)
SELECT
    sales_outlet_id,
    customer_id,
    visit_count,
    rank1
FROM
    RankedCustomers
WHERE
    rank1 <= 31
ORDER BY
    sales_outlet_id, rank1;



#2.2 매출비중분석
    
## 방문을 많이한 고객들이 많이 구매한 product 매장별로 탑3
    
WITH RankedCustomers AS (
    SELECT
        sr.sales_outlet_id,
        sr.customer_id,
        COUNT(DISTINCT CONCAT(sr.transaction_date, sr.transaction_time, sr.customer_id)) AS visit_count,
        DENSE_RANK() OVER (PARTITION BY sr.sales_outlet_id ORDER BY COUNT(DISTINCT CONCAT(sr.transaction_date, sr.transaction_time, sr.customer_id)) DESC) AS rank1
    FROM
        receipts sr
    JOIN
        sales_outlet o ON sr.sales_outlet_id = o.sales_outlet_id
    GROUP BY
        sr.sales_outlet_id, sr.customer_id
),
TopProducts AS (
    SELECT
        rc.sales_outlet_id,
        rc.customer_id,
        sr.product_id,
        p.product,
        SUM(sr.quantity) AS total_quantity,
        ROW_NUMBER() OVER (PARTITION BY rc.sales_outlet_id, rc.customer_id ORDER BY SUM(sr.quantity) DESC) AS product_rank
    FROM
        RankedCustomers rc
    JOIN
        receipts sr ON rc.sales_outlet_id = sr.sales_outlet_id AND rc.customer_id = sr.customer_id
    JOIN
        product p ON sr.product_id = p.product_id
    WHERE
        p.product_category != 'Flavours' and rc.rank1 <= 50
    GROUP BY
        rc.sales_outlet_id, rc.customer_id, sr.product_id, p.product
)
SELECT
    sales_outlet_id,
    customer_id,
    product,
    total_quantity,
    product_rank
FROM
    TopProducts
WHERE
    product_rank <= 4
ORDER BY
    sales_outlet_id, customer_id, product_rank;



## 2.2 매출비중분석
    
## 각 매장별 고객의 총 방문 수
    
SELECT
    sr.sales_outlet_id,
    COUNT(DISTINCT sr.customer_id) AS total_customers
FROM
    receipts sr
GROUP BY
    sr.sales_outlet_id
ORDER BY
    sr.sales_outlet_id;


## 파레토곡선용 매장별 방문횟수 순의 고객의 누적 매출

WITH CustomerVisits AS (
    -- Step 1: Calculate distinct visits for each customer in each outlet (same time, same outlet = 1 visit)
    SELECT
        sr.sales_outlet_id,
        sr.customer_id,
        COUNT(DISTINCT CONCAT(sr.transaction_date, sr.transaction_time)) AS total_visits,  -- Unique visits based on date and time
        SUM(sr.line_item_amount) AS total_sales  -- Total sales per customer per outlet
    FROM
        receipts sr
    WHERE
        sr.customer_id != 0  -- Exclude customer_id = 0
    GROUP BY
        sr.sales_outlet_id, sr.customer_id
),
CustomerSalesWithPercentage AS (
    -- Step 2: Calculate the total sales for each outlet and prepare data for cumulative calculations
    SELECT
        cv.sales_outlet_id,
        cv.customer_id,
        cv.total_visits,
        cv.total_sales,
        cv.total_sales / (SELECT SUM(total_sales) FROM CustomerVisits WHERE sales_outlet_id = cv.sales_outlet_id) AS sales_percentage
    FROM
        CustomerVisits cv
),
RankedCustomerSales AS (
    -- Step 3: Calculate cumulative sales percentage and sort by total visits ascending order
    SELECT
        cs.sales_outlet_id,
        cs.customer_id,
        cs.total_visits,
        cs.total_sales,
        cs.sales_percentage,
        SUM(cs.sales_percentage) OVER (PARTITION BY cs.sales_outlet_id ORDER BY cs.total_visits ASC) AS cumulative_sales_percentage  -- Cumulative percentage by outlet
    FROM
        CustomerSalesWithPercentage cs
)
-- Final result: Show customer visits, sales, cumulative sales percentage per outlet, ordered by visits
SELECT
    sales_outlet_id,
    customer_id,
    total_visits,
    total_sales,
    sales_percentage,
    cumulative_sales_percentage
FROM
    RankedCustomerSales
ORDER BY
    sales_outlet_id, total_visits ASC;



#2.3 충성고객의 구매패턴
    
## 각 지점별로 재방문 고객들이 많이산 항목 탑4
    
select sales_outlet_id, product, total_quantity
from rebuyrank4
where customer_id = 0;
