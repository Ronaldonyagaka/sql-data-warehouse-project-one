/*
=====================================================================================================================
Loads cleaned data from silver layer to gold layer
=====================================================================================================================
- Cleaned data from silver that has undergone the ETL process 

- Inserts the cleaned data from silver tables into gold view tables

=====================================================================================================================

*/







USE Datawarehouse;


SELECT 
ci.cst_id,
ci.cst_key,
ci.cst_firstname,
ci.cst_lastname,
ci.cst_marital_status,
ci.cst_gndr,
ci.cst_create_date,
ca.bdate,
ca.gen,
la.cntry
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid

-- there are two gender columns we need to keep one, let us explore
-- not that the gender from crm is the master

SELECT distinct
ci.cst_gndr,
ca.gen,
CASE  WHEN ci.cst_gndr = 'FEMALE' THEN 'Female'
      WHEN ci.cst_gndr = 'MALE' THEN 'Male'
	  WHEN ci.cst_gndr != 'UNKNOWN' THEN ci.cst_gndr
	  when ci.cst_gndr = 'FEMALE' THEN 'Female'
	  ELSE COALESCE(ca.gen, 'n/a')
	  END AS new_gen
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid
order by 1,2

-- now the improved query  and to create an object and it is a virtual one hence the reason we are creating a view

CREATE VIEW gold.dim_customers AS 
SELECT 
ROW_NUMBER () over(ORDER BY ci.cst_id) AS customer_key, -- creating a surrogate key
ci.cst_id as customer_id,
ci.cst_key as customer_number,
ci.cst_firstname as first_name,
ci.cst_lastname as last_name,
la.cntry as country,
ci.cst_marital_status as marital_status,
CASE  WHEN ci.cst_gndr = 'FEMALE' THEN 'Female'
      WHEN ci.cst_gndr = 'MALE' THEN 'Male'
	  WHEN ci.cst_gndr != 'UNKNOWN' THEN ci.cst_gndr
	  when ci.cst_gndr = 'FEMALE' THEN 'Female'
	  ELSE COALESCE(ca.gen, 'n/a')
	  END AS gender,
ca.bdate as birth_date,
ci.cst_create_date as create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

SELECT *  FROM gold.dim_customers

-- now to build the product object
CREATE VIEW gold.dim_products AS
SELECT 
ROW_NUMBER () over(ORDER BY pn.prd_start_dt,pn.prd_key ) AS product_key, -- creating a surrogate key
pn.prd_id as product_id,
pn.prd_key as product_number,
pn.prd_nm as product_name,
pn.cat_id as category_id,
pc.cat as category,
pc.subcat as subcategory,
pc.maintenance,
pn.prd_cost as product_cost,
pn.prd_line as product_line,
pn.prd_start_dt as product_start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
on pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL  -- BECAUSE WE DO NOT NEED HISTORICAL INFO JUST CURRENT INTO AND IT IS WHERE END DATE IS NULL 


CREATE VIEW gold.fact_sales AS
SELECT 
sd.sls_ord_num as order_number,
pr.product_key, -- this is the surrogate key we created from product table extracted through the join below
cu.customer_key, -- this is the surrogate key we created from product table extracted through the join below
sd.sls_order_dt as order_date,
sd.sls_ship_dt as shipping_date,
sd.sls_due_dt as due_date,
sd.sls_sales as sales_amount,
sd.sls_quantity as quantity,
sd.sls_price as sales_price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
on sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
on sd.sls_cust_id = cu.customer_id

-- checking for foreign key integrity 
select *
from gold.fact_sales sr
left join gold.dim_customers cr
on sr.customer_key = cr.customer_key
where cr.customer_key is null  -- if we get an empty table then it means all customer foreign keys are already matched

select *
from gold.fact_sales sr
left join gold.dim_products pr
on sr.product_key = pr.product_key
where pr.product_key is null  -- if we get an empty table then it means all customer foreign keys are already matched
