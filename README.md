# 📊 E-Commerce & Retail Sales Database Analysis (PostgreSQL)

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B%20%7C%2018-blue.svg)](https://www.postgresql.org/)
[![pgAdmin](https://img.shields.io/badge/pgAdmin-4-336791.svg)](https://www.pgadmin.org/)
[![SQL](https://img.shields.io/badge/SQL-DDL%20%7C%20DML%20%7C%20Window%20Functions-orange.svg)]()
[![Data Integrity](https://img.shields.io/badge/Data%20Integrity-PK%20%7C%20FK%20%7C%20CHECK-green.svg)]()

Практический проект по проектированию реляционной базы данных и комплексному бизнес-анализу розничных продаж (**Retail Sales**) за 2 года (2023-2024 гг.) в СУБД **PostgreSQL**.

---

## 📌 О проекте и бизнес-задаче

В электронной коммерции и ритейле руководство регулярно принимает решения на основе данных: какие товарные направления приносят основной денежный поток, в каких регионах средний чек максимален, кто из клиентов формирует ядро выручки, а кто перестал покупать и требует реактивации.

**Цель проекта:**
1. Спроектировать нормализованную схему реляционной базы данных (3NF) с контролем целостности данных (`PRIMARY KEY`, `FOREIGN KEY`, `CHECK`).
2. Наполнить базу транзакционными данными (3 000 заказов, 50 постоянных клиентов, 25 наименований товаров).
3. Разработать и протестировать 8 аналитических SQL-запросов разного уровня сложности: от расчета ключевых финансовых KPI до когортного анализа оттока, CTE и оконных функций (`DENSE_RANK`, `SUM() OVER`, `LAG()`).

---

## 🗄️ Архитектура и схема базы данных (ERD)

База данных состоит из 3 связанных таблиц:

```text
+-----------------------+              +--------------------------------+
|       customers       |              |             orders             |
+-----------------------+              +--------------------------------+
| PK  customer_id (INT) |<-------+     | PK  order_id (VARCHAR)         |
|     customer_name     |        |     |     order_date (DATE)          |
|     region            |        +-----| FK  customer_id (INT)          |
|     signup_date       |              | FK  product_id (INT)           |---+
+-----------------------+              |     quantity (INT, CHECK > 0)  |   |
                                       +--------------------------------+   |
                                                                            |
                                       +--------------------------------+   |
                                       |            products            |   |
                                       +--------------------------------+   |
                                       | PK  product_id (INT)           |<--+
                                       |     product_name               |
                                       |     category                   |
                                       |     unit_price (NUMERIC)       |
                                       +--------------------------------+
```

### Описание таблиц и полей:

1. **`customers` (Справочник клиентов, 50 записей):**
   - `customer_id` (`INT`, `PRIMARY KEY`) - уникальный идентификатор покупателя.
   - `customer_name` (`VARCHAR(100)`) - имя и фамилия клиента.
   - `region` (`VARCHAR(50)`) - географический регион (`North`, `South`, `East`, `West`, `Central`).
   - `signup_date` (`DATE`) - дата регистрации аккаунта (2021-2022 гг.).

2. **`products` (Каталог товаров, 25 записей):**
   - `product_id` (`INT`, `PRIMARY KEY`) - артикул товара.
   - `product_name` (`VARCHAR(100)`) - наименование продукта.
   - `category` (`VARCHAR(50)`) - категория (`Electronics`, `Furniture`, `Clothing`, `Sports`, `Food`).
   - `unit_price` (`NUMERIC(10, 2)`) - базовая розничная стоимость товара.

3. **`orders` (Факты продаж / транзакции, 3 000 записей):**
   - `order_id` (`VARCHAR(20)`, `PRIMARY KEY`) - номер чека/заказа.
   - `order_date` (`DATE`) - дата покупки (период с 01.01.2023 по 31.12.2024).
   - `customer_id` (`INT`, `FOREIGN KEY REFERENCES customers`) - ссылка на покупателя.
   - `product_id` (`INT`, `FOREIGN KEY REFERENCES products`) - ссылка на купленный товар.
   - `quantity` (`INT`, `CHECK (quantity > 0)`) - количество единиц в чеке (строго положительное).

### Целостность данных (Data Integrity):
- **Внешние ключи (`FOREIGN KEY`)** гарантируют ссылочную целостность: невозможно добавить заказ на несуществующего клиента или удалить товар, пока по нему есть транзакции.
- **Ограничение `CHECK (quantity > 0)`** защищает базу от некорректных отрицательных объемов на уровне СУБД.

---

## 🚀 Развертывание базы данных в PostgreSQL

### Шаг 1. Создание базы данных
В клиенте **pgAdmin 4** или консоли `psql` создайте пустую базу:
```sql
CREATE DATABASE retail_sales;
```

### Шаг 2. Создание структуры таблиц
Подключитесь к базе `retail_sales` и выполните скрипт [schema.sql](schema.sql):
```sql
\i path/to/schema.sql
```
*(В pgAdmin 4: откройте `Query Tool`, вставьте содержимое `schema.sql` и нажмите `F5`).*

### Шаг 3. Импорт данных из CSV
Импортируйте файлы в строгом порядке зависимостей (сначала справочники, затем таблица фактов):
1. `customers.csv` ➔ таблица `customers`
2. `products.csv` ➔ таблица `products`
3. `orders.csv` ➔ таблица `orders`

**Способ через pgAdmin 4:**
- Правый клик по таблице ➔ **Import/Export Data...**
- Переключатель: **Import**
- Формат: **csv**, разделитель (Delimiter): `,`, заголовок (Header): **Yes**, кодировка: **utf-8**.

**Способ через консоль `psql` (`\copy`):**
```sql
\copy customers FROM 'customers.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');
\copy products FROM 'products.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');
\copy orders FROM 'orders.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');
```

---

## 🔍 Бизнес-задачи и аналитические SQL-запросы

Все запросы собраны в рабочем скрипте [analysis.sql](analysis.sql). Ниже представлен подробный разбор каждой задачи с реальными результатами выполнения.

---

### Запрос 1. Основные финансовые KPI (Executive Summary)

* **Бизнес-цель:** Предоставить сводные показатели бизнеса за весь период: суммарная выручка, общее количество оформленных заказов, число активных уникальных клиентов, суммарное число проданных единиц товара и средний чек.
* **Навыки SQL:** Агрегатные функции `SUM()`, `COUNT()`, `COUNT(DISTINCT)`, `ROUND()`, `AVG()`, соединение таблиц `JOIN`.

```sql
SELECT 
    SUM(o.quantity * p.unit_price) AS total_sales,
    COUNT(order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(quantity) AS total_items_sold,
    ROUND(AVG(o.quantity * p.unit_price), 2) AS avg_sales
FROM orders o
JOIN products p ON o.product_id = p.product_id;
```

#### Результат выполнения:
![Результат Запроса 1 в pgAdmin 4](images/01_financial_kpi.png)

| total_sales | total_orders | total_customers | total_items_sold | avg_sales |
|---|---|---|---|---|
| 348 816.48 | 3 000 | 50 | 5 052 | 116.27 |

* **Бизнес-вывод:** За 2 года бизнес сгенерировал \$348.8k выручки на 3 000 заказов со средним чеком \$116.27. В среднем на одного зарегистрированного клиента приходится 60 заказов, что подтверждает высокую регулярность покупок.

---

### Запрос 2. Анализ категорий с фильтрацией (GROUP BY + HAVING)

* **Бизнес-цель:** Выделить ключевые товарные категории, принесшие компании более \$50 000 выручки, и оценить их вклад по числу заказов и штучным продажам.
* **Навыки SQL:** Группировка `GROUP BY`, фильтрация агрегированных значений через `HAVING`, сортировка `ORDER BY DESC`.

```sql
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
```

#### Результат выполнения:
![Результат Запроса 2 в pgAdmin 4](images/02_category_analysis.png)

| category | total_orders | total_items_sold | total_sales |
|---|---|---|---|
| Electronics | 614 | 801 | 139 281.99 |
| Furniture | 304 | 353 | 98 826.47 |
| Clothing | 612 | 967 | 58 075.33 |

* **Бизнес-вывод:** Из 5 категорий планку в \$50 000 преодолели только три. Категория `Electronics` лидирует по денежному объему (\$139.3k), а `Furniture` обеспечивает второе место по выручке при минимальном числе заказов (304) за счет высокого чека. Категории `Sports` и `Food` остались за рамками выборки как вспомогательные.

---

### Запрос 3. География продаж и средний чек по регионам (JOIN 3 таблиц)

* **Бизнес-цель:** Оценить распределение выручки и среднего чека по макрорегионам для оптимизации региональной логистики и маркетинга.
* **Навыки SQL:** Объединение трех таблиц (`orders` ➔ `products` ➔ `customers`), группировка по географическому признаку, округление среднего чека.

```sql
SELECT 
    SUM(o.quantity * p.unit_price) AS total_sales,
    c.region,
    ROUND(AVG(o.quantity * p.unit_price)) AS avg_sales
FROM orders o
JOIN products p ON o.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.region
ORDER BY total_sales DESC;
```

#### Результат выполнения:
![Результат Запроса 3 в pgAdmin 4](images/03_regional_sales.png)

| total_sales | region | avg_sales |
|---|---|---|
| 98 822.88 | South | 137 |
| 69 745.93 | East | 131 |
| 65 702.37 | West | 108 |
| 61 828.66 | North | 97 |
| 52 716.64 | Central | 107 |

* **Бизнес-вывод:** Регион `South` лидирует с большим отрывом (\$98.8k) и показывает самый высокий средний чек (\$137). Регион `North` генерирует сопоставимый объем заказов, но средний чек в нем минимален (\$97).

---

### Запрос 4. Поиск неактивных клиентов и оттока (LEFT JOIN Anti-Join)

* **Бизнес-цель:** Найти покупателей, которые не совершили ни одной покупки в декабре 2024 года, для запуска новогодней реактивационной промо-рассылки со скидочными купонами.
* **Навыки SQL:** Шаблон «Anti-Join» через `LEFT JOIN` с составным условием `AND` и фильтрацией `WHERE ... IS NULL`.

```sql
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
```

#### Результат выполнения (10 клиентов из 50):
![Результат Запроса 4 в pgAdmin 4](images/04_inactive_customers.png)

| customer_id | customer_name | region | signup_date |
|---|---|---|---|
| 1 | James Smith | North | 2021-01-10 |
| 9 | David Rodriguez | West | 2021-05-05 |
| 10 | Elizabeth Martinez | Central | 2021-05-20 |
| 14 | Susan Wilson | West | 2021-07-17 |
| 31 | Donald Walker | North | 2022-03-20 |
| 32 | Ashley Young | South | 2022-04-03 |
| 36 | Kimberly Scott | North | 2022-05-31 |
| 40 | Donna Flores | Central | 2022-07-28 |
| 44 | Carol Baker | West | 2022-09-24 |
| 48 | Melissa Mitchell | East | 2022-11-21 |

* **Бизнес-вывод:** Ровно 20% клиентской базы (10 человек) пропустили предновогодний сезон покупок. Этот список передается в отдел маркетинга для адресных email-рассылок.

---

### Запрос 5. Топ-5 VIP-клиентов компании (CTE / WITH)

* **Бизнес-цель:** Идентифицировать 5 наиболее ценных клиентов компании по суммарному чеку за всю историю, чтобы включить их в премиальную программу лояльности.
* **Навыки SQL:** Табличные выражения `WITH` (CTE), объединение 3 таблиц, расчет агрегатов на уровне клиента, сортировка и ограничение выборки `LIMIT`.

```sql
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
```

#### Результат выполнения:
![Результат Запроса 5 в pgAdmin 4](images/05_top5_vip_customers.png)

| customer_name | region | orders_count | total_sales |
|---|---|---|---|
| Mark Lewis | West | 244 | 24 232.74 |
| Michael Miller | South | 147 | 23 144.41 |
| Kevin Nelson | East | 74 | 15 317.73 |
| Lisa Perez | South | 107 | 14 516.41 |
| Daniel Thompson | East | 97 | 11 840.44 |

* **Бизнес-вывод:** Топ-5 клиентов принесли бизнесу \$89 051.73 (более 25% совокупной выручки компании). Потеря любого из этих клиентов напрямую отразится на финансовых результатах, поэтому за ними закрепляются индивидуальные скидки и приоритетная поддержка.

---

### Запрос 6. Топ-2 бестселлера в каждой категории (Оконная функция DENSE_RANK)

* **Бизнес-цель:** Найти по 2 самых продаваемых товара внутри абсолютно каждой категории для оптимизации складских запасов и приоритетных закупок.
* **Навыки SQL:** Оконная функция ранжирования `DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...)`, вложенный CTE, фильтрация по рангу `WHERE rank <= 2`.

```sql
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
```

#### Результат выполнения:
![Результат Запроса 6 в pgAdmin 4](images/06_top2_products_per_category.png)

| category | rank_in_category | product_name | total_sales |
|---|---|---|---|
| Clothing | 1 | Running Shoes | 18 298.17 |
| Clothing | 2 | Winter Jacket | 13 499.10 |
| Electronics | 1 | Laptop Pro 15 | 70 199.46 |
| Electronics | 2 | Monitor 27" | 33 749.25 |
| Food | 1 | Protein Bar Pack | 8 571.57 |
| Food | 2 | Ground Coffee 500g | 4 785.21 |
| Furniture | 1 | Office Chair | 27 299.09 |
| Furniture | 2 | Standing Desk | 25 849.53 |
| Sports | 1 | Water Bottle | 7 671.93 |
| Sports | 2 | Dumbbell Set | 6 509.07 |

* **Бизнес-вывод:** Абсолютный локомотив ассортимента - `Laptop Pro 15` (\$70.2k). В категории мебели основные продажи делят `Office Chair` и `Standing Desk`. Эти 10 позиций являются ключевыми драйверами складского оборота.

---

### Запрос 7. Нарастающий итог выручки по месяцам (Оконная функция SUM OVER)

* **Бизнес-цель:** Отследить непрерывную динамику накопления денежного потока компании по 24 месяцам наблюдения.
* **Навыки SQL:** Усечение дат `DATE_TRUNC('month', ...)`, оконная функция кумулятивной суммы `SUM() OVER (ORDER BY ...)`.

```sql
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
```

#### Результат выполнения (фрагмент выборки из 24 месяцев):
![Результат Запроса 7 в pgAdmin 4](images/07_cumulative_monthly_revenue.png)

| order_month | total_sales | running_total_sales |
|---|---|---|
| 2023-01-01 | 12 978.88 | 12 978.88 |
| 2023-02-01 | 16 568.12 | 29 547.00 |
| 2023-03-01 | 12 489.96 | 42 036.96 |
| ... | ... | ... |
| 2024-10-01 | 20 611.96 | 311 967.70 |
| 2024-11-01 | 16 766.73 | 328 734.43 |
| 2024-12-01 | 20 082.05 | 348 816.48 |

* **Бизнес-вывод:** Кумулятивная выручка стабильно возрастает, перешагнув отметку в \$100k в августе 2023 г., \$200k в марте 2024 г. и достигнув \$348.8k к концу 2024 года.

---

### Запрос 8. Динамика продаж месяц к месяцу (Оконная функция LAG)

* **Бизнес-цель:** Рассчитать ежемесячную выручку, выручку предыдущего месяца, абсолютный прирост/падение и процент изменения (MoM Growth Rate).
* **Навыки SQL:** Каскадные CTE, оконная функция смещения `LAG() OVER (ORDER BY ...)`, расчет темпа прироста `(current - prev) / prev * 100`.

```sql
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
```

#### Результат выполнения (фрагмент выборки):
![Результат Запроса 8 в pgAdmin 4](images/08_monthly_revenue_growth_lag.png)

| order_month | current_revenue | prev_revenue | difference_revenue | growth_pct |
|---|---|---|---|---|
| 2023-01-01 | 12 978.88 | *[null]* | *[null]* | *[null]* |
| 2023-02-01 | 16 568.12 | 12 978.88 | 3 589.24 | 28% |
| 2023-03-01 | 12 489.96 | 16 568.12 | -4 078.16 | -25% |
| 2023-04-01 | 17 239.89 | 12 489.96 | 4 749.93 | 38% |
| 2023-05-01 | 10 982.79 | 17 239.89 | -6 257.10 | -36% |
| ... | ... | ... | ... | ... |
| 2024-08-01 | 8 395.84 | 17 135.77 | -8 739.93 | -51% |
| 2024-09-01 | 16 142.88 | 8 395.84 | 7 747.04 | 92% |
| 2024-10-01 | 20 611.96 | 16 142.88 | 4 469.08 | 28% |
| 2024-11-01 | 16 766.73 | 20 611.96 | -3 845.23 | -19% |
| 2024-12-01 | 20 082.05 | 16 766.73 | 3 315.32 | 20% |

* **Бизнес-вывод:** В ритейле четко прослеживаются сезонные колебания: резкий спад в августе (-51%) с последующим взрывным отскоком в сентябре (+92%) к началу делового и учебного сезона, а также высокий предновогодний пик в декабре (\$20.08k).

---

## 📁 Структура проекта

```text
SQL_project/
├── images/           # Скриншоты выполнения аналитических запросов в pgAdmin 4
├── schema.sql        # DDL-скрипт создания схемы БД и таблиц с ограничениями (PK/FK/CHECK)
├── analysis.sql      # 8 готовых аналитических бизнес-запросов (от KPI до Window Functions)
├── customers.csv     # Таблица-измерение клиентов (50 записей)
├── products.csv      # Таблица-измерение товаров и цен (25 записей)
├── orders.csv        # Таблица фактов продаж (3 000 транзакций)
└── README.md         # Полная документация проекта и аналитический отчет
```


