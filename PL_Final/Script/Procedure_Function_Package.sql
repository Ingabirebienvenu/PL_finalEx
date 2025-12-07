-- ============================================================
-- PHASE 6: Database Interaction & Transactions
-- ============================================================

/* ============================================================
   FUNCTION 1: Calculate days until stockout
   ============================================================ */
CREATE OR REPLACE FUNCTION calculate_stockout_date(
    p_res_id IN NUMBER
) RETURN NUMBER
IS
    v_avg_daily_usage NUMBER;
    v_current_stock NUMBER;
    v_days_until_stockout NUMBER;
BEGIN
    -- Get current stock
    SELECT stock_level INTO v_current_stock
    FROM resources
    WHERE res_id = p_res_id;
    
    -- Calculate average daily usage (last 30 days)
    SELECT NVL(AVG(quantity_used), 0) INTO v_avg_daily_usage
    FROM usage_log
    WHERE res_id = p_res_id
    AND date_used >= SYSDATE - 30;
    
    -- If no usage data, return NULL
    IF v_avg_daily_usage <= 0 THEN
        RETURN NULL;
    END IF;
    
    -- Calculate days until stockout
    v_days_until_stockout := TRUNC(v_current_stock / v_avg_daily_usage);
    
    RETURN v_days_until_stockout;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE;
END calculate_stockout_date;
/

/* ============================================================
   FUNCTION 2: Calculate optimal reorder quantity
   ============================================================ */
CREATE OR REPLACE FUNCTION calculate_reorder_quantity(
    p_res_id IN NUMBER
) RETURN NUMBER
IS
    v_avg_daily_usage NUMBER;
    v_lead_time_days NUMBER := 7; -- Default lead time
    v_safety_stock NUMBER;
    v_threshold NUMBER;
    v_optimal_quantity NUMBER;
BEGIN
    -- Get threshold for the resource
    SELECT threshold INTO v_threshold
    FROM resources
    WHERE res_id = p_res_id;
    
    -- Calculate average daily usage (last 30 days)
    SELECT NVL(AVG(quantity_used), 0) INTO v_avg_daily_usage
    FROM usage_log
    WHERE res_id = p_res_id
    AND date_used >= SYSDATE - 30;
    
    -- Calculate safety stock (7 days usage)
    v_safety_stock := v_avg_daily_usage * v_lead_time_days;
    
    -- Calculate optimal quantity: 30 days usage + safety stock
    v_optimal_quantity := (v_avg_daily_usage * 30) + v_safety_stock;
    
    -- Ensure minimum reorder quantity is at least threshold
    IF v_optimal_quantity < v_threshold * 2 THEN
        v_optimal_quantity := v_threshold * 2;
    END IF;
    
    -- Round to nearest whole number
    RETURN ROUND(v_optimal_quantity);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE;
END calculate_reorder_quantity;
/

/* ============================================================
   FUNCTION 3: Validate stock level
   ============================================================ */
CREATE OR REPLACE FUNCTION validate_stock_level(
    p_res_id IN NUMBER,
    p_quantity_needed IN NUMBER
) RETURN VARCHAR2
IS
    v_current_stock NUMBER;
    v_threshold NUMBER;
    v_resource_name VARCHAR2(50);
BEGIN
    -- Get current stock information
    SELECT stock_level, threshold, name 
    INTO v_current_stock, v_threshold, v_resource_name
    FROM resources
    WHERE res_id = p_res_id;
    
    -- Check if enough stock exists
    IF p_quantity_needed > v_current_stock THEN
        RETURN 'INSUFFICIENT_STOCK: Only ' || v_current_stock || ' available for ' || v_resource_name;
    -- Check if usage will drop stock below threshold
    ELSIF v_current_stock - p_quantity_needed < v_threshold THEN
        RETURN 'WARNING: Stock will drop below threshold after this usage';
    ELSE
        RETURN 'SUFFICIENT_STOCK: ' || v_current_stock || ' available';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'ERROR: Resource not found';
    WHEN OTHERS THEN
        RETURN 'ERROR: ' || SQLERRM;
END validate_stock_level;
/

/* ============================================================
   FUNCTION 4: Get resource consumption trend
   ============================================================ */
CREATE OR REPLACE FUNCTION get_consumption_trend(
    p_res_id IN NUMBER,
    p_days_back IN NUMBER DEFAULT 30
) RETURN VARCHAR2
IS
    v_current_avg NUMBER;
    v_previous_avg NUMBER;
    v_trend_percent NUMBER;
BEGIN
    -- Current period average (last p_days_back/2 days)
    SELECT NVL(AVG(quantity_used), 0) INTO v_current_avg
    FROM usage_log
    WHERE res_id = p_res_id
    AND date_used >= SYSDATE - (p_days_back / 2);
    
    -- Previous period average (p_days_back/2 to p_days_back days ago)
    SELECT NVL(AVG(quantity_used), 0) INTO v_previous_avg
    FROM usage_log
    WHERE res_id = p_res_id
    AND date_used BETWEEN SYSDATE - p_days_back AND SYSDATE - (p_days_back / 2);
    
    -- Calculate trend percentage
    IF v_previous_avg > 0 THEN
        v_trend_percent := ((v_current_avg - v_previous_avg) / v_previous_avg) * 100;
        
        -- Categorize the trend
        IF v_trend_percent > 10 THEN
            RETURN 'INCREASING (' || ROUND(v_trend_percent, 1) || '%)';
        ELSIF v_trend_percent < -10 THEN
            RETURN 'DECREASING (' || ROUND(v_trend_percent, 1) || '%)';
        ELSE
            RETURN 'STABLE (' || ROUND(v_trend_percent, 1) || '%)';
        END IF;
    ELSE
        RETURN 'INSUFFICIENT_DATA';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'NO_DATA';
    WHEN OTHERS THEN
        RETURN 'ERROR';
END get_consumption_trend;
/

/* ============================================================
   PROCEDURE 1: Record resource usage with validation
   ============================================================ */
CREATE OR REPLACE PROCEDURE record_resource_usage(
    p_res_id IN NUMBER,
    p_quantity_used IN NUMBER
)
IS
    v_current_stock NUMBER;
    v_threshold NUMBER;
    v_exists NUMBER;
BEGIN
    -- Check if resource exists
    SELECT COUNT(*) INTO v_exists
    FROM resources
    WHERE res_id = p_res_id;

    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Resource does not exist');
    END IF;

    -- Get current stock and threshold
    SELECT stock_level, threshold
    INTO v_current_stock, v_threshold
    FROM resources
    WHERE res_id = p_res_id;

    -- Validate stock availability
    IF p_quantity_used > v_current_stock THEN
        RAISE_APPLICATION_ERROR(-20002, 'Insufficient stock');
    END IF;

    -- Insert into usage log
    INSERT INTO usage_log(res_id, quantity_used, date_used)
    VALUES(p_res_id, p_quantity_used, SYSDATE);

    -- Update remaining stock
    UPDATE resources
    SET stock_level = stock_level - p_quantity_used
    WHERE res_id = p_res_id;

    -- Check if stock falls below threshold after usage
    IF (v_current_stock - p_quantity_used) < v_threshold THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Stock level below threshold!');
    END IF;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'Resource data missing');

    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'Unexpected error: ' || SQLERRM);
END record_resource_usage;
/

/* ============================================================
   PROCEDURE 2: Create automatic reorder
   ============================================================ */
CREATE OR REPLACE PROCEDURE create_automatic_reorder(
    p_res_id IN NUMBER,
    p_approved_by IN VARCHAR2 DEFAULT NULL
)
IS
    v_optimal_quantity NUMBER;
    v_current_stock NUMBER;
    v_threshold NUMBER;
    v_resource_name VARCHAR2(50);
    v_existing_reorders NUMBER;
BEGIN
    -- Get resource details
    SELECT name, stock_level, threshold 
    INTO v_resource_name, v_current_stock, v_threshold
    FROM resources
    WHERE res_id = p_res_id;
    
    -- Check if stock is actually below threshold
    IF v_current_stock >= v_threshold THEN
        RAISE_APPLICATION_ERROR(-20002, 
            'Stock level (' || v_current_stock || ') is above threshold (' || v_threshold || ')');
    END IF;
    
    -- Check for existing pending/approved reorders
    SELECT COUNT(*) INTO v_existing_reorders
    FROM reorders
    WHERE res_id = p_res_id
    AND status IN ('Pending', 'Approved', 'Ordered');
    
    IF v_existing_reorders > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 
            'There are already ' || v_existing_reorders || ' active reorders for this resource');
    END IF;
    
    -- Calculate optimal reorder quantity
    v_optimal_quantity := calculate_reorder_quantity(p_res_id);
    
    -- Fallback to threshold calculation if no usage data
    IF v_optimal_quantity IS NULL OR v_optimal_quantity <= 0 THEN
        v_optimal_quantity := v_threshold * 2; 
    END IF;
    
    -- Create reorder entry
    INSERT INTO reorders (
        res_id, order_date, quantity, status, 
        expected_delivery, approved_by
    ) VALUES (
        p_res_id, SYSDATE, v_optimal_quantity, 'Pending',
        SYSDATE + 7, p_approved_by
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Automatic reorder created for ' || v_resource_name || 
                         ': Quantity=' || v_optimal_quantity);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20004, 'Resource ID ' || p_res_id || ' not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END create_automatic_reorder;
/

/* ============================================================
   PROCEDURE 3: Update reorder status
   ============================================================ */
CREATE OR REPLACE PROCEDURE update_reorder_status(
    p_order_id   IN NUMBER,
    p_new_status IN VARCHAR2,
    p_updated_by IN VARCHAR2 DEFAULT NULL
)
IS
    v_current_status   VARCHAR2(20);
    v_res_id           NUMBER;
    v_quantity         NUMBER;
BEGIN
    -- Fetch current reorder details
    SELECT status, res_id, quantity
    INTO v_current_status, v_res_id, v_quantity
    FROM reorders
    WHERE order_id = p_order_id;

    -- Validate status transition
    IF v_current_status IN ('Delivered', 'Cancelled') THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'Cannot update a ' || v_current_status || ' reorder.'
        );
    END IF;

    -- Update reorder status and related fields
    UPDATE reorders
    SET 
        status = p_new_status,
        approval_date = CASE 
            WHEN p_new_status = 'Approved' AND approval_date IS NULL THEN SYSDATE
            ELSE approval_date
        END,
        approved_by = CASE 
            WHEN p_new_status = 'Approved' AND approved_by IS NULL THEN p_updated_by
            ELSE approved_by
        END,
        actual_delivery = CASE 
            WHEN p_new_status = 'Delivered' AND actual_delivery IS NULL THEN SYSDATE
            ELSE actual_delivery
        END
    WHERE order_id = p_order_id;

    -- If delivered, update stock levels
    IF p_new_status = 'Delivered' THEN
        UPDATE resources
        SET stock_level = stock_level + v_quantity,
            last_updated = SYSDATE
        WHERE res_id = v_res_id;

        DBMS_OUTPUT.PUT_LINE(
            'Stock updated: +' || v_quantity || 
            ' units added to resource ' || v_res_id
        );
    END IF;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'Reorder ' || p_order_id || ' status updated to ' || p_new_status
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20006,
            'Reorder ID ' || p_order_id || ' does not exist.'
        );
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END update_reorder_status;
/

/* ============================================================
   PROCEDURE 4: Generate low stock report
   ============================================================ */
CREATE OR REPLACE PROCEDURE generate_low_stock_report(
    p_threshold_percentage IN NUMBER DEFAULT 80
)
IS
    -- Cursor to find low stock items
    CURSOR low_stock_cursor IS
        SELECT r.res_id, r.name, r.category, 
               r.stock_level, r.threshold,
               s.name as supplier_name,
               calculate_stockout_date(r.res_id) as days_until_stockout,
               get_consumption_trend(r.res_id) as consumption_trend
        FROM resources r
        LEFT JOIN suppliers s ON r.supplier_id = s.supplier_id
        WHERE r.stock_level < r.threshold * (p_threshold_percentage / 100)
        ORDER BY r.stock_level / NULLIF(r.threshold, 0);
    
    v_report_count NUMBER := 0;
BEGIN
    -- Report header
    DBMS_OUTPUT.PUT_LINE('===========================================');
    DBMS_OUTPUT.PUT_LINE('LOW STOCK REPORT - Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'));
    DBMS_OUTPUT.PUT_LINE('Threshold: Below ' || p_threshold_percentage || '% of stock threshold');
    DBMS_OUTPUT.PUT_LINE('===========================================');
    
    -- Loop through low stock items
    FOR rec IN low_stock_cursor LOOP
        v_report_count := v_report_count + 1;
        
        DBMS_OUTPUT.PUT_LINE(v_report_count || '. ' || rec.name || ' (' || rec.category || ')');
        DBMS_OUTPUT.PUT_LINE('   Current Stock: ' || rec.stock_level || ' / Threshold: ' || rec.threshold);
        DBMS_OUTPUT.PUT_LINE('   Stockout in: ' || NVL(TO_CHAR(rec.days_until_stockout), 'N/A') || ' days');
        DBMS_OUTPUT.PUT_LINE('   Consumption: ' || rec.consumption_trend);
        DBMS_OUTPUT.PUT_LINE('   Supplier: ' || rec.supplier_name);
        
        -- Add urgency recommendations
        IF rec.days_until_stockout IS NOT NULL AND rec.days_until_stockout < 7 THEN
            DBMS_OUTPUT.PUT_LINE('   ACTION REQUIRED: Urgent reorder needed!');
        ELSIF rec.days_until_stockout IS NOT NULL AND rec.days_until_stockout < 14 THEN
            DBMS_OUTPUT.PUT_LINE('   ACTION: Schedule reorder soon');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('---');
    END LOOP;
    
    -- Report summary
    IF v_report_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No resources below ' || p_threshold_percentage || '% threshold.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total items needing attention: ' || v_report_count);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===========================================');
END generate_low_stock_report;
/

/* ============================================================
   PROCEDURE 5: Bulk update stock from delivery
   ============================================================ */
CREATE OR REPLACE PROCEDURE process_bulk_delivery(
    p_res_id_list IN SYS.ODCINUMBERLIST,
    p_quantity_list IN SYS.ODCINUMBERLIST,
    p_delivery_date IN DATE DEFAULT SYSDATE
)
IS
    v_success_count NUMBER := 0;
    v_failure_count NUMBER := 0;
BEGIN
    -- Validate input lists
    IF p_res_id_list.COUNT != p_quantity_list.COUNT THEN
        RAISE_APPLICATION_ERROR(-20007, 
            'Resource list count (' || p_res_id_list.COUNT || 
            ') does not match quantity list count (' || p_quantity_list.COUNT || ')');
    END IF;
    
    -- Process each delivery item
    FOR i IN 1..p_res_id_list.COUNT LOOP
        BEGIN
            UPDATE resources
            SET stock_level = stock_level + p_quantity_list(i),
                last_updated = SYSDATE
            WHERE res_id = p_res_id_list(i);
            
            v_success_count := v_success_count + 1;
            
            DBMS_OUTPUT.PUT_LINE('Updated resource ' || p_res_id_list(i) || 
                               ': +' || p_quantity_list(i) || ' units');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('ERROR: Resource ' || p_res_id_list(i) || ' not found');
                v_failure_count := v_failure_count + 1;
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ERROR updating resource ' || p_res_id_list(i) || ': ' || SQLERRM);
                v_failure_count := v_failure_count + 1;
        END;
    END LOOP;
    
    COMMIT;
    
    -- Report processing results
    DBMS_OUTPUT.PUT_LINE('===========================================');
    DBMS_OUTPUT.PUT_LINE('BULK DELIVERY PROCESSING COMPLETE');
    DBMS_OUTPUT.PUT_LINE('Successfully updated: ' || v_success_count || ' resources');
    DBMS_OUTPUT.PUT_LINE('Failed updates: ' || v_failure_count || ' resources');
    DBMS_OUTPUT.PUT_LINE('===========================================');
END process_bulk_delivery;
/

/* ============================================================
   CURSOR 1: Process all low stock items
   ============================================================ */
DECLARE
    CURSOR low_stock_items_cursor IS
        SELECT r.res_id, r.name, r.stock_level, r.threshold,
               s.name as supplier_name, s.contact as supplier_contact
        FROM resources r
        JOIN suppliers s ON r.supplier_id = s.supplier_id
        WHERE r.stock_level < r.threshold
        ORDER BY (r.stock_level / r.threshold);
    
    v_reorder_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Processing low stock items...');
    
    FOR item_rec IN low_stock_items_cursor LOOP
        DBMS_OUTPUT.PUT_LINE('Creating reorder for: ' || item_rec.name);
        DBMS_OUTPUT.PUT_LINE('  Current Stock: ' || item_rec.stock_level || 
                           ' / Threshold: ' || item_rec.threshold);
        DBMS_OUTPUT.PUT_LINE('  Supplier: ' || item_rec.supplier_name || 
                           ' (' || item_rec.supplier_contact || ')');
        
        -- Create automatic reorder for each low stock item
        BEGIN
            create_automatic_reorder(item_rec.res_id, 'SYSTEM_AUTO');
            v_reorder_count := v_reorder_count + 1;
            DBMS_OUTPUT.PUT_LINE('  Reorder created successfully');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  ERROR: ' || SQLERRM);
        END;
        
        DBMS_OUTPUT.PUT_LINE('---');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Total reorders created: ' || v_reorder_count);
END;
/

/* ============================================================
   CURSOR 2: Monthly consumption analysis with BULK COLLECT
   ============================================================ */
DECLARE
    TYPE consumption_rec IS RECORD (
        res_id NUMBER,
        resource_name VARCHAR2(50),
        category VARCHAR2(30),
        total_consumption NUMBER,
        avg_daily NUMBER,
        peak_usage NUMBER
    );
    
    TYPE consumption_table IS TABLE OF consumption_rec;
    v_consumption_data consumption_table;
    
    CURSOR monthly_consumption_cursor IS
        SELECT 
            r.res_id,
            r.name as resource_name,
            r.category,
            SUM(u.quantity_used) as total_consumption,
            ROUND(AVG(u.quantity_used), 2) as avg_daily,
            MAX(u.quantity_used) as peak_usage
        FROM resources r
        JOIN usage_log u ON r.res_id = u.res_id
        WHERE u.date_used >= ADD_MONTHS(SYSDATE, -1)
        GROUP BY r.res_id, r.name, r.category
        ORDER BY total_consumption DESC;
BEGIN
    OPEN monthly_consumption_cursor;
    FETCH monthly_consumption_cursor BULK COLLECT INTO v_consumption_data;
    CLOSE monthly_consumption_cursor;
    
    DBMS_OUTPUT.PUT_LINE('MONTHLY CONSUMPTION ANALYSIS');
    DBMS_OUTPUT.PUT_LINE('============================');
    
    FOR i IN 1..v_consumption_data.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(i || '. ' || v_consumption_data(i).resource_name);
        DBMS_OUTPUT.PUT_LINE('   Category: ' || v_consumption_data(i).category);
        DBMS_OUTPUT.PUT_LINE('   Total Consumption: ' || v_consumption_data(i).total_consumption);
        DBMS_OUTPUT.PUT_LINE('   Average Daily: ' || v_consumption_data(i).avg_daily);
        DBMS_OUTPUT.PUT_LINE('   Peak Usage: ' || v_consumption_data(i).peak_usage);
        
        -- Add recommendation for high consumption items
        IF v_consumption_data(i).total_consumption > 1000 THEN
            DBMS_OUTPUT.PUT_LINE('   RECOMMENDATION: High consumption - monitor stock closely');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('---');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Total resources analyzed: ' || v_consumption_data.COUNT);
END;
/

/* ============================================================
   PACKAGE: Mining Stock Management Package Specification
   ============================================================ */
CREATE OR REPLACE PACKAGE mining_stock_pkg AS
    
    -- Functions
    FUNCTION calculate_stockout_date(p_res_id IN NUMBER) RETURN NUMBER;
    FUNCTION calculate_reorder_quantity(p_res_id IN NUMBER) RETURN NUMBER;
    FUNCTION validate_stock_level(p_res_id IN NUMBER, p_quantity_needed IN NUMBER) RETURN VARCHAR2;
    
    -- Procedures
    PROCEDURE record_resource_usage(
        p_res_id IN NUMBER,
        p_quantity_used IN NUMBER,
        p_department IN VARCHAR2,
        p_operator_id IN VARCHAR2 DEFAULT NULL,
        p_equipment_used IN VARCHAR2 DEFAULT NULL,
        p_notes IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE create_automatic_reorder(
        p_res_id IN NUMBER,
        p_approved_by IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE update_reorder_status(
        p_order_id IN NUMBER,
        p_new_status IN VARCHAR2,
        p_updated_by IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE generate_low_stock_report(p_threshold_percentage IN NUMBER DEFAULT 80);

    PROCEDURE process_bulk_delivery(
        p_res_id_list IN SYS.ODCINUMBERLIST,
        p_quantity_list IN SYS.ODCINUMBERLIST,
        p_delivery_date IN DATE DEFAULT SYSDATE
    );
    
    -- Utility Procedures
    PROCEDURE check_all_stock_levels;
    PROCEDURE generate_monthly_report(
        p_month IN NUMBER DEFAULT NULL,
        p_year IN NUMBER DEFAULT NULL
    );
    
END mining_stock_pkg;
/

/* ============================================================
   PACKAGE BODY: Mining Stock Management Package Implementation
   ============================================================ */
CREATE OR REPLACE PACKAGE BODY mining_stock_pkg AS

/* ============================================================
   FUNCTION 1: Calculate Days Until Stockout
   ============================================================ */
FUNCTION calculate_stockout_date(p_res_id IN NUMBER) RETURN NUMBER IS
    v_avg_daily_usage NUMBER;
    v_current_stock NUMBER;
BEGIN
    SELECT stock_level INTO v_current_stock
    FROM resources
    WHERE res_id = p_res_id;

    SELECT NVL(AVG(quantity_used), 0)
    INTO v_avg_daily_usage
    FROM usage_log
    WHERE res_id = p_res_id
    AND date_used >= SYSDATE - 30;

    -- If no usage data, return NULL
    IF v_avg_daily_usage = 0 THEN 
        RETURN NULL;
    END IF;

    RETURN TRUNC(v_current_stock / v_avg_daily_usage);

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END calculate_stockout_date;

/* ============================================================
   FUNCTION 2: Calculate Optimal Reorder Quantity
   ============================================================ */
FUNCTION calculate_reorder_quantity(p_res_id IN NUMBER) RETURN NUMBER IS
    v_avg_daily_usage NUMBER;
    v_threshold NUMBER;
    v_lead_time_days NUMBER := 7; -- Default lead time
    v_safety_stock NUMBER;
    v_optimal NUMBER;
BEGIN
    SELECT threshold INTO v_threshold
    FROM resources
    WHERE res_id = p_res_id;

    SELECT NVL(AVG(quantity_used), 0)
    INTO v_avg_daily_usage
    FROM usage_log
    WHERE res_id = p_res_id
    AND date_used >= SYSDATE - 30;

    -- Calculate safety stock based on lead time
    v_safety_stock := v_avg_daily_usage * v_lead_time_days;
    
    -- Calculate optimal quantity: 30 days usage + safety stock
    v_optimal := (v_avg_daily_usage * 30) + v_safety_stock;

    -- Ensure minimum reorder quantity
    IF v_optimal < v_threshold * 2 THEN
        v_optimal := v_threshold * 2;
    END IF;

    RETURN ROUND(v_optimal);

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END calculate_reorder_quantity;

/* ============================================================
   FUNCTION 3: Validate Stock Level
   ============================================================ */
FUNCTION validate_stock_level(p_res_id IN NUMBER, p_quantity_needed IN NUMBER)
RETURN VARCHAR2 IS
    v_stock NUMBER;
    v_threshold NUMBER;
    v_name VARCHAR2(50);
BEGIN
    SELECT stock_level, threshold, name
    INTO v_stock, v_threshold, v_name
    FROM resources
    WHERE res_id = p_res_id;

    -- Check stock availability
    IF p_quantity_needed > v_stock THEN
        RETURN 'INSUFFICIENT_STOCK: Only ' || v_stock;
    ELSIF (v_stock - p_quantity_needed) < v_threshold THEN
        RETURN 'WARNING: Stock will drop below threshold';
    ELSE
        RETURN 'SUFFICIENT_STOCK';
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'ERROR: RESOURCE NOT FOUND';
END validate_stock_level;

/* ============================================================
   PROCEDURE 1: Record Resource Usage
   ============================================================ */
PROCEDURE record_resource_usage(
    p_res_id IN NUMBER,
    p_quantity_used IN NUMBER,
    p_department IN VARCHAR2,
    p_operator_id IN VARCHAR2 DEFAULT NULL,
    p_equipment_used IN VARCHAR2 DEFAULT NULL,
    p_notes IN VARCHAR2 DEFAULT NULL
) IS
BEGIN
    INSERT INTO usage_log(res_id, quantity_used, date_used, department, operator_id, equipment_used, notes)
    VALUES(p_res_id, p_quantity_used, SYSDATE, p_department, p_operator_id, p_equipment_used, p_notes);

    UPDATE resources
    SET stock_level = stock_level - p_quantity_used,
        last_updated = SYSDATE
    WHERE res_id = p_res_id;

EXCEPTION WHEN OTHERS THEN
    RAISE;
END record_resource_usage;

/* ============================================================
   PROCEDURE 2: Create Automatic Reorder
   ============================================================ */
PROCEDURE create_automatic_reorder(p_res_id IN NUMBER, p_approved_by IN VARCHAR2) IS
    v_quantity NUMBER;
BEGIN
    -- Calculate optimal reorder quantity
    v_quantity := calculate_reorder_quantity(p_res_id);

    INSERT INTO reorders(res_id, order_date, quantity, status, approved_by)
    VALUES (p_res_id, SYSDATE, v_quantity, 'Pending', p_approved_by);

END create_automatic_reorder;

/* ============================================================
   PROCEDURE 3: Update Reorder Status
   ============================================================ */
PROCEDURE update_reorder_status(
    p_order_id IN NUMBER,
    p_new_status IN VARCHAR2,
    p_updated_by IN VARCHAR2
) IS
BEGIN
    UPDATE reorders
    SET status = p_new_status
    WHERE order_id = p_order_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20006, 'Reorder ID ' || p_order_id || ' not found');
    WHEN OTHERS THEN
        RAISE;
END update_reorder_status;

/* ============================================================
   PROCEDURE 4: Low Stock Report Generation
   ============================================================ */
PROCEDURE generate_low_stock_report(p_threshold_percentage IN NUMBER) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('LOW STOCK REPORT');
    DBMS_OUTPUT.PUT_LINE('============================');

    FOR rec IN (
        SELECT name, stock_level, threshold
        FROM resources
        WHERE stock_level < (threshold * (p_threshold_percentage / 100))
        ORDER BY stock_level
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.name || ' -> Stock: ' || rec.stock_level ||
                             ' (Threshold: ' || rec.threshold || ')');
    END LOOP;

END generate_low_stock_report;

/* ============================================================
   PROCEDURE 5: Bulk Delivery Processing
   ============================================================ */
PROCEDURE process_bulk_delivery(
    p_res_id_list IN SYS.ODCINUMBERLIST,
    p_quantity_list IN SYS.ODCINUMBERLIST,
    p_delivery_date IN DATE
) IS
BEGIN
    FOR i IN 1..p_res_id_list.COUNT LOOP
        UPDATE resources
        SET stock_level = stock_level + p_quantity_list(i),
            last_updated = p_delivery_date
        WHERE res_id = p_res_id_list(i);
    END LOOP;
END process_bulk_delivery;

/* ============================================================
   UTILITY: Full Stock Check
   ============================================================ */
PROCEDURE check_all_stock_levels IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('COMPREHENSIVE STOCK LEVEL CHECK');
    DBMS_OUTPUT.PUT_LINE('================================');

    FOR rec IN (
        SELECT name, stock_level, threshold
        FROM resources
        ORDER BY stock_level - threshold
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.name || ': ' || rec.stock_level ||
                             ' (Threshold: ' || rec.threshold || ')');
    END LOOP;
END check_all_stock_levels;

/* ============================================================
   UTILITY: Monthly Report Generation
   ============================================================ */
PROCEDURE generate_monthly_report(p_month IN NUMBER, p_year IN NUMBER) IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('MONTHLY REPORT');
    DBMS_OUTPUT.PUT_LINE('==============');

    FOR rec IN (
        SELECT r.name, SUM(u.quantity_used) AS total_used
        FROM usage_log u
        JOIN resources r ON r.res_id = u.res_id
        WHERE EXTRACT(MONTH FROM u.date_used) = NVL(p_month, EXTRACT(MONTH FROM SYSDATE))
        AND EXTRACT(YEAR  FROM u.date_used) = NVL(p_year, EXTRACT(YEAR FROM SYSDATE))
        GROUP BY r.name
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.name || ' -> ' || rec.total_used);
    END LOOP;

END generate_monthly_report;

END mining_stock_pkg;
/

/* ============================================================
   TEST SECTION: Function Testing
   ============================================================ */

-- Test Function 1: Calculate stockout date
SELECT name, stock_level, threshold,
       calculate_stockout_date(res_id) as days_until_stockout
FROM resources
WHERE res_id IN (1, 3, 7);

-- Test Function 2: Calculate reorder quantity
SELECT name, stock_level, threshold,
       calculate_reorder_quantity(res_id) as suggested_reorder_qty
FROM resources
WHERE res_id IN (1, 7, 11);

-- Test Function 3: Validate stock
SELECT name, validate_stock_level(res_id, 100) as stock_validation
FROM resources
WHERE res_id IN (1, 7);

/* ============================================================
   TEST SECTION: Procedure Testing
   ============================================================ */

-- Test Procedure 1: Record usage
BEGIN
    record_resource_usage(
        p_res_id => 1,
        p_quantity_used => 200,
        p_department => 'Drilling',
        p_operator_id => 'OP101',
        p_equipment_used => 'Excavator-05',
        p_notes => 'Morning fueling'
    );
END;
/

-- Test Procedure 2: Create automatic reorder
BEGIN
    -- First, reduce stock below threshold
    UPDATE resources SET stock_level = 800 WHERE res_id = 7;
    COMMIT;
    
    -- Create reorder
    create_automatic_reorder(7, 'MANAGER001');
END;
/

-- Test Procedure 3: Update reorder status
BEGIN
    update_reorder_status(1, 'Approved', 'SUPERVISOR_002');
END;
/

-- Test Procedure 4: Generate low stock report
BEGIN
    generate_low_stock_report(70); -- Show items below 70% of threshold
END;
/

/* ============================================================
   TEST SECTION: Window Functions (Analytics)
   ============================================================ */
SELECT 
    res_id,
    date_used,
    quantity_used,
    SUM(quantity_used) OVER (PARTITION BY res_id ORDER BY date_used) as running_total,
    AVG(quantity_used) OVER (PARTITION BY res_id ORDER BY date_used ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as moving_avg,
    RANK() OVER (PARTITION BY TRUNC(date_used) ORDER BY quantity_used DESC) as daily_rank
FROM usage_log
WHERE date_used >= SYSDATE - 7
ORDER BY res_id, date_used;

/* ============================================================
   TEST SECTION: Package Usage
   ============================================================ */
BEGIN
    mining_stock_pkg.check_all_stock_levels;
    mining_stock_pkg.generate_low_stock_report(75);
END;
/

-- ============================================================
-- END OF PHASE 6: Database Interaction & Transactions
-- ============================================================