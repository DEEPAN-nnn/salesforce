/**
 * Phone Home payload for Fairdeal. Desktop Home is a two-column Lightning page;
 * this controller feeds the stacked Phone LWC (follow-ups, inspections,
 * assignments, prospects, my leads).
 *
 * Enquiry__c field names vary by org. Field lists are resolved with describe
 * so missing custom fields do not break deploy/runtime.
 */
public with sharing class FairdealHomeMobileController {
    public class FollowUpCard {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String remarks;
        @AuraEnabled public Boolean overdue;
        @AuraEnabled public Integer overdueDays;
        @AuraEnabled public String phone;
    }

    public class ProspectCard {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String statusLine;
        @AuraEnabled public String badgeLabel;
        @AuraEnabled public String currentStage;
        @AuraEnabled public String phone;
        @AuraEnabled public Boolean hot;
    }

    public class LeadCard {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public Boolean dueToday;
        @AuraEnabled public Boolean overdue;
        @AuraEnabled public Boolean hot;
        @AuraEnabled public Date dueDate;
    }

    public class HomePayload {
        @AuraEnabled public String greeting;
        @AuraEnabled public String userName;
        @AuraEnabled public String dateLabel;
        @AuraEnabled public List<FollowUpCard> followUps;
        @AuraEnabled public Integer followUpHiddenCount;
        @AuraEnabled public Integer inspectionCount;
        @AuraEnabled public Integer newAssignmentCount;
        @AuraEnabled public String inspectionEmpty;
        @AuraEnabled public String assignmentEmpty;
        @AuraEnabled public List<ProspectCard> prospects;
        @AuraEnabled public String prospectHeadline;
        @AuraEnabled public List<LeadCard> leads;
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String warning;
    }

    private static final List<String> FOLLOW_UP_DATE_CANDIDATES = new List<String>{
        'Next_Follow_Up_Date__c',
        'Follow_Up_Date__c',
        'Followup_Date__c',
        'Next_Followup_Date__c',
        'Due_Date__c'
    };
    private static final List<String> PHONE_CANDIDATES = new List<String>{
        'WhatsApp_Number__c',
        'WhatsApp__c',
        'Mobile__c',
        'Phone__c',
        'MobilePhone__c',
        'PersonMobilePhone',
        'Phone'
    };
    private static final List<String> STATUS_CANDIDATES = new List<String>{
        'Status__c',
        'Stage__c',
        'Enquiry_Status__c',
        'Status'
    };
    private static final List<String> LOCATION_CANDIDATES = new List<String>{
        'Location__c',
        'Locality__c',
        'Area__c',
        'City__c',
        'Preferred_Location__c'
    };
    private static final List<String> TYPE_CANDIDATES = new List<String>{
        'Property_Type__c',
        'Requirement_Type__c',
        'Enquiry_Type__c',
        'Type__c'
    };
    private static final List<String> REMARK_CANDIDATES = new List<String>{
        'Last_Remark__c',
        'Last_Remarks__c',
        'Remarks__c',
        'Remark__c',
        'Latest_Remark__c'
    };
    private static final List<String> HOT_CANDIDATES = new List<String>{
        'Hot__c',
        'Is_Hot__c',
        'Hot_Lead__c'
    };
    private static final List<String> BUDGET_CANDIDATES = new List<String>{
        'Budget__c',
        'Budget_Range__c',
        'Min_Budget__c',
        'Max_Budget__c'
    };
    private static final List<String> NAME_CANDIDATES = new List<String>{
        'Name',
        'Enquiry_Name__c',
        'Customer_Name__c'
    };

    private static final Set<String> PROSPECT_STAGE_TOKENS = new Set<String>{
        'site shortlist',
        'site shortlisted',
        'trace',
        'legal',
        'registration'
    };

    @AuraEnabled(cacheable=true)
    public static HomePayload getHomePayload() {
        HomePayload payload = new HomePayload();
        payload.userName = UserInfo.getFirstName();
        if (String.isBlank(payload.userName)) {
            payload.userName = UserInfo.getName();
        }
        payload.greeting = buildGreeting() + ', ' + payload.userName + '!';
        payload.dateLabel = DateTime.now().format('EEEE, d MMMM yyyy');
        payload.followUps = new List<FollowUpCard>();
        payload.prospects = new List<ProspectCard>();
        payload.leads = new List<LeadCard>();
        payload.followUpHiddenCount = 0;
        payload.inspectionCount = 0;
        payload.newAssignmentCount = 0;
        payload.inspectionEmpty = 'No inspections scheduled for today.';
        payload.assignmentEmpty = 'No new assignments in the last 2 days.';
        payload.prospectHeadline = 'ACTIVE PROSPECTS — SITE SHORTLISTED TO REGISTRATION';
        payload.objectLabel = 'Enquiry';

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Enquiry__c')) {
            payload.warning =
                'Enquiry__c was not found in this org. Greeting still works; lists stay empty until the object is available.';
            return payload;
        }

        Schema.DescribeSObjectResult describeResult = gd.get('Enquiry__c').getDescribe();
        if (!describeResult.isAccessible()) {
            payload.warning = 'You do not have access to Enquiry__c.';
            return payload;
        }

        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        String dateField = firstExisting(fieldMap, FOLLOW_UP_DATE_CANDIDATES);
        String phoneField = firstExisting(fieldMap, PHONE_CANDIDATES);
        String statusField = firstExisting(fieldMap, STATUS_CANDIDATES);
        String locationField = firstExisting(fieldMap, LOCATION_CANDIDATES);
        String typeField = firstExisting(fieldMap, TYPE_CANDIDATES);
        String remarkField = firstExisting(fieldMap, REMARK_CANDIDATES);
        String hotField = firstExisting(fieldMap, HOT_CANDIDATES);
        String budgetField = firstExisting(fieldMap, BUDGET_CANDIDATES);
        String nameField = firstExisting(fieldMap, NAME_CANDIDATES);
        if (nameField == null) {
            nameField = 'Name';
        }

        Set<String> selectFields = new Set<String>{ 'Id', nameField, 'CreatedDate', 'LastModifiedDate', 'OwnerId' };
        addIfNotNull(selectFields, dateField);
        addIfNotNull(selectFields, phoneField);
        addIfNotNull(selectFields, statusField);
        addIfNotNull(selectFields, locationField);
        addIfNotNull(selectFields, typeField);
        addIfNotNull(selectFields, remarkField);
        addIfNotNull(selectFields, hotField);
        addIfNotNull(selectFields, budgetField);

        String soql =
            'SELECT ' +
            String.join(new List<String>(selectFields), ',') +
            ' FROM Enquiry__c WHERE OwnerId = :ownerId ORDER BY LastModifiedDate DESC LIMIT 80';
        Id ownerId = UserInfo.getUserId();
        List<SObject> rows = Database.query(soql);

        Date today = Date.today();
        List<FollowUpCard> allFollowUps = new List<FollowUpCard>();
        for (SObject row : rows) {
            String statusVal = textValue(row, statusField);
            Boolean hot = boolValue(row, hotField) || containsIgnoreCase(textValue(row, nameField), 'hot');
            Date due = dateValue(row, dateField);
            Boolean overdue = due != null && due < today;
            Boolean dueToday = due != null && due == today;

            LeadCard lead = new LeadCard();
            lead.recordId = (Id) row.get('Id');
            lead.title = textValue(row, nameField);
            lead.subtitle = joinParts(
                new List<String>{ textValue(row, typeField), textValue(row, locationField), statusVal }
            );
            lead.dueToday = dueToday;
            lead.overdue = overdue;
            lead.hot = hot;
            lead.dueDate = due;
            payload.leads.add(lead);

            if (isProspectStage(statusVal)) {
                ProspectCard prospect = new ProspectCard();
                prospect.recordId = lead.recordId;
                prospect.title = lead.title;
                if (hot && prospect.title != null && !prospect.title.toLowerCase().contains('hot')) {
                    prospect.title = prospect.title + ' (Hot candidate)';
                }
                prospect.hot = hot;
                prospect.subtitle = joinParts(
                    new List<String>{ textValue(row, typeField), textValue(row, locationField), textValue(row, budgetField) }
                );
                prospect.statusLine = String.isBlank(statusVal)
                    ? 'Site shortlisted - awaiting next step'
                    : statusVal + ' - awaiting next step';
                prospect.badgeLabel = badgeForStage(statusVal);
                prospect.currentStage = normalizeStage(statusVal);
                prospect.phone = textValue(row, phoneField);
                payload.prospects.add(prospect);
            }

            Boolean looksLikeFollowUp =
                due != null ||
                containsIgnoreCase(statusVal, 'new enquiry') ||
                containsIgnoreCase(statusVal, 'follow');
            if (looksLikeFollowUp && !isProspectStage(statusVal)) {
                FollowUpCard card = new FollowUpCard();
                card.recordId = lead.recordId;
                card.title = lead.title;
                card.subtitle = joinParts(
                    new List<String>{ textValue(row, typeField), textValue(row, locationField), statusVal }
                );
                String remarks = textValue(row, remarkField);
                card.remarks = String.isBlank(remarks) ? 'No remarks logged yet' : remarks;
                card.overdue = overdue;
                card.overdueDays = overdue && due != null ? due.daysBetween(today) : null;
                card.phone = textValue(row, phoneField);
                allFollowUps.add(card);
            }
        }

        Integer shown = Math.min(3, allFollowUps.size());
        for (Integer i = 0; i < shown; i++) {
            payload.followUps.add(allFollowUps[i]);
        }
        payload.followUpHiddenCount = allFollowUps.size() - shown;

        payload.inspectionCount = countTodayEvents();
        payload.newAssignmentCount = countRecentAssignments(rows, today);

        return payload;
    }

    private static String buildGreeting() {
        Integer hour = Integer.valueOf(DateTime.now().format('H'));
        if (hour < 12) {
            return 'Good Morning';
        }
        if (hour < 17) {
            return 'Good Afternoon';
        }
        return 'Good Evening';
    }

    private static Integer countTodayEvents() {
        if (!Schema.getGlobalDescribe().containsKey('Event')) {
            return 0;
        }
        Date today = Date.today();
        DateTime startDt = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        DateTime endDt = startDt.addDays(1);
        return [
            SELECT COUNT()
            FROM Event
            WHERE OwnerId = :UserInfo.getUserId() AND StartDateTime >= :startDt AND StartDateTime < :endDt
        ];
    }

    private static Integer countRecentAssignments(List<SObject> rows, Date today) {
        Integer count = 0;
        DateTime cutoff = DateTime.newInstance(today.addDays(-2), Time.newInstance(0, 0, 0, 0));
        for (SObject row : rows) {
            DateTime created = (DateTime) row.get('CreatedDate');
            if (created != null && created >= cutoff) {
                count++;
            }
        }
        return count;
    }

    private static String firstExisting(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> candidates
    ) {
        for (String apiName : candidates) {
            if (fieldMap.containsKey(apiName)) {
                return apiName;
            }
        }
        return null;
    }

    private static void addIfNotNull(Set<String> fields, String apiName) {
        if (apiName != null) {
            fields.add(apiName);
        }
    }

    private static String textValue(SObject row, String fieldName) {
        if (fieldName == null || row.get(fieldName) == null) {
            return null;
        }
        return String.valueOf(row.get(fieldName));
    }

    private static Date dateValue(SObject row, String fieldName) {
        if (fieldName == null || row.get(fieldName) == null) {
            return null;
        }
        Object raw = row.get(fieldName);
        if (raw instanceof Date) {
            return (Date) raw;
        }
        if (raw instanceof DateTime) {
            return ((DateTime) raw).date();
        }
        return null;
    }

    private static Boolean boolValue(SObject row, String fieldName) {
        if (fieldName == null || row.get(fieldName) == null) {
            return false;
        }
        Object raw = row.get(fieldName);
        return raw instanceof Boolean && (Boolean) raw;
    }

    private static String joinParts(List<String> parts) {
        List<String> kept = new List<String>();
        for (String part : parts) {
            if (!String.isBlank(part)) {
                kept.add(part);
            }
        }
        return String.join(kept, ' | ');
    }

    private static Boolean containsIgnoreCase(String value, String token) {
        return value != null && token != null && value.toLowerCase().contains(token.toLowerCase());
    }

    private static Boolean isProspectStage(String statusVal) {
        if (String.isBlank(statusVal)) {
            return false;
        }
        String lower = statusVal.toLowerCase();
        for (String token : PROSPECT_STAGE_TOKENS) {
            if (lower.contains(token)) {
                return true;
            }
        }
        return false;
    }

    private static String normalizeStage(String statusVal) {
        if (String.isBlank(statusVal)) {
            return 'shortlist';
        }
        String lower = statusVal.toLowerCase();
        if (lower.contains('trace')) {
            return 'trace';
        }
        if (lower.contains('legal')) {
            return 'legal';
        }
        if (lower.contains('registration')) {
            return 'registration';
        }
        return 'shortlist';
    }

    private static String badgeForStage(String statusVal) {
        String stage = normalizeStage(statusVal);
        if (stage == 'trace') {
            return 'TRACE';
        }
        if (stage == 'legal') {
            return 'LEGAL';
        }
        if (stage == 'registration') {
            return 'REGISTRATION';
        }
        return 'SITE SHORTLISTED';
    }
}
