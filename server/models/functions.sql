/*
  This file contains all the stored functions used in bhima's database and queries.
  It should be loaded after schema.sql.
*/

DELIMITER $$

/*
  HUID(hexUuid)

  Converts a hex uuid (36 chars) into a binary uuid (16 bytes)
*/
CREATE FUNCTION HUID(_uuid CHAR(36))
RETURNS BINARY(16) DETERMINISTIC
  RETURN UNHEX(REPLACE(_uuid, '-', ''));
$$


/*
  BUID(binaryUuid)

  Converts a binary uuid (16 bytes) to dash-delimited hex UUID (36 characters).
*/
CREATE FUNCTION BUID(b BINARY(16))
RETURNS CHAR(36) DETERMINISTIC
BEGIN
  DECLARE hex CHAR(32);
  SET hex = HEX(b);
  RETURN LCASE(CONCAT_WS('-', SUBSTR(hex,1, 8), SUBSTR(hex, 9,4), SUBSTR(hex, 13,4), SUBSTR(hex, 17,4), SUBSTR(hex, 21, 12)));
END
$$


/*
  GetExchangeRate(enterpriseId, currencyId, date)

  Returns the current exchange rate (`rate` column) for the given currency from
  the database.  It is up to the callee to determine how to treat the rate.

  @TODO Is there some way to make this do the IF() select as well?

  EXAMPLE

  SET currentExchangeRate = GetExchangeRate(enterpriseId, currencyId, date);
  SET currentExchangeRate = (SELECT IF(recordCurrencyId = enterpriseCurrencyId, 1, currentExchangeRate));
*/
CREATE FUNCTION GetExchangeRate(
  enterpriseId INT,
  currencyId INT,
  date TIMESTAMP
)
RETURNS DECIMAL(19, 8) DETERMINISTIC
BEGIN
  RETURN (
    SELECT e.rate FROM exchange_rate AS e
    WHERE e.enterprise_id = enterpriseId AND e.currency_id = currencyId AND e.date <= date
    ORDER BY e.date DESC LIMIT 1
  );
END $$



/*
  GenerateTransactionId(projectId)

  Returns a new transaction id to be stored in the database by scanning for used
  ids in the posting_journal and general_ledger tables.

  Optimisation note: on the second iteration of this function a SUBSELECT to fetch
  the project string is used in favour of a table JOIN. This is because the previous function made a call
  to `MAX` which aggregates results and actually returns the project string even
  if there are no records in either journal table. Without this aggregate call
  nothing is returned and a NULL id will be returned if there are no records.

  EXAMPLE

  SET transId = SELECT GenerateTransactionid(projectid);
*/
CREATE FUNCTION GenerateTransactionId(
  target_project_id SMALLINT(5)
)
RETURNS VARCHAR(100) DETERMINISTIC
BEGIN
  RETURN (
    SELECT CONCAT(
      (SELECT abbr AS project_string FROM project WHERE id = target_project_id),
      IFNULL(MAX(current_max) + 1, 1)
    ) AS id
    FROM (
      (
        SELECT trans_id_reference_number AS current_max
        FROM general_ledger
        WHERE project_id = target_project_id
        ORDER BY trans_id_reference_number DESC
        LIMIT 1
      )
      UNION
      (
        SELECT trans_id_reference_number AS current_max FROM posting_journal
        WHERE project_id = target_project_id
        ORDER BY trans_id_reference_number DESC
        LIMIT 1
      )
    )A
  );
END $$

/*
  PredictAccountTypeId(accountNumber)

  Returns the account type id of the given account number
*/
CREATE FUNCTION PredictAccountTypeId(accountNumber INT(11))
RETURNS MEDIUMINT(8) DETERMINISTIC
BEGIN
  DECLARE oneDigit CHAR(1);
  DECLARE twoDigit CHAR(2);
  DECLARE accountType VARCHAR(20);
  DECLARE accountTypeId MEDIUMINT(8);
  SET oneDigit = (SELECT LEFT(accountNumber, 1));
  SET twoDigit = (SELECT LEFT(accountNumber, 2));

  IF (oneDigit = '1') THEN
    SET accountType = 'equity';
  END IF;

  IF (oneDigit = '2' OR oneDigit = '3' OR oneDigit = '4' OR oneDigit = '5') THEN
    SET accountType = 'asset';
  END IF;

  IF (oneDigit = '6') THEN
    SET accountType = 'expense';
  END IF;

  IF (oneDigit = '7') THEN
    SET accountType = 'income';
  END IF;

  IF (twoDigit = '40') THEN
    SET accountType = 'liability';
  END IF;

  IF (twoDigit = '80' OR twoDigit = '82' OR twoDigit = '84' OR twoDigit = '86' OR twoDigit = '88') THEN
    SET accountType = 'income';
  END IF;

  IF (twoDigit = '81' OR twoDigit = '83' OR twoDigit = '85' OR twoDigit = '87' OR twoDigit = '89') THEN
    SET accountType = 'expense';
  END IF;

  SET accountTypeId = (SELECT id FROM account_type WHERE `type` = accountType LIMIT 1);

  RETURN accountTypeId;
END
$$

DELIMITER ;
