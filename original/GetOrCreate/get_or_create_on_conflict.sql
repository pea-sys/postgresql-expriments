-- get_or_create_on_conflict.sql
WITH
-- Generate a random amount of random tags
tags_to_insert AS (
    SELECT 'tag' || round(random() * 1000) AS name
    FROM generate_series(0, (random() * 10)::int)
),
-- From here on it's roughly the same...
new_tags AS (
    INSERT INTO tags (name)
      SELECT name FROM tags_to_insert
    ON CONFLICT DO NOTHING
    RETURNING *
)
SELECT * FROM new_tags
UNION ALL
SELECT * FROM tags WHERE name IN (SELECT name FROM tags_to_insert);