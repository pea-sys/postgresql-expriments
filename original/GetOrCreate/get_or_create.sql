-- get_or_create.sql
WITH
-- Generate a random amount of random tags
tags_to_insert AS (
    SELECT 'tag' || round(random() * 1000) AS name
    FROM generate_series(0, (random() * 10)::int)
),
-- From here on it's roughly the same...
new_tags AS (
    INSERT INTO tags (name)
        SELECT name
        FROM tags_to_insert t
        WHERE NOT EXISTS (
            SELECT 1
            FROM tags
            WHERE tags.name = t.name
        )
    RETURNING *
)
SELECT * FROM new_tags
UNION ALL
SELECT * FROM tags WHERE name IN (
    SELECT name
    FROM new_tags
);