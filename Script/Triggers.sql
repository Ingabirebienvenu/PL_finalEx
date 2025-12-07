-- ============================================================
-- PHASE 7: Advanced Programming & Auditing
-- ============================================================

/* ============================================================
   TABLE 1: Holiday Management Table
   Purpose: Track holidays to enforce business day restrictions
   ============================================================ */
CREATE TABLE holidays (
    holiday_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    holiday_date DATE NOT NULL,
    holiday_name VARCHAR2(100) NOT NULL,
    is_recurring CHAR(1) DEFAULT 'N' CHECK (is_recurring IN ('Y', 'N')),
    recurrence_type VARCHAR2(20), -- 'YEARLY', 'MONTHLY', 'WEEKLY'
    created_date DATE DEFAULT SYSDATE,
    created_by VARCHAR2(50),
    CONSTRAINT uk_holiday_date UNIQUE (holiday_date)
) TABLESPACE mining_data;

/* ============================================================
   TABLE 2: Comprehensive Audit Log
   Purpose: Track all database changes for security and compliance
   ============================================================ */
CREATE TABLE audit_log (
    audit_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name VARCHAR2(50) NOT NULL,
    operation_type VARCHAR2(10) NOT NULL CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE')),
    operation_date TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    user_name VARCHAR2(100) DEFAULT USER NOT NULL,
    record_id VARCHAR2(100), -- Stores primary key value(s)
    old_values CLOB, -- Stores old values in JSON format
    new_values CLOB, -- Stores new values in JSON format
    status VARCHAR2(20) DEFAULT 'SUCCESS' CHECK (status IN ('SUCCESS', 'DENIED', 'ERROR')),
    error_message VARCHAR2(4000),
    ip_address VARCHAR2(50),
    session_id VARCHAR2(50),
    machine_name VARCHAR2(100)
) TABLESPACE mining_data;

-- Indexes for audit log performance optimization
CREATE INDEX idx_audit_table_op ON audit_log(table_name, operation_type) TABLESPACE mining_index;
CREATE INDEX idx_audit_date ON audit_log(operation_date) TABLESPACE mining_index;
CREATE INDEX idx_audit_user ON audit_log(user_name) TABLESPACE mining_index;

/* ============================================================
   TABLE 3: Security Violation Log
   Purpose: Specifically log restriction violations for security monitoring
   ============================================================ */
CREATE TABLE security_violations (
    violation_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    violation_date TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    user_name VARCHAR2(100) DEFAULT USER NOT NULL,
    attempted_operation VARCHAR2(50) NOT NULL,
    attempted_table VARCHAR2(50) NOT NULL,
    restriction_type VARCHAR2(50) NOT NULL, -- 'WEEKDAY', 'HOLIDAY', 'AUTHORIZATION'
    violation_details CLOB,
    ip_address VARCHAR2(50),
    session_info VARCHAR2(500)
) TABLESPACE mining_data;

/* ============================================================
   HOLIDAY DATA INSERTION
   Purpose: Populate holiday table with sample holidays for testing
   ============================================================ */

-- Insert holidays for the upcoming month (December 2025)
INSERT INTO holidays (holiday_date, holiday_name, is_recurring, recurrence_type, created_by) 
VALUES (DATE '2025-12-01', 'Advent Sunday', 'Y', 'YEARLY', 'SYSTEM');
COMMIT;

INSERT INTO holidays (holiday_date, holiday_name, is_recurring, recurrence_type, created_by) 
VALUES (DATE '2025-12-08', 'Immaculate Conception', 'Y', 'YEARLY', 'SYSTEM');
COMMIT;

INSERT INTO holidays (holiday_date, holiday_name, is_recurring, recurrence_type, created_by) 
VALUES (DATE '2025-12-25', 'Christmas Day', 'Y', 'YEARLY', 'SYSTEM');
COMMIT;

INSERT INTO holidays (holiday_date, holiday_name, is_recurring, recurrence_type, created_by) 
VALUES (DATE '2025-12-26', 'Boxing Day', 'Y', 'YEARLY', 'SYSTEM');
COMMIT;

/* ============================================================
   HOLIDAY VERIFICATION QUERY
   Purpose: Display inserted holidays for verification
   ============================================================ */
SELECT holiday_id, holiday_date, holiday_name, is_recurring 
FROM holidays 
ORDER BY holiday_date;

/* ============================================================
   AUDITING FUNCTIONS
   Purpose: Provide reusable functions for security and auditing
   ============================================================ */

/* ============================================================
   FUNCTION 1: Check if today is a holiday
   Purpose: Determine if current date is marked as a holiday
   ============================================================ */
CREATE OR REPLACE FUNCTION is_today_holiday 
RETURN BOOLEAN
IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM holidays
    WHERE holiday_date = TRUNC(SYSDATE);
    
    RETURN (v_count > 0);
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END is_today_holiday;
/

/* ============================================================
   FUNCTION 2: Check if today is a weekday (Monday-Friday)
   Purpose: Determine if current date is a weekday
   ============================================================ */
CREATE OR REPLACE FUNCTION is_weekday 
RETURN BOOLEAN
IS
    v_day_of_week NUMBER;
BEGIN
    v_day_of_week := TO_CHAR(SYSDATE, 'D'); -- 1=Sunday, 2=Monday, ..., 7=Saturday
    
    -- Monday=2, Tuesday=3, Wednesday=4, Thursday=5, Friday=6
    RETURN (v_day_of_week BETWEEN 2 AND 6);
EXCEPTION
    WHEN OTHERS THEN
        RETURN TRUE; -- Default to restrictive (fail-safe)
END is_weekday;
/

/* ============================================================
   FUNCTION 3: Check if operation is restricted (CRITICAL REQUIREMENT)
   Purpose: Determine if operations should be restricted based on date
   ============================================================ */
CREATE OR REPLACE FUNCTION is_operation_restricted
RETURN VARCHAR2
IS
BEGIN
    -- Check if today is a holiday
    IF is_today_holiday THEN
        RETURN 'HOLIDAY_RESTRICTION';
    END IF;
    
    -- Check if today is a weekday
    IF is_weekday THEN
        RETURN 'WEEKDAY_RESTRICTION';
    END IF;
    
    RETURN NULL; -- No restriction (weekends only)
END is_operation_restricted;
/

/* ============================================================
   FUNCTION 4: Log audit entry
   Purpose: Create standardized audit log entries for all database changes
   ============================================================ */
CREATE OR REPLACE FUNCTION log_audit_entry(
    p_table_name IN VARCHAR2,
    p_operation_type IN VARCHAR2,
    p_record_id IN VARCHAR2 DEFAULT NULL,
    p_old_values IN CLOB DEFAULT NULL,
    p_new_values IN CLOB DEFAULT NULL,
    p_status IN VARCHAR2 DEFAULT 'SUCCESS',
    p_error_message IN VARCHAR2 DEFAULT NULL
) RETURN NUMBER
IS
    v_audit_id NUMBER;
    v_session_id VARCHAR2(50);
    v_machine_name VARCHAR2(100);
BEGIN
    -- Get session information for tracking
    SELECT SYS_CONTEXT('USERENV', 'SESSIONID'), 
           SYS_CONTEXT('USERENV', 'HOST')
    INTO v_session_id, v_machine_name
    FROM DUAL;
    
    -- Insert audit record with comprehensive details
    INSERT INTO audit_log (
        table_name, operation_type, record_id,
        old_values, new_values, status, error_message,
        ip_address, session_id, machine_name
    ) VALUES (
        p_table_name, p_operation_type, p_record_id,
        p_old_values, p_new_values, p_status, p_error_message,
        SYS_CONTEXT('USERENV', 'IP_ADDRESS'), v_session_id, v_machine_name
    )
    RETURNING audit_id INTO v_audit_id;
    
    RETURN v_audit_id;
EXCEPTION
    WHEN OTHERS THEN
        RETURN -1; -- Error indicator
END log_audit_entry;
/

/* ============================================================
   FUNCTION 5: Log security violation
   Purpose: Specifically log security violations for monitoring
   ============================================================ */
CREATE OR REPLACE PROCEDURE log_security_violation(
    p_operation IN VARCHAR2,
    p_table IN VARCHAR2,
    p_restriction_type IN VARCHAR2,
    p_details IN VARCHAR2 DEFAULT NULL
)
IS
    v_session_info VARCHAR2(500);
BEGIN
    -- Get comprehensive session info for forensic analysis
    SELECT 'SID: ' || SYS_CONTEXT('USERENV', 'SID') || 
           ', Module: ' || SYS_CONTEXT('USERENV', 'MODULE') ||
           ', Action: ' || SYS_CONTEXT('USERENV', 'ACTION')
    INTO v_session_info
    FROM DUAL;
    
    -- Insert security violation record
    INSERT INTO security_violations (
        attempted_operation, attempted_table, restriction_type,
        violation_details, ip_address, session_info
    ) VALUES (
        p_operation, p_table, p_restriction_type,
        p_details, SYS_CONTEXT('USERENV', 'IP_ADDRESS'), v_session_info
    );
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Don't fail if logging fails (fail-safe)
END log_security_violation;
/

/* ============================================================
   SIMPLE TRIGGERS
   Purpose: Enforce business rules with individual triggers
   ============================================================ */

-- Drop existing triggers to avoid conflicts
DROP TRIGGER trg_resources_insert_restrict;
DROP TRIGGER trg_resources_update_restrict;
DROP TRIGGER trg_resources_delete_restrict;

/* ============================================================
   TRIGGER 1: Prevent INSERT on RESOURCES during weekdays/holidays
   Purpose: Restrict resource creation to weekends only
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_resources_insert_restrict
BEFORE INSERT ON resources
FOR EACH ROW
DECLARE
    v_restriction VARCHAR2(100);
    v_audit_id NUMBER;
BEGIN
    v_restriction := is_operation_restricted;
    
    IF v_restriction IS NOT NULL THEN
        -- Log the violation
        log_security_violation(
            'INSERT', 'RESOURCES', v_restriction,
            'Attempted to insert resource: ' || :NEW.name || ' (ID would be: ' || :NEW.res_id || ')'
        );
        
        -- Log denied audit entry
        v_audit_id := log_audit_entry(
            'RESOURCES', 'INSERT', :NEW.res_id,
            NULL, NULL, 'DENIED',
            'Operation restricted: ' || v_restriction
        );
        
        -- Raise application error with appropriate message
        IF v_restriction = 'WEEKDAY_RESTRICTION' THEN
            RAISE_APPLICATION_ERROR(-20901, 
                'INSERT operation not allowed on weekdays (Monday-Friday). ' ||
                'Please try on weekends only.');
        ELSIF v_restriction = 'HOLIDAY_RESTRICTION' THEN
            RAISE_APPLICATION_ERROR(-20902,
                'INSERT operation not allowed on holidays. ' ||
                'Please try on non-holiday days.');
        END IF;
    END IF;
END;
/

/* ============================================================
   TRIGGER 2: Prevent UPDATE on RESOURCES during weekdays/holidays
   Purpose: Restrict resource modifications to weekends only
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_resources_update_restrict
BEFORE UPDATE ON resources
FOR EACH ROW
DECLARE
    v_restriction VARCHAR2(100);
    v_old_values CLOB;
    v_new_values CLOB;
    v_audit_id NUMBER;
BEGIN
    v_restriction := is_operation_restricted;
    
    IF v_restriction IS NOT NULL THEN
        -- Create JSON of old and new values for audit trail
        v_old_values := '{' ||
            '"name":"' || :OLD.name || '",' ||
            '"stock_level":' || :OLD.stock_level || ',' ||
            '"threshold":' || :OLD.threshold || ',' ||
            '"unit_price":' || :OLD.unit_price ||
        '}';
        
        v_new_values := '{' ||
            '"name":"' || :NEW.name || '",' ||
            '"stock_level":' || :NEW.stock_level || ',' ||
            '"threshold":' || :NEW.threshold || ',' ||
            '"unit_price":' || :NEW.unit_price ||
        '}';
        
        -- Log the violation
        log_security_violation(
            'UPDATE', 'RESOURCES', v_restriction,
            'Attempted to update resource ID: ' || :OLD.res_id || 
            ' from ' || :OLD.name || ' to ' || :NEW.name
        );
        
        -- Log denied audit entry
        v_audit_id := log_audit_entry(
            'RESOURCES', 'UPDATE', :OLD.res_id,
            v_old_values, v_new_values, 'DENIED',
            'Operation restricted: ' || v_restriction
        );
        
        -- Raise application error
        IF v_restriction = 'WEEKDAY_RESTRICTION' THEN
            RAISE_APPLICATION_ERROR(-20903, 
                'UPDATE operation not allowed on weekdays (Monday-Friday). ' ||
                'Please try on weekends only.');
        ELSIF v_restriction = 'HOLIDAY_RESTRICTION' THEN
            RAISE_APPLICATION_ERROR(-20904,
                'UPDATE operation not allowed on holidays. ' ||
                'Please try on non-holiday days.');
        END IF;
    END IF;
END;
/

/* ============================================================
   TRIGGER 3: Prevent DELETE on RESOURCES during weekdays/holidays
   Purpose: Restrict resource deletions to weekends only
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_resources_delete_restrict
BEFORE DELETE ON resources
FOR EACH ROW
DECLARE
    v_restriction VARCHAR2(100);
    v_old_values CLOB;
    v_audit_id NUMBER;
BEGIN
    v_restriction := is_operation_restricted;
    
    IF v_restriction IS NOT NULL THEN
        -- Create JSON of old values for audit trail
        v_old_values := '{' ||
            '"name":"' || :OLD.name || '",' ||
            '"stock_level":' || :OLD.stock_level || ',' ||
            '"threshold":' || :OLD.threshold || ',' ||
            '"supplier_id":' || :OLD.supplier_id ||
        '}';
        
        -- Log the violation
        log_security_violation(
            'DELETE', 'RESOURCES', v_restriction,
            'Attempted to delete resource ID: ' || :OLD.res_id || 
            ' (' || :OLD.name || ')'
        );
        
        -- Log denied audit entry
        v_audit_id := log_audit_entry(
            'RESOURCES', 'DELETE', :OLD.res_id,
            v_old_values, NULL, 'DENIED',
            'Operation restricted: ' || v_restriction
        );
        
        -- Raise application error
        IF v_restriction = 'WEEKDAY_RESTRICTION' THEN
            RAISE_APPLICATION_ERROR(-20905, 
                'DELETE operation not allowed on weekdays (Monday-Friday). ' ||
                'Please try on weekends only.');
        ELSIF v_restriction = 'HOLIDAY_RESTRICTION' THEN
            RAISE_APPLICATION_ERROR(-20906,
                'DELETE operation not allowed on holidays. ' ||
                'Please try on non-holiday days.');
        END IF;
    END IF;
END;
/

/* ============================================================
   COMPOUND TRIGGER
   Purpose: Advanced trigger with state management for complex auditing
   ============================================================ */

-- Drop existing compound trigger
DROP TRIGGER trg_resources_compound;

CREATE OR REPLACE TRIGGER trg_resources_compound
FOR INSERT OR UPDATE OR DELETE ON resources
COMPOUND TRIGGER

    -- Declaration section: Define types and variables
    TYPE t_audit_rec IS RECORD (
        table_name VARCHAR2(50),
        operation_type VARCHAR2(10),
        record_id VARCHAR2(100),
        old_values CLOB,
        new_values CLOB
    );
    
    TYPE t_audit_table IS TABLE OF t_audit_rec;
    g_audit_data t_audit_table := t_audit_table();
    
    v_audit_id NUMBER; -- Variable to capture audit_id
    
    /* ============================================================
       BEFORE EACH ROW: Check restrictions and collect audit data
       ============================================================ */
    BEFORE EACH ROW IS
        v_restriction VARCHAR2(100);
    BEGIN
        v_restriction := is_operation_restricted;
        
        IF v_restriction IS NOT NULL THEN
            -- Log violation immediately
            log_security_violation(
                CASE 
                    WHEN INSERTING THEN 'INSERT'
                    WHEN UPDATING THEN 'UPDATE'
                    WHEN DELETING THEN 'DELETE'
                END,
                'RESOURCES',
                v_restriction,
                'Compound trigger prevented operation on resource ID: ' || 
                COALESCE(TO_CHAR(:OLD.res_id), TO_CHAR(:NEW.res_id))
            );
            
            -- Raise error based on operation type
            IF INSERTING THEN
                RAISE_APPLICATION_ERROR(-20907, 
                    'INSERT restricted: ' || v_restriction);
            ELSIF UPDATING THEN
                RAISE_APPLICATION_ERROR(-20908, 
                    'UPDATE restricted: ' || v_restriction);
            ELSIF DELETING THEN
                RAISE_APPLICATION_ERROR(-20909, 
                    'DELETE restricted: ' || v_restriction);
            END IF;
        END IF;
        
        -- Collect audit data for successful operations
        IF INSERTING THEN
            g_audit_data.EXTEND;
            g_audit_data(g_audit_data.LAST).table_name := 'RESOURCES';
            g_audit_data(g_audit_data.LAST).operation_type := 'INSERT';
            g_audit_data(g_audit_data.LAST).record_id := :NEW.res_id;
            g_audit_data(g_audit_data.LAST).new_values := 
                '{"name":"' || :NEW.name || 
                '","stock_level":' || :NEW.stock_level || 
                ',"threshold":' || :NEW.threshold || '}';
                
        ELSIF UPDATING THEN
            g_audit_data.EXTEND;
            g_audit_data(g_audit_data.LAST).table_name := 'RESOURCES';
            g_audit_data(g_audit_data.LAST).operation_type := 'UPDATE';
            g_audit_data(g_audit_data.LAST).record_id := :OLD.res_id;
            g_audit_data(g_audit_data.LAST).old_values := 
                '{"name":"' || :OLD.name || 
                '","stock_level":' || :OLD.stock_level || 
                ',"threshold":' || :OLD.threshold || 
                ',"unit_price":' || :OLD.unit_price || '}';
            g_audit_data(g_audit_data.LAST).new_values := 
                '{"name":"' || :NEW.name || 
                '","stock_level":' || :NEW.stock_level || 
                ',"threshold":' || :NEW.threshold || 
                ',"unit_price":' || :NEW.unit_price || '}';
                
        ELSIF DELETING THEN
            g_audit_data.EXTEND;
            g_audit_data(g_audit_data.LAST).table_name := 'RESOURCES';
            g_audit_data(g_audit_data.LAST).operation_type := 'DELETE';
            g_audit_data(g_audit_data.LAST).record_id := :OLD.res_id;
            g_audit_data(g_audit_data.LAST).old_values := 
                '{"name":"' || :OLD.name || 
                '","stock_level":' || :OLD.stock_level || 
                ',"supplier_id":' || :OLD.supplier_id || '}';
        END IF;
    END BEFORE EACH ROW;
    
    /* ============================================================
       AFTER STATEMENT: Bulk audit logging for performance
       ============================================================ */
    AFTER STATEMENT IS
    BEGIN
        FOR i IN 1..g_audit_data.COUNT LOOP
            -- Log audit entries in bulk for performance
            v_audit_id := log_audit_entry(
                g_audit_data(i).table_name,
                g_audit_data(i).operation_type,
                g_audit_data(i).record_id,
                g_audit_data(i).old_values,
                g_audit_data(i).new_values,
                'SUCCESS',
                NULL
            );
        END LOOP;
        
        -- Clear collection for next statement
        g_audit_data.DELETE;
    END AFTER STATEMENT;
    
END trg_resources_compound;
/

/* ============================================================
   ADDITIONAL AUDIT TRIGGERS
   Purpose: Comprehensive auditing across all critical tables
   ============================================================ */

/* ============================================================
   TRIGGER 4: Audit all usage_log changes
   Purpose: Track all consumption recording activities
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_usage_log_audit
AFTER INSERT OR UPDATE OR DELETE ON usage_log
FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_old_values CLOB;
    v_new_values CLOB;
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
    ELSE
        v_operation := 'DELETE';
    END IF;
    
    -- Build JSON for old values (if any)
    IF UPDATING OR DELETING THEN
        v_old_values := '{' ||
            '"res_id":' || :OLD.res_id || ',' ||
            '"date_used":"' || TO_CHAR(:OLD.date_used, 'YYYY-MM-DD HH24:MI:SS') || '",' ||
            '"quantity_used":' || :OLD.quantity_used || ',' ||
            '"department":"' || :OLD.department || '"' ||
        '}';
    END IF;
    
    -- Build JSON for new values (if any)
    IF INSERTING OR UPDATING THEN
        v_new_values := '{' ||
            '"res_id":' || :NEW.res_id || ',' ||
            '"date_used":"' || TO_CHAR(:NEW.date_used, 'YYYY-MM-DD HH24:MI:SS') || '",' ||
            '"quantity_used":' || :NEW.quantity_used || ',' ||
            '"department":"' || :NEW.department || '"' ||
        '}';
    END IF;
    
    -- Log audit entry
    log_audit_entry(
        'USAGE_LOG',
        v_operation,
        COALESCE(TO_CHAR(:OLD.log_id), TO_CHAR(:NEW.log_id)),
        v_old_values,
        v_new_values,
        'SUCCESS',
        NULL
    );
END;
/

/* ============================================================
   TRIGGER 5: Audit reorders table changes
   Purpose: Track all reorder request activities
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_reorders_audit
AFTER INSERT OR UPDATE OR DELETE ON reorders
FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_details CLOB;
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_details := 'New reorder for resource ID ' || :NEW.res_id || 
                    ', quantity: ' || :NEW.quantity;
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_details := 'Reorder ID ' || :OLD.order_id || 
                    ' status changed from ' || :OLD.status || 
                    ' to ' || :NEW.status;
    ELSE
        v_operation := 'DELETE';
        v_details := 'Reorder ID ' || :OLD.order_id || 
                    ' deleted, was for resource ID ' || :OLD.res_id;
    END IF;
    
    -- Log audit entry
    log_audit_entry(
        'REORDERS',
        v_operation,
        COALESCE(TO_CHAR(:OLD.order_id), TO_CHAR(:NEW.order_id)),
        NULL,
        NULL,
        'SUCCESS',
        v_details
    );
END;
/

/* ============================================================
   TRIGGER 6: Auto-create reorder when stock drops below threshold
   Purpose: Automated inventory management
   ============================================================ */
CREATE OR REPLACE TRIGGER trg_auto_reorder
AFTER UPDATE OF stock_level ON resources
FOR EACH ROW
WHEN (OLD.stock_level >= OLD.threshold AND NEW.stock_level < NEW.threshold)
DECLARE
    v_optimal_qty NUMBER;
    v_reorder_exists NUMBER;
BEGIN
    -- Check if reorder already exists to avoid duplicates
    SELECT COUNT(*) INTO v_reorder_exists
    FROM reorders
    WHERE res_id = :NEW.res_id
    AND status IN ('Pending', 'Approved', 'Ordered');
    
    IF v_reorder_exists = 0 THEN
        -- Calculate optimal reorder quantity using existing function
        v_optimal_qty := calculate_reorder_quantity(:NEW.res_id);
        
        -- Fallback calculation if function returns NULL
        IF v_optimal_qty IS NULL OR v_optimal_qty <= 0 THEN
            v_optimal_qty := :NEW.threshold * 2;
        END IF;
        
        -- Create automatic reorder
        INSERT INTO reorders (
            res_id, order_date, quantity, status, expected_delivery
        ) VALUES (
            :NEW.res_id, SYSDATE, v_optimal_qty, 'Pending', SYSDATE + 7
        );
        
        -- Log this automatic action
        log_audit_entry(
            'RESOURCES',
            'AUTO_REORDER',
            :NEW.res_id,
            '{"old_stock":' || :OLD.stock_level || ',"threshold":' || :OLD.threshold || '}',
            '{"new_stock":' || :NEW.stock_level || ',"reorder_qty":' || v_optimal_qty || '}',
            'SUCCESS',
            'Automatic reorder triggered for ' || :NEW.name
        );
        
        DBMS_OUTPUT.PUT_LINE('AUTO-REORDER: Created for ' || :NEW.name || 
                           ' (Qty: ' || v_optimal_qty || ')');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the original update (fail-safe)
        log_audit_entry(
            'RESOURCES',
            'AUTO_REORDER_ERROR',
            :NEW.res_id,
            NULL, NULL, 'ERROR',
            'Failed to create auto-reorder: ' || SQLERRM
        );
END;
/

/* ============================================================
   PROCEDURES FOR TESTING AND REPORTING
   Purpose: Provide utilities for system verification and monitoring
   ============================================================ */

/* ============================================================
   PROCEDURE: Test all restriction scenarios
   Purpose: Comprehensive testing of security restrictions
   ============================================================ */
CREATE OR REPLACE PROCEDURE test_restriction_scenarios
IS
    v_test_date DATE;
    v_restriction VARCHAR2(100);
    v_test_result VARCHAR2(100);
    v_error_msg VARCHAR2(4000);
    v_test_res_id NUMBER; -- Test record ID
BEGIN
    DBMS_OUTPUT.PUT_LINE('===========================================');
    DBMS_OUTPUT.PUT_LINE('TESTING RESTRICTION SCENARIOS');
    DBMS_OUTPUT.PUT_LINE('===========================================');
    
    -- Test 1: Check current day restriction
    v_restriction := is_operation_restricted;
    DBMS_OUTPUT.PUT_LINE('1. Current day restriction: ' || 
                        NVL(v_restriction, 'NONE (Allowed on weekends)'));
    
    -- Test 2: Attempt INSERT on weekday (simulate)
    BEGIN
        -- Create a test resource to test restrictions
        INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
        VALUES ('TEST RESOURCE', 100, 20, 'Units', 'Test', 1, 10.00)
        RETURNING res_id INTO v_test_res_id;
        
        v_test_result := 'INSERT ALLOWED';
        DBMS_OUTPUT.PUT_LINE('2. INSERT test: ' || v_test_result);
        
        -- Clean up test data
        ROLLBACK;
    EXCEPTION
        WHEN OTHERS THEN
            v_test_result := 'INSERT DENIED: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('2. INSERT test: ' || v_test_result);
    END;
    
    -- Test 3: Check holiday table
    DBMS_OUTPUT.PUT_LINE('3. Holidays in system:');
    FOR h IN (SELECT holiday_date, holiday_name FROM holidays ORDER BY holiday_date) LOOP
        DBMS_OUTPUT.PUT_LINE('   - ' || TO_CHAR(h.holiday_date, 'DD-MON-YYYY') || ': ' || h.holiday_name);
    END LOOP;
    
    -- Test 4: View recent audit log entries
    DBMS_OUTPUT.PUT_LINE('4. Recent audit entries:');
    FOR a IN (
        SELECT audit_id, table_name, operation_type, status, 
               TO_CHAR(operation_date, 'DD-MON HH24:MI') as op_time
        FROM audit_log
        ORDER BY audit_id DESC
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('   ID ' || a.audit_id || ': ' || a.table_name || 
                           ' ' || a.operation_type || ' - ' || a.status || 
                           ' at ' || a.op_time);
    END LOOP;
    
    -- Test 5: View security violations
    DBMS_OUTPUT.PUT_LINE('5. Security violations:');
    FOR v IN (
        SELECT violation_id, restriction_type, 
               TO_CHAR(violation_date, 'DD-MON HH24:MI') as violation_time
        FROM security_violations
        ORDER BY violation_id DESC
        FETCH FIRST 3 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('   Violation ' || v.violation_id || ': ' || 
                           v.restriction_type || ' at ' || v.violation_time);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('===========================================');
    DBMS_OUTPUT.PUT_LINE('TESTING COMPLETE');
    DBMS_OUTPUT.PUT_LINE('===========================================');
END test_restriction_scenarios;
/

/* ============================================================
   PROCEDURE: Generate audit report
   Purpose: Comprehensive audit reporting for compliance and monitoring
   ============================================================ */
CREATE OR REPLACE PROCEDURE generate_audit_report(
    p_days_back IN NUMBER DEFAULT 7
)
IS
    v_total_operations NUMBER;
    v_denied_operations NUMBER;
    v_success_operations NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('AUDIT REPORT - Last ' || p_days_back || ' days');
    DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================');
    
    -- Summary statistics
    SELECT COUNT(*),
           SUM(CASE WHEN status = 'DENIED' THEN 1 ELSE 0 END),
           SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END)
    INTO v_total_operations, v_denied_operations, v_success_operations
    FROM audit_log
    WHERE operation_date >= SYSDATE - p_days_back;
    
    DBMS_OUTPUT.PUT_LINE('SUMMARY:');
    DBMS_OUTPUT.PUT_LINE('  Total operations: ' || v_total_operations);
    DBMS_OUTPUT.PUT_LINE('  Successful: ' || v_success_operations);
    DBMS_OUTPUT.PUT_LINE('  Denied: ' || v_denied_operations);
    DBMS_OUTPUT.PUT_LINE('  Success rate: ' || 
        CASE WHEN v_total_operations > 0 
             THEN ROUND((v_success_operations / v_total_operations) * 100, 1) || '%'
             ELSE 'N/A'
        END);
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('OPERATIONS BY TABLE:');
    FOR t IN (
        SELECT table_name, operation_type, status, COUNT(*) as operation_count
        FROM audit_log
        WHERE operation_date >= SYSDATE - p_days_back
        GROUP BY table_name, operation_type, status
        ORDER BY table_name, operation_type, status
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || t.table_name || ' ' || t.operation_type || 
                           ' (' || t.status || '): ' || t.operation_count);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('DENIED OPERATIONS DETAIL:');
    FOR d IN (
        SELECT table_name, operation_type, user_name, error_message,
               TO_CHAR(operation_date, 'DD-MON HH24:MI') as op_time
        FROM audit_log
        WHERE status = 'DENIED'
        AND operation_date >= SYSDATE - p_days_back
        ORDER BY operation_date DESC
        FETCH FIRST 10 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || d.op_time || ' - ' || d.user_name || 
                           ' attempted ' || d.operation_type || ' on ' || 
                           d.table_name || ': ' || SUBSTR(d.error_message, 1, 50));
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('TOP USERS:');
    FOR u IN (
        SELECT user_name, COUNT(*) as operation_count
        FROM audit_log
        WHERE operation_date >= SYSDATE - p_days_back
        GROUP BY user_name
        ORDER BY operation_count DESC
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || u.user_name || ': ' || u.operation_count || ' operations');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('================================================');
END generate_audit_report;
/

-- ============================================================
-- END OF PHASE 7: Advanced Programming & Auditing
-- ============================================================