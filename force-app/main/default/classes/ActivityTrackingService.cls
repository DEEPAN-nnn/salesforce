/**
 * Creates one ActivityTracking__c row per Task or Event when WhatId points
 * at an Enquiry__c (Sales Funnel) whose Record Type name is Enquiry.
 */
public with sharing class ActivityTrackingService {
    private static final String ENQUIRY_RECORD_TYPE = 'Enquiry';
    private static final Integer NAME_MAX_LENGTH = 80;

    public static void createFromActivities(List<SObject> activities) {
        if (activities == null || activities.isEmpty()) {
            return;
        }

        List<SObject> enquiryActivities = new List<SObject>();
        Set<Id> enquiryIds = new Set<Id>();

        for (SObject activity : activities) {
            Id whatId = (Id) activity.get('WhatId');
            if (whatId == null || whatId.getSObjectType() != Enquiry__c.SObjectType) {
                continue;
            }
            enquiryActivities.add(activity);
            enquiryIds.add(whatId);
        }

        if (enquiryActivities.isEmpty()) {
            return;
        }

        Set<Id> validEnquiryIds = getEnquiryRecordTypeIds(enquiryIds);
        if (validEnquiryIds.isEmpty()) {
            return;
        }

        Set<String> activityIds = new Set<String>();
        List<SObject> toTrack = new List<SObject>();
        for (SObject activity : enquiryActivities) {
            Id whatId = (Id) activity.get('WhatId');
            if (!validEnquiryIds.contains(whatId)) {
                continue;
            }
            toTrack.add(activity);
            activityIds.add(String.valueOf(activity.Id));
        }

        if (toTrack.isEmpty()) {
            return;
        }

        Set<String> existingActivityIds = new Set<String>();
        for (ActivityTracking__c existing : [
            SELECT Activity_Event_Task__c
            FROM ActivityTracking__c
            WHERE Activity_Event_Task__c IN :activityIds
        ]) {
            existingActivityIds.add(existing.Activity_Event_Task__c);
        }

        List<ActivityTracking__c> trackers = new List<ActivityTracking__c>();
        for (SObject activity : toTrack) {
            String activityId = String.valueOf(activity.Id);
            if (existingActivityIds.contains(activityId)) {
                continue;
            }
            existingActivityIds.add(activityId);

            trackers.add(
                new ActivityTracking__c(
                    Name = buildName(activity),
                    Activity_Event_Task__c = activityId,
                    Sales_Funnel__c = (Id) activity.get('WhatId')
                )
            );
        }

        if (!trackers.isEmpty()) {
            insert trackers;
        }
    }

    private static Set<Id> getEnquiryRecordTypeIds(Set<Id> enquiryIds) {
        Set<Id> validIds = new Set<Id>();
        for (Enquiry__c enquiry : [
            SELECT Id, RecordType.Name, RecordType.DeveloperName
            FROM Enquiry__c
            WHERE Id IN :enquiryIds
        ]) {
            if (isEnquiryRecordType(enquiry)) {
                validIds.add(enquiry.Id);
            }
        }
        return validIds;
    }

    @TestVisible
    private static Boolean isEnquiryRecordType(Enquiry__c enquiry) {
        if (enquiry == null || enquiry.RecordType == null) {
            return false;
        }
        return matchesEnquiryName(enquiry.RecordType.Name) ||
            matchesEnquiryName(enquiry.RecordType.DeveloperName);
    }

    private static Boolean matchesEnquiryName(String value) {
        return String.isNotBlank(value) && value.equalsIgnoreCase(ENQUIRY_RECORD_TYPE);
    }

    private static String buildName(SObject activity) {
        String subject = (String) activity.get('Subject');
        String name = String.isBlank(subject) ? ('Activity ' + activity.Id) : subject.trim();
        if (name.length() > NAME_MAX_LENGTH) {
            name = name.substring(0, NAME_MAX_LENGTH);
        }
        return name;
    }
}
