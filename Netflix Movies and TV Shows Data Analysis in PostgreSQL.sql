-- ============================================================
-- Netflix Data Analysis Project (PostgreSQL)
-- Dataset: netflix_dataset.csv (8807 records, 12 columns)
-- Columns: show_id, type, title, director, cast, country, date_added,
--          release_year, rating, duration, listed_in, description
-- ============================================================

-- ------------------------------------------------------------
-- Step 1: Create Table & Import Data
-- ------------------------------------------------------------

DROP TABLE IF EXISTS netflix;

CREATE TABLE netflix (
    show_id       VARCHAR(6),
    type          VARCHAR(10),
    title         VARCHAR(150),    -- max length checked in Excel = 104
    director      VARCHAR(250),    -- max 208
    casts         VARCHAR(1000),   -- 'cast' is reserved keyword, renamed to 'casts'; max 771
    country       VARCHAR(150),    -- max 123
    date_added    VARCHAR(50),     -- stored as text
    release_year  INT,
    rating        VARCHAR(10),
    duration      VARCHAR(15),
    listed_in     VARCHAR(100),    -- originally kept 25, changed to 100 after import failed
    description   VARCHAR(250)     -- max 250
);

-- After import, check data
SELECT * FROM netflix;

-- Check total number of records
SELECT COUNT(*) FROM netflix; -- should be 8807 rows


-- ============================================================
-- Step 2: 15 Business Questions & Solutions
-- ============================================================

-- ------------------------------------------------------------
-- 1. Count the number of Movies vs TV Shows
-- ------------------------------------------------------------

SELECT type, COUNT(*) AS total_content
FROM netflix
GROUP BY type;


-- ------------------------------------------------------------
-- 2. Find the most common rating for Movies and TV Shows
-- ------------------------------------------------------------

SELECT * FROM netflix;

WITH cte AS (
    SELECT type, rating, COUNT(rating) AS cnt,
           RANK() OVER(PARTITION BY type ORDER BY COUNT(rating) DESC) AS rn
    FROM netflix
    GROUP BY type, rating
)
SELECT type, rating AS most_common_rating
FROM cte
WHERE rn = 1;


-- ------------------------------------------------------------
-- 3. List all movies released in a specific year (e.g., 2020)
-- ------------------------------------------------------------

SELECT * FROM netflix;
SELECT date_added, release_year FROM netflix LIMIT 5;

SELECT title
FROM netflix
WHERE type = 'Movie' AND release_year = 2020;


-- ------------------------------------------------------------
-- 4. Find the top 5 countries with the most content on Netflix
-- ------------------------------------------------------------

SELECT * FROM netflix LIMIT 5;

SELECT country, COUNT(*) AS total_count
FROM netflix
GROUP BY country
ORDER BY total_count DESC
LIMIT 5;

-- Method 1: Using STRING_TO_ARRAY() and UNNEST()
SELECT country, STRING_TO_ARRAY(country, ',') AS new_country FROM netflix;

SELECT country, UNNEST(STRING_TO_ARRAY(country, ',')) AS new_country FROM netflix;

SELECT TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS new_country, COUNT(show_id) AS total_content
FROM netflix
GROUP BY TRIM(UNNEST(STRING_TO_ARRAY(country, ',')))
ORDER BY total_content DESC
LIMIT 5;

-- Method 2: Using REGEXP_SPLIT_TO_TABLE()
SELECT show_id, type, TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) FROM netflix;

SELECT TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) AS country, COUNT(show_id) AS total_content
FROM netflix
GROUP BY TRIM(REGEXP_SPLIT_TO_TABLE(country, ','))
ORDER BY total_content DESC
LIMIT 5;


-- ------------------------------------------------------------
-- 5. Identify the longest movie
-- ------------------------------------------------------------

SELECT type, title, duration FROM netflix WHERE type = 'Movie';

SELECT * FROM (
    SELECT title, duration, LENGTH(duration), LENGTH(LTRIM(duration)),
           LTRIM(duration), POSITION(' ' IN LTRIM(duration))
    FROM netflix
    WHERE type = 'Movie'
) t
WHERE LENGTH(duration) <> LENGTH(LTRIM(duration));

-- Method 1: Using SUBSTRING and POSITION
SELECT title AS movie, duration
FROM (
    SELECT title,
           CAST(SUBSTRING(duration, 1, POSITION(' ' IN LTRIM(duration)) - 1) AS INT) AS duration,
           ROW_NUMBER() OVER(ORDER BY CAST(SUBSTRING(duration, 1, POSITION(' ' IN LTRIM(duration)) - 1) AS INT) DESC) AS rn
    FROM netflix
    WHERE type = 'Movie' AND duration IS NOT NULL
) t
WHERE rn = 1;

-- Method 2: Using SPLIT_PART()
SELECT *
FROM (
    SELECT DISTINCT title AS movie,
           SPLIT_PART(duration,' ',1)::NUMERIC AS duration
    FROM netflix
    WHERE type = 'Movie'
) subquery
WHERE duration = (SELECT MAX(SPLIT_PART(duration,' ',1)::NUMERIC) FROM netflix);


-- ------------------------------------------------------------
-- 6. Find content added in the last 5 years
-- ------------------------------------------------------------

SELECT show_id, type, title, date_added FROM netflix;

SELECT show_id, type, title, date_added, date_added::DATE FROM netflix;
SELECT show_id, type, title, date_added, CAST(date_added AS DATE) FROM netflix;
SELECT show_id, type, title, date_added, TO_DATE(date_added, 'Month DD, YYYY') FROM netflix;

-- Method 1: Using DATE_PART
SELECT show_id, type, title, date_added,
       DATE_PART('year', CURRENT_DATE) - DATE_PART('year', date_added::DATE)
FROM netflix
WHERE DATE_PART('year', CURRENT_DATE) - DATE_PART('year', date_added::DATE) <= 5;

-- Method 2: Using interval
SELECT *
FROM netflix
WHERE TO_DATE(date_added, 'Month DD, YYYY') > CURRENT_DATE - INTERVAL '5 years';


-- ------------------------------------------------------------
-- 7. Find all movies/TV shows by director 'Rajiv Chilaka'
-- ------------------------------------------------------------

SELECT *
FROM netflix
WHERE director = 'Rajiv Chilaka';

SELECT *
FROM netflix
WHERE director LIKE '%Rajiv Chilaka%';

SELECT *
FROM netflix
WHERE director ILIKE '%Rajiv Chilaka%';


-- ------------------------------------------------------------
-- 8. List all TV shows with more than 5 seasons
-- ------------------------------------------------------------

SELECT * FROM netflix WHERE type = 'TV Show';

-- Method 1: Using LEFT
SELECT title, duration
FROM netflix
WHERE type = 'TV Show' AND LEFT(duration, POSITION(' ' IN duration) - 1)::INT > 5;

-- Method 2: Using SPLIT_PART
SELECT title, duration
FROM netflix
WHERE type = 'TV Show' AND SPLIT_PART(duration,' ',1)::NUMERIC > 5;


-- ------------------------------------------------------------
-- 9. Count number of content items in each genre
-- ------------------------------------------------------------

-- Method 1: Using REGEXP_SPLIT_TO_TABLE()
WITH cte AS (
    SELECT show_id, TRIM(REGEXP_SPLIT_TO_TABLE(listed_in, ',')) AS genre
    FROM netflix
)
SELECT genre, COUNT(*) AS total_count
FROM cte
GROUP BY genre;

-- Method 2: Using STRING_TO_ARRAY() and UNNEST()
SELECT show_id, STRING_TO_ARRAY(listed_in, ',') AS genre FROM netflix;

SELECT genre, COUNT(show_id)
FROM (
    SELECT show_id, TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) AS genre
    FROM netflix
) t
GROUP BY genre;


-- ------------------------------------------------------------
-- 10. Find each year and the average number of content releases in India; return top 5 years
-- ------------------------------------------------------------

WITH cte AS (
    SELECT show_id,
           DATE_PART('year', TO_DATE(date_added, 'Month DD, YYYY')) AS release_year,
           TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) AS country
    FROM netflix
)
SELECT release_year,
       ROUND(COUNT(show_id) * 100.0 / (SELECT COUNT(*) FROM cte WHERE country = 'India'), 2) AS avg_release
FROM cte
WHERE country = 'India'
GROUP BY release_year
ORDER BY avg_release DESC
LIMIT 5;


-- ------------------------------------------------------------
-- 11. List all movies that are documentaries
-- ------------------------------------------------------------

SELECT * FROM netflix
WHERE type = 'Movie' AND listed_in ILIKE '%Documentaries%';


-- ------------------------------------------------------------
-- 12. Find all content without a director
-- ------------------------------------------------------------

SELECT * FROM netflix
WHERE director IS NULL;


-- ------------------------------------------------------------
-- 13. Find how many movies actor 'Salman Khan' appeared in the last 10 years
-- ------------------------------------------------------------

SELECT CURRENT_DATE - INTERVAL '10 years';

SELECT *
FROM netflix
WHERE casts ILIKE '%Salman Khan%'
  AND type = 'Movie'
  AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10;


-- ------------------------------------------------------------
-- 14. Top 10 actors with most movies produced in India
-- ------------------------------------------------------------

WITH cte AS (
    SELECT show_id, TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) AS actors
    FROM netflix
    WHERE country LIKE '%India%'
)
SELECT actors, COUNT(*) AS no_of_appearance
FROM cte
GROUP BY actors
ORDER BY no_of_appearance DESC
LIMIT 10;


-- ------------------------------------------------------------
-- 15. Categorize content as 'Bad' (description has 'kill' or 'violence') or 'Good'
-- ------------------------------------------------------------

SELECT * FROM netflix
WHERE description ILIKE '%kill%' OR description ILIKE '%violence%';

WITH cte AS (
    SELECT *,
           CASE WHEN description ILIKE '%kill%' OR description ILIKE '%violence%'
                THEN 'Bad' ELSE 'Good' END AS category
    FROM netflix
)
SELECT category, COUNT(*) AS total_content
FROM cte
GROUP BY category;

-- ============================================================
-- End of Netflix Data Analysis (PostgreSQL)
-- ============================================================
