# Work Order Amount Paid vs Payment Records

## Answer for bizdev

**Work Order `Amount Paid` is supposed to hold a dollar amount, but it is not wired to Payment Records today.**

It will **not** update just because a Payment Record exists. Those are two different fields on two different objects.

| Place | What the screenshot showed (WO 05101444) |
| --- | --- |
| Payment Record `852701` → Amount Paid | **$126.00** (populated) |
| Payment Record → Installer Amount | **$101.00** |
| Work Order Accounting Fields → Amount Paid | **blank** |
| Installer Payment Complete / Client Payment Complete | checked |
| Installer Pay Date / Client Payment Date | 1/16/2026 and 1/26/2026 |
| Exported to Accounting | checked (export date 1/7/2026) |
| Key Rec # / Manually Key Rec'd | blank / unchecked |
| Payment Record Invoice/Payment | blank |

## Why this is not a roll-up

The Work Order field shows an **inline-edit pencil**. In Salesforce:

- **Formula** fields are not inline-editable
- **Roll-Up Summary** fields are not inline-editable

So Work Order Amount Paid is a normal writable currency field. Payment Record Amount Paid can be $126 while the parent stays empty unless a Flow, Apex trigger, Process Builder, or accounting writeback **copies** it.

This GitHub project has no existing Flow/Trigger that writes Work Order Amount Paid. Prior org work only showed export lock behavior (`Status = Exported`) and Intacct/Sage installer fields — not a payment roll-up.

## Timeline on WO 05101444 (why it looks “stuck”)

1. **1/7/2026** — exported to accounting (`Status = Exported`). No Payment Record yet.
2. **1/16/2026** — installer pay date stamped; installer payment complete.
3. **1/26/2026** — client payment date stamped; client payment complete. Matches Payment Record Customer Paid Date and check number `01262026`.
4. **1/28/2026 12:40 PM** — Payment Record `852701` created with Amount Paid $126.

So payment **dates and complete flags** were written (manually or by the accounting job), but **Amount Paid on the Work Order was never written**. The Payment Record arrived **after** export. If any copy-to-WO logic only ran at export time, it would have had nothing to copy.

`Invoice/Payment` on the Payment Record is empty. If a Flow’s entry condition requires that field, it would skip this row.

`Key Rec #` is blank and `Manually Key Rec'd` is unchecked. If Amount Paid is meant to be filled by the key-receipt / cash-application step, that step did not run.

## What Amount Paid likely means

On the Work Order layout it sits with **installer** accounting fields (installer pay date, installer payment complete, RFI adjustment), not with a roll-up caption like “Total from Payment Records”.

On the Payment Record, **Amount Paid ($126)** and **Installer Amount ($101)** are different. Confirm with accounting whether the Work Order field should be:

- SUM of Payment Record **Amount Paid** (client cash, $126 on this WO), or
- SUM of **Installer Amount** ($101), or
- a value posted from Intacct/Sage at key rec time (never a Salesforce roll-up)

Until that is confirmed, this change uses **SUM of Payment Record Amount Paid**, which is what the report compared.

## Fix in this branch

Apex that:

1. Finds the child object labeled **Payment Record** / **Payment Records** under Work Order
2. Finds currency fields labeled **Amount Paid** on both objects
3. Sets Work Order Amount Paid to the **sum** of related Payment Record Amount Paid
4. Runs on Payment Record insert/update/delete/undelete (`Payment_Record__c` trigger)
5. Can backfill existing WOs via `AmountPaidRollupBatch`

Parent updates use `Database.update(..., false)` so one locked Exported WO does not fail the whole batch.

## Confirm in the org (Setup)

1. Work Order → Amount Paid → field type. Expect **Currency**, not Formula / Roll-Up Summary.
2. Payment Record → Work Order field. If it is **Lookup**, Salesforce cannot use a native roll-up; automation is required. If it is **Master-Detail**, a native roll-up is an alternative to Apex.
3. Setup → Flows / Process Builder / Triggers on Payment Record. Look for updates to Work Order Amount Paid.
4. Failed Flow Interviews / Apex jobs around 1/28/2026 for WO `05101444`.

## Diagnostic SOQL (adjust API names after describe)

```sql
SELECT Id, WorkOrderNumber, Status, Amount_Paid__c
FROM WorkOrder
WHERE WorkOrderNumber = '05101444'

SELECT Id, Name, Amount_Paid__c, Installer_Amount__c, CreatedDate
FROM Payment_Record__c
WHERE Work_Order__c IN (
  SELECT Id FROM WorkOrder WHERE WorkOrderNumber = '05101444'
)
```

If those API names 404, run `scripts/diagnose_amount_paid.apex` in Developer Console → Anonymous Apex. It prints the resolved object/field names.
