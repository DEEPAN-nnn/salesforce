@IsTest
private class FairdealHomeMobileControllerTest {
    @IsTest
    static void getHomePayload_returnsGreeting() {
        Test.startTest();
        FairdealHomeMobileController.HomePayload payload = FairdealHomeMobileController.getHomePayload();
        Test.stopTest();

        System.assertNotEquals(null, payload, 'Payload should be returned');
        System.assertNotEquals(null, payload.greeting, 'Greeting should be set');
        System.assert(payload.greeting.contains(UserInfo.getFirstName()) || payload.greeting.contains(UserInfo.getName()));
        System.assertNotEquals(null, payload.dateLabel);
        System.assertNotEquals(null, payload.followUps);
        System.assertNotEquals(null, payload.prospects);
        System.assertNotEquals(null, payload.leads);
        System.assert(payload.inspectionCount >= 0);
        System.assert(payload.newAssignmentCount >= 0);
    }
}
