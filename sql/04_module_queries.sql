-- ============================================================================
-- Script: 04_module_queries.sql
-- Project: Advanced Bank Management System (BACSE202)
-- Database Engine: Oracle Database (Oracle XE / SQL*Plus / SQL Developer)
-- Description: 4 Team Member Modules, each with 1 INSERT, 1 UPDATE, 1 DELETE
--              (all wrapped in SAVEPOINT/ROLLBACK to preserve seed data), and
--              5 labeled SELECT queries covering JOINs, aggregations,
--              subqueries, and built-in Oracle functions.
-- Run as: @sql/04_module_queries.sql
-- ============================================================================

SET SERVEROUTPUT ON;
SET LINESIZE 200;
SET PAGESIZE 50;

-- ============================================================================
-- MODULE 1: CORE BANKING
-- Tables: CUSTOMER, CUSTOMER_PHONE, ACCOUNT, CUSTOMER_ACCOUNT, TRANSACTION
-- Team Member: Module 1
-- ============================================================================

-- ----------------------------------------------------------------------------
-- M1 DML: INSERT (Demonstrating adding a new customer with account)
-- Wrapped in SAVEPOINT; ROLLBACK restores seed data after demonstration
-- ----------------------------------------------------------------------------
SAVEPOINT sp_m1_dml;

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1011, 'Divya', 'Lakshmi', 'Nair', TO_DATE('2000-06-15', 'YYYY-MM-DD'), 'divya.nair@vitap.ac.in', 'KH-12', 'VIT Housing Colony', 'Vellore', 'Tamil Nadu', '632014');

INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1011, '9500123456');

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042021, 'Savings', 12000.00, TO_DATE('2026-10-18', 'YYYY-MM-DD'), 'Active', 102);

INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1011, 10042021);

-- M1 DML: UPDATE (Update customer email)
UPDATE CUSTOMER
SET    Email = 'aarav.sharma.updated@gmail.com'
WHERE  Customer_ID = 1001;

-- M1 DML: DELETE (Remove an orphan phone record)
DELETE FROM CUSTOMER_PHONE
WHERE  Customer_ID = 1003 AND Phone_Number = '9884011223';

-- Rollback to preserve seed data integrity for subsequent runs
ROLLBACK TO SAVEPOINT sp_m1_dml;

-- ----------------------------------------------------------------------------
-- M1 SELECT QUERIES
-- ----------------------------------------------------------------------------

-- [M1-Q1] Simple retrieval: All active customers with their primary account,
--         ordered by Customer_ID
SELECT
    c.Customer_ID,
    c.First_Name || ' ' || NVL(c.Middle_Name || ' ', '') || c.Last_Name AS Full_Name,
    c.City,
    c.State,
    c.Email
FROM   CUSTOMER c
WHERE  EXISTS (
    SELECT 1 FROM CUSTOMER_ACCOUNT ca
    JOIN   ACCOUNT a ON ca.Account_No = a.Account_No
    WHERE  ca.Customer_ID = c.Customer_ID AND a.Status = 'Active'
)
ORDER BY c.Customer_ID;

-- [M1-Q2] Multi-table JOIN: Customers with all their linked accounts,
--         branch name, and current balance
SELECT
    c.Customer_ID,
    c.First_Name || ' ' || c.Last_Name        AS Customer_Name,
    a.Account_No,
    a.Account_Type,
    TO_CHAR(a.Balance, 'FM99,99,99,999.00')   AS Balance,
    a.Status                                   AS Account_Status,
    b.Branch_Name,
    b.IFSC_Code
FROM   CUSTOMER c
JOIN   CUSTOMER_ACCOUNT ca ON c.Customer_ID = ca.Customer_ID
JOIN   ACCOUNT a            ON ca.Account_No = a.Account_No
JOIN   BRANCH b             ON a.Branch_ID   = b.Branch_ID
ORDER BY c.Customer_ID, a.Account_No;

-- [M1-Q3] Group Aggregation: Monthly transaction summary (last 6 months)
--         showing count, total deposits, total withdrawals per month
SELECT
    TO_CHAR(t.Transaction_Date, 'MON-YYYY')              AS Txn_Month,
    COUNT(*)                                              AS Total_Txns,
    SUM(CASE WHEN t.Transaction_Type IN ('Deposit','Transfer_Credit') THEN t.Amount ELSE 0 END)
                                                          AS Total_Credits,
    SUM(CASE WHEN t.Transaction_Type IN ('Withdrawal','Transfer_Debit','Loan_EMI','FD_Booking') THEN t.Amount ELSE 0 END)
                                                          AS Total_Debits,
    ROUND(AVG(t.Amount), 2)                               AS Avg_Txn_Amount
FROM   TRANSACTION t
WHERE  t.Transaction_Date >= ADD_MONTHS(SYSDATE, -6)
GROUP BY TO_CHAR(t.Transaction_Date, 'MON-YYYY'), TRUNC(t.Transaction_Date, 'MM')
ORDER BY TRUNC(t.Transaction_Date, 'MM');

-- [M1-Q4] Nested Subquery: Customers whose total account balance
--         is ABOVE the average balance across all accounts
SELECT
    c.Customer_ID,
    c.First_Name || ' ' || c.Last_Name        AS Customer_Name,
    SUM(a.Balance)                             AS Total_Balance,
    ROUND(SUM(a.Balance) - (SELECT AVG(Balance) FROM ACCOUNT), 2)
                                               AS Above_Avg_By
FROM   CUSTOMER c
JOIN   CUSTOMER_ACCOUNT ca ON c.Customer_ID = ca.Customer_ID
JOIN   ACCOUNT a            ON ca.Account_No = a.Account_No
GROUP BY c.Customer_ID, c.First_Name, c.Last_Name
HAVING SUM(a.Balance) > (SELECT AVG(Balance) FROM ACCOUNT)
ORDER BY Total_Balance DESC;

-- [M1-Q5] Built-in Oracle Functions: Customer profile card with derived age,
--         account tenure in months, and formatted details
SELECT
    c.Customer_ID,
    UPPER(c.First_Name || ' ' || c.Last_Name)            AS Customer_Name_UPPER,
    fn_get_customer_age(c.Customer_ID)                   AS Age_Years,
    TO_CHAR(c.Date_of_Birth, 'DD-Mon-YYYY')              AS DOB_Formatted,
    a.Account_No,
    a.Account_Type,
    ROUND(MONTHS_BETWEEN(SYSDATE, a.Open_Date))          AS Account_Tenure_Months,
    TO_CHAR(a.Balance, 'FM\u20B999,99,99,999.00')         AS Balance_INR,
    NVL(cp.Phone_Number, 'No Phone Registered')          AS Primary_Phone,
    CASE
        WHEN a.Balance >= 100000 THEN 'Platinum'
        WHEN a.Balance >= 25000  THEN 'Gold'
        WHEN a.Balance >= 5000   THEN 'Silver'
        ELSE 'Basic'
    END                                                  AS Tier
FROM   CUSTOMER c
JOIN   CUSTOMER_ACCOUNT ca ON c.Customer_ID = ca.Customer_ID
JOIN   ACCOUNT a            ON ca.Account_No = a.Account_No
LEFT JOIN CUSTOMER_PHONE cp ON c.Customer_ID = cp.Customer_ID
                             AND cp.Phone_Number = (
                                 SELECT MIN(Phone_Number)
                                 FROM   CUSTOMER_PHONE
                                 WHERE  Customer_ID = c.Customer_ID
                             )
ORDER BY c.Customer_ID;


-- ============================================================================
-- MODULE 2: CARDS, BENEFICIARIES & FUND TRANSFERS
-- Tables: CARD, BENEFICIARY, FUND_TRANSFER
-- Team Member: Module 2
-- ============================================================================

-- ----------------------------------------------------------------------------
-- M2 DML: INSERT, UPDATE, DELETE wrapped in SAVEPOINT
-- ----------------------------------------------------------------------------
SAVEPOINT sp_m2_dml;

-- M2 INSERT: Issue a new Forex card to account 10042015
INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (711, 10042015, 'Credit', TO_DATE('2026-10-18', 'YYYY-MM-DD'), TO_DATE('2031-10-31', 'YYYY-MM-DD'), 'Active');

-- M2 UPDATE: Block card 709 permanently (customer request)
UPDATE CARD
SET    Status = 'Blocked'
WHERE  Card_ID = 709;

-- M2 DELETE: Remove a failed fund transfer record (data hygiene)
DELETE FROM FUND_TRANSFER
WHERE  Transfer_ID = 808 AND Status = 'Failed';

ROLLBACK TO SAVEPOINT sp_m2_dml;

-- ----------------------------------------------------------------------------
-- M2 SELECT QUERIES
-- ----------------------------------------------------------------------------

-- [M2-Q1] Simple retrieval: All active cards expiring within 6 months
SELECT
    c.Card_ID,
    c.Account_No,
    c.Card_Type,
    TO_CHAR(c.Issue_Date,   'DD-Mon-YYYY') AS Issue_Date,
    TO_CHAR(c.Expiry_Date,  'DD-Mon-YYYY') AS Expiry_Date,
    c.Status,
    ROUND(MONTHS_BETWEEN(c.Expiry_Date, SYSDATE)) AS Months_Until_Expiry
FROM   CARD c
WHERE  c.Status = 'Active'
  AND  c.Expiry_Date BETWEEN SYSDATE AND ADD_MONTHS(SYSDATE, 6)
ORDER BY c.Expiry_Date;

-- [M2-Q2] Multi-table JOIN: Fund transfers with full source account,
--         beneficiary name, customer name, and transfer details
SELECT
    ft.Transfer_ID,
    c.Customer_ID,
    c.First_Name || ' ' || c.Last_Name             AS Sender_Name,
    ft.Account_No                                   AS Source_Account,
    b.Beneficiary_Name,
    b.IFSC_Code                                     AS Beneficiary_IFSC,
    TO_CHAR(ft.Amount, 'FM99,99,99,999.00')         AS Amount,
    ft.Transfer_Mode,
    TO_CHAR(ft.Transfer_Date, 'DD-Mon-YYYY')        AS Transfer_Date,
    ft.Status                                       AS Transfer_Status
FROM   FUND_TRANSFER ft
JOIN   BENEFICIARY b      ON ft.Beneficiary_ID = b.Beneficiary_ID
JOIN   CUSTOMER    c      ON b.Customer_ID     = c.Customer_ID
ORDER BY ft.Transfer_Date DESC;

-- [M2-Q3] Group Aggregation: Transfer volume by mode
--         showing count, total amount, and avg amount per mode
SELECT
    ft.Transfer_Mode,
    COUNT(*)                                        AS Total_Transfers,
    TO_CHAR(SUM(ft.Amount), 'FM99,99,99,999.00')   AS Total_Volume,
    TO_CHAR(ROUND(AVG(ft.Amount), 2), 'FM99,99,999.00') AS Avg_Transfer,
    SUM(CASE WHEN ft.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed_Count,
    SUM(CASE WHEN ft.Status = 'Failed'    THEN 1 ELSE 0 END) AS Failed_Count
FROM   FUND_TRANSFER ft
GROUP BY ft.Transfer_Mode
ORDER BY Total_Volume DESC;

-- [M2-Q4] Nested Subquery: Customers who have MORE than the average number
--         of registered beneficiaries (high-value transfer profiles)
SELECT
    c.Customer_ID,
    c.First_Name || ' ' || c.Last_Name             AS Customer_Name,
    COUNT(b.Beneficiary_ID)                         AS Beneficiary_Count
FROM   CUSTOMER c
JOIN   BENEFICIARY b ON c.Customer_ID = b.Customer_ID
GROUP BY c.Customer_ID, c.First_Name, c.Last_Name
HAVING COUNT(b.Beneficiary_ID) >= ALL (
    SELECT COUNT(*) FROM BENEFICIARY GROUP BY Customer_ID
)
ORDER BY Beneficiary_Count DESC;

-- [M2-Q5] Built-in Oracle Functions: Card expiry dashboard for relationship
--         managers, using MONTHS_BETWEEN, NVL, CASE, and TO_CHAR
SELECT
    crd.Card_ID,
    cst.Customer_ID,
    UPPER(cst.First_Name || ' ' || cst.Last_Name)  AS Customer_Name,
    crd.Card_Type,
    TO_CHAR(crd.Issue_Date,  'DD-Mon-YYYY')        AS Issued_On,
    TO_CHAR(crd.Expiry_Date, 'DD-Mon-YYYY')        AS Expires_On,
    ROUND(MONTHS_BETWEEN(crd.Expiry_Date, SYSDATE)) AS Months_Left,
    crd.Status,
    CASE
        WHEN crd.Status = 'Expired'                       THEN 'ACTION: Renew Immediately'
        WHEN MONTHS_BETWEEN(crd.Expiry_Date, SYSDATE) < 3 THEN 'ACTION: Renewal Soon'
        WHEN MONTHS_BETWEEN(crd.Expiry_Date, SYSDATE) < 6 THEN 'WATCH: Expiring This Year'
        ELSE 'OK'
    END                                            AS Action_Required
FROM   CARD crd
JOIN   ACCOUNT a ON crd.Account_No = a.Account_No
JOIN   CUSTOMER_ACCOUNT ca ON a.Account_No = ca.Account_No
JOIN   CUSTOMER cst ON ca.Customer_ID = cst.Customer_ID
ORDER BY crd.Expiry_Date;


-- ============================================================================
-- MODULE 3: LOANS & FIXED DEPOSITS
-- Tables: LOAN, LOAN_PAYMENT, FIXED_DEPOSIT
-- Team Member: Module 3
-- ============================================================================

-- ----------------------------------------------------------------------------
-- M3 DML: INSERT, UPDATE, DELETE wrapped in SAVEPOINT
-- ----------------------------------------------------------------------------
SAVEPOINT sp_m3_dml;

-- M3 INSERT: New Education Loan for customer 1008
INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (311, 1008, 'Personal Loan', 150000.00, 13.00, TO_DATE('2026-10-18', 'YYYY-MM-DD'), 'Pending');

-- M3 UPDATE: Mark FD 201 status (already matured) to 'Matured' with correct status
UPDATE FIXED_DEPOSIT
SET    Status = 'Matured'
WHERE  FD_ID = 201 AND Maturity_Date < SYSDATE;

-- M3 DELETE: Remove loan payment made in error (test environment)
DELETE FROM LOAN_PAYMENT
WHERE  Payment_ID = 410;

ROLLBACK TO SAVEPOINT sp_m3_dml;

-- ----------------------------------------------------------------------------
-- M3 SELECT QUERIES
-- ----------------------------------------------------------------------------

-- [M3-Q1] Simple retrieval: All active loans ordered by outstanding
--         principal descending (for loan officer review dashboard)
SELECT
    l.Loan_ID,
    l.Customer_ID,
    l.Loan_Type,
    TO_CHAR(l.Principal_Amount, 'FM99,99,99,999.00') AS Principal,
    l.Interest_Rate || '%'                            AS Rate,
    TO_CHAR(l.Start_Date, 'DD-Mon-YYYY')             AS Start_Date,
    l.Status
FROM   LOAN l
WHERE  l.Status IN ('Active', 'Pending')
ORDER BY l.Principal_Amount DESC;

-- [M3-Q2] Multi-table JOIN: Loan repayment history with customer name
--         and running total paid
SELECT
    lp.Payment_ID,
    l.Loan_ID,
    c.First_Name || ' ' || c.Last_Name           AS Customer_Name,
    l.Loan_Type,
    TO_CHAR(l.Principal_Amount, 'FM99,99,99,999.00') AS Loan_Principal,
    TO_CHAR(lp.Payment_Date, 'DD-Mon-YYYY')       AS Payment_Date,
    TO_CHAR(lp.Amount, 'FM99,99,999.00')          AS EMI_Paid,
    lp.Payment_Mode,
    l.Status                                      AS Loan_Status
FROM   LOAN_PAYMENT lp
JOIN   LOAN     l ON lp.Loan_ID      = l.Loan_ID
JOIN   CUSTOMER c ON l.Customer_ID   = c.Customer_ID
ORDER BY l.Loan_ID, lp.Payment_Date;

-- [M3-Q3] Group Aggregation: Loan summary statistics by Loan_Type
SELECT
    l.Loan_Type,
    COUNT(*)                                           AS Total_Loans,
    SUM(CASE WHEN l.Status = 'Active'    THEN 1 ELSE 0 END) AS Active_Count,
    SUM(CASE WHEN l.Status = 'Closed'    THEN 1 ELSE 0 END) AS Closed_Count,
    TO_CHAR(SUM(l.Principal_Amount),  'FM99,99,99,99,999.00') AS Total_Disbursed,
    TO_CHAR(ROUND(AVG(l.Principal_Amount), 2), 'FM99,99,99,999.00') AS Avg_Loan_Size,
    ROUND(AVG(l.Interest_Rate), 2) || '%'              AS Avg_Rate
FROM   LOAN l
GROUP BY l.Loan_Type
ORDER BY SUM(l.Principal_Amount) DESC;

-- [M3-Q4] Nested/Correlated Subquery: Fixed Deposits whose maturity value
--         (via function) exceeds double the average principal in FIXED_DEPOSIT
SELECT
    fd.FD_ID,
    c.Customer_ID,
    c.First_Name || ' ' || c.Last_Name           AS Customer_Name,
    TO_CHAR(fd.Principal_Amount, 'FM99,99,99,999.00') AS Principal,
    fd.Interest_Rate || '%'                       AS Rate,
    TO_CHAR(fd.Start_Date,    'DD-Mon-YYYY')      AS Start_Date,
    TO_CHAR(fd.Maturity_Date, 'DD-Mon-YYYY')      AS Maturity_Date,
    TO_CHAR(fn_calc_fd_maturity_value(fd.FD_ID),  'FM99,99,99,999.00') AS Maturity_Value,
    fd.Status
FROM   FIXED_DEPOSIT fd
JOIN   CUSTOMER c ON fd.Customer_ID = c.Customer_ID
WHERE  fn_calc_fd_maturity_value(fd.FD_ID) > (
    SELECT 2 * AVG(Principal_Amount) FROM FIXED_DEPOSIT
)
ORDER BY fn_calc_fd_maturity_value(fd.FD_ID) DESC;

-- [M3-Q5] Built-in Oracle Functions: FD profitability report with compound
--         interest gain, tenure in years, and customer age profile
SELECT
    fd.FD_ID,
    UPPER(c.First_Name || ' ' || c.Last_Name)        AS Customer_Name,
    fn_get_customer_age(c.Customer_ID)               AS Customer_Age,
    fd.Loan_Type_Equiv,
    TO_CHAR(fd.Principal_Amount, 'FM99,99,99,999.00') AS Principal,
    fd.Interest_Rate || '% p.a.'                     AS Interest_Rate,
    ROUND(MONTHS_BETWEEN(fd.Maturity_Date, fd.Start_Date) / 12, 1)
                                                      AS Tenure_Years,
    TO_CHAR(fn_calc_fd_maturity_value(fd.FD_ID), 'FM99,99,99,999.00')
                                                      AS Maturity_Value,
    TO_CHAR(fn_calc_fd_maturity_value(fd.FD_ID) - fd.Principal_Amount, 'FM99,99,99,999.00')
                                                      AS Interest_Earned,
    NVL(fd.Status, 'Unknown')                        AS FD_Status,
    CASE
        WHEN fd.Status = 'Matured'             THEN 'Renew or Withdraw'
        WHEN fd.Status = 'Prematurely Closed'  THEN 'Premature Penalty Applied'
        ELSE 'Accruing Interest'
    END                                              AS Recommendation
FROM (
    SELECT
        FD_ID, Customer_ID, Principal_Amount, Interest_Rate,
        Start_Date, Maturity_Date, Status,
        'Fixed Deposit' AS Loan_Type_Equiv
    FROM FIXED_DEPOSIT
) fd
JOIN CUSTOMER c ON fd.Customer_ID = c.Customer_ID
ORDER BY fn_calc_fd_maturity_value(fd.FD_ID) DESC;


-- ============================================================================
-- MODULE 4: BRANCHES, EMPLOYEES & CUSTOMER COMPLAINTS
-- Tables: BRANCH, EMPLOYEE, COMPLAINT
-- Team Member: Module 4
-- ============================================================================

-- ----------------------------------------------------------------------------
-- M4 DML: INSERT, UPDATE, DELETE wrapped in SAVEPOINT
-- ----------------------------------------------------------------------------
SAVEPOINT sp_m4_dml;

-- M4 INSERT: Open a new branch in Ahmedabad
INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (111, 'Ahmedabad SG Highway Branch', 'NOLA0000111', 'Unit 201, One Horizon Center, SG Highway, Ahmedabad, Gujarat 380054');

-- M4 UPDATE: Give Branch Manager a 10% salary raise
UPDATE EMPLOYEE
SET    Salary = ROUND(Salary * 1.10, 2)
WHERE  Designation = 'Branch Manager';

-- M4 DELETE: Remove a resolved complaint older than 90 days
DELETE FROM COMPLAINT
WHERE  Status = 'Resolved'
  AND  Resolution_Date < (SYSDATE - 90);

ROLLBACK TO SAVEPOINT sp_m4_dml;

-- ----------------------------------------------------------------------------
-- M4 SELECT QUERIES
-- ----------------------------------------------------------------------------

-- [M4-Q1] Simple retrieval: All branches with their city extracted from Address,
--         ordered by Branch_ID
SELECT
    Branch_ID,
    Branch_Name,
    IFSC_Code,
    Address
FROM   BRANCH
ORDER BY Branch_ID;

-- [M4-Q2] Multi-table JOIN: Employees with their branch details and
--         designation, showing branch city context
SELECT
    e.Employee_ID,
    e.Employee_Name,
    e.Designation,
    TO_CHAR(e.Salary, 'FM99,99,99,999.00')  AS Salary,
    e.Phone,
    b.Branch_Name,
    b.IFSC_Code
FROM   EMPLOYEE e
JOIN   BRANCH b ON e.Branch_ID = b.Branch_ID
ORDER BY e.Designation, e.Salary DESC;

-- [M4-Q3] Group Aggregation: Complaint resolution statistics by Status,
--         with average days to resolve (for resolved complaints)
SELECT
    c.Status,
    COUNT(*)                                          AS Total_Complaints,
    ROUND(AVG(
        CASE WHEN c.Status = 'Resolved' AND c.Resolution_Date IS NOT NULL
             THEN c.Resolution_Date - c.Complaint_Date
             ELSE NULL
        END
    ), 1)                                             AS Avg_Resolution_Days,
    MIN(c.Complaint_Date)                             AS Oldest_Complaint,
    MAX(c.Complaint_Date)                             AS Latest_Complaint
FROM   COMPLAINT c
GROUP BY c.Status
ORDER BY
    CASE c.Status
        WHEN 'Open'        THEN 1
        WHEN 'In Progress' THEN 2
        WHEN 'Resolved'    THEN 3
        ELSE 4
    END;

-- [M4-Q4] Nested Subquery: Branches that have AT LEAST ONE complaint from
--         a customer linked to an account in that branch (branch-level risk)
SELECT DISTINCT
    b.Branch_ID,
    b.Branch_Name,
    b.IFSC_Code,
    (SELECT COUNT(*) FROM ACCOUNT a WHERE a.Branch_ID = b.Branch_ID)    AS Total_Accounts,
    (SELECT COUNT(*) FROM EMPLOYEE e WHERE e.Branch_ID = b.Branch_ID)   AS Staff_Count
FROM   BRANCH b
WHERE  EXISTS (
    SELECT 1
    FROM   COMPLAINT cmp
    JOIN   CUSTOMER_ACCOUNT ca ON cmp.Customer_ID = ca.Customer_ID
    JOIN   ACCOUNT a           ON ca.Account_No   = a.Account_No
    WHERE  a.Branch_ID = b.Branch_ID
)
ORDER BY b.Branch_ID;

-- [M4-Q5] Built-in Oracle Functions: Employee payroll dashboard using
--         NVL, ROUND, TO_CHAR, MONTHS_BETWEEN (tenure proxy), UPPER, CASE
SELECT
    e.Employee_ID,
    UPPER(e.Employee_Name)                            AS Employee_Name_UPPER,
    e.Designation,
    TO_CHAR(e.Salary, 'FM\u20B999,99,99,999.00')      AS Monthly_Salary,
    TO_CHAR(ROUND(e.Salary * 12, 2), 'FM\u20B999,99,99,999.00')
                                                      AS Annual_CTC,
    NVL(b.Branch_Name, 'Unassigned')                  AS Branch,
    b.IFSC_Code,
    CASE
        WHEN e.Designation = 'Branch Manager'        THEN 'L5 - Senior Leadership'
        WHEN e.Designation IN ('Senior Auditor',
                               'Loan Officer')       THEN 'L4 - Middle Management'
        WHEN e.Designation = 'Relationship Manager'  THEN 'L3 - Front Office'
        WHEN e.Designation = 'Clerk'                 THEN 'L2 - Operations'
        ELSE 'L1 - Support'
    END                                               AS Pay_Grade,
    CASE
        WHEN e.Salary > 100000 THEN 'High'
        WHEN e.Salary > 70000  THEN 'Mid'
        ELSE 'Entry'
    END                                               AS Salary_Band,
    -- Complaint load: number of open complaints in this branch
    (SELECT COUNT(*) FROM COMPLAINT cmp
     JOIN   CUSTOMER_ACCOUNT ca ON cmp.Customer_ID = ca.Customer_ID
     JOIN   ACCOUNT a           ON ca.Account_No   = a.Account_No
     WHERE  a.Branch_ID = e.Branch_ID AND cmp.Status = 'Open'
    )                                                 AS Open_Complaints_In_Branch
FROM   EMPLOYEE e
JOIN   BRANCH b ON e.Branch_ID = b.Branch_ID
ORDER BY e.Salary DESC, e.Designation;
