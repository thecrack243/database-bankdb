-- Assertion-based smoke tests for the seeded demonstration database.
-- All changes made during these checks are rolled back.

BEGIN;

DO $$
DECLARE
    v_balance NUMERIC(19, 2);
    v_status TEXT;
    v_outstanding NUMERIC(19, 2);
    v_bad_transactions BIGINT;
    v_rejected BOOLEAN;
    v_account_id BIGINT;
    v_ledger_account_id BIGINT;
    v_bank_id BIGINT;
    v_transaction_type TEXT;
    v_i INTEGER;
BEGIN
    SELECT current_balance INTO v_balance
    FROM account_balances WHERE account_number = 'ACC100001';
    IF v_balance <> 2300.00 THEN
        RAISE EXCEPTION 'ACC100001 expected 2300.00, got %', v_balance;
    END IF;

    SELECT current_balance INTO v_balance
    FROM account_balances WHERE account_number = 'ACC100002';
    IF v_balance <> 5200.00 THEN
        RAISE EXCEPTION 'ACC100002 expected 5200.00, got %', v_balance;
    END IF;

    SELECT l.status, lb.outstanding_balance
    INTO v_status, v_outstanding
    FROM loan AS l
    JOIN loan_balances AS lb ON lb.loan_id = l.loan_id
    WHERE l.loan_number = 'LN-2026-001';
    IF v_status <> 'ACTIVE' OR v_outstanding <> 24500.00 THEN
        RAISE EXCEPTION 'Sample loan expected ACTIVE / 24500.00, got % / %',
            v_status, v_outstanding;
    END IF;

    SELECT COUNT(*) INTO v_bad_transactions
    FROM (
        SELECT t.transaction_id
        FROM bank_transaction AS t
        JOIN transaction_entry AS e ON e.transaction_id = t.transaction_id
        WHERE t.status = 'POSTED'
        GROUP BY t.transaction_id
        HAVING SUM(e.amount) <> 0 OR COUNT(*) < 2
    ) AS invalid_postings;
    IF v_bad_transactions <> 0 THEN
        RAISE EXCEPTION 'Found % unbalanced posted transactions', v_bad_transactions;
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM post_withdrawal(
            (SELECT account_id FROM bank_account WHERE account_number = 'ACC100003'),
            5000.00, 'TEST-OVERDRAW-001'
        );
    EXCEPTION WHEN OTHERS THEN
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'An overdrawn withdrawal was unexpectedly accepted';
    END IF;

    v_rejected := FALSE;
    BEGIN
        PERFORM post_transfer(
            (SELECT account_id FROM bank_account WHERE account_number = 'ACC100001'),
            (SELECT account_id FROM bank_account WHERE account_number = 'ACC100002'),
            5000.00, 'TEST-OVERDRAW-TRANSFER-001'
        );
    EXCEPTION WHEN OTHERS THEN
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'An overdrawn transfer was unexpectedly accepted';
    END IF;

    FOR v_i IN 1..6 LOOP
        PERFORM post_withdrawal(
            (SELECT account_id FROM bank_account WHERE account_number = 'ACC100002'),
            1.00, 'TEST-SAVINGS-' || v_i
        );
    END LOOP;
    v_rejected := FALSE;
    BEGIN
        PERFORM post_withdrawal(
            (SELECT account_id FROM bank_account WHERE account_number = 'ACC100002'),
            1.00, 'TEST-SAVINGS-7'
        );
    EXCEPTION WHEN OTHERS THEN
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'Savings account exceeded its six-debit monthly limit';
    END IF;

    PERFORM post_withdrawal(
        (SELECT account_id FROM bank_account WHERE account_number = 'ACC100005'),
        100.00, 'TEST-FD-EARLY-001'
    );
    SELECT current_balance INTO v_balance
    FROM account_balances WHERE account_number = 'ACC100005';
    IF v_balance <> 5895.00 THEN
        RAISE EXCEPTION 'Early fixed-deposit withdrawal expected 5895.00, got %',
            v_balance;
    END IF;
    SELECT t.transaction_type INTO v_transaction_type
    FROM bank_transaction AS t
    WHERE t.reference = 'TEST-FD-EARLY-001';
    IF v_transaction_type <> 'EARLY_WITHDRAWAL' THEN
        RAISE EXCEPTION 'Early fixed-deposit withdrawal type was %', v_transaction_type;
    END IF;

    SELECT account_id, ledger_account_id, bank_id
    INTO v_account_id, v_ledger_account_id, v_bank_id
    FROM bank_account
    WHERE account_number = 'ACC100001';

    v_rejected := FALSE;
    BEGIN
        INSERT INTO bank_transaction (bank_id, reference, transaction_type, currency)
        VALUES (v_bank_id, 'TEST-UNBALANCED-001', 'TRANSFER', 'USD');
        INSERT INTO transaction_entry (bank_id, transaction_id, ledger_account_id, amount)
        SELECT v_bank_id, transaction_id, v_ledger_account_id, -10.00
        FROM bank_transaction
        WHERE reference = 'TEST-UNBALANCED-001';
        UPDATE bank_transaction
        SET status = 'POSTED', posted_at = clock_timestamp()
        WHERE reference = 'TEST-UNBALANCED-001';
        SET CONSTRAINTS ALL IMMEDIATE;
    EXCEPTION WHEN OTHERS THEN
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'An unbalanced posted transaction was unexpectedly accepted';
    END IF;

    v_rejected := FALSE;
    BEGIN
        UPDATE bank_transaction
        SET description = 'This update must fail'
        WHERE reference = 'SEED-DEP-100001';
    EXCEPTION WHEN OTHERS THEN
        v_rejected := TRUE;
    END;
    IF NOT v_rejected THEN
        RAISE EXCEPTION 'A posted transaction was unexpectedly mutable';
    END IF;
END;
$$;

ROLLBACK;
