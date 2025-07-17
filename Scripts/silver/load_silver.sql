
/*
=====================================================================================================================
Stored Procedure : Loads cleaned data from bronze layer to silver layer
=====================================================================================================================
- Cleaned data from bronze that has undergone the ETL process 
- Proceeds to truncate silver tables
- Inserts the cleaned data from bronze tables into silver tables

Usage Example:

  EXEC silver.load_silver
=====================================================================================================================

*/



CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME ,  @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE ();
		PRINT '=======================================';
		PRINT 'loading silver Layer';
		PRINT '=======================================';

		PRINT '---------------------------------------';
		PRINT 'loading CRM Tables';
		PRINT '---------------------------------------';

		SET @start_time = GETDATE ();
		PRINT '» Truncating Data Into: silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '» Inserting Data Into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date)
		SELECT
		cst_id,
		cst_key,
		TRIM(cst_firstname) as cst_firstname,
		TRIM(cst_lastname) as cst_lastname ,
		CASE
			WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'MARRIED'
			WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'SINGLE'
			ELSE 'UNKNOWN'
		END cst_marital_status,
		CASE
			WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'FEMALE'
			WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'MALE'
			ELSE 'UNKNOWN'
		END cst_gndr,
		cst_create_date
		FROM
		(
		SELECT *, ROW_NUMBER() OVER( PARTITION BY cst_id ORDER BY cst_create_date desc) as latest_date
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL )L
		WHERE latest_date = 1;
		SET @end_time = GETDATE ();
		PRINT '» Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) as VARCHAR) + 'seconds';
		PRINT '---------------------------------------';




		SET @start_time = GETDATE ();
		PRINT '» Truncating Data Into: silver.crm_prd_info';
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '» Inserting Data Into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
		prd_id ,
		cat_id,
		prd_key ,
		prd_nm ,
		prd_cost ,
		prd_line  ,
		prd_start_dt ,
		prd_end_dt )
		SELECT
		prd_id,
		REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') AS cat_id, -- SO AS TO MATCH THE COLUMN VALUE OF TABLE PX
		SUBSTRING(prd_key, 7,LEN(prd_key)) AS prd_key, -- EXTRACTING 7TH CHARACTER TO LAST
		prd_nm,
		COALESCE (prd_cost,0) AS prd_cost, --CHANGE NULL VALUES TO 0
		CASE UPPER(TRIM (prd_line))
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'Unknown'
		END AS prd_line,
		CAST(prd_start_dt AS DATE) AS prd_start_dt,-- CHANGE DATA TYPE
		CAST(LEAD (prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS DATE)  AS prd_end_dt -- TAKE LATEST DATE OF prd_key AND REPLACE THE FAULTY DATE

		FROM bronze.crm_prd_info
		SET @end_time = GETDATE ();
		PRINT '» Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) as VARCHAR) + 'seconds';
		PRINT '---------------------------------------'; 


		SET @start_time = GETDATE ();
		PRINT '» Truncating Data Into: silver.crm_sales_details';
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '» Inserting Data Into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
		sls_ord_num  ,
		sls_prd_key , 
		sls_cust_id ,
		sls_order_dt ,
		sls_ship_dt ,
		sls_due_dt ,
		sls_sales ,
		sls_quantity ,
		sls_price 

		)
		SELECT 
		sls_ord_num ,
		sls_prd_key ,
		sls_cust_id , 
		CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS varchar) AS DATE) -- CHANGE TO DATE TYPE, MUST CAST TO VARCHAR FIRST
		END AS sls_order_dt,
		CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS varchar) AS DATE) -- CHANGE TO DATE TYPE, MUST CAST TO VARCHAR FIRST
		END AS sls_ship_dt,
		CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS varchar) AS DATE) -- CHANGE TO DATE TYPE, MUST CAST TO VARCHAR FIRST
		END AS sls_due_dt,
		CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
				THEN  sls_quantity * ABS(sls_price)
				ELSE sls_sales
				END AS sls_sales,
		sls_quantity ,
		CASE WHEN sls_price IS NULL OR sls_price <= 0
				THEN sls_sales / NULLIF(sls_quantity,0) -- JUST INCASE ANY QUANTITY IS 0 WILL BE REPLACED BY NULL INSTEAD
				ELSE sls_price
				END AS sls_price  
		FROM bronze.crm_sales_details
		SET @end_time = GETDATE ();
		PRINT '» Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) as VARCHAR) + 'seconds';
		PRINT '---------------------------------------';

		PRINT '---------------------------------------';
		PRINT 'loading ERM Tables';
		PRINT '---------------------------------------';

		SET @start_time = GETDATE ();
		PRINT '» Truncating Data Into: silver.erp_cust_az12';
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '» Inserting Data Into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
		cid, 
		bdate, 
		gen)

		SELECT 
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,len(cid))
			ELSE cid
			END AS cid,-- removing 'nas' from the cid values that used to start with For example 'NASAW00011000' so as to match other foreign key

		CASE WHEN bdate	> GETDATE() THEN NULL
			ELSE bdate
			END AS bdate,

		CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male' 
			ELSE 'n/a'
			END AS gen
		
		FROM bronze.erp_cust_az12
		SET @end_time = GETDATE ();
		PRINT '» Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) as VARCHAR) + 'seconds';
		PRINT '---------------------------------------';

		SET @start_time = GETDATE ();
		PRINT '» Truncating Data Into: silver.erp_loc_a101';
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '» Inserting Data Into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
		cid,
		cntry
		)
		SELECT 
		REPLACE(cid, '-', '') as cid,
		CASE WHEN TRIM (cntry) = 'DE' THEN 'Germany'
			 WHEN TRIM (cntry) IN ('US', 'USA') THEN 'United States'
			 WHEN TRIM (cntry) =  '' or cntry is NULL THEN 'n/a'
			 ELSE TRIM(cntry)
			 END AS cntry
		FROM bronze.erp_loc_a101
		SET @end_time = GETDATE ();
		PRINT '» Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) as VARCHAR) + 'seconds';
		PRINT '---------------------------------------';

		SET @start_time = GETDATE ();
		PRINT '» Truncating Data Into: silver.erp_px_cat_g1v2';
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '» Inserting Data Into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
		id,
		cat,
		subcat,
		maintenance
		)
		SELECT 
		id,
		cat,
		subcat,
		maintenance
		FROM bronze.erp_px_cat_g1v2 
		SET @end_time = GETDATE ();
		PRINT '» Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) as VARCHAR) + 'seconds';
		PRINT '---------------------------------------';

		SET @batch_end_time = GETDATE();
		PRINT '---------------------------------------';
		PRINT 'Loading Silver Layer is Completed';
		PRINT 'Total Duration: ' + cast(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';

	END TRY
	BEGIN CATCH
			PRINT '-----------------------------------------'
			PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
			PRINT 'ERROR MESSAGE' + ERROR_MESSAGE ();
			PRINT 'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS NVARCHAR);
			PRINT 'ERROR MESSAGE' + CAST(ERROR_STATE() AS NVARCHAR);
			PRINT '-----------------------------------------'

	END CATCH
END

