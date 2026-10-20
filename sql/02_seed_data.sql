-- ============================================================================
-- Script: 02_seed_data.sql
-- Project: Advanced Bank Management System (BACSE202)
-- Database Engine: Oracle Database (Oracle XE / SQL*Plus / SQL Developer)
-- Description: Realistic Indian banking seed data for all 14 tables (149 INSERTs)
--              Strictly honoring schema check constraints, foreign keys,
--              and Oracle date formats.
-- ============================================================================

-- ============================================================================
-- 1. BRANCH (10 Records: IDs 101 to 110)
-- ============================================================================
INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (101, 'Vellore Main Branch', 'NOLA0000101', '45 Katpadi Main Road, Near Gandhi Nagar, Vellore, Tamil Nadu 632006');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (102, 'VIT Campus Branch', 'NOLA0000102', 'VIT Technology Tower Ground Floor, Tiruvalam Road, Vellore, Tamil Nadu 632014');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (103, 'Chennai Anna Nagar Branch', 'NOLA0000103', '12 Second Avenue, Roundtana, Anna Nagar, Chennai, Tamil Nadu 600040');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (104, 'Bengaluru Koramangala Branch', 'NOLA0000104', '88 80 Feet Road, 4th Block, Koramangala, Bengaluru, Karnataka 560034');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (105, 'Hyderabad HITEC City Branch', 'NOLA0000105', 'Cyber Towers Concourse, Madhapur, HITEC City, Hyderabad, Telangana 500081');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (106, 'Mumbai BKC Branch', 'NOLA0000106', 'Tower 3, G Block, Bandra Kurla Complex, Bandra East, Mumbai, Maharashtra 400051');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (107, 'Delhi Connaught Place Branch', 'NOLA0000107', '21 Regal Building, Outer Circle, Connaught Place, New Delhi, Delhi 110001');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (108, 'Pune Shivajinagar Branch', 'NOLA0000108', '1105 Fergusson College Road, Shivajinagar, Pune, Maharashtra 411005');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (109, 'Kochi Marine Drive Branch', 'NOLA0000109', 'Shanmugham Road, Marine Drive Promenade, Kochi, Kerala 682031');

INSERT INTO BRANCH (Branch_ID, Branch_Name, IFSC_Code, Address)
VALUES (110, 'Kolkata Park Street Branch', 'NOLA0000110', '54 Mother Teresa Sarani, Park Street, Kolkata, West Bengal 700016');


-- ============================================================================
-- 2. CUSTOMER (10 Records: IDs 1001 to 1010)
-- Note: 'Age' is derived via fn_get_customer_age(Date_of_Birth)
-- ============================================================================
INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1001, 'Aarav', 'Kumar', 'Sharma', TO_DATE('1988-04-15', 'YYYY-MM-DD'), 'aarav.sharma@gmail.com', 'A-204', 'Silk Mill Road, Katpadi', 'Vellore', 'Tamil Nadu', '632007');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1002, 'Priya', 'Sundar', 'Rajan', TO_DATE('1994-08-22', 'YYYY-MM-DD'), 'priya.sundar94@outlook.com', 'Flat 3B', 'Green Valley Layout, Tiruvalam', 'Vellore', 'Tamil Nadu', '632014');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1003, 'Rohan', 'Mahesh', 'Verma', TO_DATE('1982-11-10', 'YYYY-MM-DD'), 'rohan.verma@tcs.com', 'Villa 12', 'Poes Garden Ext', 'Chennai', 'Tamil Nadu', '600086');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1004, 'Ananya', 'Ramesh', 'Iyer', TO_DATE('1999-01-30', 'YYYY-MM-DD'), 'ananya.iyer99@gmail.com', '78/2', '12th Main, Indiranagar', 'Bengaluru', 'Karnataka', '560038');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1005, 'Vikram', 'Chandrasekhar', 'Reddy', TO_DATE('1976-06-18', 'YYYY-MM-DD'), 'vikram.reddy@rediffmail.com', 'H.No 4-50', 'Jubilee Hills Road No. 36', 'Hyderabad', 'Telangana', '500033');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1006, 'Neha', 'Sunil', 'Deshmukh', TO_DATE('1991-09-05', 'YYYY-MM-DD'), 'neha.deshmukh@yahoo.co.in', 'Penthouse 14', 'Dr. Ambedkar Road, Khar West', 'Mumbai', 'Maharashtra', '400052');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1007, 'Karan', 'Dev', 'Malhotra', TO_DATE('1985-12-14', 'YYYY-MM-DD'), 'karan.malhotra@delhitech.in', 'C-4/15', 'Vasant Kunj Sector C', 'New Delhi', 'Delhi', '110070');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1008, 'Sneha', 'Pradeep', 'Kulkarni', TO_DATE('2001-03-25', 'YYYY-MM-DD'), 'sneha.kulkarni@infosys.com', 'Plot 45', 'Senapati Bapat Road', 'Pune', 'Maharashtra', '411016');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1009, 'Mathew', 'Thomas', 'Varghese', TO_DATE('1979-07-08', 'YYYY-MM-DD'), 'mathew.varghese@cochinport.gov.in', 'Kadavil 21', 'Panampilly Nagar', 'Kochi', 'Kerala', '682036');

INSERT INTO CUSTOMER (Customer_ID, First_Name, Middle_Name, Last_Name, Date_of_Birth, Email, House_No, Street, City, State, PIN)
VALUES (1010, 'Subhash', 'Chandra', 'Banerjee', TO_DATE('1996-10-19', 'YYYY-MM-DD'), 'subhash.banerjee@wipro.com', '9B/1', 'Southern Avenue, Lake Market', 'Kolkata', 'West Bengal', '700029');


-- ============================================================================
-- 3. CUSTOMER_PHONE (12 Records: Multivalued Attribute Representation)
-- Customers 1001 and 1002 have 2 phone numbers each
-- ============================================================================
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1001, '9840123456');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1001, '9840198765');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1002, '9444112233');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1002, '9444998877');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1003, '9884011223');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1004, '9900123489');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1005, '9701234567');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1006, '9820123456');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1007, '9811098765');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1008, '9890123456');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1009, '9447012345');
INSERT INTO CUSTOMER_PHONE (Customer_ID, Phone_Number) VALUES (1010, '9830123456');


-- ============================================================================
-- 4. ACCOUNT (10 Records: Account_No 10042011 to 10042020)
-- ============================================================================
INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042011, 'Savings', 125000.00, TO_DATE('2021-03-10', 'YYYY-MM-DD'), 'Active', 101);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042012, 'Salary', 89500.50, TO_DATE('2022-07-15', 'YYYY-MM-DD'), 'Active', 102);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042013, 'Current', 450000.00, TO_DATE('2019-11-20', 'YYYY-MM-DD'), 'Active', 103);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042014, 'Savings', 35200.75, TO_DATE('2023-01-05', 'YYYY-MM-DD'), 'Active', 104);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042015, 'Current', 1850000.00, TO_DATE('2018-05-12', 'YYYY-MM-DD'), 'Active', 105);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042016, 'Savings', 754000.00, TO_DATE('2020-09-18', 'YYYY-MM-DD'), 'Active', 106);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042017, 'Salary', 142000.00, TO_DATE('2022-02-28', 'YYYY-MM-DD'), 'Active', 107);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042018, 'Savings', 8500.00, TO_DATE('2024-04-14', 'YYYY-MM-DD'), 'Active', 108);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042019, 'Current', 920000.00, TO_DATE('2017-08-30', 'YYYY-MM-DD'), 'Active', 109);

INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
VALUES (10042020, 'Savings', 215400.00, TO_DATE('2021-12-01', 'YYYY-MM-DD'), 'Active', 110);


-- ============================================================================
-- 5. CUSTOMER_ACCOUNT (12 Records: M:N Junction, Including 2 Joint Accounts)
-- Account 10042011 is joint between Customer 1001 & 1002
-- Account 10042015 is joint between Customer 1005 & 1006
-- ============================================================================
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1001, 10042011);
-- Joint Holder
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1002, 10042011);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1002, 10042012);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1003, 10042013);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1004, 10042014);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1005, 10042015);
-- Joint Holder
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1006, 10042015);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1006, 10042016);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1007, 10042017);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1008, 10042018);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1009, 10042019);
INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No) VALUES (1010, 10042020);


-- ============================================================================
-- 6. TRANSACTION (15 Records: IDs 9001 to 9015)
-- Dates span May 2026 to October 2026 for rich 6-month analytics & cash-flow
-- ============================================================================
INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9001, 10042011, 'Deposit', 25000.00, TO_DATE('2026-05-10', 'YYYY-MM-DD'), '10:14:22', 'Cash');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9002, 10042012, 'Deposit', 85000.00, TO_DATE('2026-05-31', 'YYYY-MM-DD'), '09:00:15', 'NEFT');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9003, 10042013, 'Transfer_Debit', 45000.00, TO_DATE('2026-06-12', 'YYYY-MM-DD'), '14:25:30', 'RTGS');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9004, 10042014, 'Withdrawal', 5000.00, TO_DATE('2026-06-25', 'YYYY-MM-DD'), '19:40:05', 'ATM');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9005, 10042015, 'Loan_EMI', 38500.00, TO_DATE('2026-07-05', 'YYYY-MM-DD'), '06:30:00', 'Auto-Debit');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9006, 10042016, 'FD_Booking', 100000.00, TO_DATE('2026-07-18', 'YYYY-MM-DD'), '11:15:45', 'NEFT');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9007, 10042017, 'Transfer_Debit', 12000.00, TO_DATE('2026-08-04', 'YYYY-MM-DD'), '16:05:10', 'UPI');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9008, 10042011, 'Transfer_Credit', 12000.00, TO_DATE('2026-08-04', 'YYYY-MM-DD'), '16:05:12', 'UPI');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9009, 10042018, 'Deposit', 15000.00, TO_DATE('2026-08-20', 'YYYY-MM-DD'), '12:30:00', 'Cheque');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9010, 10042019, 'Withdrawal', 50000.00, TO_DATE('2026-09-02', 'YYYY-MM-DD'), '15:10:40', 'Cash');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9011, 10042020, 'Transfer_Debit', 28000.00, TO_DATE('2026-09-15', 'YYYY-MM-DD'), '18:22:19', 'IMPS');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9012, 10042013, 'Transfer_Credit', 28000.00, TO_DATE('2026-09-15', 'YYYY-MM-DD'), '18:22:20', 'IMPS');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9013, 10042012, 'Loan_EMI', 18200.00, TO_DATE('2026-10-05', 'YYYY-MM-DD'), '06:30:00', 'Auto-Debit');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9014, 10042014, 'Deposit', 20000.00, TO_DATE('2026-10-12', 'YYYY-MM-DD'), '10:45:00', 'UPI');

INSERT INTO TRANSACTION (Transaction_ID, Account_No, Transaction_Type, Amount, Transaction_Date, Transaction_Time, Transaction_Mode)
VALUES (9015, 10042015, 'Deposit', 120000.00, TO_DATE('2026-10-16', 'YYYY-MM-DD'), '13:55:12', 'RTGS');


-- ============================================================================
-- 7. EMPLOYEE (10 Records: IDs 501 to 510)
-- Designations: Branch Manager, Loan Officer, Relationship Manager, Senior Auditor, Clerk
-- ============================================================================
INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (501, 'Rajeshwari Swaminathan', 'Branch Manager', 125000.00, '9443210987', 101);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (502, 'Venkatesh Murthy', 'Loan Officer', 82000.00, '9443210988', 101);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (503, 'Kavita Menon', 'Branch Manager', 130000.00, '9841029384', 102);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (504, 'Girish Hegde', 'Relationship Manager', 75000.00, '9845012399', 104);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (505, 'Srinivas Rao', 'Branch Manager', 140000.00, '9703049586', 105);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (506, 'Pooja Bhatt', 'Senior Auditor', 95000.00, '9821034872', 106);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (507, 'Amitabh Sen', 'Loan Officer', 88000.00, '9810023456', 107);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (508, 'Manish Chitale', 'Relationship Manager', 72000.00, '9890045612', 108);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (509, 'Biju Kurien', 'Clerk', 45000.00, '9447098123', 109);

INSERT INTO EMPLOYEE (Employee_ID, Employee_Name, Designation, Salary, Phone, Branch_ID)
VALUES (510, 'Debolina Mukherjee', 'Clerk', 46000.00, '9830076543', 110);


-- ============================================================================
-- 8. LOAN (10 Records: IDs 301 to 310)
-- Types: Home Loan, Education Loan, Vehicle Loan, Personal Loan, Business Loan
-- ============================================================================
INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (301, 1001, 'Home Loan', 4500000.00, 8.50, TO_DATE('2024-01-15', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (302, 1002, 'Education Loan', 1200000.00, 9.25, TO_DATE('2023-08-20', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (303, 1003, 'Vehicle Loan', 850000.00, 8.75, TO_DATE('2025-02-10', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (304, 1004, 'Personal Loan', 300000.00, 11.50, TO_DATE('2024-11-05', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (305, 1005, 'Business Loan', 7500000.00, 10.25, TO_DATE('2023-05-18', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (306, 1006, 'Home Loan', 6200000.00, 8.40, TO_DATE('2022-09-01', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (307, 1007, 'Vehicle Loan', 950000.00, 8.90, TO_DATE('2024-06-14', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (308, 1008, 'Education Loan', 800000.00, 9.00, TO_DATE('2025-07-22', 'YYYY-MM-DD'), 'Active');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (309, 1009, 'Business Loan', 3500000.00, 10.50, TO_DATE('2021-04-11', 'YYYY-MM-DD'), 'Closed');

INSERT INTO LOAN (Loan_ID, Customer_ID, Loan_Type, Principal_Amount, Interest_Rate, Start_Date, Status)
VALUES (310, 1010, 'Personal Loan', 250000.00, 12.00, TO_DATE('2026-02-19', 'YYYY-MM-DD'), 'Active');


-- ============================================================================
-- 9. LOAN_PAYMENT (10 Records: IDs 401 to 410)
-- ============================================================================
INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (401, 301, TO_DATE('2026-05-05', 'YYYY-MM-DD'), 42500.00, 'Auto-Debit');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (402, 301, TO_DATE('2026-06-05', 'YYYY-MM-DD'), 42500.00, 'Auto-Debit');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (403, 302, TO_DATE('2026-06-15', 'YYYY-MM-DD'), 14500.00, 'NEFT');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (404, 303, TO_DATE('2026-07-10', 'YYYY-MM-DD'), 18200.00, 'UPI');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (405, 304, TO_DATE('2026-07-25', 'YYYY-MM-DD'), 9800.00, 'UPI');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (406, 305, TO_DATE('2026-08-05', 'YYYY-MM-DD'), 78000.00, 'NEFT');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (407, 306, TO_DATE('2026-08-10', 'YYYY-MM-DD'), 58500.00, 'Auto-Debit');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (408, 307, TO_DATE('2026-09-05', 'YYYY-MM-DD'), 20500.00, 'Cheque');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (409, 308, TO_DATE('2026-09-20', 'YYYY-MM-DD'), 11200.00, 'Auto-Debit');

INSERT INTO LOAN_PAYMENT (Payment_ID, Loan_ID, Payment_Date, Amount, Payment_Mode)
VALUES (410, 310, TO_DATE('2026-10-05', 'YYYY-MM-DD'), 8900.00, 'Cash');


-- ============================================================================
-- 10. CARD (10 Records: IDs 701 to 710)
-- Card Types: Debit, Credit, Platinum Debit, Forex
-- ============================================================================
INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (701, 10042011, 'Debit', TO_DATE('2022-04-01', 'YYYY-MM-DD'), TO_DATE('2027-03-31', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (702, 10042011, 'Credit', TO_DATE('2023-01-15', 'YYYY-MM-DD'), TO_DATE('2028-01-31', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (703, 10042012, 'Platinum Debit', TO_DATE('2022-08-10', 'YYYY-MM-DD'), TO_DATE('2027-08-31', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (704, 10042013, 'Credit', TO_DATE('2020-05-12', 'YYYY-MM-DD'), TO_DATE('2025-05-31', 'YYYY-MM-DD'), 'Expired');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (705, 10042014, 'Debit', TO_DATE('2023-02-01', 'YYYY-MM-DD'), TO_DATE('2028-02-28', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (706, 10042015, 'Forex', TO_DATE('2023-11-20', 'YYYY-MM-DD'), TO_DATE('2026-11-30', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (707, 10042016, 'Platinum Debit', TO_DATE('2021-10-05', 'YYYY-MM-DD'), TO_DATE('2026-10-31', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (708, 10042017, 'Credit', TO_DATE('2024-03-01', 'YYYY-MM-DD'), TO_DATE('2029-03-31', 'YYYY-MM-DD'), 'Active');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (709, 10042018, 'Debit', TO_DATE('2024-05-10', 'YYYY-MM-DD'), TO_DATE('2029-05-31', 'YYYY-MM-DD'), 'Blocked');

INSERT INTO CARD (Card_ID, Account_No, Card_Type, Issue_Date, Expiry_Date, Status)
VALUES (710, 10042020, 'Platinum Debit', TO_DATE('2022-01-18', 'YYYY-MM-DD'), TO_DATE('2027-01-31', 'YYYY-MM-DD'), 'Active');


-- ============================================================================
-- 11. BENEFICIARY (10 Records: IDs 601 to 610)
-- ============================================================================
INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (601, 1001, 'Vijay Sharma Enterprises', 10042013, 'NOLA0000103');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (602, 1002, 'Ramesh Sundar', 10042011, 'NOLA0000101');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (603, 1003, 'Meera Verma', 10042014, 'NOLA0000104');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (604, 1004, 'Rameshwaram Tech Labs', 10042015, 'NOLA0000105');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (605, 1005, 'Hyderabad Infra Projects', 10042019, 'NOLA0000109');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (606, 1006, 'Khar Welfare Society', 10042016, 'NOLA0000106');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (607, 1007, 'Delhi Education Society', 10042017, 'NOLA0000107');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (608, 1008, 'Pune Tech Solutions', 10042018, 'NOLA0000108');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (609, 1009, 'Cochin Maritime Exports', 10042019, 'NOLA0000109');

INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
VALUES (610, 1010, 'Bengal Art Gallery', 10042020, 'NOLA0000110');


-- ============================================================================
-- 12. FUND_TRANSFER (10 Records: IDs 801 to 810)
-- Modes: UPI, NEFT, RTGS, IMPS
-- ============================================================================
INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (801, 10042011, 601, 15000.00, TO_DATE('2026-05-15', 'YYYY-MM-DD'), 'NEFT', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (802, 10042012, 602, 4500.00, TO_DATE('2026-06-02', 'YYYY-MM-DD'), 'UPI', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (803, 10042013, 603, 75000.00, TO_DATE('2026-06-20', 'YYYY-MM-DD'), 'RTGS', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (804, 10042014, 604, 8500.00, TO_DATE('2026-07-08', 'YYYY-MM-DD'), 'IMPS', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (805, 10042015, 605, 250000.00, TO_DATE('2026-07-28', 'YYYY-MM-DD'), 'RTGS', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (806, 10042016, 606, 12000.00, TO_DATE('2026-08-14', 'YYYY-MM-DD'), 'NEFT', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (807, 10042017, 607, 3500.00, TO_DATE('2026-08-30', 'YYYY-MM-DD'), 'UPI', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (808, 10042018, 608, 1500.00, TO_DATE('2026-09-12', 'YYYY-MM-DD'), 'UPI', 'Failed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (809, 10042019, 609, 185000.00, TO_DATE('2026-09-25', 'YYYY-MM-DD'), 'RTGS', 'Completed');

INSERT INTO FUND_TRANSFER (Transfer_ID, Account_No, Beneficiary_ID, Amount, Transfer_Date, Transfer_Mode, Status)
VALUES (810, 10042020, 610, 22000.00, TO_DATE('2026-10-10', 'YYYY-MM-DD'), 'IMPS', 'Completed');


-- ============================================================================
-- 13. FIXED_DEPOSIT (10 Records: IDs 201 to 210)
-- Principal_Amount >= 5000
-- ============================================================================
INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (201, 1001, 200000.00, 7.10, TO_DATE('2023-01-10', 'YYYY-MM-DD'), TO_DATE('2026-01-10', 'YYYY-MM-DD'), 'Matured');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (202, 1002, 50000.00, 6.85, TO_DATE('2024-03-15', 'YYYY-MM-DD'), TO_DATE('2027-03-15', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (203, 1003, 500000.00, 7.25, TO_DATE('2023-06-20', 'YYYY-MM-DD'), TO_DATE('2028-06-20', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (204, 1004, 25000.00, 6.75, TO_DATE('2025-02-01', 'YYYY-MM-DD'), TO_DATE('2026-02-01', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (205, 1005, 1500000.00, 7.50, TO_DATE('2022-11-15', 'YYYY-MM-DD'), TO_DATE('2027-11-15', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (206, 1006, 800000.00, 7.20, TO_DATE('2024-08-10', 'YYYY-MM-DD'), TO_DATE('2029-08-10', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (207, 1007, 100000.00, 7.00, TO_DATE('2023-09-05', 'YYYY-MM-DD'), TO_DATE('2026-09-05', 'YYYY-MM-DD'), 'Matured');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (208, 1008, 10000.00, 6.50, TO_DATE('2025-05-12', 'YYYY-MM-DD'), TO_DATE('2026-05-12', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (209, 1009, 350000.00, 7.15, TO_DATE('2024-04-18', 'YYYY-MM-DD'), TO_DATE('2027-04-18', 'YYYY-MM-DD'), 'Active');

INSERT INTO FIXED_DEPOSIT (FD_ID, Customer_ID, Principal_Amount, Interest_Rate, Start_Date, Maturity_Date, Status)
VALUES (210, 1010, 150000.00, 6.90, TO_DATE('2023-12-01', 'YYYY-MM-DD'), TO_DATE('2025-12-01', 'YYYY-MM-DD'), 'Prematurely Closed');


-- ============================================================================
-- 14. COMPLAINT (10 Records: IDs 901 to 910)
-- Statuses: Open, In Progress, Resolved
-- ============================================================================
INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (901, 1001, 'ATM dispensed INR 4,000 less than requested amount at Katpadi junction ATM', TO_DATE('2026-05-12', 'YYYY-MM-DD'), 'Resolved', TO_DATE('2026-05-15', 'YYYY-MM-DD'));

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (902, 1002, 'SMS alerts not triggered for UPI transaction reference TXN8921892', TO_DATE('2026-06-08', 'YYYY-MM-DD'), 'Resolved', TO_DATE('2026-06-10', 'YYYY-MM-DD'));

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (903, 1003, 'Netbanking mobile app crashes on generating e-statement PDF', TO_DATE('2026-07-02', 'YYYY-MM-DD'), 'Resolved', TO_DATE('2026-07-06', 'YYYY-MM-DD'));

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (904, 1004, 'Wrong annual card maintenance fee debited for Platinum Debit card', TO_DATE('2026-08-11', 'YYYY-MM-DD'), 'Resolved', TO_DATE('2026-08-16', 'YYYY-MM-DD'));

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (905, 1005, 'Delay in commercial loan subsidy credit under state incentive scheme', TO_DATE('2026-08-28', 'YYYY-MM-DD'), 'In Progress', NULL);

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (906, 1006, 'Forex card international contactless POS transaction declined in Dubai airport', TO_DATE('2026-09-04', 'YYYY-MM-DD'), 'Resolved', TO_DATE('2026-09-07', 'YYYY-MM-DD'));

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (907, 1007, 'Cheque clearing delayed beyond standard turnaround time of 48 hours', TO_DATE('2026-09-18', 'YYYY-MM-DD'), 'In Progress', NULL);

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (908, 1008, 'Debit card blocked unexpectedly after PIN retry lockout without SMS alert', TO_DATE('2026-09-29', 'YYYY-MM-DD'), 'In Progress', NULL);

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (909, 1009, 'Unauthorized auto-debit notification received for unknown biller registration', TO_DATE('2026-10-08', 'YYYY-MM-DD'), 'Open', NULL);

INSERT INTO COMPLAINT (Complaint_ID, Customer_ID, Description, Complaint_Date, Status, Resolution_Date)
VALUES (910, 1010, 'Request for interest certificate for Income Tax filing not generated online', TO_DATE('2026-10-14', 'YYYY-MM-DD'), 'Open', NULL);


-- ============================================================================
-- COMMIT ALL TRANSACTIONS
-- ============================================================================
COMMIT;
