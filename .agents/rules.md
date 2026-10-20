# Project Rules: Advanced Bank Management System (BACSE202)

## 1. Database Engine & Syntax Rules
- Target Database: Oracle Database (Oracle XE / SQL*Plus / SQL Developer compatible).
- Forbidden Syntax: NEVER use MySQL/PostgreSQL syntax (`AUTO_INCREMENT`, `LIMIT`, `DATETIME`, `BOOLEAN` in SQL DDL, or `IF EXISTS` in DROP statements).
- Required Oracle Syntax: Use `VARCHAR2(n)`, `NUMBER(p,s)`, `DATE`, `SYSDATE`, `TO_DATE('YYYY-MM-DD', 'YYYY-MM-DD')`, and `FETCH FIRST n ROWS ONLY` or `ROWNUM`.
- Every PL/SQL block (`CREATE OR REPLACE PROCEDURE/FUNCTION/TRIGGER` or `DECLARE...BEGIN...END;`) in `.sql` files MUST be terminated with a forward slash `/` on a new line.

## 2. Exact 14-Table Relational Schema
Strictly use these 14 table names and column names across all SQL scripts and Python backend queries:
1. BRANCH (Branch_ID PK, Branch_Name, IFSC_Code, Address)
2. CUSTOMER (Customer_ID PK, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
   - Note: `Age` is a derived attribute calculated dynamically from `Date_of_Birth` via PL/SQL function `fn_get_customer_age` and is NOT stored as a column.
3. CUSTOMER_PHONE (Customer_ID FK, Phone_Number, PK(Customer_ID, Phone_Number))
4. ACCOUNT (Account_No PK, Account_Type, Balance, Open_Date, Status, Branch_ID FK)
5. CUSTOMER_ACCOUNT (Customer_ID FK, Account_No FK, PK(Customer_ID, Account_No))
6. TRANSACTION (Transaction_ID PK, Account_No FK, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
7. EMPLOYEE (Employee_ID PK, Employee_Name, Designation, Salary, Phone, Branch_ID FK)
8. LOAN (Loan_ID PK, Customer_ID FK, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
9. LOAN_PAYMENT (Payment_ID PK, Loan_ID FK, Payment_Date, Amount, Payment_Mode)
10. CARD (Card_ID PK, Account_No FK, Card_Type, Issue_Date, Expiry_Date, Status)
11. BENEFICIARY (Beneficiary_ID PK, Customer_ID FK, Beneficiary_Name, Account_No, IFSC_Code)
12. FUND_TRANSFER (Transfer_ID PK, Account_No FK, Beneficiary_ID FK, Amount, Transfer_Date, Transfer_Mode, Status)
13. FIXED_DEPOSIT (FD_ID PK, Customer_ID FK, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
14. COMPLAINT (Complaint_ID PK, Customer_ID FK, Description, Complaint_Date, Status, Resolution_Date)

## 3. Application Flow & Module Division
- Every database action executed from the Python Flask backend must return a trace dictionary showing:
  `User Operation -> SQL/PL/SQL Component -> Tables Involved -> Database Update/Retrieval -> Result`.
- Divide operations into 4 Team Member Modules (each module has 1 INSERT, 1 UPDATE, 1 DELETE, and 5 SELECT queries):
  * Module 1: Core Banking (Customer, Customer_Phone, Account, Customer_Account, Transaction)
  * Module 2: Cards, Beneficiaries & Fund Transfers (Card, Beneficiary, Fund_Transfer)
  * Module 3: Loans & Fixed Deposits (Loan, Loan_Payment, Fixed_Deposit)
  * Module 4: Branches, Employees & Customer Complaints (Branch, Employee, Complaint)
