@IsTest
private class EventNoResponseInviteeCleanupTest {
    @IsTest
    static void deletesInviteeWithNoResponseOlderThan24Hours() {
        User invitee = insertInviteeUser();
        Event eventRecord = insertEvent();

        EventRelation relation;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            relation = new EventRelation(
                EventId = eventRecord.Id,
                RelationId = invitee.Id,
                IsInvitee = true,
                Status = 'New'
            );
            insert relation;
        }
        Test.setCreatedDate(relation.Id, Datetime.now().addHours(-25));

        Test.startTest();
        Database.executeBatch(new EventNoResponseInviteeCleanup(), 200);
        Test.stopTest();

        Integer remaining = [
            SELECT COUNT()
            FROM EventRelation
            WHERE Id = :relation.Id
        ];
        System.assertEquals(0, remaining, 'No Response invitee older than 24 hours should be removed');
    }

    @IsTest
    static void keepsRecentNoResponseInvitee() {
        User invitee = insertInviteeUser();
        Event eventRecord = insertEvent();

        EventRelation relation = new EventRelation(
            EventId = eventRecord.Id,
            RelationId = invitee.Id,
            IsInvitee = true,
            Status = 'New'
        );
        insert relation;

        Test.startTest();
        Database.executeBatch(new EventNoResponseInviteeCleanup(), 200);
        Test.stopTest();

        Integer remaining = [
            SELECT COUNT()
            FROM EventRelation
            WHERE Id = :relation.Id
        ];
        System.assertEquals(1, remaining, 'Invitee invited less than 24 hours ago should stay');
    }

    @IsTest
    static void doesNotRemoveEventOwner() {
        Event eventRecord = insertEvent();
        Datetime cutoff = Datetime.now().addHours(-25);

        List<EventRelation> ownerRelations = [
            SELECT Id
            FROM EventRelation
            WHERE EventId = :eventRecord.Id
                AND RelationId = :UserInfo.getUserId()
        ];
        for (EventRelation ownerRelation : ownerRelations) {
            Test.setCreatedDate(ownerRelation.Id, cutoff);
        }

        Test.startTest();
        Database.executeBatch(new EventNoResponseInviteeCleanup(), 200);
        Test.stopTest();

        Integer ownerStillPresent = [
            SELECT COUNT()
            FROM Event
            WHERE Id = :eventRecord.Id
                AND OwnerId = :UserInfo.getUserId()
        ];
        System.assertEquals(1, ownerStillPresent, 'Event owner must not be removed');
    }

    private static Event insertEvent() {
        Event eventRecord = new Event(
            Subject = 'No response cleanup',
            StartDateTime = System.now().addDays(2),
            EndDateTime = System.now().addDays(2).addHours(1)
        );
        insert eventRecord;
        return eventRecord;
    }

    private static User insertInviteeUser() {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
        String unique = String.valueOf(Datetime.now().getTime());
        User invitee = new User(
            Alias = 'invtee',
            Email = 'invitee' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Invitee',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'invitee' + unique + '@example.com.test'
        );
        insert invitee;
        return invitee;
    }
}
