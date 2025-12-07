-- Final summary
BEGIN
    DBMS_OUTPUT.PUT_LINE(chr(10) || '===========================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VII - FINAL SUMMARY');
    DBMS_OUTPUT.PUT_LINE('===========================================');
    
    -- Count valid objects
    DECLARE
        v_total_objects NUMBER;
        v_valid_objects NUMBER;
        v_invalid_objects NUMBER;
    BEGIN
        SELECT COUNT(*),
               SUM(CASE WHEN status = 'VALID' THEN 1 ELSE 0 END),
               SUM(CASE WHEN status = 'INVALID' THEN 1 ELSE 0 END)
        INTO v_total_objects, v_valid_objects, v_invalid_objects
        FROM user_objects
        WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'TRIGGER')
        AND object_name IN (
            SELECT object_name FROM user_objects
            WHERE object_name LIKE 'TRG_%'
            OR object_name LIKE 'IS_%'
            OR object_name LIKE 'LOG_%'
            OR object_name LIKE 'CALCULATE_%'
            OR object_name LIKE 'VALIDATE_%'
            OR object_name LIKE 'GET_%'
            OR object_name IN ('TEST_RESTRICTION_SCENARIOS', 'GENERATE_AUDIT_REPORT')
        );
        
        DBMS_OUTPUT.PUT_LINE('Object Status:');
        DBMS_OUTPUT.PUT_LINE('  Total objects: ' || v_total_objects);
        DBMS_OUTPUT.PUT_LINE('  Valid objects: ' || v_valid_objects || ' ✓');
        DBMS_OUTPUT.PUT_LINE('  Invalid objects: ' || v_invalid_objects || 
            CASE WHEN v_invalid_objects > 0 THEN ' ✗' ELSE ' ✓' END);
    END;
    
    -- Count data in audit tables
    DBMS_OUTPUT.PUT_LINE(chr(10) || 'Audit Data:');
    DBMS_OUTPUT.PUT_LINE('  Audit log entries: ' || (SELECT COUNT(*) FROM audit_log));
    DBMS_OUTPUT.PUT_LINE('  Security violations: ' || (SELECT COUNT(*) FROM security_violations));
    DBMS_OUTPUT.PUT_LINE('  Holidays defined: ' || (SELECT COUNT(*) FROM holidays));
    
    -- CRITICAL REQUIREMENT check
    DBMS_OUTPUT.PUT_LINE(chr(10) || 'CRITICAL REQUIREMENT Status:');
    DBMS_OUTPUT.PUT_LINE('  INSERT restriction: ' || 
        CASE WHEN is_operation_restricted IS NOT NULL THEN 'ACTIVE (blocked)' ELSE 'INACTIVE (allowed)' END);
    DBMS_OUTPUT.PUT_LINE('  Today''s restriction: ' || NVL(is_operation_restricted, 'NONE'));
    
    DBMS_OUTPUT.PUT_LINE(chr(10) || '===========================================');
    DBMS_OUTPUT.PUT_LINE('PHASE VII TESTING COMPLETE');
    DBMS_OUTPUT.PUT_LINE('===========================================');
END;
/