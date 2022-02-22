WITH where_table AS (SELECT * FROM payment p, rental r , inventory i, store s ,address a, city c, country cy, staff m where p.rental_id = r.rental_id and r.inventory_id = i.inventory_id and i.store_id = s.store_id and s.address_id = a.address_id and a.city_id = c.city_id and c.country_id = cy.country_id and s.manager_staff_id = m.staff_id)
    ,join_table AS (SELECT * FROM payment p JOIN rental r ON p.rental_id = r.rental_id JOIN inventory i ON r.inventory_id = i.inventory_id JOIN store s ON i.store_id = s.store_id JOIN address a ON s.address_id = a.address_id JOIN city c ON a.city_id = c.city_id JOIN country cy ON c.country_id = cy.country_id JOIN staff m ON s.manager_staff_id = m.staff_id)
(
  table where_table
  EXCEPT ALL SELECT * FROM join_table
) UNION ALL (
  SELECT * FROM join_table
  EXCEPT ALL SELECT * FROM where_table
) 
