-- ============================================================================
-- Script: 01_schema_ddl.sql
-- Project: Advanced Bank Management System (BACSE202)
-- Database Engine: Oracle Database (Oracle XE / SQL*Plus / SQL Developer)
-- Description: DDL script creating all 14 relational tables with explicit
--              named constraints and clean drop routine.
-- ============================================================================

SET SERVEROUTPUT ON;

-- ============================================================================
-- SECTION 1: Safe Drop of Existing Tables in Reverse Dependency Order
-- ============================================================================
DECLARE
    TYPE t_table_array IS TABLE OF VARCHAR2(30);
    v_tables t_table_array := t_table_array(
        'COMPLAINT',
        'FIXED_DEPOSIT',
        'FUND_TRANSFER',
        'BENEFICIARY',
        'CARD',
        'LOAN_PAYMENT',
        'LOAN',
        'TRANSACTION',
        'CUSTOMER_ACCOUNT',
        'CUSTOMER_PHONE',
        'EMPLOYEE',
        'ACCOUNT',
        'CUSTOMER',
        'BRANCH'
    );
BEGIN
    FOR i IN 1..v_tables.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || v_tables(i) || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Cleaned up existing table: ' || v_tables(i));
        EXCEPTION
            WHEN OTHERS THEN
                -- Ignore ORA-00942: table or view does not exist
                IF SQLCODE != -942 THEN
                    RAISE;
                END IF;
        END;
    END LOOP;
END;
/

-- ============================================================================
-- SECTION 2: Create 14 Tables in Parent-to-Child Order
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BRANCH
-- ----------------------------------------------------------------------------
CREATE TABLE BRANCH (
    Branch_ID   NUMBER(10),
    Branch_Name VARCHAR2(100) NOT NULL,
    IFSC_Code   VARCHAR2(20)  NOT NULL,
    Address     VARCHAR2(250) NOT NULL,
    CONSTRAINT pk_branch PRIMARY KEY (Branch_ID),
    CONSTRAINT uq_branch_ifsc UNIQUE (IFSC_Code)
);

-- ----------------------------------------------------------------------------
-- 2. CUSTOMER
-- Note: 'Age' is a derived attribute dynamically computed from Date_of_Birth
-- via PL/SQL function fn_get_customer_age and is NOT stored as a physical column.
-- ----------------------------------------------------------------------------
CREATE TABLE CUSTOMER (
    Customer_ID   NUMBER(10),
    First_Name    VARCHAR2(50)  NOT NULL,
    Middle_Name   VARCHAR2(50),
    Last_Name     VARCHAR2(50)  NOT NULL,
    Date_of_Birth DATE          NOT NULL,
    Email         VARCHAR2(100) NOT NULL,
    House_No      VARCHAR2(30),
    Street        VARCHAR2(100),
    City          VARCHAR2(50)  NOT NULL,
    State         VARCHAR2(50)  NOT NULL,
    PIN           VARCHAR2(10)  NOT NULL,
    CONSTRAINT pk_customer PRIMARY KEY (Customer_ID),
    CONSTRAINT uq_customer_email UNIQUE (Email)
);

-- ----------------------------------------------------------------------------
-- 3. CUSTOMER_PHONE
-- Multi-valued attribute implementation with composite primary key
-- ----------------------------------------------------------------------------
CREATE TABLE CUSTOMER_PHONE (
    Customer_ID  NUMBER(10),
    Phone_Number VARCHAR2(15) NOT NULL,
    CONSTRAINT pk_customer_phone PRIMARY KEY (Customer_ID, Phone_Number),
    CONSTRAINT fk_cp_customer FOREIGN KEY (Customer_ID) 
        REFERENCES CUSTOMER(Customer_ID) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 4. ACCOUNT
-- ----------------------------------------------------------------------------
CREATE TABLE ACCOUNT (
    Account_No   NUMBER(12),
    Account_Type VARCHAR2(30)           NOT NULL,
    Balance      NUMBER(15,2) DEFAULT 0 NOT NULL,
    Open_Date    DATE DEFAULT SYSDATE   NOT NULL,
    Status       VARCHAR2(20) DEFAULT 'Active' NOT NULL,
    Branch_ID    NUMBER(10)             NOT NULL,
    CONSTRAINT pk_account PRIMARY KEY (Account_No),
    CONSTRAINT fk_account_branch FOREIGN KEY (Branch_ID) 
        REFERENCES BRANCH(Branch_ID),
    CONSTRAINT chk_account_type CHECK (Account_Type IN ('Savings', 'Current', 'Salary')),
    CONSTRAINT chk_account_balance CHECK (Balance >= 0),
    CONSTRAINT chk_account_status CHECK (Status IN ('Active', 'Inactive', 'Frozen', 'Closed'))
);

-- ----------------------------------------------------------------------------
-- 5. CUSTOMER_ACCOUNT
-- M:N relationship junction table between CUSTOMER and ACCOUNT
-- ----------------------------------------------------------------------------
CREATE TABLE CUSTOMER_ACCOUNT (
    Customer_ID NUMBER(10),
    Account_No  NUMBER(12),
    CONSTRAINT pk_customer_account PRIMARY KEY (Customer_ID, Account_No),
    CONSTRAINT fk_ca_customer FOREIGN KEY (Customer_ID) 
        REFERENCES CUSTOMER(Customer_ID) ON DELETE CASCADE,
    CONSTRAINT fk_ca_account FOREIGN KEY (Account_No) 
        REFERENCES ACCOUNT(Account_No) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 6. TRANSACTION
-- ----------------------------------------------------------------------------
CREATE TABLE TRANSACTION (
    Transaction_ID   NUMBER(12),
    Account_No       NUMBER(12)             NOT NULL,
    Transaction_Type VARCHAR2(30)           NOT NULL,
    Amount           NUMBER(15,2)           NOT NULL,
    Transaction_Date DATE DEFAULT SYSDATE   NOT NULL,
    Transaction_Time VARCHAR2(15)           NOT NULL,
    Transaction_Mode VARCHAR2(30)           NOT NULL,
    CONSTRAINT pk_transaction PRIMARY KEY (Transaction_ID),
    CONSTRAINT fk_trans_account FOREIGN KEY (Account_No) 
        REFERENCES ACCOUNT(Account_No),
    CONSTRAINT chk_trans_type CHECK (Transaction_Type IN ('Deposit', 'Withdrawal', 'Transfer_Debit', 'Transfer_Credit', 'Loan_EMI', 'FD_Booking')),
    CONSTRAINT chk_trans_amount CHECK (Amount > 0),
    CONSTRAINT chk_trans_mode CHECK (Transaction_Mode IN ('UPI', 'NEFT', 'RTGS', 'IMPS', 'ATM', 'Cash', 'Cheque', 'Auto-Debit'))
);

-- ----------------------------------------------------------------------------
-- 7. EMPLOYEE
-- ----------------------------------------------------------------------------
CREATE TABLE EMPLOYEE (
    Employee_ID   NUMBER(10),
    Employee_Name VARCHAR2(100) NOT NULL,
    Designation   VARCHAR2(60)  NOT NULL,
    Salary        NUMBER(12,2)  NOT NULL,
    Phone         VARCHAR2(15)  NOT NULL,
    Branch_ID     NUMBER(10)    NOT NULL,
    CONSTRAINT pk_employee PRIMARY KEY (Employee_ID),
    CONSTRAINT fk_employee_branch FOREIGN KEY (Branch_ID) 
        REFERENCES BRANCH(Branch_ID),
    CONSTRAINT chk_employee_salary CHECK (Salary > 0),
    CONSTRAINT uq_employee_phone UNIQUE (Phone)
);

-- ----------------------------------------------------------------------------
-- 8. LOAN
-- ----------------------------------------------------------------------------
CREATE TABLE LOAN (
    Loan_ID          NUMBER(10),
    Customer_ID      NUMBER(10)             NOT NULL,
    Loan_Type        VARCHAR2(40)           NOT NULL,
    Principal_Amount NUMBER(15,2)           NOT NULL,
    Interest_Rate    NUMBER(5,2)            NOT NULL,
    Start_Date       DATE DEFAULT SYSDATE   NOT NULL,
    Status           VARCHAR2(20) DEFAULT 'Active' NOT NULL,
    CONSTRAINT pk_loan PRIMARY KEY (Loan_ID),
    CONSTRAINT fk_loan_customer FOREIGN KEY (Customer_ID) 
        REFERENCES CUSTOMER(Customer_ID),
    CONSTRAINT chk_loan_type CHECK (Loan_Type IN ('Home Loan', 'Education Loan', 'Vehicle Loan', 'Personal Loan', 'Business Loan')),
    CONSTRAINT chk_loan_principal CHECK (Principal_Amount > 0),
    CONSTRAINT chk_loan_interest CHECK (Interest_Rate > 0),
    CONSTRAINT chk_loan_status CHECK (Status IN ('Active', 'Closed', 'Pending', 'Defaulted'))
);

-- ----------------------------------------------------------------------------
-- 9. LOAN_PAYMENT
-- ----------------------------------------------------------------------------
CREATE TABLE LOAN_PAYMENT (
    Payment_ID   NUMBER(12),
    Loan_ID      NUMBER(10)           NOT NULL,
    Payment_Date DATE DEFAULT SYSDATE NOT NULL,
    Amount       NUMBER(15,2)         NOT NULL,
    Payment_Mode VARCHAR2(30)         NOT NULL,
    CONSTRAINT pk_loan_payment PRIMARY KEY (Payment_ID),
    CONSTRAINT fk_lp_loan FOREIGN KEY (Loan_ID) 
        REFERENCES LOAN(Loan_ID),
    CONSTRAINT chk_lp_amount CHECK (Amount > 0),
    CONSTRAINT chk_lp_mode CHECK (Payment_Mode IN ('UPI', 'NEFT', 'Auto-Debit', 'Cash', 'Cheque'))
);

-- ----------------------------------------------------------------------------
-- 10. CARD
-- ----------------------------------------------------------------------------
CREATE TABLE CARD (
    Card_ID     NUMBER(12),
    Account_No  NUMBER(12)             NOT NULL,
    Card_Type   VARCHAR2(20)           NOT NULL,
    Issue_Date  DATE DEFAULT SYSDATE   NOT NULL,
    Expiry_Date DATE                   NOT NULL,
    Status      VARCHAR2(20) DEFAULT 'Active' NOT NULL,
    CONSTRAINT pk_card PRIMARY KEY (Card_ID),
    CONSTRAINT fk_card_account FOREIGN KEY (Account_No) 
        REFERENCES ACCOUNT(Account_No),
    CONSTRAINT chk_card_type CHECK (Card_Type IN ('Debit', 'Credit', 'Platinum Debit', 'Forex')),
    CONSTRAINT chk_card_status CHECK (Status IN ('Active', 'Blocked', 'Expired'))
);

-- ----------------------------------------------------------------------------
-- 11. BENEFICIARY
-- ----------------------------------------------------------------------------
CREATE TABLE BENEFICIARY (
    Beneficiary_ID   NUMBER(10),
    Customer_ID      NUMBER(10)    NOT NULL,
    Beneficiary_Name VARCHAR2(100) NOT NULL,
    Account_No       NUMBER(12)    NOT NULL,
    IFSC_Code        VARCHAR2(20)  NOT NULL,
    CONSTRAINT pk_beneficiary PRIMARY KEY (Beneficiary_ID),
    CONSTRAINT fk_beneficiary_customer FOREIGN KEY (Customer_ID) 
        REFERENCES CUSTOMER(Customer_ID)
);

-- ----------------------------------------------------------------------------
-- 12. FUND_TRANSFER
-- ----------------------------------------------------------------------------
CREATE TABLE FUND_TRANSFER (
    Transfer_ID    NUMBER(12),
    Account_No     NUMBER(12)               NOT NULL,
    Beneficiary_ID NUMBER(10)               NOT NULL,
    Amount         NUMBER(15,2)             NOT NULL,
    Transfer_Date  DATE DEFAULT SYSDATE     NOT NULL,
    Transfer_Mode  VARCHAR2(20)             NOT NULL,
    Status         VARCHAR2(20) DEFAULT 'Completed' NOT NULL,
    CONSTRAINT pk_fund_transfer PRIMARY KEY (Transfer_ID),
    CONSTRAINT fk_ft_account FOREIGN KEY (Account_No) 
        REFERENCES ACCOUNT(Account_No),
    CONSTRAINT fk_ft_beneficiary FOREIGN KEY (Beneficiary_ID) 
        REFERENCES BENEFICIARY(Beneficiary_ID),
    CONSTRAINT chk_ft_amount CHECK (Amount > 0),
    CONSTRAINT chk_ft_mode CHECK (Transfer_Mode IN ('UPI', 'NEFT', 'RTGS', 'IMPS')),
    CONSTRAINT chk_ft_status CHECK (Status IN ('Completed', 'Pending', 'Failed'))
);

-- ----------------------------------------------------------------------------
-- 13. FIXED_DEPOSIT
-- ----------------------------------------------------------------------------
CREATE TABLE FIXED_DEPOSIT (
    FD_ID            NUMBER(10),
    Customer_ID      NUMBER(10)             NOT NULL,
    Principal_Amount NUMBER(15,2)           NOT NULL,
    Interest_Rate    NUMBER(5,2)            NOT NULL,
    Start_Date       DATE DEFAULT SYSDATE   NOT NULL,
    Maturity_Date    DATE                   NOT NULL,
    Status           VARCHAR2(20) DEFAULT 'Active' NOT NULL,
    CONSTRAINT pk_fixed_deposit PRIMARY KEY (FD_ID),
    CONSTRAINT fk_fd_customer FOREIGN KEY (Customer_ID) 
        REFERENCES CUSTOMER(Customer_ID),
    CONSTRAINT chk_fd_principal CHECK (Principal_Amount >= 5000),
    CONSTRAINT chk_fd_interest CHECK (Interest_Rate > 0),
    CONSTRAINT chk_fd_status CHECK (Status IN ('Active', 'Matured', 'Prematurely Closed'))
);

-- ----------------------------------------------------------------------------
-- 14. COMPLAINT
-- ----------------------------------------------------------------------------
CREATE TABLE COMPLAINT (
    Complaint_ID    NUMBER(10),
    Customer_ID     NUMBER(10)             NOT NULL,
    Description     VARCHAR2(500)          NOT NULL,
    Complaint_Date  DATE DEFAULT SYSDATE   NOT NULL,
    Status          VARCHAR2(20) DEFAULT 'Open' NOT NULL,
    Resolution_Date DATE,
    CONSTRAINT pk_complaint PRIMARY KEY (Complaint_ID),
    CONSTRAINT fk_complaint_customer FOREIGN KEY (Customer_ID) 
        REFERENCES CUSTOMER(Customer_ID),
    CONSTRAINT chk_complaint_status CHECK (Status IN ('Open', 'In Progress', 'Resolved'))
);
