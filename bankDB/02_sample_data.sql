-- Synthetic demonstration data. Run after 01_schema.sql.
-- The sample is deliberately small enough to explain during a presentation.

BEGIN;

INSERT INTO bank (bank_code, name)
VALUES ('RIVERSTONE', 'Riverstone Bank')
ON CONFLICT (bank_code) DO NOTHING;

INSERT INTO branch (
    bank_id, branch_code, name, address, city, region, country_code, phone
)
SELECT bank_id, 'KIN-GOMBE', 'Gombe Branch', '12 Boulevard du 30 Juin',
       'Kinshasa', 'Kinshasa', 'CD', '+243 000 000 001'
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, branch_code) DO NOTHING;

INSERT INTO branch (
    bank_id, branch_code, name, address, city, region, country_code, phone
)
SELECT bank_id, 'LUB-CBD', 'Lubumbashi Central', '8 Avenue Lumumba',
       'Lubumbashi', 'Haut-Katanga', 'CD', '+243 000 000 002'
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, branch_code) DO NOTHING;

INSERT INTO employee (
    bank_id, branch_id, employee_number, first_name, last_name,
    email, phone, job_title, hired_on
)
SELECT b.bank_id, br.branch_id, 'EMP-001', 'Grace', 'Ilunga',
       'grace.ilunga@example.test', '+243 000 000 101', 'Branch Manager', DATE '2024-01-15'
FROM bank AS b
JOIN branch AS br ON br.bank_id = b.bank_id AND br.branch_code = 'KIN-GOMBE'
WHERE b.bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, employee_number) DO NOTHING;

INSERT INTO employee (
    bank_id, branch_id, employee_number, manager_id, first_name, last_name,
    email, phone, job_title, hired_on
)
SELECT b.bank_id, br.branch_id, 'EMP-002', e.employee_id, 'Patrick', 'Mwamba',
       'patrick.mwamba@example.test', '+243 000 000 102', 'Loan Officer', DATE '2024-03-01'
FROM bank AS b
JOIN branch AS br ON br.bank_id = b.bank_id AND br.branch_code = 'LUB-CBD'
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-001'
WHERE b.bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, employee_number) DO NOTHING;

INSERT INTO customer (
    bank_id, customer_number, customer_type, first_name, last_name,
    national_id, email, phone, address, city, country_code
)
SELECT bank_id, 'CUST-001', 'PERSONAL', 'Amina', 'Mbuyi',
       'CD-NID-0001', 'amina.mbuyi@example.test', '+243 000 001 001',
       '24 Avenue des Huileries', 'Kinshasa', 'CD'
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, customer_number) DO NOTHING;

INSERT INTO customer (
    bank_id, customer_number, customer_type, first_name, last_name,
    national_id, email, phone, address, city, country_code
)
SELECT bank_id, 'CUST-002', 'PERSONAL', 'Jean', 'Kabila',
       'CD-NID-0002', 'jean.kabila@example.test', '+243 000 002 001',
       '5 Avenue Kasa-Vubu', 'Kinshasa', 'CD'
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, customer_number) DO NOTHING;

INSERT INTO customer (
    bank_id, customer_number, customer_type, business_name,
    tax_id, email, phone, address, city, country_code
)
SELECT bank_id, 'CUST-003', 'BUSINESS', 'Katanga Supplies SARL',
       'CD-TAX-1003', 'accounts@katangasupplies.example.test',
       '+243 000 003 001', '18 Avenue Sendwe', 'Lubumbashi', 'CD'
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, customer_number) DO NOTHING;

-- System ledger accounts balance the customer-facing entries.
INSERT INTO ledger_account (bank_id, account_code, name, ledger_class, currency, is_system)
SELECT bank_id, 'SYS-CASH-USD', 'Cash clearing - USD', 'CASH_CLEARING', 'USD', TRUE
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, account_code) DO NOTHING;

INSERT INTO ledger_account (bank_id, account_code, name, ledger_class, currency, is_system)
SELECT bank_id, 'SYS-INTEREST-USD', 'Interest expense - USD', 'INTEREST_EXPENSE', 'USD', TRUE
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, account_code) DO NOTHING;

INSERT INTO ledger_account (bank_id, account_code, name, ledger_class, currency, is_system)
SELECT bank_id, 'SYS-FEE-USD', 'Fee income - USD', 'FEE_INCOME', 'USD', TRUE
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, account_code) DO NOTHING;

INSERT INTO ledger_account (bank_id, account_code, name, ledger_class, currency, is_system)
SELECT bank_id, 'SYS-EQUITY-USD', 'Opening equity - USD', 'OPENING_EQUITY', 'USD', TRUE
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, account_code) DO NOTHING;

INSERT INTO ledger_account (bank_id, account_code, name, ledger_class, currency, is_system)
SELECT bank_id, 'SYS-ADJUSTMENT-USD', 'Adjustment clearing - USD',
       'ADJUSTMENT_CLEARING', 'USD', TRUE
FROM bank WHERE bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, account_code) DO NOTHING;

-- Each customer deposit account has a corresponding ledger account.
INSERT INTO ledger_account (
    bank_id, branch_id, account_code, name, ledger_class, currency
)
SELECT b.bank_id, br.branch_id, codes.account_code, codes.account_name,
       'CUSTOMER_DEPOSIT', 'USD'
FROM bank AS b
JOIN branch AS br ON br.bank_id = b.bank_id
CROSS JOIN (VALUES
    ('CUST-ACC-100001', 'Amina Mbuyi - Checking'),
    ('CUST-ACC-100002', 'Amina Mbuyi - Savings'),
    ('CUST-ACC-100003', 'Jean Kabila - Checking'),
    ('CUST-ACC-100005', 'Jean Kabila - Fixed Deposit'),
    ('CUST-ACC-100004', 'Katanga Supplies - Checking')
) AS codes(account_code, account_name)
WHERE b.bank_code = 'RIVERSTONE'
  AND (
      (codes.account_code IN ('CUST-ACC-100001', 'CUST-ACC-100002', 'CUST-ACC-100005')
       AND br.branch_code = 'KIN-GOMBE')
      OR (codes.account_code = 'CUST-ACC-100003' AND br.branch_code = 'KIN-GOMBE')
      OR (codes.account_code = 'CUST-ACC-100004' AND br.branch_code = 'LUB-CBD')
  )
ON CONFLICT (bank_id, account_code) DO NOTHING;

INSERT INTO bank_account (
    bank_id, branch_id, ledger_account_id, account_number,
    account_type, currency, overdraft_limit, interest_rate, withdrawal_limit,
    term_months, early_withdrawal_penalty_rate
)
SELECT
    b.bank_id, br.branch_id, la.ledger_account_id, v.account_number,
    v.account_type, 'USD', v.overdraft_limit, v.interest_rate, v.withdrawal_limit,
    v.term_months, v.early_withdrawal_penalty_rate
FROM bank AS b
JOIN (VALUES
    ('ACC100001', 'CUST-ACC-100001', 'CHECKING', 500.00::NUMERIC, 0::NUMERIC, NULL::INTEGER, NULL::INTEGER, NULL::NUMERIC, 'KIN-GOMBE'),
    ('ACC100002', 'CUST-ACC-100002', 'SAVINGS', 0::NUMERIC, 0.025::NUMERIC, 6, NULL::INTEGER, NULL::NUMERIC, 'KIN-GOMBE'),
    ('ACC100003', 'CUST-ACC-100003', 'CHECKING', 0::NUMERIC, 0::NUMERIC, NULL::INTEGER, NULL::INTEGER, NULL::NUMERIC, 'KIN-GOMBE'),
    ('ACC100004', 'CUST-ACC-100004', 'CHECKING', 1000.00::NUMERIC, 0::NUMERIC, NULL::INTEGER, NULL::INTEGER, NULL::NUMERIC, 'LUB-CBD'),
    ('ACC100005', 'CUST-ACC-100005', 'FIXED_DEPOSIT', 0::NUMERIC, 0.045::NUMERIC, NULL::INTEGER, 12, 0.05::NUMERIC, 'KIN-GOMBE')
) AS v(account_number, ledger_code, account_type, overdraft_limit, interest_rate, withdrawal_limit, term_months, early_withdrawal_penalty_rate, branch_code)
    ON TRUE
JOIN branch AS br ON br.bank_id = b.bank_id AND br.branch_code = v.branch_code
JOIN ledger_account AS la ON la.bank_id = b.bank_id AND la.account_code = v.ledger_code
WHERE b.bank_code = 'RIVERSTONE'
ON CONFLICT (account_number) DO NOTHING;

INSERT INTO account_holder (bank_id, account_id, customer_id, holder_role)
SELECT b.bank_id, a.account_id, c.customer_id, 'OWNER'
FROM bank AS b
JOIN bank_account AS a ON a.bank_id = b.bank_id
JOIN customer AS c ON c.bank_id = b.bank_id
WHERE b.bank_code = 'RIVERSTONE'
  AND (
      (a.account_number IN ('ACC100001', 'ACC100002') AND c.customer_number = 'CUST-001')
      OR (a.account_number IN ('ACC100003', 'ACC100005') AND c.customer_number = 'CUST-002')
      OR (a.account_number = 'ACC100004' AND c.customer_number = 'CUST-003')
  )
ON CONFLICT (account_id, customer_id) DO NOTHING;

-- A loan-specific receivable ledger keeps principal and repayments traceable.
INSERT INTO ledger_account (
    bank_id, branch_id, account_code, name, ledger_class, currency
)
SELECT b.bank_id, br.branch_id, 'LOAN-LN-2026-001',
       'Loan receivable - LN-2026-001', 'LOAN_RECEIVABLE', 'USD'
FROM bank AS b
JOIN branch AS br ON br.bank_id = b.bank_id AND br.branch_code = 'LUB-CBD'
WHERE b.bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, account_code) DO NOTHING;

INSERT INTO loan (
    bank_id, loan_number, customer_id, branch_id, loan_officer_id,
    disbursement_account_id, ledger_account_id, loan_type, currency,
    principal, annual_interest_rate, term_months, status, approved_at
)
SELECT b.bank_id, 'LN-2026-001', c.customer_id, br.branch_id, e.employee_id,
       a.account_id, la.ledger_account_id, 'BUSINESS', 'USD',
       25000.00, 0.120000, 24, 'APPROVED', TIMESTAMPTZ '2026-10-15 09:00:00+00'
FROM bank AS b
JOIN customer AS c ON c.bank_id = b.bank_id AND c.customer_number = 'CUST-003'
JOIN branch AS br ON br.bank_id = b.bank_id AND br.branch_code = 'LUB-CBD'
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-002'
JOIN bank_account AS a ON a.bank_id = b.bank_id AND a.account_number = 'ACC100004'
JOIN ledger_account AS la ON la.bank_id = b.bank_id AND la.account_code = 'LOAN-LN-2026-001'
WHERE b.bank_code = 'RIVERSTONE'
ON CONFLICT (bank_id, loan_number) DO NOTHING;

-- Seed customer balances using the same atomic posting function as the demo.
SELECT post_deposit(a.account_id, 2500.00, 'SEED-DEP-100001', e.employee_id, 'Opening sample deposit')
FROM bank_account AS a
JOIN bank AS b ON b.bank_id = a.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-001'
WHERE b.bank_code = 'RIVERSTONE' AND a.account_number = 'ACC100001'
  AND NOT EXISTS (SELECT 1 FROM bank_transaction WHERE reference = 'SEED-DEP-100001');

SELECT post_deposit(a.account_id, 5000.00, 'SEED-DEP-100002', e.employee_id, 'Opening sample deposit')
FROM bank_account AS a
JOIN bank AS b ON b.bank_id = a.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-001'
WHERE b.bank_code = 'RIVERSTONE' AND a.account_number = 'ACC100002'
  AND NOT EXISTS (SELECT 1 FROM bank_transaction WHERE reference = 'SEED-DEP-100002');

SELECT post_deposit(a.account_id, 4000.00, 'SEED-DEP-100003', e.employee_id, 'Opening sample deposit')
FROM bank_account AS a
JOIN bank AS b ON b.bank_id = a.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-001'
WHERE b.bank_code = 'RIVERSTONE' AND a.account_number = 'ACC100003'
  AND NOT EXISTS (SELECT 1 FROM bank_transaction WHERE reference = 'SEED-DEP-100003');

SELECT post_deposit(a.account_id, 6000.00, 'SEED-DEP-100005', e.employee_id, 'Fixed-deposit principal')
FROM bank_account AS a
JOIN bank AS b ON b.bank_id = a.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-001'
WHERE b.bank_code = 'RIVERSTONE' AND a.account_number = 'ACC100005'
  AND NOT EXISTS (SELECT 1 FROM bank_transaction WHERE reference = 'SEED-DEP-100005');

SELECT post_deposit(a.account_id, 10000.00, 'SEED-DEP-100004', e.employee_id, 'Opening sample deposit')
FROM bank_account AS a
JOIN bank AS b ON b.bank_id = a.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-002'
WHERE b.bank_code = 'RIVERSTONE' AND a.account_number = 'ACC100004'
  AND NOT EXISTS (SELECT 1 FROM bank_transaction WHERE reference = 'SEED-DEP-100004');

SELECT post_transfer(src.account_id, dst.account_id, 200.00, 'SEED-TRF-100001',
                     e.employee_id, 'Sample transfer from checking to savings')
FROM bank_account AS src
JOIN bank_account AS dst ON dst.account_number = 'ACC100002'
JOIN bank AS b ON b.bank_id = src.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-001'
WHERE b.bank_code = 'RIVERSTONE' AND src.account_number = 'ACC100001'
  AND NOT EXISTS (SELECT 1 FROM bank_transaction WHERE reference = 'SEED-TRF-100001');

SELECT post_loan_disbursement(l.loan_id, 'SEED-LOAN-DISB-001',
                              e.employee_id, 'Sample approved-loan disbursement')
FROM loan AS l
JOIN bank AS b ON b.bank_id = l.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-002'
WHERE b.bank_code = 'RIVERSTONE'
  AND l.loan_number = 'LN-2026-001'
  AND l.status = 'APPROVED'
  AND NOT EXISTS (
      SELECT 1 FROM bank_transaction WHERE reference = 'SEED-LOAN-DISB-001'
  );

SELECT post_loan_repayment(l.loan_id, l.disbursement_account_id, 500.00,
                           'SEED-LOAN-PAY-001', e.employee_id,
                           'Sample loan repayment')
FROM loan AS l
JOIN bank AS b ON b.bank_id = l.bank_id
JOIN employee AS e ON e.bank_id = b.bank_id AND e.employee_number = 'EMP-002'
WHERE b.bank_code = 'RIVERSTONE'
  AND l.loan_number = 'LN-2026-001'
  AND l.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1 FROM bank_transaction WHERE reference = 'SEED-LOAN-PAY-001'
  );

COMMIT;
