@IsTest
private class ActivityTrackingServiceTest {
    @IsTest
    static void createsTrackerForTaskOnEnquiry() {
        Enquiry__c enquiry = insertEnquiry();

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

    @IsTest
    static void handleCheckInCreatesAttendanceLog() {
        Enquiry__c enquiry = insertEnquiry();
        Event eventRecord = new Event(
            Subject = 'Site visit',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = enquiry.Id
        );
        insert eventRecord;

        DateTime checkInTime = System.now();
        Test.startTest();
        ActivityTrackingService.handleCheckIn(
            eventRecord.Id,
            '11.0116',
            '79.3691',
            checkInTime,
            'Kadichambadi, Tamil Nadu',
            '{"lat" :11.0116, "lng" :79.3691}'
        );
        Test.stopTest();

        List<Attendance_Log__c> logs = [
            SELECT Event_Id__c, Status__c, OwnerId, Check_In_Time__c, Start_Location_Address__c,
                Current_Coordinates__c, ActivityTrackingRelation__c
            FROM Attendance_Log__c
            WHERE Event_Id__c = :String.valueOf(eventRecord.Id)
        ];
        System.assertEquals(1, logs.size(), 'Check In should create one Attendance Log');
        System.assertEquals('Checked In', logs[0].Status__c);
        System.assertEquals(UserInfo.getUserId(), logs[0].OwnerId);
        System.assertEquals(checkInTime, logs[0].Check_In_Time__c);
        System.assertEquals('Kadichambadi, Tamil Nadu', logs[0].Start_Location_Address__c);
        System.assertNotEquals(null, logs[0].ActivityTrackingRelation__c);
    }

    @IsTest
    static void handleCheckInDoesNotCreateSecondOpenLog() {
        Enquiry__c enquiry = insertEnquiry();
        Event eventRecord = new Event(
            Subject = 'Site visit',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = enquiry.Id
        );
        insert eventRecord;

        ActivityTrackingService.handleCheckIn(
            eventRecord.Id,
            '11.0116',
            '79.3691',
            System.now(),
            'Address',
            '{"lat" :11.0116, "lng" :79.3691}'
        );

        Test.startTest();
        ActivityTrackingService.handleCheckIn(
            eventRecord.Id,
            '11.02',
            '79.40',
            System.now(),
            'Other address',
            '{"lat" :11.02, "lng" :79.40}'
        );
        Test.stopTest();

        Integer logCount = [
            SELECT COUNT()
            FROM Attendance_Log__c
            WHERE Event_Id__c = :String.valueOf(eventRecord.Id)
        ];
        System.assertEquals(1, logCount, 'Second Check In should not create another open log');
    }

    @IsTest
    static void handleCheckOutUpdatesOpenAttendanceLog() {
        Enquiry__c enquiry = insertEnquiry();
        Event eventRecord = new Event(
            Subject = 'Site visit',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = enquiry.Id
        );
        insert eventRecord;

        ActivityTrackingService.handleCheckIn(
            eventRecord.Id,
            '11.0116',
            '79.3691',
            System.now(),
            'Kadichambadi, Tamil Nadu',
            '{"lat" :11.0116, "lng" :79.3691}'
        );

        DateTime checkOutTime = System.now().addHours(1);
        Test.startTest();
        ActivityTrackingService.handleCheckOut(
            eventRecord.Id,
            '9.47947',
            '78.89265',
            checkOutTime,
            'Devipattinam, Tamil Nadu',
            '{"lat" :9.47947, "lng" :78.89265}',
            221.55
        );
        Test.stopTest();

        List<Attendance_Log__c> logs = [
            SELECT Status__c, Check_Out_Time__c, End_Location_Address__c,
                Distance_Between_Check_In_and_Check_Out__c, Check_Out_Geo__c
            FROM Attendance_Log__c
            WHERE Event_Id__c = :String.valueOf(eventRecord.Id)
        ];
        System.assertEquals(1, logs.size());
        System.assertEquals('Checked Out', logs[0].Status__c);
        System.assertEquals(checkOutTime, logs[0].Check_Out_Time__c);
        System.assertEquals('Devipattinam, Tamil Nadu', logs[0].End_Location_Address__c);
        System.assertEquals(221.55, logs[0].Distance_Between_Check_In_and_Check_Out__c);
        System.assertNotEquals(null, logs[0].Check_Out_Geo__c);
    }

    @IsTest
    static void eventUpdateTriggerCreatesAndUpdatesAttendanceLog() {
        Enquiry__c enquiry = insertEnquiry();
        Event eventRecord = new Event(
            Subject = 'Site visit',
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1),
            WhatId = enquiry.Id
        );
        insert eventRecord;

        eventRecord.Start_Location__Latitude__s = 11.0116;
        eventRecord.Start_Location__Longitude__s = 79.3691;
        eventRecord.Start_Date_Time__c = System.now();
        eventRecord.Start_Location_Address__c = 'Kadichambadi, Tamil Nadu';
        eventRecord.Current_Coordinates__c = '{"lat" :11.0116, "lng" :79.3691}';

        Test.startTest();
        update eventRecord;
        Test.stopTest();

        List<Attendance_Log__c> afterCheckIn = [
            SELECT Status__c
            FROM Attendance_Log__c
            WHERE Event_Id__c = :String.valueOf(eventRecord.Id)
        ];
        System.assertEquals(1, afterCheckIn.size());
        System.assertEquals('Checked In', afterCheckIn[0].Status__c);

        eventRecord.End_Location__Latitude__s = 9.47947;
        eventRecord.End_Location__Longitude__s = 78.89265;
        eventRecord.End_Date_Time__c = System.now().addHours(1);
        eventRecord.End_Location_Address__c = 'Devipattinam, Tamil Nadu';
        eventRecord.Current_Coordinates__c = '{"lat" :9.47947, "lng" :78.89265}';
        eventRecord.Distance_Between_Check_In_and_Check_Out__c = 221.55;
        update eventRecord;

        List<Attendance_Log__c> afterCheckOut = [
            SELECT Status__c, Distance_Between_Check_In_and_Check_Out__c
            FROM Attendance_Log__c
            WHERE Event_Id__c = :String.valueOf(eventRecord.Id)
        ];
        System.assertEquals(1, afterCheckOut.size());
        System.assertEquals('Checked Out', afterCheckOut[0].Status__c);
        System.assertEquals(221.55, afterCheckOut[0].Distance_Between_Check_In_and_Check_Out__c);
    }

    private static Enquiry__c insertEnquiry() {
        Enquiry__c enquiry = new Enquiry__c();
        Id recordTypeId = getAvailableRecordTypeId();
        if (recordTypeId != null) {
            enquiry.RecordTypeId = recordTypeId;
        }

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

    private static Id getAvailableRecordTypeId() {
        for (Schema.RecordTypeInfo info : Schema.SObjectType.Enquiry__c.getRecordTypeInfos()) {
            if (info.isAvailable() && !info.isMaster()) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }
}
