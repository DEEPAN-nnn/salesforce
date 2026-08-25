@IsTest
private class HighlightsPanelControllerTest {
    @IsTest
    static void getCurrentUserProfileName_returnsName() {
        Test.startTest();
        String profileName = HighlightsPanelController.getCurrentUserProfileName();
        Test.stopTest();
        System.assertNotEquals(null, profileName, 'Profile name should be returned');
        System.assert(profileName.length() > 0, 'Profile name should not be blank');
    }

    @IsTest
    static void followToggle_worksWhenObjectSupportsSubscriptions() {
        Account acc = new Account(Name = 'HP Follow Test');
        insert acc;

        Test.startTest();
        Boolean before = HighlightsPanelController.isFollowing(acc.Id);
        Boolean afterFollow = HighlightsPanelController.toggleFollow(acc.Id);
        Boolean afterUnfollow = HighlightsPanelController.toggleFollow(acc.Id);
        Test.stopTest();

        System.assertEquals(false, before);
        System.assertEquals(true, afterFollow);
        System.assertEquals(false, afterUnfollow);
    }

    @IsTest
    static void toggleFollow_nullId_throws() {
        Boolean threw = false;
        try {
            HighlightsPanelController.toggleFollow(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Null recordId should throw AuraHandledException');
    }

    @IsTest
    static void createFeedPost_blankBody_throws() {
        Account acc = new Account(Name = 'HP Post Test');
        insert acc;
        Boolean threw = false;
        try {
            HighlightsPanelController.createFeedPost(acc.Id, '  ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Blank post body should throw');
    }

    @IsTest
    static void createFeedPoll_tooFewChoices_throws() {
        Account acc = new Account(Name = 'HP Poll Test');
        insert acc;
        Boolean threw = false;
        try {
            HighlightsPanelController.createFeedPoll(
                acc.Id,
                'Question?',
                JSON.serialize(new List<String>{ 'Only one' })
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Poll with < 2 choices should throw');
    }
}
