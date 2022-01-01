WITH RECURSIVE rec(organization_id ,name, parent_id) AS (
    select * from organization_tbl where organization_id = 2
    union all
    select b.organization_id,b.name,b.parent_id from rec a join organization_tbl b
    on a.organization_id = b.parent_id)
select organization_id, name, parent_id from rec;