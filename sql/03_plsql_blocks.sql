-- ============================================================================
-- Script: 03_plsql_blocks.sql
-- Project: Advanced Bank Management System (BACSE202)
-- Database Engine: Oracle Database (Oracle XE / SQL*Plus / SQL Developer)
-- Description: All PL/SQL objects - 2 Triggers, 2 Functions, 2 Procedures,
--              and 1 Cursor Procedure with anonymous execution block.
-- Run as: @sql/03_plsql_blocks.sql  (from SQL*Plus connected to schema)
-- ============================================================================

SET SERVEROUTPUT ON;

-- ============================================================================
-- TRIGGER 1: trg_prevent_min_balance_breach
-- Purpose: Enforce minimum balance of Rs. 1,000 for Savings Accounts.
--          Fires BEFORE any UPDATE on the Balance column of ACCOUNT.
-- ============================================================================
CREATE OR REPLACE TRIGGER trg_prevent_min_balance_breach
    BEFORE UPDATE OF Balance ON ACCOUNT
    FOR EACH ROW
BEGIN
    IF :NEW.Account_Type = 'Savings' AND :NEW.Balance < 1000 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Minimum balance of Rs. 1,000 must be maintained for Savings Accounts.'
        );
    END IF;
END;
/

-- ============================================================================
-- TRIGGER 2: trg_auto_complaint_resolution
-- Purpose: Automatically set or clear Resolution_Date when complaint Status
--          is changed to or from 'Resolved'.
--          Fires BEFORE any UPDATE on the Status column of COMPLAINT.
-- ============================================================================
CREATE OR REPLACE TRIGGER trg_auto_complaint_resolution
    BEFORE UPDATE OF Status ON COMPLAINT
    FOR EACH ROW
BEGIN
    IF :NEW.Status = 'Resolved' AND (:OLD.Status != 'Resolved' OR :OLD.Resolution_Date IS NULL) THEN
        -- Auto-stamp the resolution date when marked Resolved
        :NEW.Resolution_Date := SYSDATE;
    ELSIF :NEW.Status != 'Resolved' THEN
        -- Clear the resolution date if status is reverted away from Resolved
        :NEW.Resolution_Date := NULL;
    END IF;
END;
/

-- ============================================================================
-- FUNCTION 1: fn_get_customer_age
-- Purpose: Derived attribute - Returns the current age in whole years
--          for a given Customer_ID. Returns 0 if customer not found.
--          Called from Python backend and SQL queries instead of storing Age.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_customer_age(p_customer_id IN NUMBER)
    RETURN NUMBER
IS
    v_dob    CUSTOMER.Date_of_Birth%TYPE;
    v_age    NUMBER := 0;
BEGIN
    SELECT Date_of_Birth
    INTO   v_dob
    FROM   CUSTOMER
    WHERE  Customer_ID = p_customer_id;

    v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, v_dob) / 12);
    RETURN v_age;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END fn_get_customer_age;
/

-- ============================================================================
-- FUNCTION 2: fn_calc_fd_maturity_value
-- Purpose: Calculates compound interest maturity value for a Fixed Deposit.
--          Formula: Principal * (1 + Rate/100) ^ (Months/12)
--          Returns ROUND(..., 2) value. Returns 0 if FD not found.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_calc_fd_maturity_value(p_fd_id IN NUMBER)
    RETURN NUMBER
IS
    v_principal  FIXED_DEPOSIT.Principal_Amount%TYPE;
    v_rate       FIXED_DEPOSIT.Interest_Rate%TYPE;
    v_start      FIXED_DEPOSIT.Start_Date%TYPE;
    v_maturity   FIXED_DEPOSIT.Maturity_Date%TYPE;
    v_result     NUMBER := 0;
    v_years      NUMBER;
BEGIN
    SELECT Principal_Amount, Interest_Rate, Start_Date, Maturity_Date
    INTO   v_principal, v_rate, v_start, v_maturity
    FROM   FIXED_DEPOSIT
    WHERE  FD_ID = p_fd_id;

    v_years  := MONTHS_BETWEEN(v_maturity, v_start) / 12;
    v_result := ROUND(v_principal * POWER(1 + (v_rate / 100), v_years), 2);
    RETURN v_result;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END fn_calc_fd_maturity_value;
/

-- ============================================================================
-- PROCEDURE 1: sp_process_fund_transfer
-- Purpose: End-to-end fund transfer: validates account status and balance,
--          debits ACCOUNT.Balance, inserts into FUND_TRANSFER and TRANSACTION.
--          ORA-20001 (min balance trigger) is surfaced as an ERROR to caller.
-- Parameters:
--   p_acc_no        IN  - Source account number
--   p_beneficiary_id IN - Registered beneficiary ID
--   p_amount        IN  - Transfer amount (must be > 0)
--   p_mode          IN  - Transfer mode ('UPI','NEFT','RTGS','IMPS')
--   p_status_msg    OUT - 'SUCCESS: ...' or 'ERROR: ...' message
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_process_fund_transfer(
    p_acc_no         IN  NUMBER,
    p_beneficiary_id IN  NUMBER,
    p_amount         IN  NUMBER,
    p_mode           IN  VARCHAR2,
    p_status_msg     OUT VARCHAR2
)
IS
    v_acc_status  ACCOUNT.Status%TYPE;
    v_balance     ACCOUNT.Balance%TYPE;
    v_transfer_id FUND_TRANSFER.Transfer_ID%TYPE;
    v_txn_id      TRANSACTION.Transaction_ID%TYPE;
BEGIN
    -- Step 1: Validate account exists, is Active, and has sufficient balance
    SELECT Status, Balance
    INTO   v_acc_status, v_balance
    FROM   ACCOUNT
    WHERE  Account_No = p_acc_no
    FOR UPDATE;  -- Row-level lock to prevent concurrent modification

    IF v_acc_status != 'Active' THEN
        p_status_msg := 'ERROR: Account ' || p_acc_no || ' is not Active (Status: ' || v_acc_status || ').';
        RETURN;
    END IF;

    IF v_balance < p_amount THEN
        p_status_msg := 'ERROR: Insufficient balance. Available: Rs. ' || v_balance || ', Requested: Rs. ' || p_amount || '.';
        RETURN;
    END IF;

    -- Step 2: Generate next Transfer_ID and Transaction_ID
    SELECT NVL(MAX(Transfer_ID), 800) + 1 INTO v_transfer_id FROM FUND_TRANSFER;
    SELECT NVL(MAX(Transaction_ID), 9000) + 1 INTO v_txn_id FROM TRANSACTION;

    -- Step 3: Debit account balance (invokes trg_prevent_min_balance_breach)
    UPDATE ACCOUNT
    SET    Balance = Balance - p_amount
    WHERE  Account_No = p_acc_no;

    -- Step 4: Record in FUND_TRANSFER
    INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
    VALUES (v_transfer_id, p_acc_no, p_beneficiary_id, p_amount, SYSDATE, p_mode, 'Completed');

    -- Step 5: Record debit in TRANSACTION
    INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
    VALUES (v_txn_id, p_acc_no, 'Transfer_Debit', p_amount, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), p_mode);

    COMMIT;
    p_status_msg := 'SUCCESS: Rs. ' || p_amount || ' transferred via ' || p_mode || '. Transfer_ID: ' || v_transfer_id || ', Transaction_ID: ' || v_txn_id || '.';

EXCEPTION
    WHEN OTHERS THEN
        -- Surface ORA-20001 (min balance trigger) and any other error clearly to caller
        ROLLBACK;
        p_status_msg := 'ERROR: ' || SQLERRM;
END sp_process_fund_transfer;
/

-- ============================================================================
-- PROCEDURE 2: sp_pay_loan_emi
-- Purpose: Records an EMI payment for a loan. Auto-closes the loan if the
--          cumulative amount paid >= Principal_Amount.
-- Parameters:
--   p_loan_id    IN  - Loan ID to pay against
--   p_amount     IN  - EMI payment amount
--   p_mode       IN  - Payment mode ('UPI','NEFT','Auto-Debit','Cash','Cheque')
--   p_status_msg OUT - 'SUCCESS: ...' or 'ERROR: ...' message
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_pay_loan_emi(
    p_loan_id    IN  NUMBER,
    p_amount     IN  NUMBER,
    p_mode       IN  VARCHAR2,
    p_status_msg OUT VARCHAR2
)
IS
    v_cust_id       LOAN.Customer_ID%TYPE;
    v_principal     LOAN.Principal_Amount%TYPE;
    v_loan_status   LOAN.Status%TYPE;
    v_acc_no        ACCOUNT.Account_No%TYPE;
    v_balance       ACCOUNT.Balance%TYPE;
    v_payment_id    LOAN_PAYMENT.Payment_ID%TYPE;
    v_txn_id        TRANSACTION.Transaction_ID%TYPE;
    v_total_paid    NUMBER := 0;
BEGIN
    -- Step 1: Fetch loan details and lock
    SELECT Customer_ID, Principal_Amount, Status
    INTO   v_cust_id, v_principal, v_loan_status
    FROM   LOAN
    WHERE  Loan_ID = p_loan_id
    FOR UPDATE;

    IF v_loan_status = 'Closed' THEN
        p_status_msg := 'ERROR: Loan ' || p_loan_id || ' is already Closed. No further payments required.';
        RETURN;
    END IF;

    IF v_loan_status = 'Defaulted' THEN
        p_status_msg := 'ERROR: Loan ' || p_loan_id || ' is in Defaulted status. Contact Branch Manager.';
        RETURN;
    END IF;

    -- Step 2: Find active account for customer to debit EMI from
    BEGIN
        SELECT a.Account_No, a.Balance
        INTO   v_acc_no, v_balance
        FROM   CUSTOMER_ACCOUNT ca
        JOIN   ACCOUNT a ON ca.Account_No = a.Account_No
        WHERE  ca.Customer_ID = v_cust_id
          AND  a.Status = 'Active'
          AND  ROWNUM = 1
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_status_msg := 'ERROR: No active bank account found for Customer ' || v_cust_id || ' to debit EMI.';
            RETURN;
    END;

    IF v_balance < p_amount THEN
        p_status_msg := 'ERROR: Insufficient account balance. Available: Rs. ' || v_balance || ', EMI: Rs. ' || p_amount || '.';
        RETURN;
    END IF;

    -- Step 3: Debit customer account (triggers trg_prevent_min_balance_breach)
    UPDATE ACCOUNT
    SET    Balance = Balance - p_amount
    WHERE  Account_No = v_acc_no;

    -- Step 4: Generate next Payment_ID and Transaction_ID
    SELECT NVL(MAX(Payment_ID), 400) + 1 INTO v_payment_id FROM LOAN_PAYMENT;
    SELECT NVL(MAX(Transaction_ID), 9000) + 1 INTO v_txn_id FROM TRANSACTION;

    -- Step 5: Insert EMI payment record into LOAN_PAYMENT
    INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
    VALUES (v_payment_id, p_loan_id, SYSDATE, p_amount, p_mode);

    -- Step 6: Record debit in TRANSACTION table
    INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
    VALUES (v_txn_id, v_acc_no, 'Loan_EMI', p_amount, SYSDATE, TO_CHAR(SYSDATE, 'HH24:MI:SS'), p_mode);

    -- Step 7: Calculate cumulative total paid
    SELECT NVL(SUM(Amount), 0)
    INTO   v_total_paid
    FROM   LOAN_PAYMENT
    WHERE  Loan_ID = p_loan_id;

    -- Step 8: Auto-close loan if fully repaid
    IF v_total_paid >= v_principal THEN
        UPDATE LOAN
        SET    Status = 'Closed'
        WHERE  Loan_ID = p_loan_id;

        COMMIT;
        p_status_msg := 'SUCCESS: EMI of Rs. ' || p_amount || ' debited from Account ' || v_acc_no ||
                        ' (Payment_ID: ' || v_payment_id || ', Txn_ID: ' || v_txn_id || '). Loan ' || p_loan_id ||
                        ' is now CLOSED. Total repaid: Rs. ' || v_total_paid || '.';
    ELSE
        COMMIT;
        p_status_msg := 'SUCCESS: EMI of Rs. ' || p_amount || ' debited from Account ' || v_acc_no ||
                        ' (Payment_ID: ' || v_payment_id || ', Txn_ID: ' || v_txn_id || '). Outstanding: Rs. ' ||
                        ROUND(v_principal - v_total_paid, 2) || '.';
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_status_msg := 'ERROR: Loan ID ' || p_loan_id || ' not found.';
    WHEN OTHERS THEN
        ROLLBACK;
        p_status_msg := 'ERROR: ' || SQLERRM;
END sp_pay_loan_emi;
/

-- ============================================================================
-- PROCEDURE 3: sp_branch_audit_cursor
-- Purpose: Uses an explicit cursor to iterate over all branches and print
--          a formatted audit report showing total accounts, total deposit
--          balance, and total employees per branch via DBMS_OUTPUT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_branch_audit_cursor
IS
    -- Explicit cursor joining BRANCH with ACCOUNT and EMPLOYEE aggregates
    CURSOR cur_branch_performance IS
        SELECT
            b.Branch_ID,
            b.Branch_Name,
            b.IFSC_Code,
            COUNT(DISTINCT a.Account_No)                     AS Total_Accounts,
            NVL(SUM(a.Balance), 0)                           AS Total_Balance,
            COUNT(DISTINCT e.Employee_ID)                    AS Total_Employees
        FROM   BRANCH b
        LEFT JOIN ACCOUNT  a ON a.Branch_ID = b.Branch_ID
        LEFT JOIN EMPLOYEE e ON e.Branch_ID = b.Branch_ID
        GROUP BY b.Branch_ID, b.Branch_Name, b.IFSC_Code
        ORDER BY b.Branch_ID;

    v_rec cur_branch_performance%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('        NOVA BANK - BRANCH PERFORMANCE AUDIT REPORT         ');
    DBMS_OUTPUT.PUT_LINE('        Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(RPAD('Branch ID', 12) || RPAD('IFSC Code', 14) ||
                         RPAD('Accounts', 10)  || RPAD('Total Balance (Rs.)', 22) ||
                         RPAD('Employees', 10) || 'Branch Name');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 90, '-'));

    OPEN cur_branch_performance;
    LOOP
        FETCH cur_branch_performance INTO v_rec;
        EXIT WHEN cur_branch_performance%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_rec.Branch_ID, 12)                      ||
            RPAD(v_rec.IFSC_Code, 14)                      ||
            RPAD(v_rec.Total_Accounts, 10)                 ||
            RPAD(TO_CHAR(v_rec.Total_Balance, 'FM99,99,99,999.00'), 22) ||
            RPAD(v_rec.Total_Employees, 10)                ||
            v_rec.Branch_Name
        );
    END LOOP;
    CLOSE cur_branch_performance;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 90, '-'));
    DBMS_OUTPUT.PUT_LINE('Audit complete. Rows processed: ' || cur_branch_performance%ROWCOUNT);
    DBMS_OUTPUT.PUT_LINE('============================================================');
END sp_branch_audit_cursor;
/

-- ============================================================================
-- ANONYMOUS BLOCK: Execute Branch Audit (SQL*Plus direct run)
-- Calls sp_branch_audit_cursor and prints its output to console.
-- ============================================================================
BEGIN
    sp_branch_audit_cursor;
END;
/

-- ============================================================================
-- VERIFICATION: Quick test of both functions with sample data
-- ============================================================================
DECLARE
    v_age        NUMBER;
    v_maturity   NUMBER;
    v_msg        VARCHAR2(500);
BEGIN
    -- Test fn_get_customer_age
    v_age := fn_get_customer_age(1001);
    DBMS_OUTPUT.PUT_LINE('Customer 1001 (Aarav Kumar Sharma) Age: ' || v_age || ' years');

    v_age := fn_get_customer_age(1008);
    DBMS_OUTPUT.PUT_LINE('Customer 1008 (Sneha Pradeep Kulkarni) Age: ' || v_age || ' years');

    -- Test fn_calc_fd_maturity_value
    v_maturity := fn_calc_fd_maturity_value(203);
    DBMS_OUTPUT.PUT_LINE('FD 203 Maturity Value: Rs. ' || TO_CHAR(v_maturity, 'FM99,99,99,999.00'));

    v_maturity := fn_calc_fd_maturity_value(205);
    DBMS_OUTPUT.PUT_LINE('FD 205 Maturity Value: Rs. ' || TO_CHAR(v_maturity, 'FM99,99,99,999.00'));

    -- Test sp_pay_loan_emi (small payment; should not close loan)
    sp_pay_loan_emi(302, 5000.00, 'UPI', v_msg);
    DBMS_OUTPUT.PUT_LINE('Loan EMI Test: ' || v_msg);
END;
/
