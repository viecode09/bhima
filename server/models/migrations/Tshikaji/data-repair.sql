/**
This script fixes data issues on a case by case basis.
*/

-- change the transaction to FC from USD
UPDATE bhima_test.general_ledger SET currency_id = 1 WHERE trans_id = "HBB110039";


-- update period totals
CALL bhima_test.zRecalculatePeriodTotals();
