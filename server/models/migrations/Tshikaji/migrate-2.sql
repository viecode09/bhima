
-- optimisations for bulk data import
-- see https://dev.mysql.com/doc/refman/5.7/en/optimizing-innodb-bulk-data-loading.html
SET autocommit=0;
SET foreign_key_checks=0;
SET unique_checks=0;

/*!40101 SET NAMES utf8 */;
/*!40101 SET character_set_client = utf8 */;

/*
Useful Functions/ Procedures
*/

DROP PROCEDURE IF EXISTS MergeSector;
DROP PROCEDURE IF EXISTS VouchersFromTransactionTypeGL;
DROP PROCEDURE IF EXISTS VouchersFromTransactionTypePJ;

DELIMITER $$

CREATE PROCEDURE ComputePeriodZero(
  IN year INT
) BEGIN
  DECLARE fyId INT;
  DECLARE previousFyId INT;
  DECLARE enterpriseId INT;
  DECLARE periodZeroId INT;

  SELECT id, previous_fiscal_year_id, enterprise_id
    INTO fyId, previousFyId, enterpriseId
  FROM fiscal_year WHERE YEAR(start_date) = year;

  SET periodZeroId = CONCAT(year, 0);

  -- UPDATE period SET start_date = DATE(CONCAT(year, '-01-01')) AND end_date = DATE(CONCAT(year, '-01-01'));

  INSERT INTO period_total (enterprise_id, fiscal_year_id, period_id, account_id, credit, debit, locked)
    SELECT enterpriseId, fyId, periodZeroId, account_id, SUM(credit), SUM(debit), 0
    FROM period_total
    WHERE fiscal_year_id = previousFyId
    GROUP BY account_id;
END $$


-- NOTE: this uses 2.x's tables, not 1.x's
CREATE PROCEDURE VouchersFromTransactionTypeGL(
  IN transactionTypeId INT
) BEGIN
  CREATE TEMPORARY TABLE transactions AS
    SELECT * FROM general_ledger WHERE transaction_type_id = transactionTypeId;

  CREATE TEMPORARY TABLE mapping AS
    SELECT DISTINCT trans_id, HUID(UUID()) record_uuid FROM general_ledger WHERE transaction_type_id = transactionTypeId;

  CREATE TEMPORARY TABLE stage_voucher AS
    SELECT m.record_uuid, MAX(trans_date) date, MAX(project_id) project_id, NULL AS reference, MAX(currency_id) currency_id,
      SUM(debit) amount, MAX(description) description, MAX(user_id) user_id, MAX(trans_date) created_at, transactionTypeId AS type_id
      FROM transactions t JOIN mapping m ON t.trans_id = m.trans_id
      GROUP BY t.trans_id;

  INSERT INTO voucher (`uuid`, `date`, project_id, reference, currency_id, amount, description, user_id, created_at, type_id)
    SELECT record_uuid, date, project_id, reference, currency_id, amount, description, user_id, created_at, type_id
    FROM stage_voucher;


  INSERT INTO voucher_item (`uuid`, account_id, debit, credit, voucher_uuid, document_uuid, entity_uuid)
    SELECT HUID(UUID()), account_id, debit, credit, m.record_uuid, reference_uuid, entity_uuid
    FROM transactions t JOIN mapping m ON t.trans_id = m.trans_id;

  UPDATE general_ledger gl JOIN mapping m ON gl.trans_id = m.trans_id SET gl.record_uuid = m.record_uuid WHERE transaction_type_id = transactionTypeId;

  DROP TABLE transactions;
  DROP TABLE mapping;
  DROP TABLE stage_voucher;
END $$

CREATE PROCEDURE VouchersFromTransactionTypePJ(
  IN transactionTypeId INT
) BEGIN
  CREATE TEMPORARY TABLE transactions AS
    SELECT * FROM posting_journal WHERE transaction_type_id = transactionTypeId;

  CREATE TEMPORARY TABLE mapping AS
    SELECT DISTINCT trans_id, HUID(UUID()) record_uuid FROM posting_journal WHERE transaction_type_id = transactionTypeId;

  CREATE TEMPORARY TABLE stage_voucher AS
    SELECT m.record_uuid, MAX(trans_date) date, MAX(project_id) project_id, NULL AS reference, MAX(currency_id) currency_id,
      SUM(debit) amount, MAX(description) description, MAX(user_id) user_id, MAX(trans_date) created_at, transactionTypeId AS type_id
      FROM transactions t JOIN mapping m ON t.trans_id = m.trans_id
      GROUP BY t.trans_id;

  INSERT INTO voucher (`uuid`, `date`, project_id, reference, currency_id, amount, description, user_id, created_at, type_id)
    SELECT record_uuid, date, project_id, reference, currency_id, amount, description, user_id, created_at, type_id
    FROM stage_voucher;


  INSERT INTO voucher_item (`uuid`, account_id, debit, credit, voucher_uuid, document_uuid, entity_uuid)
    SELECT HUID(UUID()), account_id, debit, credit, m.record_uuid, reference_uuid, entity_uuid
    FROM transactions t JOIN mapping m ON t.trans_id = m.trans_id;

  UPDATE posting_journal gl JOIN mapping m ON gl.trans_id = m.trans_id SET gl.record_uuid = m.record_uuid WHERE transaction_type_id = transactionTypeId;

  DROP TABLE transactions;
  DROP TABLE mapping;
  DROP TABLE stage_voucher;
END $$

DELIMITER ;

-- journal
CALL VouchersFromTransactionTypePJ(4);
CALL VouchersFromTransactionTypeGL(4);
-- accounting
CALL VouchersFromTransactionTypePJ(5);
CALL VouchersFromTransactionTypeGL(5);
-- pcash_convention
CALL VouchersFromTransactionTypePJ(8);
CALL VouchersFromTransactionTypeGL(8);
-- import_automatique
CALL VouchersFromTransactionTypePJ(9);
CALL VouchersFromTransactionTypeGL(9);
-- pcash_transfer
CALL VouchersFromTransactionTypePJ(10);
CALL VouchersFromTransactionTypeGL(10);
-- generic_income
CALL VouchersFromTransactionTypePJ(11);
CALL VouchersFromTransactionTypeGL(11);
-- distribution
CALL VouchersFromTransactionTypePJ(12);
CALL VouchersFromTransactionTypeGL(12);
-- stock loss
CALL VouchersFromTransactionTypePJ(13);
CALL VouchersFromTransactionTypeGL(13);
-- payroll
CALL VouchersFromTransactionTypePJ(14);
CALL VouchersFromTransactionTypeGL(14);
-- donation
CALL VouchersFromTransactionTypePJ(15);
CALL VouchersFromTransactionTypeGL(15);
-- tax_payment
CALL VouchersFromTransactionTypePJ(16);
CALL VouchersFromTransactionTypeGL(16);
-- cotisation_engagement
CALL VouchersFromTransactionTypePJ(17);
CALL VouchersFromTransactionTypeGL(17);
-- tax_engagement
CALL VouchersFromTransactionTypePJ(18);
CALL VouchersFromTransactionTypeGL(18);
-- cotisation_paiement
CALL VouchersFromTransactionTypePJ(19);
CALL VouchersFromTransactionTypeGL(19);
-- generic_expense
CALL VouchersFromTransactionTypePJ(20);
CALL VouchersFromTransactionTypeGL(20);
-- indirect_purchase
CALL VouchersFromTransactionTypePJ(21);
CALL VouchersFromTransactionTypeGL(21);
-- confirm_purchase
CALL VouchersFromTransactionTypePJ(22);
CALL VouchersFromTransactionTypeGL(22);
-- salary_advance
CALL VouchersFromTransactionTypePJ(23);
CALL VouchersFromTransactionTypeGL(23);
-- employee_invoice
CALL VouchersFromTransactionTypePJ(24);
CALL VouchersFromTransactionTypeGL(24);
-- pcash_employee
CALL VouchersFromTransactionTypePJ(25);
CALL VouchersFromTransactionTypeGL(25);
-- cash_return
CALL VouchersFromTransactionTypePJ(27);
CALL VouchersFromTransactionTypeGL(27);
-- reversing_stock
CALL VouchersFromTransactionTypePJ(28);
CALL VouchersFromTransactionTypeGL(28);
-- confirmation_integration
CALL VouchersFromTransactionTypePJ(32);
CALL VouchersFromTransactionTypeGL(32);
-- group_invoice
CALL VouchersFromTransactionTypePJ(33);
CALL VouchersFromTransactionTypeGL(33);
-- service_return_stock
CALL VouchersFromTransactionTypePJ(34);
CALL VouchersFromTransactionTypeGL(34);

-- WARNING: cash is last because it takes the longest
-- select project_id, reference, count(reference) n from cash GROUP BY project_id, reference HAVING n > 1;
CREATE TEMPORARY TABLE cash_migrate AS SELECT * FROM bhima.cash ORDER BY bhima.cash.uuid;
ALTER TABLE cash_migrate ADD INDEX `uuid` (`uuid`);

-- we have duplicate references to clean up
CREATE TEMPORARY TABLE cash_reference_dupes AS
  SELECT project_id, reference, MIN(uuid) AS uuid, 0 AS 'n' FROM cash_migrate GROUP BY project_id, reference HAVING COUNT(reference) > 1;

SET @c = (SELECT max(reference) FROM cash_migrate);
UPDATE cash_reference_dupes SET n = (@c := @c + 1);

-- choose one project at random to shift up.  We will use HBB
UPDATE cash_migrate cm JOIN cash_reference_dupes cd ON cm.uuid = cd.uuid SET cm.reference = cd.n;

CREATE TEMPORARY TABLE reversed_cash_payments AS SELECT HUID(cash_uuid) AS `uuid` FROM bhima.cash_discard;
ALTER TABLE reversed_cash_payments ADD INDEX `uuid` (`uuid`);

INSERT INTO cash (`uuid`, project_id, reference, `date`, debtor_uuid, currency_id, amount, user_id, cashbox_id, description, is_caution, reversed, edited, created_at)
  SELECT HUID(cm.uuid), cm.project_id, cm.reference, cm.`date`, HUID(cm.deb_cred_uuid), cm.currency_id, cm.cost, cm.user_id, cm.cashbox_id, cm.description, cm.is_caution, 0, 0, cm.`date`
  FROM cash_migrate cm;

UPDATE cash SET reversed = 1 WHERE cash.uuid IN (SELECT uuid from reversed_cash_payments);
DROP TABLE reversed_cash_payments;

/* CASH ITEM */
/*
*/
INSERT INTO cash_item (`uuid`, cash_uuid, amount, invoice_uuid)
  SELECT HUID(`uuid`), HUID(cash_uuid), allocated_cost, HUID(invoice_uuid) FROM bhima.cash_item;

CREATE TEMPORARY TABLE `cash_record_map` AS SELECT HUID(c.uuid) AS uuid, p.trans_id FROM bhima.cash c JOIN bhima.posting_journal p ON c.uuid = p.inv_po_id;
INSERT INTO `cash_record_map` SELECT HUID(c.uuid) AS uuid, p.trans_id FROM bhima.cash c JOIN bhima.general_ledger p ON c.uuid = p.inv_po_id;

ALTER TABLE cash_record_map MODIFY trans_id VARCHAR(100) NOT NULL COLLATE utf8_general_ci;
ALTER TABLE cash_record_map ADD INDEX `trans_id` (`trans_id`);

UPDATE posting_journal pj JOIN cash_record_map crm ON pj.trans_id = crm.trans_id SET pj.record_uuid = crm.uuid;
UPDATE general_ledger gl JOIN cash_record_map crm ON gl.trans_id = crm.trans_id SET gl.record_uuid = crm.uuid;

DROP TABLE cash_reference_dupes;
DROP TABLE cash_migrate;
DROP TABLE cash_record_map;

/*
Linking - Journal/General Ledger

Update Journal + GL make cash payments reference invoices.

*/
CREATE TEMPORARY TABLE invoice_links AS
  SELECT gl.uuid, ci.invoice_uuid FROM cash_item ci JOIN general_ledger gl ON
    ci.cash_uuid = gl.record_uuid AND
    ci.amount = gl.credit AND
    gl.entity_uuid IS NOT NULL;

INSERT INTO invoice_links
  SELECT gl.uuid, ci.invoice_uuid FROM cash_item ci JOIN posting_journal gl ON
    ci.cash_uuid = gl.record_uuid AND
    ci.amount = gl.credit AND
    gl.entity_uuid IS NOT NULL;

ALTER TABLE invoice_links ADD INDEX `uuid` (`uuid`);

UPDATE general_ledger gl JOIN invoice_links iv ON gl.uuid = iv.uuid SET gl.reference_uuid = iv.invoice_uuid;
UPDATE posting_journal gl JOIN invoice_links iv ON gl.uuid = iv.uuid SET gl.reference_uuid = iv.invoice_uuid;

DROP TABLE invoice_links;

DROP PROCEDURE VouchersFromTransactionTypeGL;
DROP PROCEDURE VouchersFromTransactionTypePJ;

-- compute period 0 for the following fiscal years
/*
CALL ComputePeriodZero(2015);
CALL ComputePeriodZero(2016);
CALL ComputePeriodZero(2017);
CALL ComputePeriodZero(2018);
*/

/* RECOMPUTE */
Call ComputeAccountClass();
Call zRecomputeEntityMap();
Call zRecomputeDocumentMap();
Call zRecalculatePeriodTotals();

COMMIT;

/* ENABLE AUTOCOMMIT AFTER THE SCRIPT */
SET autocommit=1;
SET foreign_key_checks=1;
SET unique_checks=1;
