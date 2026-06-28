-- Этап 1. Создание и заполнение БД
CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id INT,
    auto TEXT,
    gasoline_consumption NUMERIC,
    price NUMERIC,
    date DATE,
    person_name TEXT,
    phone TEXT,
    discount INT,
    brand_origin TEXT
);



CREATE SCHEMA car_shop;

CREATE TABLE car_shop.countries (
    country_id serial PRIMARY KEY, 	/* serial — используется для автоинкремента первичного ключа */
    country_name varchar(50) NOT NULL UNIQUE 	/* varchar — название страны хранится текстом */
);
CREATE TABLE car_shop.brands (
    brand_id serial PRIMARY KEY, 	/* serial — используется для автоинкремента первичного ключа */
    brand_name varchar(50) NOT NULL UNIQUE, 	/* varchar — название бренда может содержать буквы, цифры и символы */
    country_id int NOT NULL REFERENCES car_shop.countries(country_id) 	* int — внешний ключ хранит идентификатор страны */
);
CREATE TABLE car_shop.models (
    model_id serial PRIMARY KEY, 	/* serial — используется для автоинкремента первичного ключа */
    brand_id int NOT NULL REFERENCES car_shop.brands(brand_id), 	/* int — внешний ключ хранит идентификатор бренда */
    model_name varchar(100) NOT NULL 	/* varchar — название модели может содержать буквы, цифры и пробелы */
);
CREATE TABLE car_shop.customers (
    customer_id serial PRIMARY KEY, 	/* serial — используется для автоинкремента первичного ключа */
    person_name varchar(100) NOT NULL, 	/* varchar — имя покупателя является строкой переменной длины */
    phone varchar(50) NOT NULL UNIQUE 	/* varchar — может содержать +, -, пробелы и скобки */
);

CREATE TABLE car_shop.colors (
    color_id serial PRIMARY KEY, 	/* serial — автоинкремент для уникального идентификатора цвета */
    color_name varchar(50) NOT NULL UNIQUE 	/* varchar — цвет хранится текстом*/
);
CREATE TABLE car_shop.cars (
    car_id serial PRIMARY KEY, 	/* serial — используется для автоинкремента первичного ключа */
    model_id int NOT NULL REFERENCES car_shop.models(model_id), 	/* int — внешний ключ хранит идентификатор модели */
    color_id int NOT NULL REFERENCES car_shop.colors(color_id), 	/* int — внешний ключ хранит идентификатор цвета */
    gasoline_consumption numeric(4,1) 	/* numeric(4,1) — расход топлива может быть дробным*/
);
CREATE TABLE car_shop.sales (
    sale_id serial PRIMARY KEY, 	/* serial — используется для автоинкремента первичного ключа */
    car_id int NOT NULL REFERENCES car_shop.cars(car_id),	 /* int — внешний ключ хранит идентификатор автомобиля */
    customer_id int NOT NULL REFERENCES car_shop.customers(customer_id),	 /* int — внешний ключ хранит идентификатор покупателя */
    sale_date date NOT NULL, 	/* date — хранит только дату продажи без времени */
    price numeric(9,2) NOT NULL, 	/* numeric(9,2) — цена может содержать копейки*/
    discount smallint DEFAULT 0		/* smallint — скидка является небольшим целым числом (например, процент) */
);




INSERT INTO car_shop.countries (country_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

SELECT * 
FROM car_shop.countries;


INSERT INTO car_shop.brands (brand_name, country_id)
SELECT DISTINCT
    split_part(s.auto, ' ', 1) AS brand_name,
    c.country_id
FROM raw_data.sales AS s
LEFT JOIN car_shop.countries AS c
    ON s.brand_origin = c.country_name
WHERE split_part(s.auto, ' ', 1) IS NOT NULL
  AND c.country_id IS NOT NULL;

SELECT *
FROM car_shop.brands;


INSERT INTO car_shop.models (brand_id, model_name)
SELECT DISTINCT
    b.brand_id,
    trim(
        regexp_replace(
            split_part(s.auto, ',', 1),
            '^' || b.brand_name || '\s+',
            ''
        )
    ) AS model_name
FROM raw_data.sales AS s
JOIN car_shop.brands AS b
    ON split_part(s.auto, ' ', 1) = b.brand_name
WHERE s.auto IS NOT NULL;

SELECT 
* FROM car_shop.models;


INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT
    trim(split_part(auto, ',', 2)) AS color_name
FROM raw_data.sales;

SELECT * 
FROM car_shop.colors;


INSERT INTO car_shop.customers (person_name, phone)
SELECT DISTINCT
    person_name,
    phone
FROM raw_data.sales;

SELECT * 
FROM car_shop.customers;


INSERT INTO car_shop.cars (model_id, color_id, gasoline_consumption)
SELECT DISTINCT
    m.model_id,
    c.color_id,
    s.gasoline_consumption
FROM raw_data.sales AS s
JOIN car_shop.brands AS b
    ON b.brand_name = split_part(s.auto, ' ', 1)
JOIN car_shop.models AS m
    ON m.brand_id = b.brand_id
   AND m.model_name = trim(
        regexp_replace(
            split_part(s.auto, ',', 1),
            '^' || b.brand_name || '\s+',
            ''
        )
   )
JOIN car_shop.colors AS c
    ON c.color_name = trim(split_part(s.auto, ',', 2));

SELECT * 
FROM car_shop.cars;


INSERT INTO car_shop.sales (car_id, customer_id, sale_date, price, discount)
SELECT
    car.car_id,
    cu.customer_id,
    s.date,
    s.price,
    s.discount
FROM raw_data.sales AS s
JOIN car_shop.brands AS b
    ON b.brand_name = split_part(s.auto, ' ', 1)
JOIN car_shop.models AS m
    ON m.brand_id = b.brand_id
   AND m.model_name = trim(
        regexp_replace(
            split_part(s.auto, ',', 1),
            '^' || b.brand_name || '\s+',
            ''
        )
   )
JOIN car_shop.colors AS col
    ON col.color_name = trim(split_part(s.auto, ',', 2))
JOIN car_shop.cars AS car
    ON car.model_id = m.model_id
   AND car.color_id = col.color_id
   AND car.gasoline_consumption = s.gasoline_consumption
JOIN car_shop.customers AS cu
    ON cu.phone = s.phone;

SELECT *
FROM car_shop.sales;


-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

SELECT
    ROUND(
        COUNT(DISTINCT model_id) FILTER (WHERE gasoline_consumption IS NULL) * 100.0
        / COUNT(DISTINCT model_id),
        2
    ) AS nulls_percentage_gasoline_consumption
FROM car_shop.cars;


---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.


SELECT
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM car_shop.sales s
JOIN car_shop.cars c
    ON s.car_id = c.car_id
JOIN car_shop.models m
    ON c.model_id = m.model_id
JOIN car_shop.brands b
    ON m.brand_id = b.brand_id
GROUP BY
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date)
ORDER BY
    b.brand_name,
    year; 


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.


SELECT
    EXTRACT(YEAR FROM sale_date) AS year,
    EXTRACT(MONTH FROM sale_date) AS month,
    ROUND(AVG(price * (1 - discount / 100.0)), 2) AS average_price
FROM car_shop.sales
WHERE EXTRACT(YEAR FROM sale_date) = 2022
GROUP BY
    EXTRACT(YEAR FROM sale_date),
    EXTRACT(MONTH FROM sale_date)
ORDER BY
    year,
    month;


---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.


SELECT
    c.person_name AS person,
    STRING_AGG(
        b.brand_name || ' ' || m.model_name,
        ', '
    ) AS cars
FROM car_shop.customers AS c
JOIN car_shop.sales AS s
    ON c.customer_id = s.customer_id
JOIN car_shop.cars AS ca
    ON s.car_id = ca.car_id
JOIN car_shop.models AS m
    ON ca.model_id = m.model_id
JOIN car_shop.brands AS b
    ON m.brand_id = b.brand_id
GROUP BY c.person_name
ORDER BY person;


---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.


SELECT COUNT(*) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';


SELECT
    c.country_name AS brand_origin,
    ROUND(MIN(s.price / (1 - s.discount / 100.0)), 2) AS price_min,
    ROUND(MAX(s.price / (1 - s.discount / 100.0)), 2) AS price_max
FROM car_shop.sales AS s
JOIN car_shop.cars AS car
    ON s.car_id = car.car_id
JOIN car_shop.models AS m
    ON car.model_id = m.model_id
JOIN car_shop.brands AS b
    ON m.brand_id = b.brand_id
JOIN car_shop.countries AS c
    ON b.country_id = c.country_id
GROUP BY c.country_name
ORDER BY c.country_name;

