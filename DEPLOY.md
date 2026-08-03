# Manager daily approval notification (one per manager / day)

## Problem

Scheduled flow `301C400000XdmP5IAJ` (partial copy sandbox) creates a **Custom Notification for every `Approval__c` record**.

When the same manager (`Approver__c`) has many pending approvals, the bell shows a **list of notifications** (one per record).

**Expected:** one notification per manager per day, summarizing pending approvals.

## Root cause

Schedule-triggered flows that start on an **object** run **once per matching record**. Sending the notification inside that path → N notifications for N rows.

## Fix

1. Apex `ManagerDailyApprovalNotifier`
   - Queries `Approval__c` where `Approval_Status__c = Pending` and `Approver__c != null`
   - Groups by `Approver__c`
   - Sends **one** `Messaging.CustomNotification` per manager
   - Body example: `You have 5 pending approval requests. Open to review.`
   - Target = one of that manager’s pending approval records
2. Schedule-triggered Flow `Manager_Daily_Approval_Notification`
   - Runs **once daily** (no object / not per-record)
   - Calls the Apex invocable action
   - Shipped as **Draft** — activate after deploy and after deactivating the old flow

## Deploy steps (partial copy sandbox)

1. **Deactivate** the old scheduled flow (`301C400000XdmP5IAJ`) so it stops sending per-record notifications.
2. Deploy Apex + Flow (this package).
3. Confirm Custom Notification Type DeveloperName is `Dead_Approval_Notification`  
   (or change the Flow input / Apex default to your org’s type).
4. **Activate** Flow `Manager Daily Approval Notification` (or schedule Apex):

```apex
System.schedule(
  'Manager Daily Approval Notify',
  '0 0 9 * * ?',
  new ManagerDailyApprovalNotifier()
);
```

5. Smoke test:

```apex
ManagerDailyApprovalNotifier.Request req = new ManagerDailyApprovalNotifier.Request();
req.notificationTypeDeveloperName = 'Dead_Approval_Notification';
req.approvalStatus = 'Pending';
List<ManagerDailyApprovalNotifier.Result> res =
  ManagerDailyApprovalNotifier.sendDailyNotifications(
    new List<ManagerDailyApprovalNotifier.Request>{ req }
  );
System.debug(res);
```

A manager with 3 pending approvals should get **1** bell notification, not 3.

## Notes

- Default status filter: `Pending` (same value used when creating approvals in `Request_Dead_Approval`).
- Default notification type: `Dead_Approval_Notification`.
- If your scheduled job used different criteria (date window, record type, etc.), tell us and we can tighten the SOQL.
