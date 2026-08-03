@IsTest
private class ManagerDailyApprovalNotifierTest {
    @IsTest
    static void groupsPendingApprovalsIntoOneDraftPerManager() {
        Id managerA = UserInfo.getUserId();
        Id managerB = UserInfo.getUserId();
        // Distinct fake user Ids for grouping (valid 15-char key prefix 005)
        managerA = (Id) '005000000000001AAA';
        managerB = (Id) '005000000000002AAA';

        List<Approval__c> pending = new List<Approval__c>{
            fakeApproval('a0X000000000001AAA', managerA),
            fakeApproval('a0X000000000002AAA', managerA),
            fakeApproval('a0X000000000003AAA', managerA),
            fakeApproval('a0X000000000004AAA', managerB)
        };

        Map<Id, List<Approval__c>> grouped = ManagerDailyApprovalNotifier.groupByManager(pending);
        System.assertEquals(2, grouped.size(), 'Should group to two managers');
        System.assertEquals(3, grouped.get(managerA).size());
        System.assertEquals(1, grouped.get(managerB).size());

        List<ManagerDailyApprovalNotifier.NotificationDraft> drafts = ManagerDailyApprovalNotifier.buildDrafts(
            grouped
        );
        System.assertEquals(2, drafts.size(), 'One notification draft per manager, not per record');

        Map<Id, ManagerDailyApprovalNotifier.NotificationDraft> byManager = new Map<Id, ManagerDailyApprovalNotifier.NotificationDraft>();
        for (ManagerDailyApprovalNotifier.NotificationDraft draft : drafts) {
            byManager.put(draft.managerId, draft);
        }
        System.assertEquals(3, byManager.get(managerA).pendingCount);
        System.assertEquals(1, byManager.get(managerB).pendingCount);
        System.assert(
            byManager.get(managerA).body.contains('3'),
            'Manager A body should mention pending count 3'
        );
        System.assert(
            byManager.get(managerB).body.contains('1'),
            'Manager B body should mention pending count 1'
        );
    }

    @IsTest
    static void invocableReturnsZeroWhenNotificationTypeMissing() {
        ManagerDailyApprovalNotifier.bypassSend = true;
        ManagerDailyApprovalNotifier.draftsSent.clear();

        ManagerDailyApprovalNotifier.Request req = new ManagerDailyApprovalNotifier.Request();
        req.notificationTypeDeveloperName = 'Type_That_Does_Not_Exist_XYZ';
        req.approvalStatus = 'Pending';

        Test.startTest();
        List<ManagerDailyApprovalNotifier.Result> results = ManagerDailyApprovalNotifier.sendDailyNotifications(
            new List<ManagerDailyApprovalNotifier.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(0, results[0].managersNotified);
        System.assertEquals(0, ManagerDailyApprovalNotifier.draftsSent.size());
    }

    @IsTest
    static void schedulableExecuteRunsWithoutError() {
        ManagerDailyApprovalNotifier.bypassSend = true;
        Test.startTest();
        String jobId = System.schedule(
            'ManagerDailyApprovalNotifierTest',
            '0 0 9 * * ?',
            new ManagerDailyApprovalNotifier()
        );
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    private static Approval__c fakeApproval(String approvalId, Id managerId) {
        return (Approval__c) JSON.deserialize(
            '{"Id":"' + approvalId + '","Approver__c":"' + String.valueOf(managerId) + '"}',
            Approval__c.class
        );
    }
}
