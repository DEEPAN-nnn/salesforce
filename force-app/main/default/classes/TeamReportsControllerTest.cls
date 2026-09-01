@IsTest
private class TeamReportsControllerTest {
    @IsTest
    static void getTeamReports_doesNotThrow() {
        Test.startTest();
        List<TeamReportsController.TeamReportCard> cards = TeamReportsController.getTeamReports();
        Test.stopTest();
        System.assertNotEquals(null, cards);
        System.assertEquals(5, cards.size(), 'One card per supplied report');
        for (TeamReportsController.TeamReportCard card : cards) {
            System.assertNotEquals(null, card.name);
            System.assertNotEquals(null, card.colorClass);
        }
    }
}
