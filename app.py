"""
app.py — Flask Web Application Backend
Project: Advanced Bank Management System (BACSE202)

All routes return JSON (with a mandatory 'trace' key) except GET / which
renders templates/index.html.

Endpoints
─────────
GET  /                                    → Renders main dashboard
GET  /api/customers                       → Customer list for top-bar switcher
GET  /api/overview/<customer_id>          → Full Bento Grid data for one customer
POST /api/transfer                        → sp_process_fund_transfer (live DML)
POST /api/pay-emi                         → sp_pay_loan_emi (live DML)
GET  /api/cursor-report                   → Branch audit (mirrors cur_branch_performance)
POST /api/module/<mod_id>/<action>        → Module DML: insert | update | delete
GET  /api/module-queries/<mod_id>/<q_num> → Execute labelled SELECT [Mx-Qy]
"""

import os
import oracledb
from flask import Flask, render_template, request, jsonify
from db import query_all, execute_dml, call_proc

app = Flask(__name__)
app.config["JSON_SORT_KEYS"] = False


# ─────────────────────────────────────────────────────────────────────────────
# GET /
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/customers
# Returns the customer list for the top-bar customer switcher.
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/api/customers")
def get_customers():
    sql = """
        SELECT
            c.Customer_ID,
            c.First_Name || ' ' || NVL(c.Middle_Name || ' ', '') || c.Last_Name AS Full_Name,
            c.Email,
            c.City,
            c.State
        FROM CUSTOMER c
        ORDER BY c.Customer_ID
    """
    result = query_all(sql, meta={
        "op":     "List all customers for switcher",
        "comp":   "SELECT Query",
        "tables": ["CUSTOMER"],
    })
    return jsonify(result)


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/overview/<customer_id>
# Full Bento Grid payload for the dashboard.
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/api/overview/<int:customer_id>")
def get_overview(customer_id: int):
    cid = customer_id

    # 1. Customer profile + derived Age (fn_get_customer_age)
    profile_sql = """
        SELECT
            c.Customer_ID,
            c.First_Name || ' ' || NVL(c.Middle_Name || ' ', '') || c.Last_Name AS Full_Name,
            c.Email,
            c.City,
            c.State,
            c.PIN,
            TO_CHAR(c.Date_of_Birth, 'DD-Mon-YYYY') AS Date_of_Birth,
            fn_get_customer_age(c.Customer_ID)       AS Age
        FROM CUSTOMER c
        WHERE c.Customer_ID = :cid
    """
    profile = query_all(profile_sql, {"cid": cid}, meta={
        "op":     "Fetch customer profile with derived Age",
        "comp":   "SELECT + PL/SQL Function fn_get_customer_age",
        "tables": ["CUSTOMER"],
    })

    # 2. All accounts owned by customer + branch details
    accounts_sql = """
        SELECT
            a.Account_No,
            a.Account_Type,
            TO_CHAR(a.Balance, 'FM99,99,99,999.00') AS Balance_Fmt,
            a.Balance                                AS Balance_Raw,
            TO_CHAR(a.Open_Date, 'DD-Mon-YYYY')     AS Open_Date,
            a.Status,
            b.Branch_Name,
            b.IFSC_Code
        FROM   CUSTOMER_ACCOUNT ca
        JOIN   ACCOUNT a ON ca.Account_No = a.Account_No
        JOIN   BRANCH  b ON a.Branch_ID   = b.Branch_ID
        WHERE  ca.Customer_ID = :cid
        ORDER BY a.Account_No
    """
    accounts = query_all(accounts_sql, {"cid": cid}, meta={
        "op":     "Fetch all accounts and branch details for customer",
        "comp":   "SELECT Query (INNER JOIN)",
        "tables": ["CUSTOMER_ACCOUNT", "ACCOUNT", "BRANCH"],
    })

    # 3. Total balance across all the customer's accounts
    total_balance = sum(
        row.get("balance_raw", 0) or 0
        for row in accounts["rows"]
    )

    # 4. 6-month monthly transaction trend (spline chart data)
    trend_sql = """
        SELECT
            TO_CHAR(t.Transaction_Date, 'Mon-YYYY')   AS Month_Label,
            TRUNC(t.Transaction_Date, 'MM')            AS Month_Sort,
            SUM(CASE WHEN t.Transaction_Type IN ('Deposit', 'Transfer_Credit')
                     THEN t.Amount ELSE 0 END)         AS Credits,
            SUM(CASE WHEN t.Transaction_Type IN ('Withdrawal', 'Transfer_Debit',
                                                  'Loan_EMI', 'FD_Booking')
                     THEN t.Amount ELSE 0 END)         AS Debits,
            COUNT(*)                                   AS Txn_Count
        FROM   TRANSACTION t
        JOIN   CUSTOMER_ACCOUNT ca ON t.Account_No = ca.Account_No
        WHERE  ca.Customer_ID    = :cid
          AND  t.Transaction_Date >= ADD_MONTHS(SYSDATE, -6)
        GROUP BY TO_CHAR(t.Transaction_Date, 'Mon-YYYY'),
                 TRUNC(t.Transaction_Date, 'MM')
        ORDER BY TRUNC(t.Transaction_Date, 'MM')
    """
    trend = query_all(trend_sql, {"cid": cid}, meta={
        "op":     "Fetch 6-month monthly transaction trend",
        "comp":   "SELECT Query (GROUP BY / CASE WHEN)",
        "tables": ["TRANSACTION", "CUSTOMER_ACCOUNT"],
    })

    # 5. Recent transactions (last 10)
    recent_sql = """
        SELECT
            t.Transaction_ID,
            t.Account_No,
            t.Transaction_Type,
            t.Transaction_Mode,
            TO_CHAR(t.Transaction_Date, 'DD-Mon-YYYY') AS Txn_Date,
            t.Transaction_Time                          AS Txn_Time,
            t.Amount
        FROM   TRANSACTION t
        JOIN   CUSTOMER_ACCOUNT ca ON t.Account_No = ca.Account_No
        WHERE  ca.Customer_ID = :cid
        ORDER BY t.Transaction_Date DESC, t.Transaction_ID DESC
        FETCH FIRST 10 ROWS ONLY
    """
    recent_txns = query_all(recent_sql, {"cid": cid}, meta={
        "op":     "Fetch recent transactions for customer",
        "comp":   "SELECT Query (JOIN + FETCH FIRST)",
        "tables": ["TRANSACTION", "CUSTOMER_ACCOUNT"],
    })

    # 6. Monthly cash-flow card (credits vs debits, current month)
    cashflow_sql = """
        SELECT
            TO_CHAR(t.Transaction_Date, 'Mon-YYYY') AS Month_Label,
            SUM(CASE WHEN t.Transaction_Type IN ('Deposit', 'Transfer_Credit')
                     THEN t.Amount ELSE 0 END)       AS Total_Credits,
            SUM(CASE WHEN t.Transaction_Type IN ('Withdrawal', 'Transfer_Debit',
                                                  'Loan_EMI', 'FD_Booking')
                     THEN t.Amount ELSE 0 END)       AS Total_Debits
        FROM   TRANSACTION t
        JOIN   CUSTOMER_ACCOUNT ca ON t.Account_No = ca.Account_No
        WHERE  ca.Customer_ID = :cid
          AND  TRUNC(t.Transaction_Date, 'MM') = TRUNC(SYSDATE, 'MM')
        GROUP BY TO_CHAR(t.Transaction_Date, 'Mon-YYYY')
    """
    cashflow = query_all(cashflow_sql, {"cid": cid}, meta={
        "op":     "Fetch monthly cash-flow for current month",
        "comp":   "SELECT Query (GROUP BY / CASE WHEN)",
        "tables": ["TRANSACTION", "CUSTOMER_ACCOUNT"],
    })

    # 7. Active loans + EMI repayment progress
    loans_sql = """
        SELECT
            l.Loan_ID,
            l.Loan_Type,
            l.Principal_Amount,
            l.Interest_Rate,
            TO_CHAR(l.Start_Date, 'DD-Mon-YYYY') AS Start_Date,
            l.Status,
            NVL((SELECT SUM(lp.Amount)
                 FROM   LOAN_PAYMENT lp
                 WHERE  lp.Loan_ID = l.Loan_ID), 0) AS Total_Paid,
            ROUND(l.Principal_Amount - NVL((SELECT SUM(lp2.Amount)
                  FROM LOAN_PAYMENT lp2
                  WHERE lp2.Loan_ID = l.Loan_ID), 0), 2) AS Outstanding
        FROM   LOAN l
        WHERE  l.Customer_ID = :cid
        ORDER BY l.Loan_ID
    """
    loans = query_all(loans_sql, {"cid": cid}, meta={
        "op":     "Fetch loans with EMI repayment progress",
        "comp":   "SELECT Query (Scalar Subquery)",
        "tables": ["LOAN", "LOAN_PAYMENT"],
    })

    # 8. Registered beneficiaries
    bene_sql = """
        SELECT
            Beneficiary_ID,
            Beneficiary_Name,
            Account_No,
            IFSC_Code
        FROM   BENEFICIARY
        WHERE  Customer_ID = :cid
        ORDER BY Beneficiary_ID
    """
    beneficiaries = query_all(bene_sql, {"cid": cid}, meta={
        "op":     "Fetch registered beneficiaries",
        "comp":   "SELECT Query",
        "tables": ["BENEFICIARY"],
    })

    # 9. Fixed Deposits with compound maturity value
    fd_sql = """
        SELECT
            fd.FD_ID,
            fd.Principal_Amount,
            fd.Interest_Rate,
            TO_CHAR(fd.Start_Date,    'DD-Mon-YYYY')  AS Start_Date,
            TO_CHAR(fd.Maturity_Date, 'DD-Mon-YYYY')  AS Maturity_Date,
            fd.Status,
            ROUND(MONTHS_BETWEEN(fd.Maturity_Date, fd.Start_Date) / 12, 1) AS Tenure_Years,
            fn_calc_fd_maturity_value(fd.FD_ID)        AS Maturity_Value
        FROM   FIXED_DEPOSIT fd
        WHERE  fd.Customer_ID = :cid
        ORDER BY fd.FD_ID
    """
    fds = query_all(fd_sql, {"cid": cid}, meta={
        "op":     "Fetch fixed deposits with compound maturity value",
        "comp":   "SELECT + PL/SQL Function fn_calc_fd_maturity_value",
        "tables": ["FIXED_DEPOSIT"],
    })

    return jsonify({
        "customer_id":   cid,
        "profile":       profile["rows"][0] if profile["rows"] else {},
        "accounts":      accounts["rows"],
        "total_balance": round(total_balance, 2),
        "trend":         trend["rows"],
        "recent_txns":   recent_txns["rows"],
        "cashflow":      cashflow["rows"][0] if cashflow["rows"] else {},
        "loans":         loans["rows"],
        "beneficiaries": beneficiaries["rows"],
        "fixed_deposits": fds["rows"],
        "traces": {
            "profile":        profile["trace"],
            "accounts":       accounts["trace"],
            "trend":          trend["trace"],
            "recent_txns":    recent_txns["trace"],
            "cashflow":       cashflow["trace"],
            "loans":          loans["trace"],
            "beneficiaries":  beneficiaries["trace"],
            "fixed_deposits": fds["trace"],
        }
    })


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/transfer
# Calls sp_process_fund_transfer. Surfaces ORA-20001 trigger error as HTTP 400.
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/api/transfer", methods=["POST"])
def transfer():
    data          = request.get_json(force=True)
    account_no    = int(data.get("account_no", 0))
    beneficiary_id = int(data.get("beneficiary_id", 0))
    amount        = float(data.get("amount", 0))
    mode          = str(data.get("mode", "UPI"))

    result = call_proc(
        proc_name="sp_process_fund_transfer",
        in_params=[account_no, beneficiary_id, amount, mode],
        out_type=oracledb.STRING,
        meta={
            "op":     f"Fund transfer of Rs.{amount} via {mode}",
            "comp":   "PL/SQL Procedure sp_process_fund_transfer + Trigger trg_prevent_min_balance_breach",
            "tables": ["ACCOUNT", "FUND_TRANSFER", "TRANSACTION"],
        },
    )

    output_msg = result.get("output", "")

    # If the trigger (ORA-20001) or any other Oracle error blocked the transfer,
    # the procedure sets p_status_msg to 'ERROR: …' and we propagate HTTP 400.
    if str(output_msg).startswith("ERROR:"):
        return jsonify({
            "success": False,
            "message": output_msg,
            "trace":   result["trace"],
        }), 400

    return jsonify({
        "success": True,
        "message": output_msg,
        "trace":   result["trace"],
    })


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/pay-emi
# Calls sp_pay_loan_emi.
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/api/pay-emi", methods=["POST"])
def pay_emi():
    data    = request.get_json(force=True)
    loan_id = int(data.get("loan_id", 0))
    amount  = float(data.get("amount", 0))
    mode    = str(data.get("mode", "UPI"))

    result = call_proc(
        proc_name="sp_pay_loan_emi",
        in_params=[loan_id, amount, mode],
        out_type=oracledb.STRING,
        meta={
            "op":     f"Pay EMI of Rs.{amount} for Loan {loan_id} via {mode}",
            "comp":   "PL/SQL Procedure sp_pay_loan_emi + Trigger trg_prevent_min_balance_breach",
            "tables": ["LOAN_PAYMENT", "LOAN", "ACCOUNT", "TRANSACTION"],
        },
    )

    output_msg = result.get("output", "")

    if str(output_msg).startswith("ERROR:"):
        return jsonify({
            "success": False,
            "message": output_msg,
            "trace":   result["trace"],
        }), 400

    return jsonify({
        "success": True,
        "message": output_msg,
        "trace":   result["trace"],
    })


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/cursor-report
# Mirrors cur_branch_performance from sp_branch_audit_cursor.
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/api/cursor-report")
def cursor_report():
    sql = """
        SELECT
            b.Branch_ID,
            b.Branch_Name,
            b.IFSC_Code,
            COUNT(DISTINCT a.Account_No)                       AS Total_Accounts,
            NVL(SUM(a.Balance), 0)                             AS Total_Balance,
            COUNT(DISTINCT e.Employee_ID)                      AS Total_Employees
        FROM   BRANCH   b
        LEFT JOIN ACCOUNT   a ON a.Branch_ID = b.Branch_ID
        LEFT JOIN EMPLOYEE  e ON e.Branch_ID = b.Branch_ID
        GROUP BY b.Branch_ID, b.Branch_Name, b.IFSC_Code
        ORDER BY b.Branch_ID
    """
    result = query_all(sql, meta={
        "op":     "Branch audit report — mirrors cur_branch_performance cursor",
        "comp":   "SELECT Query (LEFT JOIN Aggregation) — mirrors sp_branch_audit_cursor",
        "tables": ["BRANCH", "ACCOUNT", "EMPLOYEE"],
    })
    return jsonify(result)


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/module/<mod_id>/<action>
# Module DML operations: insert | update | delete
# ─────────────────────────────────────────────────────────────────────────────

@app.route("/api/module/<int:mod_id>/<string:action>", methods=["POST"])
def module_dml(mod_id: int, action: str):
    data   = request.get_json(force=True)
    action = action.lower()

    if action not in ("insert", "update", "delete"):
        return jsonify({"error": "action must be insert, update, or delete"}), 400

    # ── Module 1: Core Banking ─────────────────────────────────────────────
    if mod_id == 1:
        if action == "insert":
            # If account_no already exists or is not provided, pick MAX + 1
            acc_no = int(data.get("account_no", 0))
            check = query_all("SELECT COUNT(*) AS cnt FROM ACCOUNT WHERE Account_No = :acc_no", {"acc_no": acc_no})
            if acc_no <= 0 or (check.get("rows") and check["rows"][0].get("cnt", 0) > 0):
                nxt = query_all("SELECT NVL(MAX(Account_No), 10042020) + 1 AS next_acc FROM ACCOUNT")
                acc_no = int(nxt["rows"][0]["next_acc"])

            # Insert a new ACCOUNT and link it to an existing customer
            sql = """
                INSERT INTO ACCOUNT (Account_No, Account_Type, Balance, Open_Date, Status, Branch_ID)
                VALUES (:acc_no, :acc_type, :balance, SYSDATE, 'Active', :branch_id)
            """
            params = {
                "acc_no":    acc_no,
                "acc_type":  data.get("account_type", "Savings"),
                "balance":   float(data.get("balance", 0)),
                "branch_id": int(data.get("branch_id", 101)),
            }
            r1 = execute_dml(sql, params, meta={
                "op":     f"Open new bank account {acc_no}",
                "comp":   "INSERT Statement",
                "tables": ["ACCOUNT"],
            })
            if not r1.get("success", True):
                return jsonify({"error": r1.get("error"), "trace": r1.get("trace")}), 400

            # Link to customer
            sql2 = """
                INSERT INTO CUSTOMER_ACCOUNT (Customer_ID, Account_No)
                VALUES (:cid, :acc_no)
            """
            r2 = execute_dml(sql2, {"cid": int(data["customer_id"]), "acc_no": acc_no}, meta={
                "op":     f"Link account {acc_no} to customer {data['customer_id']}",
                "comp":   "INSERT Statement",
                "tables": ["CUSTOMER_ACCOUNT"],
            })
            if not r2.get("success", True):
                return jsonify({"error": r2.get("error"), "trace": r2.get("trace")}), 400

            return jsonify({
                "success": True,
                "account_no": acc_no,
                "rows_affected": r1["rows_affected"] + r2["rows_affected"],
                "trace": r1["trace"],
                "traces": [r1["trace"], r2["trace"]]
            })

        elif action == "update":
            # Update ACCOUNT.Status
            sql = """
                UPDATE ACCOUNT
                SET    Status = :status
                WHERE  Account_No = :acc_no
            """
            r = execute_dml(sql, {"status": data["status"], "acc_no": int(data["account_no"])}, meta={
                "op":     f"Update account status to {data.get('status')}",
                "comp":   "UPDATE Statement",
                "tables": ["ACCOUNT"],
            })
            return jsonify(r)

        elif action == "delete":
            # Delete a CUSTOMER_PHONE record
            sql = """
                DELETE FROM CUSTOMER_PHONE
                WHERE  Customer_ID   = :cid
                  AND  Phone_Number  = :phone
            """
            r = execute_dml(sql, {"cid": int(data["customer_id"]), "phone": data["phone_number"]}, meta={
                "op":     "Delete customer phone number",
                "comp":   "DELETE Statement",
                "tables": ["CUSTOMER_PHONE"],
            })
            return jsonify(r)

    # ── Module 2: Cards, Beneficiaries & Fund Transfers ────────────────────
    elif mod_id == 2:
        if action == "insert":
            # Insert new BENEFICIARY
            sql = """
                INSERT INTO BENEFICIARY (Beneficiary_ID, Customer_ID, Beneficiary_Name, Account_No, IFSC_Code)
                VALUES (NVL((SELECT MAX(Beneficiary_ID) FROM BENEFICIARY), 600) + 1,
                        :cid, :bname, :acc_no, :ifsc)
            """
            r = execute_dml(sql, {
                "cid":    int(data["customer_id"]),
                "bname":  data["beneficiary_name"],
                "acc_no": int(data["account_no"]),
                "ifsc":   data["ifsc_code"],
            }, meta={
                "op":     "Register new beneficiary",
                "comp":   "INSERT Statement",
                "tables": ["BENEFICIARY"],
            })
            return jsonify(r)

        elif action == "update":
            # Update CARD.Status (Active / Blocked)
            sql = """
                UPDATE CARD
                SET    Status = :status
                WHERE  Card_ID = :card_id
            """
            r = execute_dml(sql, {"status": data["status"], "card_id": int(data["card_id"])}, meta={
                "op":     f"Update card {data.get('card_id')} status to {data.get('status')}",
                "comp":   "UPDATE Statement",
                "tables": ["CARD"],
            })
            return jsonify(r)

        elif action == "delete":
            # Delete a BENEFICIARY record
            sql = """
                DELETE FROM BENEFICIARY
                WHERE  Beneficiary_ID = :bid
            """
            r = execute_dml(sql, {"bid": int(data["beneficiary_id"])}, meta={
                "op":     f"Delete beneficiary {data.get('beneficiary_id')}",
                "comp":   "DELETE Statement",
                "tables": ["BENEFICIARY"],
            })
            return jsonify(r)

    # ── Module 3: Loans & Fixed Deposits ──────────────────────────────────
    elif mod_id == 3:
        if action == "insert":
            # Insert new FIXED_DEPOSIT
            sql = """
                INSERT INTO FIXED_DEPOSIT
                    (FD_ID, Customer_ID, Principal_Amount, Interest_Rate,
                     Start_Date, Maturity_Date, Status)
                VALUES
                    (NVL((SELECT MAX(FD_ID) FROM FIXED_DEPOSIT), 200) + 1,
                     :cid, :principal, :rate,
                     TO_DATE(:start_date, 'YYYY-MM-DD'),
                     TO_DATE(:maturity_date, 'YYYY-MM-DD'),
                     'Active')
            """
            r = execute_dml(sql, {
                "cid":           int(data["customer_id"]),
                "principal":     float(data["principal_amount"]),
                "rate":          float(data["interest_rate"]),
                "start_date":    data["start_date"],
                "maturity_date": data["maturity_date"],
            }, meta={
                "op":     "Create new Fixed Deposit",
                "comp":   "INSERT Statement",
                "tables": ["FIXED_DEPOSIT"],
            })
            return jsonify(r)

        elif action == "update":
            # Update LOAN Status or Interest_Rate
            field  = data.get("field", "Status")   # "Status" or "Interest_Rate"
            if field == "Status":
                sql = "UPDATE LOAN SET Status = :val WHERE Loan_ID = :lid"
            else:
                sql = "UPDATE LOAN SET Interest_Rate = :val WHERE Loan_ID = :lid"
            r = execute_dml(sql, {"val": data["value"], "lid": int(data["loan_id"])}, meta={
                "op":     f"Update loan {data.get('loan_id')} {field}",
                "comp":   "UPDATE Statement",
                "tables": ["LOAN"],
            })
            return jsonify(r)

        elif action == "delete":
            # Delete a FIXED_DEPOSIT (only if not Active)
            sql = """
                DELETE FROM FIXED_DEPOSIT
                WHERE  FD_ID = :fd_id
            """
            r = execute_dml(sql, {"fd_id": int(data["fd_id"])}, meta={
                "op":     f"Delete Fixed Deposit {data.get('fd_id')}",
                "comp":   "DELETE Statement",
                "tables": ["FIXED_DEPOSIT"],
            })
            return jsonify(r)

    # ── Module 4: Branch, Employees & Complaints ───────────────────────────
    elif mod_id == 4:
        if action == "insert":
            # Insert new COMPLAINT
            sql = """
                INSERT INTO COMPLAINT
                    (Complaint_ID, Customer_ID, Description, Complaint_Date, Status)
                VALUES
                    (NVL((SELECT MAX(Complaint_ID) FROM COMPLAINT), 900) + 1,
                     :cid, :desc, SYSDATE, 'Open')
            """
            r = execute_dml(sql, {
                "cid":  int(data["customer_id"]),
                "desc": data["description"],
            }, meta={
                "op":     "File new customer complaint",
                "comp":   "INSERT Statement",
                "tables": ["COMPLAINT"],
            })
            return jsonify(r)

        elif action == "update":
            # Update COMPLAINT.Status — fires trg_auto_complaint_resolution
            sql = """
                UPDATE COMPLAINT
                SET    Status = :status
                WHERE  Complaint_ID = :cmp_id
            """
            r = execute_dml(sql, {
                "status":  data["status"],
                "cmp_id":  int(data["complaint_id"]),
            }, meta={
                "op":     f"Update complaint {data.get('complaint_id')} status to {data.get('status')}",
                "comp":   "UPDATE Statement + Trigger trg_auto_complaint_resolution",
                "tables": ["COMPLAINT"],
            })
            return jsonify(r)

        elif action == "delete":
            # Delete a COMPLAINT
            sql = """
                DELETE FROM COMPLAINT
                WHERE  Complaint_ID = :cmp_id
            """
            r = execute_dml(sql, {"cmp_id": int(data["complaint_id"])}, meta={
                "op":     f"Delete complaint {data.get('complaint_id')}",
                "comp":   "DELETE Statement",
                "tables": ["COMPLAINT"],
            })
            return jsonify(r)

    return jsonify({"error": f"Module {mod_id} not found"}), 404


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/module-queries/<mod_id>/<q_num>
# Executes the [Mx-Qy] SELECT from 04_module_queries.sql (clean dict mapping).
# ─────────────────────────────────────────────────────────────────────────────

# Clean dictionary of all 20 labeled SELECT queries.
# Unicode rupee escape (\u20B9) removed for plain SQL; TO_CHAR format adjusted.
MODULE_QUERIES: dict[tuple[int, int], tuple[str, str, list[str]]] = {

    # ── Module 1: Core Banking ────────────────────────────────────────────
    (1, 1): (
        """
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
        ORDER BY c.Customer_ID
        """,
        "[M1-Q1] Customers with at least one Active account",
        ["CUSTOMER", "CUSTOMER_ACCOUNT", "ACCOUNT"],
    ),
    (1, 2): (
        """
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
        ORDER BY c.Customer_ID, a.Account_No
        """,
        "[M1-Q2] Customer accounts with branch details (4-table JOIN)",
        ["CUSTOMER", "CUSTOMER_ACCOUNT", "ACCOUNT", "BRANCH"],
    ),
    (1, 3): (
        """
        SELECT
            TO_CHAR(t.Transaction_Date, 'MON-YYYY')  AS Txn_Month,
            COUNT(*)                                  AS Total_Txns,
            SUM(CASE WHEN t.Transaction_Type IN ('Deposit','Transfer_Credit')
                     THEN t.Amount ELSE 0 END)        AS Total_Credits,
            SUM(CASE WHEN t.Transaction_Type IN ('Withdrawal','Transfer_Debit',
                                                 'Loan_EMI','FD_Booking')
                     THEN t.Amount ELSE 0 END)        AS Total_Debits,
            ROUND(AVG(t.Amount), 2)                   AS Avg_Txn_Amount
        FROM   TRANSACTION t
        WHERE  t.Transaction_Date >= ADD_MONTHS(SYSDATE, -6)
        GROUP BY TO_CHAR(t.Transaction_Date, 'MON-YYYY'),
                 TRUNC(t.Transaction_Date, 'MM')
        ORDER BY TRUNC(t.Transaction_Date, 'MM')
        """,
        "[M1-Q3] Monthly transaction summary — last 6 months",
        ["TRANSACTION"],
    ),
    (1, 4): (
        """
        SELECT
            c.Customer_ID,
            c.First_Name || ' ' || c.Last_Name   AS Customer_Name,
            SUM(a.Balance)                        AS Total_Balance,
            ROUND(SUM(a.Balance) - (SELECT AVG(Balance) FROM ACCOUNT), 2)
                                                  AS Above_Avg_By
        FROM   CUSTOMER c
        JOIN   CUSTOMER_ACCOUNT ca ON c.Customer_ID = ca.Customer_ID
        JOIN   ACCOUNT a            ON ca.Account_No = a.Account_No
        GROUP BY c.Customer_ID, c.First_Name, c.Last_Name
        HAVING SUM(a.Balance) > (SELECT AVG(Balance) FROM ACCOUNT)
        ORDER BY Total_Balance DESC
        """,
        "[M1-Q4] Customers with total balance above average (Nested Subquery)",
        ["CUSTOMER", "CUSTOMER_ACCOUNT", "ACCOUNT"],
    ),
    (1, 5): (
        """
        SELECT
            c.Customer_ID,
            UPPER(c.First_Name || ' ' || c.Last_Name)           AS Customer_Name_UPPER,
            fn_get_customer_age(c.Customer_ID)                  AS Age_Years,
            TO_CHAR(c.Date_of_Birth, 'DD-Mon-YYYY')             AS DOB_Formatted,
            a.Account_No,
            a.Account_Type,
            ROUND(MONTHS_BETWEEN(SYSDATE, a.Open_Date))         AS Account_Tenure_Months,
            TO_CHAR(a.Balance, 'FM99,99,99,999.00')             AS Balance_INR,
            NVL(cp.Phone_Number, 'No Phone Registered')         AS Primary_Phone,
            CASE
                WHEN a.Balance >= 100000 THEN 'Platinum'
                WHEN a.Balance >= 25000  THEN 'Gold'
                WHEN a.Balance >= 5000   THEN 'Silver'
                ELSE 'Basic'
            END                                                 AS Tier
        FROM   CUSTOMER c
        JOIN   CUSTOMER_ACCOUNT ca ON c.Customer_ID = ca.Customer_ID
        JOIN   ACCOUNT a            ON ca.Account_No = a.Account_No
        LEFT JOIN CUSTOMER_PHONE cp ON c.Customer_ID = cp.Customer_ID
                                   AND cp.Phone_Number = (
                                       SELECT MIN(Phone_Number)
                                       FROM   CUSTOMER_PHONE
                                       WHERE  Customer_ID = c.Customer_ID
                                   )
        ORDER BY c.Customer_ID
        """,
        "[M1-Q5] Customer profile card — fn_get_customer_age + CASE Tier",
        ["CUSTOMER", "CUSTOMER_ACCOUNT", "ACCOUNT", "CUSTOMER_PHONE"],
    ),

    # ── Module 2: Cards, Beneficiaries & Fund Transfers ───────────────────
    (2, 1): (
        """
        SELECT
            c.Card_ID,
            c.Account_No,
            c.Card_Type,
            TO_CHAR(c.Issue_Date,  'DD-Mon-YYYY') AS Issue_Date,
            TO_CHAR(c.Expiry_Date, 'DD-Mon-YYYY') AS Expiry_Date,
            c.Status,
            ROUND(MONTHS_BETWEEN(c.Expiry_Date, SYSDATE)) AS Months_Until_Expiry
        FROM   CARD c
        WHERE  c.Status = 'Active'
          AND  c.Expiry_Date BETWEEN SYSDATE AND ADD_MONTHS(SYSDATE, 6)
        ORDER BY c.Expiry_Date
        """,
        "[M2-Q1] Active cards expiring within 6 months",
        ["CARD"],
    ),
    (2, 2): (
        """
        SELECT
            ft.Transfer_ID,
            c.Customer_ID,
            c.First_Name || ' ' || c.Last_Name              AS Sender_Name,
            ft.Account_No                                    AS Source_Account,
            b.Beneficiary_Name,
            b.IFSC_Code                                      AS Beneficiary_IFSC,
            TO_CHAR(ft.Amount, 'FM99,99,99,999.00')         AS Amount,
            ft.Transfer_Mode,
            TO_CHAR(ft.Transfer_Date, 'DD-Mon-YYYY')        AS Transfer_Date,
            ft.Status                                        AS Transfer_Status
        FROM   FUND_TRANSFER ft
        JOIN   BENEFICIARY b ON ft.Beneficiary_ID = b.Beneficiary_ID
        JOIN   CUSTOMER    c ON b.Customer_ID     = c.Customer_ID
        ORDER BY ft.Transfer_Date DESC
        """,
        "[M2-Q2] Fund transfers with beneficiary and sender details (JOIN)",
        ["FUND_TRANSFER", "BENEFICIARY", "CUSTOMER"],
    ),
    (2, 3): (
        """
        SELECT
            ft.Transfer_Mode,
            COUNT(*)                                             AS Total_Transfers,
            TO_CHAR(SUM(ft.Amount), 'FM99,99,99,999.00')        AS Total_Volume,
            TO_CHAR(ROUND(AVG(ft.Amount), 2), 'FM99,99,999.00') AS Avg_Transfer,
            SUM(CASE WHEN ft.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed_Count,
            SUM(CASE WHEN ft.Status = 'Failed'    THEN 1 ELSE 0 END) AS Failed_Count
        FROM   FUND_TRANSFER ft
        GROUP BY ft.Transfer_Mode
        ORDER BY SUM(ft.Amount) DESC
        """,
        "[M2-Q3] Transfer volume by mode (GROUP BY Aggregation)",
        ["FUND_TRANSFER"],
    ),
    (2, 4): (
        """
        SELECT
            c.Customer_ID,
            c.First_Name || ' ' || c.Last_Name   AS Customer_Name,
            COUNT(b.Beneficiary_ID)               AS Beneficiary_Count
        FROM   CUSTOMER c
        JOIN   BENEFICIARY b ON c.Customer_ID = b.Customer_ID
        GROUP BY c.Customer_ID, c.First_Name, c.Last_Name
        HAVING COUNT(b.Beneficiary_ID) >= ALL (
            SELECT COUNT(*) FROM BENEFICIARY GROUP BY Customer_ID
        )
        ORDER BY Beneficiary_Count DESC
        """,
        "[M2-Q4] Customers with maximum beneficiaries (>= ALL Subquery)",
        ["CUSTOMER", "BENEFICIARY"],
    ),
    (2, 5): (
        """
        SELECT
            crd.Card_ID,
            cst.Customer_ID,
            UPPER(cst.First_Name || ' ' || cst.Last_Name)   AS Customer_Name,
            crd.Card_Type,
            TO_CHAR(crd.Issue_Date,  'DD-Mon-YYYY')         AS Issued_On,
            TO_CHAR(crd.Expiry_Date, 'DD-Mon-YYYY')         AS Expires_On,
            ROUND(MONTHS_BETWEEN(crd.Expiry_Date, SYSDATE)) AS Months_Left,
            crd.Status,
            CASE
                WHEN crd.Status = 'Expired'                            THEN 'ACTION: Renew Immediately'
                WHEN MONTHS_BETWEEN(crd.Expiry_Date, SYSDATE) < 3     THEN 'ACTION: Renewal Soon'
                WHEN MONTHS_BETWEEN(crd.Expiry_Date, SYSDATE) < 6     THEN 'WATCH: Expiring This Year'
                ELSE 'OK'
            END  AS Action_Required
        FROM   CARD crd
        JOIN   ACCOUNT          a  ON crd.Account_No  = a.Account_No
        JOIN   CUSTOMER_ACCOUNT ca ON a.Account_No    = ca.Account_No
        JOIN   CUSTOMER         cst ON ca.Customer_ID = cst.Customer_ID
        ORDER BY crd.Expiry_Date
        """,
        "[M2-Q5] Card expiry dashboard — MONTHS_BETWEEN + CASE",
        ["CARD", "ACCOUNT", "CUSTOMER_ACCOUNT", "CUSTOMER"],
    ),

    # ── Module 3: Loans & Fixed Deposits ──────────────────────────────────
    (3, 1): (
        """
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
        ORDER BY l.Principal_Amount DESC
        """,
        "[M3-Q1] Active / Pending loans ordered by principal",
        ["LOAN"],
    ),
    (3, 2): (
        """
        SELECT
            lp.Payment_ID,
            l.Loan_ID,
            c.First_Name || ' ' || c.Last_Name              AS Customer_Name,
            l.Loan_Type,
            TO_CHAR(l.Principal_Amount, 'FM99,99,99,999.00') AS Loan_Principal,
            TO_CHAR(lp.Payment_Date, 'DD-Mon-YYYY')         AS Payment_Date,
            TO_CHAR(lp.Amount, 'FM99,99,999.00')            AS EMI_Paid,
            lp.Payment_Mode,
            l.Status                                         AS Loan_Status
        FROM   LOAN_PAYMENT lp
        JOIN   LOAN     l ON lp.Loan_ID    = l.Loan_ID
        JOIN   CUSTOMER c ON l.Customer_ID = c.Customer_ID
        ORDER BY l.Loan_ID, lp.Payment_Date
        """,
        "[M3-Q2] Loan repayment history with customer name (JOIN)",
        ["LOAN_PAYMENT", "LOAN", "CUSTOMER"],
    ),
    (3, 3): (
        """
        SELECT
            l.Loan_Type,
            COUNT(*)                                                  AS Total_Loans,
            SUM(CASE WHEN l.Status = 'Active' THEN 1 ELSE 0 END)    AS Active_Count,
            SUM(CASE WHEN l.Status = 'Closed' THEN 1 ELSE 0 END)    AS Closed_Count,
            TO_CHAR(SUM(l.Principal_Amount), 'FM99,99,99,99,999.00') AS Total_Disbursed,
            TO_CHAR(ROUND(AVG(l.Principal_Amount), 2), 'FM99,99,99,999.00') AS Avg_Loan_Size,
            ROUND(AVG(l.Interest_Rate), 2) || '%'                    AS Avg_Rate
        FROM   LOAN l
        GROUP BY l.Loan_Type
        ORDER BY SUM(l.Principal_Amount) DESC
        """,
        "[M3-Q3] Loan statistics by type (GROUP BY Aggregation)",
        ["LOAN"],
    ),
    (3, 4): (
        """
        SELECT
            fd.FD_ID,
            c.Customer_ID,
            c.First_Name || ' ' || c.Last_Name              AS Customer_Name,
            TO_CHAR(fd.Principal_Amount, 'FM99,99,99,999.00') AS Principal,
            fd.Interest_Rate || '%'                          AS Rate,
            TO_CHAR(fd.Start_Date,    'DD-Mon-YYYY')        AS Start_Date,
            TO_CHAR(fd.Maturity_Date, 'DD-Mon-YYYY')        AS Maturity_Date,
            TO_CHAR(fn_calc_fd_maturity_value(fd.FD_ID), 'FM99,99,99,999.00') AS Maturity_Value,
            fd.Status
        FROM   FIXED_DEPOSIT fd
        JOIN   CUSTOMER c ON fd.Customer_ID = c.Customer_ID
        WHERE  fn_calc_fd_maturity_value(fd.FD_ID) > (
            SELECT 2 * AVG(Principal_Amount) FROM FIXED_DEPOSIT
        )
        ORDER BY fn_calc_fd_maturity_value(fd.FD_ID) DESC
        """,
        "[M3-Q4] High-value FDs — fn_calc_fd_maturity_value > 2x average",
        ["FIXED_DEPOSIT", "CUSTOMER"],
    ),
    (3, 5): (
        """
        SELECT
            fd.FD_ID,
            UPPER(c.First_Name || ' ' || c.Last_Name)           AS Customer_Name,
            fn_get_customer_age(c.Customer_ID)                  AS Customer_Age,
            TO_CHAR(fd.Principal_Amount, 'FM99,99,99,999.00')   AS Principal,
            fd.Interest_Rate || '% p.a.'                        AS Interest_Rate,
            ROUND(MONTHS_BETWEEN(fd.Maturity_Date, fd.Start_Date) / 12, 1)
                                                                AS Tenure_Years,
            TO_CHAR(fn_calc_fd_maturity_value(fd.FD_ID), 'FM99,99,99,999.00')
                                                                AS Maturity_Value,
            TO_CHAR(fn_calc_fd_maturity_value(fd.FD_ID) - fd.Principal_Amount,
                    'FM99,99,99,999.00')                        AS Interest_Earned,
            NVL(fd.Status, 'Unknown')                           AS FD_Status,
            CASE
                WHEN fd.Status = 'Matured'            THEN 'Renew or Withdraw'
                WHEN fd.Status = 'Prematurely Closed' THEN 'Premature Penalty Applied'
                ELSE 'Accruing Interest'
            END                                                 AS Recommendation
        FROM   FIXED_DEPOSIT fd
        JOIN   CUSTOMER c ON fd.Customer_ID = c.Customer_ID
        ORDER BY fn_calc_fd_maturity_value(fd.FD_ID) DESC
        """,
        "[M3-Q5] FD profitability report — fn_calc_fd_maturity_value + fn_get_customer_age + CASE",
        ["FIXED_DEPOSIT", "CUSTOMER"],
    ),

    # ── Module 4: Branch, Employees & Complaints ───────────────────────────
    (4, 1): (
        """
        SELECT
            Branch_ID,
            Branch_Name,
            IFSC_Code,
            Address
        FROM   BRANCH
        ORDER BY Branch_ID
        """,
        "[M4-Q1] All branches ordered by ID",
        ["BRANCH"],
    ),
    (4, 2): (
        """
        SELECT
            e.Employee_ID,
            e.Employee_Name,
            e.Designation,
            TO_CHAR(e.Salary, 'FM99,99,99,999.00') AS Salary,
            e.Phone,
            b.Branch_Name,
            b.IFSC_Code
        FROM   EMPLOYEE e
        JOIN   BRANCH b ON e.Branch_ID = b.Branch_ID
        ORDER BY e.Designation, e.Salary DESC
        """,
        "[M4-Q2] Employees with branch details (JOIN)",
        ["EMPLOYEE", "BRANCH"],
    ),
    (4, 3): (
        """
        SELECT
            c.Status,
            COUNT(*)  AS Total_Complaints,
            ROUND(AVG(
                CASE WHEN c.Status = 'Resolved' AND c.Resolution_Date IS NOT NULL
                     THEN c.Resolution_Date - c.Complaint_Date
                     ELSE NULL
                END
            ), 1)     AS Avg_Resolution_Days,
            MIN(c.Complaint_Date) AS Oldest_Complaint,
            MAX(c.Complaint_Date) AS Latest_Complaint
        FROM   COMPLAINT c
        GROUP BY c.Status
        ORDER BY
            CASE c.Status
                WHEN 'Open'        THEN 1
                WHEN 'In Progress' THEN 2
                WHEN 'Resolved'    THEN 3
                ELSE 4
            END
        """,
        "[M4-Q3] Complaint resolution statistics by status (GROUP BY)",
        ["COMPLAINT"],
    ),
    (4, 4): (
        """
        SELECT DISTINCT
            b.Branch_ID,
            b.Branch_Name,
            b.IFSC_Code,
            (SELECT COUNT(*) FROM ACCOUNT  a WHERE a.Branch_ID = b.Branch_ID) AS Total_Accounts,
            (SELECT COUNT(*) FROM EMPLOYEE e WHERE e.Branch_ID = b.Branch_ID) AS Staff_Count
        FROM   BRANCH b
        WHERE  EXISTS (
            SELECT 1
            FROM   COMPLAINT       cmp
            JOIN   CUSTOMER_ACCOUNT ca ON cmp.Customer_ID = ca.Customer_ID
            JOIN   ACCOUNT          a  ON ca.Account_No   = a.Account_No
            WHERE  a.Branch_ID = b.Branch_ID
        )
        ORDER BY b.Branch_ID
        """,
        "[M4-Q4] Branches with at least one complaint (EXISTS + Scalar Subquery)",
        ["BRANCH", "COMPLAINT", "CUSTOMER_ACCOUNT", "ACCOUNT", "EMPLOYEE"],
    ),
    (4, 5): (
        """
        SELECT
            e.Employee_ID,
            UPPER(e.Employee_Name)                         AS Employee_Name_UPPER,
            e.Designation,
            TO_CHAR(e.Salary, 'FM99,99,99,999.00')        AS Monthly_Salary,
            TO_CHAR(ROUND(e.Salary * 12, 2), 'FM99,99,99,999.00') AS Annual_CTC,
            NVL(b.Branch_Name, 'Unassigned')               AS Branch,
            b.IFSC_Code,
            CASE
                WHEN e.Designation = 'Branch Manager'         THEN 'L5 - Senior Leadership'
                WHEN e.Designation IN ('Senior Auditor',
                                       'Loan Officer')        THEN 'L4 - Middle Management'
                WHEN e.Designation = 'Relationship Manager'   THEN 'L3 - Front Office'
                WHEN e.Designation = 'Clerk'                  THEN 'L2 - Operations'
                ELSE 'L1 - Support'
            END                                            AS Pay_Grade,
            CASE
                WHEN e.Salary > 100000 THEN 'High'
                WHEN e.Salary >  70000 THEN 'Mid'
                ELSE 'Entry'
            END                                            AS Salary_Band,
            (SELECT COUNT(*) FROM COMPLAINT cmp
             JOIN   CUSTOMER_ACCOUNT ca ON cmp.Customer_ID = ca.Customer_ID
             JOIN   ACCOUNT          a  ON ca.Account_No   = a.Account_No
             WHERE  a.Branch_ID = e.Branch_ID AND cmp.Status = 'Open'
            )                                              AS Open_Complaints_In_Branch
        FROM   EMPLOYEE e
        JOIN   BRANCH b ON e.Branch_ID = b.Branch_ID
        ORDER BY e.Salary DESC, e.Designation
        """,
        "[M4-Q5] Employee payroll dashboard — NVL + UPPER + CASE + Scalar Subquery",
        ["EMPLOYEE", "BRANCH", "COMPLAINT", "CUSTOMER_ACCOUNT", "ACCOUNT"],
    ),
}


@app.route("/api/module-queries/<int:mod_id>/<int:q_num>")
def module_query(mod_id: int, q_num: int):
    key = (mod_id, q_num)
    if key not in MODULE_QUERIES:
        return jsonify({
            "error": f"No query found for Module {mod_id} Q{q_num}. "
                     f"Valid: mod_id 1-4, q_num 1-5."
        }), 404

    sql, description, tables = MODULE_QUERIES[key]

    result = query_all(sql, meta={
        "op":     description,
        "comp":   "SELECT Query (from 04_module_queries.sql)",
        "tables": tables,
    })
    result["query_label"] = f"M{mod_id}-Q{q_num}"
    result["description"] = description
    return jsonify(result)


# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "true").lower() == "true"
    print(f"\n  Nova Bank — Advanced Bank Management System (BACSE202)")
    print(f"  Flask server starting on http://127.0.0.1:{port}\n")
    app.run(host="0.0.0.0", port=port, debug=debug)
