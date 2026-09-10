/**
 * Creates one ActivityTracking__c row per Task or Event when WhatId
 * points at an Enquiry__c (Sales Funnel) record.
 */
public with sharing class ActivityTrackingService {
    private static final Integer NAME_MAX_LENGTH = 80;

    public static void createFromActivities(List<SObject> activities) {
        if (activities == null || activities.isEmpty()) {
            return;
        }

        Set<String> activityIds = new Set<String>();
        List<SObject> toTrack = new List<SObject>();

        for (SObject activity : activities) {
            Id whatId = (Id) activity.get('WhatId');
            if (whatId == null || whatId.getSObjectType() != Enquiry__c.SObjectType) {
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

    private static String buildName(SObject activity) {
        String objectLabel = activity.getSObjectType() == Event.SObjectType ? 'Event' : 'Task';
        String subject = (String) activity.get('Subject');
        String name = objectLabel + ' - ' + (String.isBlank(subject) ? String.valueOf(activity.Id) : subject.trim());
        if (name.length() > NAME_MAX_LENGTH) {
            name = name.substring(0, NAME_MAX_LENGTH);
        }
        return name;
    }
}
