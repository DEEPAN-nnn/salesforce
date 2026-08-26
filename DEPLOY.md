# Skip cancel of Exported BDC Work Orders

Flow: `Work_Order_BDC_Update_Status_to_Completed` (currently v9 in the org)

## Why Failed Flow Interviews piled up

The flow is **record-triggered after save** on Work Order.

Entry logic was:

```
( ( (POStatus Completed/completed AND Status Scheduled/Past Due) OR POStatus cancelled ) )
AND POStatus IsChanged
AND Job_Category starts with BDC
```

The **OR POStatus = cancelled** branch does **not** require Status = Scheduled or Past Due.

So when client `POStatus__c` changes to `cancelled` on a Work Order that is already **Exported**, the flow still runs.

It then takes **Copy 1 of Update WO Status** and sets:

- `Status` = `Canceled`
- `Sub_Status__c` = `Client Canceled`

That hits the Work Order validation rule:

> Sorry, you cannot cancel a Work Order in "Exported" Status.

`WorkOrderFlowBypass` runs first, but this validation rule does **not** honor that bypass.

Example that failed: `0WO4x000001JOVUGA4` — Status **Exported**, already closed, Completed Date July 2023. Client status changed to cancelled years later.

## Fix (this package)

1. **Start condition** also requires `Status != Exported` so those records never start an interview.
2. **Cancelled** decision requires `Status != Exported` (defense in depth). Those interviews end on the default path instead of updating.
3. **Fault connector** on the cancel Update Records element (same as the complete path).

## Deploy

1. Deploy Flow `Work_Order_BDC_Update_Status_to_Completed`.
2. Confirm the new version is **Active** (this metadata is Active; it should activate on deploy).
3. Optional: deactivate old v9 if Salesforce left it as an inactive version (normal).
4. Failed interviews already in the list stay there; they are history. New Exported + cancelled updates should not add more.

```bash
sf project deploy start --manifest manifest/package.xml
```

## What this does not change

- Completing Scheduled / Past Due BDC WOs when `POStatus__c` becomes Completed.
- Canceling BDC WOs that are **not** Exported (those still set Status = Canceled).
- The validation rule itself (it is correct for accounting/export). If you ever need to cancel an Exported WO, do that as a controlled data fix, not via this automation.
