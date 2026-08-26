# Work Order: BDC - Update Status to Completed

Record-triggered **after save** flow on Work Order. It keeps Salesforce `Status` in sync with client `POStatus__c` for BDC jobs.

## What this flow does

It runs when **all** of these are true:

- `Job_Category__c` starts with **BDC**
- `POStatus__c` **changed**
- And either:
  - Client status is **Completed** / **completed** and Salesforce status is **Scheduled** or **Past Due**, or
  - Client status is **cancelled** (any Salesforce status)

Then it does one of three things:

| Client POStatus | Salesforce Status | What the flow does |
|---|---|---|
| Completed | Scheduled or Past Due, and the service appointment end time is in the past | Sets Salesforce `Status` = **Completed**, `Sub_Status__c` = **Pending Installer Pay**, stamps `Completed_Date__c` |
| cancelled | Not Exported | Sets Salesforce `Status` = **Canceled**, `Sub_Status__c` = **Client Canceled** |
| cancelled | **Exported** | **Does not cancel.** Shows an error on `POStatus__c` and **rolls back** the save so the user knows the WO cannot be cancelled |

Exported work orders are locked after they are sent to accounting. The org already has a validation rule for that. Previously the flow still tried to set Status = Canceled, the rule blocked it, and the user only saw a **Failed Flow Interview** (or a generic flow fault) — not a clear “you cannot cancel” message.

## Fix in this version

1. **Cancel Eligibility** decision runs first (before Get SA).
2. If `POStatus__c` = cancelled and `Status` = Exported → **Custom Error** on `POStatus__c`:

   > Sorry, you cannot cancel a Work Order in Exported Status. Exported work orders are locked after they have been sent to accounting.

   Custom Error does **not** create a failed interview. The record change is rolled back, so client status does not stay cancelled while Salesforce stays Exported.
3. Other cancels and the complete path are unchanged. Cancel update has a fault connector like the complete path.

## Deploy

```bash
sf project deploy start --manifest manifest/package.xml
```

Confirm the new flow version is **Active**.

## Test plan

1. **Exported + cancel (must see the message)**  
   BDC Work Order with `Status` = Exported. Set `POStatus__c` to cancelled and save.  
   Expect: save fails, field/page error that you cannot cancel an Exported WO, Status stays Exported, **no** new Failed Flow Interview.

2. **Scheduled + cancel (still allowed)**  
   BDC Work Order with `Status` = Scheduled. Set `POStatus__c` to cancelled.  
   Expect: `Status` = Canceled, `Sub_Status__c` = Client Canceled.

3. **Scheduled/Past Due + complete**  
   BDC Work Order Scheduled or Past Due, appointment end time in the past, `POStatus__c` → Completed.  
   Expect: `Status` = Completed, `Sub_Status__c` = Pending Installer Pay.
