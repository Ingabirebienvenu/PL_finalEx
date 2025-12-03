# PL_finalEx
# PL/SQL Oracle Database Capstone Project
# Academic Year: 2025-2026 | Semester: 5
# Lecturer: Eric Maniraguha | eric.maniraguha@auca.ac.rw
# Institution: Adventist University of Central Africa (AUCA)


# 📋Topic: Mining Resource Optimization & Stock Tracking System 

# 📋Project Description 

📝Mining operations require continuous availability of essential resources such as fuel, explosives, 
and spare parts. Any delay in restocking these resources can lead to serious production 
downtime, safety risks, and increased operational costs. To address this, the Mining Resource 
Optimization & Stock Tracking System is designed to automate the monitoring, analysis, and 
replenishment of mining materials. 

 # Phase II
 # Business process modeling - UML/BPMN diagram + 1-page explanation

<img width="3078" height="4524" alt="deepseek_mermaid_20251203_1dda15" src="https://github.com/user-attachments/assets/121210c0-db7c-4ceb-8315-356fd4fb58df" />

BUSINESS PROCESS: MINING RESOURCE OPTIMIZATION

1. PROCESS INITIATION: Mining operations team logs daily consumption of resources (fuel, explosives, parts).

2. STOCK MONITORING: System automatically updates stock levels and compares against predefined thresholds.

3. DECISION POINT: If stock < threshold, trigger reorder process; else continue monitoring.

4. REORDER CALCULATION: System calculates optimal reorder quantity based on:
   - Average daily consumption
   - Lead time considerations
   - Supplier constraints

5. ORDER GENERATION: Automatic insertion into reorders table with 'Pending' status.

6. PROCUREMENT NOTIFICATION: System flags procurement department for action.

7. SUPPLIER FULFILLMENT: Supplier receives order, delivers resources.

8. STOCK UPDATE: Upon receipt, stock levels updated, reorder status changed to 'Completed'.

MIS FUNCTIONS:
- Real-time inventory tracking
- Automated decision-making
- Predictive analytics for stock forecasting
- Supplier performance monitoring
- Audit trail of all transactions

ORGANIZATIONAL IMPACT:
- 30% reduction in production downtime
- 15% decrease in inventory holding costs
- Improved safety compliance
- Enhanced procurement planning

ANALYTICS OPPORTUNITIES:
- Consumption trend analysis
- Supplier reliability scoring
- Stockout risk prediction
- Cost optimization modeling


# 📝Phase III
# Logical database design - ER diagram + data dictionary


1. ER Diagram

![WhatsApp Image 2025-12-03 at 14 15 44](https://github.com/user-attachments/assets/e9020442-2fb9-4c77-ab37-21742d6482d0)

 2. BI Considerations:

 # Phase III Data Dictionary

This document provides the complete data dictionary for the Mining Stock Management System, including all tables, columns, data types, constraints, and purposes.

| Table       | Column        | Data Type       | Constraints                                        | Purpose                                      |
|------------|---------------|----------------|---------------------------------------------------|----------------------------------------------|
| Suppliers  | supplier_id   | NUMBER(10)     | PK, NOT NULL                                      | Unique supplier identifier                   |
| Suppliers  | name          | VARCHAR2(50)   | NOT NULL                                         | Supplier company name                        |
| Suppliers  | contact       | VARCHAR2(50)   | NOT NULL                                         | Phone/email contact                          |
| Resources  | res_id        | NUMBER(10)     | PK, NOT NULL                                     | Unique resource identifier                   |
| Resources  | name          | VARCHAR2(50)   | NOT NULL, UNIQUE                                 | Resource name (Diesel, Explosives)          |
| Resources  | stock_level   | NUMBER(10,2)   | NOT NULL, CHECK (>= 0)                           | Current quantity in stock                    |
| Resources  | threshold     | NUMBER(10,2)   | NOT NULL, CHECK (> 0)                            | Minimum stock before reorder                 |
| Resources  | supplier_id   | NUMBER(10)     | FK → Suppliers, NOT NULL                          | Supplier providing this resource            |
| usage_log  | log_id        | NUMBER(10)     | PK, NOT NULL                                     | Unique log entry                             |
| usage_log  | res_id        | NUMBER(10)     | FK → Resources, NOT NULL                          | Resource consumed                             |
| usage_log  | date_used     | DATE           | NOT NULL                                         | Date of consumption                           |
| usage_log  | quantity_used | NUMBER(10,2)   | NOT NULL, CHECK (> 0)                             | Amount consumed                               |
| Reorders   | order_id      | NUMBER(10)     | PK, NOT NULL                                     | Unique reorder identifier                     |
| Reorders   | res_id        | NUMBER(10)     | FK → Resources, NOT NULL                          | Resource to reorder                           |
| Reorders   | supplier_id   | NUMBER(10)     | FK → Suppliers, NOT NULL                          | Supplier for this order                        |
| Reorders   | order_date    | DATE           | NOT NULL, DEFAULT SYSDATE                          | When reorder was generated                    |
| Reorders   | quantity      | NUMBER(10,2)   | NOT NULL, CHECK (> 0)                             | Quantity to order                             |
| Reorders   | status        | VARCHAR2(20)   | NOT NULL, CHECK IN ('Pending','Completed')        | Order status                                  |



 # 📝PHASE IV: Database Creation  Oracle PDB + configuration scripts

 Objective: Create and configure Oracle pluggable database.

# 📋 STEP 1: Connect to Oracle as SYSDBA

# 📊 STEP 2: Check Current Database Status
 <img width="1920" height="1080" alt="Screenshot (642)" src="https://github.com/user-attachments/assets/efb2843d-ca51-45f3-b700-96851df20457" />

# 🏗️ STEP 3: Create Your Pluggable Database (PDB)
 And
 🔓 STEP 4: Open Your New PDB
<img width="1920" height="1080" alt="Screenshot (643)" src="https://github.com/user-attachments/assets/dd070ce9-1ca5-4d83-bd79-d7d072c28f06" />


✅ STEP 5: Verify PDB Was Created
<img width="1920" height="1080" alt="Screenshot (643)" src="https://github.com/user-attachments/assets/0c7ac041-8777-4da3-9e4e-c6cda05b8211" />

# 💾 STEP 6: Create Custom Tablespaces
1 Create DATA Tablespace
2 Create INDEX Tablespace
3 Verify Tablespaces
<img width="1920" height="1080" alt="Screenshot (645)" src="https://github.com/user-attachments/assets/1a5d302b-7994-4ebf-8387-28a7f33d0d25" />


# 👤 STEP 10: Create Your Application User and 🔑 STEP 11: Grant Privileges
<img width="1920" height="1080" alt="Screenshot (646)" src="https://github.com/user-attachments/assets/163a8ebf-6be3-42f2-accf-13775b61465b" />

# ✅ STEP 12: Verify User and Privileges
1 Check User Details
2 Check System Privileges
3 Check Tablespace Quotas
<img width="1920" height="1080" alt="Screenshot (647)" src="https://github.com/user-attachments/assets/299635ef-ce64-4206-8d13-d9c83bb7b371" />


# 🔧 STEP 13: Configure Database Parameters
1 Check Memory Settings
2 Check Archive Log Mode
<img width="1920" height="1080" alt="Screenshot (648)" src="https://github.com/user-attachments/assets/235134e1-dedd-49e1-ac58-9ced4ce90bc8" />
























