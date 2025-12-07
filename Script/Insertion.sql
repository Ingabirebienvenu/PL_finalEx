CREATE INDEX idx_resources_supplier ON resources(supplier_id) TABLESPACE mining_index;
CREATE INDEX idx_resources_category ON resources(category) TABLESPACE mining_index;
CREATE INDEX idx_usage_log_resource_date ON usage_log(res_id, date_used) TABLESPACE mining_index;
CREATE INDEX idx_usage_log_date ON usage_log(date_used) TABLESPACE mining_index;
CREATE INDEX idx_reorders_resource ON reorders(res_id) TABLESPACE mining_index;
CREATE INDEX idx_reorders_status ON reorders(status) TABLESPACE mining_index;
CREATE INDEX idx_reorders_dates ON reorders(order_date, expected_delivery) TABLESPACE mining_index;


INSERT INTO suppliers (name, contact, email, phone, address) VALUES
('Mining Supplies Ltd', 'John Smith', 'john@miningsupplies.com', '+250788123456', 'Kigali, Rwanda');

INSERT INTO suppliers (name, contact, email, phone, address) VALUES
('Explosives Inc', 'Sarah Johnson', 'sarah@explosives.com', '+250788654321', 'Kampala, Uganda');

INSERT INTO suppliers (name, contact, email, phone, address) VALUES
('Fuel Distributors Africa', 'Robert Mugisha', 'robert@fuelafrica.com', '+250788111222', 'Nairobi, Kenya');

INSERT INTO suppliers (name, contact, email, phone, address) VALUES
('Heavy Machinery Parts Co', 'Alice Uwase', 'alice@partsco.com', '+250788333444', 'Bujumbura, Burundi');

INSERT INTO suppliers (name, contact, email, phone, address) VALUES
('Chemical Solutions Ltd', 'David Kamanzi', 'david@chemsolutions.com', '+250788555666', 'Dar es Salaam, Tanzania');

COMMIT;



INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Diesel Fuel', 5000, 1000, 'Liters', 'Fuel', 3, 1.25);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Gasoline', 2000, 500, 'Liters', 'Fuel', 3, 1.45);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('ANFO Explosives', 8000, 2000, 'Kilograms', 'Explosives', 2, 2.75);


INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Detonators', 500, 100, 'Units', 'Explosives', 2, 5.50);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Excavator Engine Oil', 200, 50, 'Liters', 'Lubricants', 1, 12.99);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Hydraulic Fluid', 300, 75, 'Liters', 'Lubricants', 1, 8.75);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Drill Bits (Large)', 45, 10, 'Units', 'Spare Parts', 4, 89.99);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Conveyor Belts', 12, 3, 'Units', 'Spare Parts', 4, 450.00);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Cyanide', 1500, 300, 'Kilograms', 'Chemicals', 5, 15.25);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Lime', 5000, 1000, 'Kilograms', 'Chemicals', 5, 0.75);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Safety Helmets', 150, 30, 'Units', 'Spare Parts', 1, 25.00);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Safety Gloves', 300, 50, 'Pairs', 'Spare Parts', 1, 8.50);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Electric Fuses', 200, 40, 'Units', 'Spare Parts', 4, 3.25);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Lubricating Grease', 400, 100, 'Kilograms', 'Lubricants', 1, 4.75);

INSERT INTO resources (name, stock_level, threshold, unit_of_measure, category, supplier_id, unit_price)
VALUES ('Blasting Caps', 600, 150, 'Units', 'Explosives', 2, 2.25);

COMMIT;










DECLARE
    v_date DATE;
    v_resource_id NUMBER;
    v_quantity NUMBER;
    v_stock NUMBER;
BEGIN
    FOR i IN 1..300 LOOP
        v_date := SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0,30));
        v_resource_id := TRUNC(DBMS_RANDOM.VALUE(1,16));

        BEGIN
            SELECT stock_level INTO v_stock FROM resources WHERE res_id = v_resource_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                CONTINUE;
        END;

        IF v_resource_id IN (1,2) THEN
            v_quantity := ROUND(DBMS_RANDOM.VALUE(100,500),2);
        ELSIF v_resource_id IN (3,9,10,14) THEN
            v_quantity := ROUND(DBMS_RANDOM.VALUE(50,300),2);
        ELSE
            v_quantity := ROUND(DBMS_RANDOM.VALUE(1,50),2);
        END IF;

        IF v_quantity > v_stock THEN
            v_quantity := v_stock;
        END IF;

        IF v_quantity > 0 THEN
            INSERT INTO usage_log (res_id, date_used, quantity_used, department, operator_id, equipment_used)
            VALUES (
                v_resource_id,
                v_date,
                v_quantity,
                CASE TRUNC(DBMS_RANDOM.VALUE(1,5))
                    WHEN 1 THEN 'Drilling'
                    WHEN 2 THEN 'Excavation'
                    WHEN 3 THEN 'Processing'
                    ELSE 'Maintenance'
                END,
                'OP' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1,51)),3,'0'),
                CASE 
                    WHEN v_resource_id IN (1,2,5,6,14) THEN 'Excavator-0' || TRUNC(DBMS_RANDOM.VALUE(1,10))
                    WHEN v_resource_id IN (3,4,15) THEN 'Drilling Rig-' || TRUNC(DBMS_RANDOM.VALUE(1,6))
                    ELSE 'Various Equipment'
                END
            );

            UPDATE resources
            SET stock_level = stock_level - v_quantity,
                last_updated = SYSDATE
            WHERE res_id = v_resource_id;
        END IF;
    END LOOP;

    COMMIT;
END;
/






INSERT INTO reorders (res_id, order_date, quantity, status, expected_delivery) 
VALUES (7, SYSDATE - 5, 25, 'Delivered', SYSDATE - 2);
COMMIT;

INSERT INTO reorders (res_id, order_date, quantity, status, expected_delivery) 
VALUES (8, SYSDATE - 3, 5, 'Ordered', SYSDATE + 7);
COMMIT;

INSERT INTO reorders (res_id, order_date, quantity, status, expected_delivery) 
VALUES (11, SYSDATE - 1, 100, 'Pending', NULL);
COMMIT;

INSERT INTO reorders (res_id, order_date, quantity, status, expected_delivery) 
VALUES (12, SYSDATE - 2, 200, 'Approved', SYSDATE + 5);
COMMIT;