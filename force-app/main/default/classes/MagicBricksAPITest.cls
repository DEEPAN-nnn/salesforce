@IsTest
private class MagicBricksAPITest {
    @IsTest
    static void phoneVariants_includeLast10AndCountryCode() {
        List<String> variants = MagicBricksAPI.phoneVariants('9930696541');
        System.assert(variants.contains('9930696541'));
        System.assert(variants.contains('919930696541'));
        System.assert(variants.contains('+919930696541'));

        List<String> fromPlus = MagicBricksAPI.phoneVariants('+91 99306 96541');
        System.assert(fromPlus.contains('9930696541'));
    }

    @IsTest
    static void customerCodes_useFrplPrefix() {
        List<String> codes = MagicBricksAPI.customerCodesFor(new List<String>{ '9930696541' });
        System.assert(codes.contains('FRPL9930696541'));
    }

    @IsTest
    static void findExistingContact_matchesPlus91Mobile() {
        Contact existing = new Contact(
            LastName = 'Kumar',
            FirstName = 'Akshat',
            MobilePhone = '+919930696541',
            Phone = '+919930696541',
            Email = 'other@example.com'
        );
        insert existing;

        Test.startTest();
        Contact found = MagicBricksAPI.findExistingContact(
            '9930696541',
            'akshatkumar.5@gmail.com'
        );
        Test.stopTest();

        System.assertNotEquals(null, found, 'Should match on last-10 / +91 variants');
        System.assertEquals(existing.Id, found.Id);
    }

    @IsTest
    static void findExistingContact_matchesCustomerCodeWhenPhoneDiffers() {
        Contact existing = new Contact(
            LastName = 'Existing',
            MobilePhone = '0000000000',
            Customer_Code__c = 'FRPL9930696541'
        );
        insert existing;

        Test.startTest();
        Contact found = MagicBricksAPI.findExistingContact('9930696541', 'nobody@example.com');
        Test.stopTest();

        System.assertNotEquals(null, found);
        System.assertEquals(existing.Id, found.Id);
    }

    @IsTest
    static void findExistingContact_blankEmailDoesNotMatchEmptyEmails() {
        insert new Contact(LastName = 'NoEmail');

        Test.startTest();
        Contact found = MagicBricksAPI.findExistingContact(null, null);
        Test.stopTest();

        System.assertEquals(null, found);
    }
}
