-- Demonstration SQL queries. Run after 01_schema.sql and 02_sample_data.sql.

-- 1) Open accounts owned by a customer, showing the home branch and live balance.
SELECT
    c.customer_number,
    concat_ws(' ', c.first_name, c.last_name, c.business_name) AS customer_name,
    a.account_number,
    a.account_type,
    b.branch_code,
    b.city,
    bal.current_balance,
    a.currency
FROM customer AS c
JOIN account_holder AS h
  ON h.customer_id = c.customer_id
 AND h.bank_id = c.bank_id
JOIN bank_account AS a
  ON a.account_id = h.account_id
 AND a.bank_id = h.bank_id
JOIN branch AS b
  ON b.branch_id = a.branch_id
 AND b.bank_id = a.bank_id
JOIN account_balances AS bal ON bal.account_id = a.account_id
WHERE c.customer_number = 'CUST-001'
  AND h.removed_at IS NULL
  AND a.status = 'OPEN'
ORDER BY a.account_number;

-- Expected: ACC100001 has 2300.00 USD; ACC100002 has 5200.00 USD.

-- 2) Posted activity on one account, including its matching ledger lines.
SELECT
    t.reference,
    t.transaction_type,
    t.posted_at,
    e.amount AS account_change,
    t.description
FROM bank_account AS a
JOIN transaction_entry AS e
  ON e.ledger_account_id = a.ledger_account_id
JOIN bank_transaction AS t
  ON t.transaction_id = e.transaction_id
 AND t.bank_id = e.bank_id
WHERE a.account_number = 'ACC100001'
  AND t.status = 'POSTED'
ORDER BY t.transaction_id;

-- Expected: seed deposit +2500.00; sample transfer -200.00.

-- 3) Approved or active loans with the borrower, home branch, and outstanding amount.
SELECT
    l.loan_number,
    COALESCE(c.business_name, concat_ws(' ', c.first_name, c.last_name)) AS borrower,
    br.branch_code,
    l.status,
    l.principal,
    lb.outstanding_balance,
    l.currency
FROM loan AS l
JOIN customer AS c
  ON c.customer_id = l.customer_id
 AND c.bank_id = l.bank_id
JOIN branch AS br
  ON br.branch_id = l.branch_id
 AND br.bank_id = l.bank_id
JOIN loan_balances AS lb ON lb.loan_id = l.loan_id
WHERE l.status IN ('APPROVED', 'ACTIVE')
ORDER BY l.loan_number;

-- Expected: LN-2026-001 for Katanga Supplies SARL, ACTIVE,
-- principal 25000.00 and outstanding 24500.00 after one 500.00 repayment.

-- 4) Branch-level customer-account totals (useful for the manager's report).
SELECT
    br.branch_code,
    br.city,
    a.account_type,
    COUNT(*) AS account_count,
    SUM(bal.current_balance) AS total_balance,
    a.currency
FROM branch AS br
JOIN bank_account AS a
  ON a.branch_id = br.branch_id
 AND a.bank_id = br.bank_id
JOIN account_balances AS bal ON bal.account_id = a.account_id
WHERE a.status = 'OPEN'
GROUP BY br.branch_code, br.city, a.account_type, a.currency
ORDER BY br.branch_code, a.account_type;
