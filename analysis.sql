-- ==============================================================================
-- БИЗНЕС-АНАЛИЗ РОЗНИЧНЫХ ПРОДАЖ (RETAIL SALES)
-- СУБД: PostgreSQL
-- ==============================================================================


-- ------------------------------------------------------------------------------
-- ЗАПРОС 1. ОСНОВНЫЕ ФИНАНСОВЫЕ KPI (EXECUTIVE SUMMARY)
-- Бизнес-цель: общая выручка, число заказов, клиентов, проданных штук и средний чек
-- ------------------------------------------------------------------------------

SELECT 
    SUM(o.quantity * p.unit_price) AS total_sales,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(quantity) AS total_items_sold,
    ROUND(AVG(o.quantity * p.unit_price), 2) AS avg_sales
FROM orders o
JOIN products p ON o.product_id = p.product_id;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 2. АНАЛИЗ КАТЕГОРИЙ И ФИЛЬТРАЦИЯ (GROUP BY + HAVING)
-- Бизнес-цель: категории с выручкой более 50 000$
-- ------------------------------------------------------------------------------

SELECT 
    p.category,
    COUNT(o.order_id) AS total_orders,
    SUM(quantity) AS total_items_sold,
    SUM(o.quantity * p.unit_price) AS total_sales
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category
HAVING SUM(o.quantity * p.unit_price) > 50000
ORDER BY total_sales DESC;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 3. ГЕОГРАФИЯ ПРОДАЖ (JOIN ТРЕХ ТАБЛИЦ)
-- Бизнес-цель: продажи и средний чек по регионам
-- ------------------------------------------------------------------------------

SELECT 
    SUM(o.quantity * p.unit_price) AS total_sales,
    c.region,
    ROUND(AVG(o.quantity * p.unit_price)) AS avg_sales
FROM orders o
JOIN products p ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.region
ORDER BY total_sales DESC;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 4. ПОИСК НЕАКТИВНЫХ КЛИЕНТОВ / ОТТОК (LEFT JOIN + WHERE IS NULL)
-- Бизнес-цель: найти клиентов, которые НЕ совершили ни одной покупки
-- в декабре 2024 года, для новогодней рассылки скидочных промокодов.
-- ------------------------------------------------------------------------------

SELECT 
    c.customer_id,
    c.customer_name,
    c.region,
    c.signup_date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
    AND o.order_date >= '2024-12-01'
WHERE o.order_id IS NULL
ORDER BY c.customer_id;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 5. ТОП-5 VIP-КЛИЕНТОВ (CTE / WITH)
-- Бизнес-цель: найти 5 самых ценных покупателей по сумме покупок
-- ------------------------------------------------------------------------------

WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.region,
        signup_date,
        SUM(o.quantity * p.unit_price) AS total_sales,
        COUNT(o.order_id) AS orders_count
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN products p ON o.product_id = p.product_id
    GROUP BY c.customer_id, c.customer_name, c.region
)
SELECT 
    customer_name,
    region,
    orders_count,
    total_sales
FROM customer_metrics
ORDER BY total_sales DESC
LIMIT 5;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 6. ТОП-2 ТОВАРА В КАЖДОЙ КАТЕГОРИИ (ОКОННАЯ ФУНКЦИЯ DENSE_RANK)
-- Бизнес-цель: 2 самых продаваемых товара внутри КАЖДОЙ категории
-- ------------------------------------------------------------------------------

WITH product_sales AS (
    SELECT 
        p.category,
        p.product_name,
        SUM(o.quantity * p.unit_price) AS total_sales,
        DENSE_RANK() OVER (
            PARTITION BY p.category 
            ORDER BY SUM(o.quantity * p.unit_price) DESC
        ) AS rank_in_category
    FROM orders o
    JOIN products p ON o.product_id = p.product_id
    GROUP BY p.category, p.product_name
)
SELECT 
    category,
    rank_in_category,
    product_name,
    total_sales
FROM product_sales
WHERE rank_in_category <= 2
ORDER BY category, rank_in_category;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 7. НАРАСТАЮЩИЙ ИТОГ ВЫРУЧКИ ПО МЕСЯЦАМ (ОКОННАЯ ФУНКЦИЯ SUM OVER)
-- Бизнес-цель: отследить накопление выручки компании от месяца к месяцу (24 строки)
-- ------------------------------------------------------------------------------

WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', o.order_date)::date AS order_month,
        SUM(o.quantity * p.unit_price) AS total_sales
    FROM orders o
    JOIN products p ON o.product_id = p.product_id
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT 
    order_month,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_month) AS running_total_sales
FROM monthly_sales
ORDER BY order_month;



-- ------------------------------------------------------------------------------
-- ЗАПРОС 8. ДИНАМИКА МЕСЯЦ К МЕСЯЦУ (ОКОННАЯ ФУНКЦИЯ LAG)
-- Бизнес-цель: выручка этого месяца, прошлого месяца, разница и темп прироста в %
-- ------------------------------------------------------------------------------

WITH monthly_summary AS (
    SELECT 
        DATE_TRUNC('month', o.order_date)::date AS order_month,
        SUM(o.quantity * p.unit_price) AS current_revenue
    FROM orders o
    JOIN products p ON o.product_id = p.product_id
    GROUP BY DATE_TRUNC('month', o.order_date)
),
monthly_with_lag AS (
    SELECT 
        order_month,
        current_revenue,
        LAG(current_revenue) OVER (ORDER BY order_month) AS prev_revenue
    FROM monthly_summary
)
SELECT 
    order_month,
    current_revenue,
    prev_revenue,
    current_revenue - prev_revenue AS difference_revenue,
    ROUND((current_revenue - prev_revenue) / prev_revenue * 100) AS growth_pct
FROM monthly_with_lag
ORDER BY order_month;
