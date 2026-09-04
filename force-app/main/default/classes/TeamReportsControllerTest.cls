@IsTest
private class TeamReportsControllerTest {
    @IsTest
    static void getTeamReports_doesNotThrow() {
        Test.startTest();
        List<TeamReportsController.TeamReportCard> cards = TeamReportsController.getTeamReports(
            'THIS_MONTH'
        );
        Test.stopTest();
        System.assertNotEquals(null, cards);
        System.assertEquals(5, cards.size(), 'One card per supplied report');
        for (TeamReportsController.TeamReportCard card : cards) {
            System.assertNotEquals(null, card.name);
            System.assertNotEquals(null, card.colorClass);
        }
    }

    @IsTest
    static void parseDateRange_namedAndStandardLastN() {
        TeamReportsController.DateRangeOverride month = TeamReportsController.parseDateRange(
            'THIS_MONTH'
        );
        System.assertEquals('THIS_MONTH', month.durationValue);
        System.assertEquals(false, month.isCustom);

        TeamReportsController.DateRangeOverride last7 = TeamReportsController.parseDateRange(
            'LAST_N_DAYS:7'
        );
        System.assertEquals('LAST_N_DAYS:7', last7.durationValue);
        System.assertEquals(false, last7.isCustom);
    }

    @IsTest
    static void parseDateRange_customForUnsupportedLastN() {
        TeamReportsController.DateRangeOverride last3 = TeamReportsController.parseDateRange(
            'LAST_N_DAYS:3'
        );
        System.assertEquals('CUSTOM', last3.durationValue);
        System.assertEquals(true, last3.isCustom);
        System.assertEquals(Date.today(), last3.endDate);
        System.assertEquals(Date.today().addDays(-2), last3.startDate);

        TeamReportsController.DateRangeOverride last15 = TeamReportsController.parseDateRange(
            'LAST_N_DAYS:15'
        );
        System.assertEquals('CUSTOM', last15.durationValue);
        System.assertEquals(Date.today().addDays(-14), last15.startDate);
    }

    @IsTest
    static void parseDateRange_blankDefaultsToThisMonth() {
        TeamReportsController.DateRangeOverride parsed = TeamReportsController.parseDateRange(
            null
        );
        System.assertEquals('THIS_MONTH', parsed.durationValue);
    }
}
