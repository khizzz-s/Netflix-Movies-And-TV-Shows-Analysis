## Netflix Movies and TV Shows Data Analysis using SQL

![](https://github.com/khizzz-s/Netflix-Movies-TV-Shows-Analysis/blob/main/logo.png)

## Overview

This project presents a comprehensive analysis of Netflix’s movies and TV shows dataset using SQL (PostgreSQL).\
The goal is to extract meaningful insights and answer key business questions by querying and transforming the dataset.

## Objectives

- Analyze the distribution of content types (Movies vs TV Shows)
- Identify the most common ratings by content type
- List and explore content based on release year, countries, and duration
- Categorize and analyze content using keywords and specific criteria

## Dataset

- **Source:** [Netflix Movies and TV Shows Dataset on Kaggle](https://www.kaggle.com/datasets/shivamb/netflix-shows?resource=download)
- Contains \~8807 records and 12 columns

## Table Schema

```sql
DROP TABLE IF EXISTS netflix;
CREATE TABLE netflix (
    show_id      VARCHAR(5),
    type         VARCHAR(10),
    title        VARCHAR(250),
    director     VARCHAR(550),
    casts        VARCHAR(1050),
    country      VARCHAR(550),
    date_added   VARCHAR(55),
    release_year INT,
    rating       VARCHAR(15),
    duration     VARCHAR(15),
    listed_in    VARCHAR(250),
    description  VARCHAR(550)
);
```

## Business Questions & Solutions

Below are 15 key business questions explored using SQL, along with brief objectives and queries.

---

### 1. Count the Number of Movies vs TV Shows

**Objective:** Find distribution of content types.

```sql
SELECT type, COUNT(*) as total_content
FROM netflix
GROUP BY type;
```

---

### 2. Find the Most Common Rating for Movies and TV Shows

**Objective:** Identify most frequent rating for each type.

```sql
WITH cte AS (
	SELECT type, rating, COUNT(rating) AS cnt,
	       RANK() OVER(PARTITION BY type ORDER BY COUNT(rating) DESC) AS rn
	FROM netflix
	GROUP BY type, rating
)
SELECT type, rating as most_common_rating
FROM cte
WHERE rn = 1;
```

---

### 3. List All Movies Released in a Specific Year (e.g., 2020)

**Objective:** Show movies released in 2020.

```sql
SELECT title
FROM netflix
WHERE type = 'Movie' AND release_year = 2020;
```

---

### 4. Find the Top 5 Countries with the Most Content

**Objective:** Identify top 5 countries producing Netflix content.

**Method 1: Using STRING\_TO\_ARRAY and UNNEST**

```sql
SELECT TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) as country,
       COUNT(show_id) as total_content
FROM netflix
GROUP BY TRIM(UNNEST(STRING_TO_ARRAY(country, ',')))
ORDER BY total_content DESC
LIMIT 5;
```

**Method 2: Using REGEXP\_SPLIT\_TO\_TABLE**

```sql
SELECT TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) as country,
       COUNT(show_id) as total_content
FROM netflix
GROUP BY TRIM(REGEXP_SPLIT_TO_TABLE(country, ','))
ORDER BY total_content DESC
LIMIT 5;
```

---

### 5. Identify the Longest Movie

**Objective:** Find movie with longest duration.

**Method 1: Using SPLIT\_PART**

```sql
SELECT *
FROM (
	SELECT DISTINCT title as movie,
	       SPLIT_PART(duration, ' ', 1)::numeric as duration
	FROM netflix
	WHERE type = 'Movie'
) subquery
WHERE duration = (SELECT MAX(SPLIT_PART(duration, ' ', 1)::numeric) FROM netflix);
```

**Method 2: Using SUBSTRING**

```sql
SELECT title as movie, duration
FROM (
	SELECT title,
	       CAST(SUBSTRING(duration, 1, POSITION(' ' in LTRIM(duration)) - 1) AS INT) as duration,
	       ROW_NUMBER() OVER (ORDER BY CAST(SUBSTRING(duration, 1, POSITION(' ' in LTRIM(duration)) - 1) AS INT) DESC) as rn
	FROM netflix
	WHERE type = 'Movie' AND duration IS NOT NULL
) t
WHERE rn = 1;
```

---

### 6. Find Content Added in the Last 5 Years

**Objective:** Show content added in the last five years.

```sql
SELECT *
FROM netflix
WHERE TO_DATE(date_added, 'Month DD, YYYY') >= CURRENT_DATE - INTERVAL '5 years';
```

---

### 7. Find All Movies/TV Shows by Director 'Rajiv Chilaka'

**Objective:** Filter content by a specific director.

```sql
SELECT *
FROM netflix
WHERE director ILIKE '%Rajiv Chilaka%';
```

---

### 8. List TV Shows with More Than 5 Seasons

**Objective:** Identify TV shows with more than five seasons.

**Method 1: Using SPLIT\_PART**

```sql
SELECT *
FROM netflix
WHERE type = 'TV Show' AND SPLIT_PART(duration, ' ', 1)::INT > 5;
```

**Method 2: Using LEFT**

```sql
SELECT title, duration
FROM netflix
WHERE type = 'TV Show' AND LEFT(duration, POSITION(duration, ' ') - 1)::INT > 5;
```

---

### 9. Count Number of Content Items in Each Genre

**Objective:** Get content count by genre.

**Method 1: Using STRING\_TO\_ARRAY**

```sql
SELECT genre, COUNT(show_id)
FROM (
	SELECT show_id, TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) as genre
	FROM netflix
) t
GROUP BY genre;
```

**Method 2: Using REGEXP\_SPLIT\_TO\_TABLE**

```sql
WITH cte AS (
	SELECT show_id, TRIM(REGEXP_SPLIT_TO_TABLE(listed_in, ',')) as genre
	FROM netflix
)
SELECT genre, COUNT(*) as total_count
FROM cte
GROUP BY genre;
```

---

### 10. Find Each Year and Average Content Release in India; Top 5 Years

**Objective:** Rank years with highest average release count in India.

```sql
WITH cte AS (
	SELECT show_id,
	       DATE_PART('year', date_added::DATE) as release_year,
	       TRIM(REGEXP_SPLIT_TO_TABLE(country, ',')) as country
	FROM netflix
)
SELECT release_year,
       ROUND(COUNT(show_id) * 100.0 / (SELECT COUNT(*) FROM cte WHERE country = 'India'), 2) as avg_release
FROM cte
WHERE country = 'India'
GROUP BY release_year
ORDER BY avg_release DESC
LIMIT 5;
```

---

### 11. List Movies that are Documentaries

**Objective:** Filter movies tagged as documentaries.

```sql
SELECT *
FROM netflix
WHERE type = 'Movie' AND listed_in ILIKE '%Documentaries%';
```

---

### 12. Find All Content Without a Director

**Objective:** Identify content missing director data.

```sql
SELECT *
FROM netflix
WHERE director IS NULL;
```

---

### 13. Find Movies with 'Salman Khan' in the Last 10 Years

**Objective:** Count movies featuring Salman Khan recently.

```sql
SELECT *
FROM netflix
WHERE casts ILIKE '%Salman Khan%' AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10;
```

---

### 14. Find Top 10 Actors in Indian Movies

**Objective:** Top actors by appearance in Indian-produced movies.

```sql
WITH cte AS (
	SELECT show_id, TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) as actors
	FROM netflix
	WHERE country LIKE '%India%'
)
SELECT actors, COUNT(*) as no_of_appearance
FROM cte
GROUP BY actors
ORDER BY no_of_appearance DESC
LIMIT 10;
```

---

### 15. Categorize Content as 'Good' or 'Bad' Based on Keywords

**Objective:** Label content containing 'kill' or 'violence' as 'Bad'.

```sql
WITH cte AS (
	SELECT *,
	       CASE WHEN description ILIKE '%kill%' OR description ILIKE '%violence%' THEN 'Bad' ELSE 'Good' END as category
	FROM netflix
)
SELECT category, COUNT(*) as total_content
FROM cte
GROUP BY category;
```

---

## Findings and Conclusion

- Movies make up the larger share of Netflix content.
- Certain countries like the US and India produce the most content.
- Popular genres and ratings reflect user demand and preferences.
- Text analysis helps categorize and better understand content themes.

## Author

**Syed Ateeb Shah**\
This project is part of my portfolio to demonstrate SQL data analysis skills using PostgreSQL.\
For questions, feedback, or collaboration opportunities, feel free to connect or open an issue.

