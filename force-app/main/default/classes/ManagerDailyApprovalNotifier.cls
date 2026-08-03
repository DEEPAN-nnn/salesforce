/**
 * Sends ONE Custom Notification per manager per day for pending Approval__c records.
 *
 * Replaces schedule-triggered flows that process each Approval__c row individually
 * (e.g. flow Id 301C400000XdmP5IAJ), which create a separate bell notification per
 * record for the same Approver__c / manager.
 *
 * Usage:
 * 1) Deactivate the old per-record scheduled flow in the sandbox.
 * 2) Deploy this class (+ test).
 * 3) Either:
 *    - Activate Flow Manager_Daily_Approval_Notification, or
 *    - Schedule Apex: System.schedule('Manager Daily Approval Notify', '0 0 9 * * ?', new ManagerDailyApprovalNotifier());
 */
public without sharing class ManagerDailyApprovalNotifier implements Schedulable {
    public static final String DEFAULT_NOTIFICATION_TYPE = 'Dead_Approval_Notification';
    public static final String DEFAULT_STATUS = 'Pending';

    @TestVisible
    private static Boolean bypassSend = false;

    @TestVisible
    private static List<NotificationDraft> draftsSent = new List<NotificationDraft>();

    public class NotificationDraft {
        public Id managerId;
        public Integer pendingCount;
        public Id targetApprovalId;
        public String title;
        public String body;
    }

    public class Request {
        @InvocableVariable(
            label='Custom Notification Type DeveloperName'
            description='DeveloperName of Custom Notification Type. Defaults to Dead_Approval_Notification.'
        )
        public String notificationTypeDeveloperName;

        @InvocableVariable(
            label='Approval Status Filter'
            description='Only include Approval__c rows with this Approval_Status__c. Defaults to Pending.'
        )
        public String approvalStatus;
    }

    public class Result {
        @InvocableVariable(label='Managers Notified')
        public Integer managersNotified;

        @InvocableVariable(label='Pending Approvals Considered')
        public Integer pendingApprovalsConsidered;
    }

    public void execute(SchedulableContext sc) {
        Request req = new Request();
        req.notificationTypeDeveloperName = DEFAULT_NOTIFICATION_TYPE;
        req.approvalStatus = DEFAULT_STATUS;
        sendDailyNotifications(new List<Request>{ req });
    }

    @InvocableMethod(
        label='Send Daily Manager Approval Notifications'
        description='Groups pending Approval__c by Approver__c and sends one Custom Notification per manager.'
    )
    public static List<Result> sendDailyNotifications(List<Request> requests) {
        Request req = (requests != null && !requests.isEmpty() && requests[0] != null)
            ? requests[0]
            : new Request();

        String typeName = String.isBlank(req.notificationTypeDeveloperName)
            ? DEFAULT_NOTIFICATION_TYPE
            : req.notificationTypeDeveloperName.trim();
        String statusFilter = String.isBlank(req.approvalStatus)
            ? DEFAULT_STATUS
            : req.approvalStatus.trim();

        Result outcome = new Result();
        outcome.managersNotified = 0;
        outcome.pendingApprovalsConsidered = 0;

        Id notificationTypeId = resolveNotificationTypeId(typeName);
        if (notificationTypeId == null) {
            System.debug(
                LoggingLevel.ERROR,
                'ManagerDailyApprovalNotifier: Custom Notification Type not found: ' + typeName
            );
            return new List<Result>{ outcome };
        }

        List<Approval__c> pending = [
            SELECT Id, Name, Approver__c, Approval_Status__c, Sales_Funnel__c
            FROM Approval__c
            WHERE Approval_Status__c = :statusFilter AND Approver__c != NULL
            ORDER BY CreatedDate ASC
        ];

        outcome.pendingApprovalsConsidered = pending.size();
        if (pending.isEmpty()) {
            return new List<Result>{ outcome };
        }

        Map<Id, List<Approval__c>> byManager = groupByManager(pending);
        List<NotificationDraft> drafts = buildDrafts(byManager);

        for (NotificationDraft draft : drafts) {
            sendNotification(notificationTypeId, draft);
            outcome.managersNotified++;
        }

        return new List<Result>{ outcome };
    }

    @TestVisible
    private static Map<Id, List<Approval__c>> groupByManager(List<Approval__c> approvals) {
        Map<Id, List<Approval__c>> byManager = new Map<Id, List<Approval__c>>();
        for (Approval__c row : approvals) {
            if (row.Approver__c == null) {
                continue;
            }
            if (!byManager.containsKey(row.Approver__c)) {
                byManager.put(row.Approver__c, new List<Approval__c>());
            }
            byManager.get(row.Approver__c).add(row);
        }
        return byManager;
    }

    @TestVisible
    private static List<NotificationDraft> buildDrafts(Map<Id, List<Approval__c>> byManager) {
        List<NotificationDraft> drafts = new List<NotificationDraft>();
        for (Id managerId : byManager.keySet()) {
            List<Approval__c> rows = byManager.get(managerId);
            NotificationDraft draft = new NotificationDraft();
            draft.managerId = managerId;
            draft.pendingCount = rows.size();
            draft.targetApprovalId = rows[0].Id;
            draft.title = 'Pending approval requests';
            draft.body = rows.size() == 1
                ? 'You have 1 pending approval request. Open to review.'
                : 'You have ' +
                  String.valueOf(rows.size()) +
                  ' pending approval requests. Open to review.';
            drafts.add(draft);
        }
        return drafts;
    }

    private static Id resolveNotificationTypeId(String developerName) {
        List<CustomNotificationType> types = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        return types.isEmpty() ? null : types[0].Id;
    }

    private static void sendNotification(Id notificationTypeId, NotificationDraft draft) {
        draftsSent.add(draft);
        if (bypassSend || Test.isRunningTest()) {
            return;
        }

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notificationTypeId);
        notification.setTitle(draft.title);
        notification.setBody(draft.body);
        notification.setTargetId(draft.targetApprovalId);
        notification.send(new Set<String>{ String.valueOf(draft.managerId) });
    }
}
