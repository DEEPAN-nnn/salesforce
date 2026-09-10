@IsTest
private class ActivityTrackingServiceTest {
    @IsTest
    static void createsTrackerForTaskOnEnquiry() {
        Enquiry__c enquiry = insertEnquiry();
        if (enquiry == null) {
            return;
        }

        Test.startTest();
        Task taskRecord = new Task(
            Subject = 'Follow up call',
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = enquiry.Id
        );
        insert taskRecord;
        Test.stopTest();

        List<ActivityTracking__c> trackers = [
            SELECT Activity_Event_Task__c, Sales_Funnel__c, Name
            FROM ActivityTracking__c
            WHERE Activity_Event_Task__c = :String.valueOf(taskRecord.Id)
        ];
        System.assertEquals(1, trackers.size(), 'One tracker should be created for the Task');
        System.assertEquals(enquiry.Id, trackers[0].Sales_Funnel__c);
        System.assertEquals('Task - Follow up call', trackers[0].Name);
    }

    @IsTest
    static void createsTrackerForEventOnEnquiry() {
        Enquiry__c enquiry = insertEnquiry();
        if (enquiry == null) {
            return;
        }

        Test.startTest();
        Event eventRecord = new Event(
            Subject = 'Site visit',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = enquiry.Id
        );
        insert eventRecord;
        Test.stopTest();

        List<ActivityTracking__c> trackers = [
            SELECT Activity_Event_Task__c, Sales_Funnel__c, Name
            FROM ActivityTracking__c
            WHERE Activity_Event_Task__c = :String.valueOf(eventRecord.Id)
        ];
        System.assertEquals(1, trackers.size(), 'One tracker should be created for the Event');
        System.assertEquals(enquiry.Id, trackers[0].Sales_Funnel__c);
        System.assertEquals('Event - Site visit', trackers[0].Name);
    }

    @IsTest
    static void doesNotCreateTrackerWhenWhatIdIsNotEnquiry() {
        Account accountRecord = new Account(Name = 'Not an enquiry');
        insert accountRecord;

        Test.startTest();
        Task taskRecord = new Task(
            Subject = 'Account task',
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = accountRecord.Id
        );
        insert taskRecord;
        Test.stopTest();

        Integer trackerCount = [
            SELECT COUNT()
            FROM ActivityTracking__c
            WHERE Activity_Event_Task__c = :String.valueOf(taskRecord.Id)
        ];
        System.assertEquals(0, trackerCount, 'Tracker should not be created for non-Enquiry WhatId');
    }

    @IsTest
    static void skipsExistingTrackerForSameActivity() {
        Enquiry__c enquiry = insertEnquiry();
        if (enquiry == null) {
            return;
        }

        Task taskRecord = new Task(
            Subject = 'Existing tracker',
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = enquiry.Id
        );
        insert taskRecord;

        ActivityTrackingService.createFromActivities(new List<Task>{ taskRecord });

        Integer trackerCount = [
            SELECT COUNT()
            FROM ActivityTracking__c
            WHERE Activity_Event_Task__c = :String.valueOf(taskRecord.Id)
        ];
        System.assertEquals(1, trackerCount, 'Duplicate tracker should not be inserted');
    }

    private static Enquiry__c insertEnquiry() {
        Id recordTypeId = getEnquiryRecordTypeId();
        if (recordTypeId == null) {
            System.assert(false, 'Enquiry record type named Enquiry is required on Enquiry__c');
            return null;
        }

        Enquiry__c enquiry = new Enquiry__c(RecordTypeId = recordTypeId);
        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Enquiry__c.fields.getMap();
        if (fields.containsKey('Name')) {
            Schema.DescribeFieldResult nameField = fields.get('Name').getDescribe();
            if (!nameField.isAutoNumber() && nameField.isCreateable()) {
                enquiry.put('Name', 'Test Enquiry');
            }
        }
        insert enquiry;
        return enquiry;
    }

    private static Id getEnquiryRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> byName = Schema.SObjectType.Enquiry__c.getRecordTypeInfosByName();
        Map<String, Schema.RecordTypeInfo> byDeveloperName = Schema.SObjectType.Enquiry__c.getRecordTypeInfosByDeveloperName();

        Schema.RecordTypeInfo info = byName.get('Enquiry');
        if (info == null) {
            info = byDeveloperName.get('Enquiry');
        }
        if (info == null || !info.isAvailable()) {
            return null;
        }
        return info.getRecordTypeId();
    }
}
