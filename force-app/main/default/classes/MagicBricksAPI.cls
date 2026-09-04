/**
 * Magicbricks inbound REST. Contact matching must happen before insert so
 * "Update Contact Customer code" does not write FRPL+mobile onto a second
 * Contact (Customer_Code__c is unique).
 */
@RestResource(urlMapping='/magicbrick')
global without sharing class MagicBricksAPI {
    public class MagicBricksWrapper {
        public String enquiryName { get; set; }
        public String companyName { get; set; }
        public String email { get; set; }
        public String salutation { get; set; }
        public String firstName { get; set; }
        public String lastName { get; set; }
        public String contactPerson1 { get; set; }
        public String customerType { get; set; }
        public String channels { get; set; }
        public String source { get; set; }
        public String wantTo { get; set; }
        public String propertyType { get; set; }
        public String lookingFor { get; set; }
        public String city { get; set; }
        public String msg { get; set; }
        public String pid { get; set; }
        public String mbAcc { get; set; }
        public String subUser { get; set; }
    }

    @HttpPost
    global static void getMagicBricksDetails() {
        String requestBody = '';
        try {
            if (RestContext.request != null && RestContext.request.requestBody != null) {
                requestBody = RestContext.request.requestBody.toString();
            }
            if (String.isBlank(requestBody)) {
                System.debug('Magicbricks requestBody is null');
                LoggerService.logError(
                    'MagicBricksAPI',
                    'getMagicBricksDetails',
                    'requestBody is null or empty',
                    requestBody,
                    'MagicBricks'
                );
                writeResponse('requestBody is null', 400);
                return;
            }

            List<Contact> contactsToInsert = new List<Contact>();
            List<Enquiry__c> enquiriesToInsert = new List<Enquiry__c>();

            MagicBricksWrapper wrapper = (MagicBricksWrapper) JSON.deserialize(
                requestBody,
                MagicBricksWrapper.class
            );
            System.debug('MagicBricks wrapper--> ' + wrapper);
            String enquiryRecordType = Schema.SObjectType.Enquiry__c.getRecordTypeInfosByDeveloperName()
                .get('Enquiry_Stage')
                .getRecordTypeId();

            if (wrapper == null) {
                writeResponse('requestBody is null', 400);
                return;
            }

            Contact existingContact = findExistingContact(wrapper.contactPerson1, wrapper.email);

            if (existingContact == null) {
                Contact con = new Contact();
                if (String.isNotBlank(wrapper.firstName)) {
                    if (wrapper.firstName.contains(' ')) {
                        List<String> nameParts = wrapper.firstName.split(' ', 2);
                        con.FirstName = nameParts[0];
                        con.LastName = nameParts[1];
                    } else {
                        con.LastName = wrapper.firstName;
                    }
                }
                con.Salutation = wrapper.salutation;
                if (String.isBlank(con.LastName)) {
                    System.debug('MagicBricks Name Field Cannot Be Empty');
                    LoggerService.logError(
                        'MagicBricksAPI',
                        'getMagicBricksDetails',
                        'Name Field Cannot Be Empty',
                        requestBody,
                        'MagicBricks'
                    );
                    writeResponse('Name Field Cannot Be Empty', 400);
                    return;
                }
                if (String.isNotBlank(wrapper.contactPerson1)) {
                    con.Phone = wrapper.contactPerson1;
                    con.MobilePhone = wrapper.contactPerson1;
                } else {
                    System.debug('MagicBricks PhoneNumber Field Cannot Be Empty');
                    LoggerService.logError(
                        'MagicBricksAPI',
                        'getMagicBricksDetails',
                        'PhoneNumber Field Cannot Be Empty',
                        requestBody,
                        'MagicBricks'
                    );
                    writeResponse('PhoneNumber Field Cannot Be Empty', 400);
                    return;
                }

                con.Email = wrapper.email != null ? wrapper.email : '';
                contactsToInsert.add(con);
            }

            Enquiry__c enq = new Enquiry__c();
            enq.Enquiry_Body__c = requestBody;
            if (String.isNotBlank(wrapper.contactPerson1)) {
                enq.Contact_1_Phone__c = wrapper.contactPerson1;
            } else {
                System.debug('MagicBricks Contact 1 Phone Field Cannot Be Empty');
                LoggerService.logError(
                    'MagicBricksAPI',
                    'getMagicBricksDetails',
                    'Contact 1 Phone Field Cannot Be Empty',
                    requestBody,
                    'MagicBricks'
                );
                writeResponse('Contact 1 Phone Field Cannot Be Empty', 400);
                return;
            }
            enq.Customer_Type__c = wrapper.customerType;
            enq.Channel__c = wrapper.channels;
            enq.Source__c = wrapper.source;
            enq.Want_To__c = wrapper.wantTo;
            enq.Property_Type__c = wrapper.propertyType;
            enq.Looking_For__c = wrapper.lookingFor;
            enq.City__c = wrapper.city;
            enq.Internal_Note__c = wrapper.msg;
            enq.Project_ID__c = wrapper.pid;
            enq.RecordTypeId = enquiryRecordType;
            enq.Sub_User_Account__c = wrapper.subUser;

            if (wrapper.mbAcc == '377770' || wrapper.mbAcc == '29282633') {
                List<Contact> mbAcc = [
                    SELECT Id, Name
                    FROM Contact
                    WHERE Name = 'Fairdeal_Mum'
                    LIMIT 1
                ];
                if (!mbAcc.isEmpty()) {
                    enq.Source_Name__c = mbAcc.get(0).Id;
                }
            } else if (wrapper.mbAcc == '621106' || wrapper.mbAcc == '58048381') {
                List<Contact> mbAcc = [
                    SELECT Id, Name
                    FROM Contact
                    WHERE Name = 'Mb9821045056'
                    LIMIT 1
                ];
                if (!mbAcc.isEmpty()) {
                    enq.Source_Name__c = mbAcc.get(0).Id;
                }
            }

            if (existingContact != null) {
                enq.Contact__c = existingContact.Id;
            }

            enquiriesToInsert.add(enq);

            if (!contactsToInsert.isEmpty()) {
                insert contactsToInsert;
                if (!enquiriesToInsert.isEmpty()) {
                    enquiriesToInsert.get(0).Contact__c = contactsToInsert.get(0).Id;
                }
            }

            if (!enquiriesToInsert.isEmpty()) {
                insert enquiriesToInsert;
            }

            System.debug('MagicBricks enquiriesToInsert-->' + enquiriesToInsert);
            writeResponse('Success', 200);
        } catch (Exception e) {
            System.debug('Magicbricks Error: ' + e.getMessage());
            LoggerService.logError('MagicBricksAPI', 'getMagicBricksDetails', e, requestBody, 'MagicBricks');
            writeResponse('Error: ' + e.getMessage(), 500);
        }
    }

    /**
     * Match in this order: Customer_Code__c (FRPL+mobile), phone variants, then email.
     * Exact Phone/Email only missed contacts stored as +91… while Magicbricks sent 10 digits.
     */
    @TestVisible
    static Contact findExistingContact(String phone, String email) {
        List<String> phoneVariants = phoneVariants(phone);
        List<String> customerCodes = customerCodesFor(phoneVariants);

        if (!customerCodes.isEmpty()) {
            List<Contact> byCode = [
                SELECT Id, Name, Email, Phone, MobilePhone, Customer_Code__c
                FROM Contact
                WHERE Customer_Code__c IN :customerCodes
                LIMIT 1
            ];
            if (!byCode.isEmpty()) {
                return byCode[0];
            }
        }

        if (!phoneVariants.isEmpty()) {
            List<Contact> byPhone = [
                SELECT Id, Name, Email, Phone, MobilePhone, Customer_Code__c
                FROM Contact
                WHERE Phone IN :phoneVariants OR MobilePhone IN :phoneVariants
                LIMIT 1
            ];
            if (!byPhone.isEmpty()) {
                return byPhone[0];
            }
        }

        if (String.isNotBlank(email)) {
            List<Contact> byEmail = [
                SELECT Id, Name, Email, Phone, MobilePhone, Customer_Code__c
                FROM Contact
                WHERE Email = :email
                LIMIT 1
            ];
            if (!byEmail.isEmpty()) {
                return byEmail[0];
            }
        }
        return null;
    }

    @TestVisible
    static List<String> phoneVariants(String phone) {
        Set<String> values = new Set<String>();
        if (String.isBlank(phone)) {
            return new List<String>();
        }
        values.add(phone.trim());
        String digits = phone.replaceAll('[^0-9]', '');
        if (String.isNotBlank(digits)) {
            values.add(digits);
            String last10 = digits.length() > 10 ? digits.substring(digits.length() - 10) : digits;
            values.add(last10);
            values.add('0' + last10);
            values.add('91' + last10);
            values.add('+91' + last10);
        }
        values.remove(null);
        values.remove('');
        return new List<String>(values);
    }

    @TestVisible
    static List<String> customerCodesFor(List<String> phones) {
        Set<String> codes = new Set<String>();
        for (String phone : phones) {
            if (String.isBlank(phone) || phone.startsWith('+')) {
                continue;
            }
            codes.add('FRPL' + phone);
        }
        return new List<String>(codes);
    }

    private static void writeResponse(String body, Integer statusCode) {
        if (RestContext.response == null) {
            RestContext.response = new RestResponse();
        }
        RestContext.response.responseBody = Blob.valueOf(body);
        RestContext.response.statusCode = statusCode;
    }
}
