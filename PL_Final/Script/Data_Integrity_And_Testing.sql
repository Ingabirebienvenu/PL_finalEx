-- =============================================
-- DATA INTEGRITY AND VERIFICATION QUERIES
-- =============================================

-- Table record counts
SELECT 'Suppliers' AS table_name, COUNT(*) AS record_count FROM suppliers
UNION ALL
SELECT 'Resources' AS table_name, COUNT(*) FROM resources
UNION ALL
SELECT 'Usage Log' AS table_name, COUNT(*) FROM usage_log
UNION ALL
SELECT 'Reorders' AS table_name, COUNT(*) FROM reorders
ORDER BY table_name;

-- =============================================
-- TESTING QUERIES
-- =============================================

-- Resources with stock status
SELECT r.res_id, r.name, r.category, r.stock_level, r.threshold,
       CASE 
           WHEN r.stock_level < r.threshold THEN 'BELOW THRESHOLD'
           WHEN r.stock_level < r.threshold * 1.5 THEN 'LOW'
           ELSE 'OK'
       END as stock_status,
       s.name as supplier_name
FROM resources r
LEFT JOIN suppliers s ON r.supplier_id = s.supplier_id
ORDER BY r.res_id;

-- Last 10 usage entries
SELECT * FROM (
    SELECT log_id, res_id, date_used, quantity_used, department
    FROM usage_log
    ORDER BY date_used DESC
) WHERE ROWNUM <= 10;

-- Reorders check
SELECT r.order_id, res.name as resource_name, r.order_date, 
       r.quantity, r.status, r.expected_delivery
FROM reorders r
JOIN resources res ON r.res_id = res.res_id
ORDER BY r.order_date DESC;

-- Comprehensive verification
SELECT 
    'SUPPLIERS: ' || COUNT(*) as count_summary
FROM suppliers
UNION ALL
SELECT 'RESOURCES: ' || COUNT(*) FROM resources
UNION ALL
SELECT 'USAGE LOG: ' || COUNT(*) FROM usage_log
UNION ALL
SELECT 'REORDERS: ' || COUNT(*) FROM reorders;

-- Check which resources need reordering
SELECT r.name, r.stock_level, r.threshold,
       CASE WHEN r.stock_level < r.threshold THEN 'NEEDS REORDER' 
            ELSE 'OK' END as status
FROM resources r
WHERE r.stock_level < r.threshold * 1.2
ORDER BY r.stock_level / r.threshold;

-- =============================================
-- END OF TESTING QUERIES
-- =============================================