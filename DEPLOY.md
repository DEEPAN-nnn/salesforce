# Deploy Amount Paid rollup

Do **not** deploy `Work_Order_Client_PO_Status_Changed`. That flow does not write Amount Paid; it is checked in only as evidence. See `docs/AMOUNT_PAID_INVESTIGATION.md`.


## What to deploy

- `AmountPaidRollup`
- `AmountPaidRollupInvocable`
- `AmountPaidRollupBatch`
- `AmountPaidRollupTest`
- Trigger `PaymentRecordAmountPaidRollup` on `Payment_Record__c`

If the trigger fails to deploy because the object API name is not `Payment_Record__c`:

1. In Setup, open the Payment Record object and copy the API name.
2. Rename the trigger object in `force-app/main/default/triggers/PaymentRecordAmountPaidRollup.trigger`.
3. Deploy classes first, then the renamed trigger.

Classes still work without the trigger: call invocable action **Roll up Payment Amount Paid to Work Order** from a record-triggered flow on Payment Record, and/or schedule the batch.

## Deploy

```bash
sf project deploy start --manifest manifest/package.xml --wait 10
```

Run tests: `AmountPaidRollupTest`.

## Backfill WOs that already have Payment Records

Developer Console → Anonymous Apex:

```apex
Database.executeBatch(new AmountPaidRollupBatch(), 50);
```

Optional daily schedule:

```apex
System.schedule(
    'Amount Paid Rollup',
    '0 30 2 * * ?',
    new AmountPaidRollupBatch()
);
```

## After deploy

Open Work Order `05101444` (or any reported WO). Amount Paid should equal the sum of Payment Record Amount Paid ($126.00 on the example). If it stays blank, check debug logs for `AmountPaidRollup failed for Work Order` — Exported-status validation may be blocking the parent update.
