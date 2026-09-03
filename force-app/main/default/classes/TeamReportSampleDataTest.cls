@IsTest
private class TeamReportSampleDataTest {
    @IsTest
    static void inspect_returnsText() {
        Test.startTest();
        String log = TeamReportSampleData.inspect();
        Test.stopTest();
        System.assertNotEquals(null, log);
        System.assert(log.contains('My Team Token Achieved'));
        System.assert(log.contains('Action Wise Conversion Report - Overview'));
    }

    @IsTest
    static void createAndDelete_doNotThrow() {
        Test.startTest();
        String created = TeamReportSampleData.createSamples();
        String deleted = TeamReportSampleData.deleteSamples();
        Test.stopTest();
        System.assertNotEquals(null, created);
        System.assertNotEquals(null, deleted);
    }
}
