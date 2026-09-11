/**
 * Creates Activity Tracking when a Task or Event is related to Enquiry__c.
 * Creates or updates Attendance Log when a user checks in or out of an Event.
 */
public with sharing class ActivityTrackingService {
    private static final Integer NAME_MAX_LENGTH = 80;
    private static final String STATUS_CHECKED_IN = 'Checked In';
    private static final String STATUS_CHECKED_OUT = 'Checked Out';

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

    /**
     * Event after update. GetLocation already wrote check-in/out fields on Event.
     * Check In: Start_Date_Time__c went from blank to a value.
     * Check Out: End_Date_Time__c went from blank to a value.
     */
    public static void syncVisitsFromEventUpdates(List<Event> newEvents, Map<Id, Event> oldMap) {
        if (newEvents == null || newEvents.isEmpty() || oldMap == null) {
            return;
        }

        for (Event eventRecord : newEvents) {
            Event oldEvent = oldMap.get(eventRecord.Id);
            if (oldEvent == null) {
                continue;
            }

            if (oldEvent.Start_Date_Time__c == null && eventRecord.Start_Date_Time__c != null) {
                handleCheckIn(
                    eventRecord.Id,
                    toString(eventRecord.Start_Location__Latitude__s),
                    toString(eventRecord.Start_Location__Longitude__s),
                    eventRecord.Start_Date_Time__c,
                    eventRecord.Start_Location_Address__c,
                    eventRecord.Current_Coordinates__c
                );
            }

            if (oldEvent.End_Date_Time__c == null && eventRecord.End_Date_Time__c != null) {
                handleCheckOut(
                    eventRecord.Id,
                    toString(eventRecord.End_Location__Latitude__s),
                    toString(eventRecord.End_Location__Longitude__s),
                    eventRecord.End_Date_Time__c,
                    eventRecord.End_Location_Address__c,
                    eventRecord.Current_Coordinates__c,
                    eventRecord.Distance_Between_Check_In_and_Check_Out__c
                );
            }
        }
    }

    public static void handleCheckIn(
        Id eventId,
        String latitude,
        String longitude,
        DateTime checkInTime,
        String address,
        String coordinatesJson
    ) {
        if (eventId == null || eventId.getSObjectType() != Event.SObjectType) {
            return;
        }

        Id userId = UserInfo.getUserId();
        String eventIdValue = String.valueOf(eventId);

        if (hasOpenVisit(eventIdValue, userId)) {
            return;
        }

        Attendance_Log__c visit = new Attendance_Log__c();
        visit.Name = buildVisitName();
        visit.ActivityTrackingRelation__c = getTrackerId(eventIdValue);
        visit.Event_Id__c = eventIdValue;
        visit.OwnerId = userId;
        visit.Status__c = STATUS_CHECKED_IN;
        visit.Check_In_Time__c = checkInTime;
        visit.Start_Location_Address__c = address;
        visit.Current_Coordinates__c = truncate(coordinatesJson, 255);

        Decimal lat = parseDecimal(latitude);
        Decimal lng = parseDecimal(longitude);
        if (lat != null && lng != null) {
            visit.Check_In_Geo__c = Location.newInstance(lat, lng);
        }

        insert visit;
    }

    public static void handleCheckOut(
        Id eventId,
        String latitude,
        String longitude,
        DateTime checkOutTime,
        String address,
        String coordinatesJson,
        Decimal distance
    ) {
        if (eventId == null || eventId.getSObjectType() != Event.SObjectType) {
            return;
        }

        Id userId = UserInfo.getUserId();
        String eventIdValue = String.valueOf(eventId);

        List<Attendance_Log__c> openVisits = [
            SELECT Id
            FROM Attendance_Log__c
            WHERE Event_Id__c = :eventIdValue
                AND OwnerId = :userId
                AND Status__c = :STATUS_CHECKED_IN
            LIMIT 1
        ];
        if (openVisits.isEmpty()) {
            return;
        }

        Attendance_Log__c visit = openVisits[0];
        visit.Status__c = STATUS_CHECKED_OUT;
        visit.Check_Out_Time__c = checkOutTime;
        visit.End_Location_Address__c = address;
        visit.Current_Coordinates__c = truncate(coordinatesJson, 255);
        visit.Distance_Between_Check_In_and_Check_Out__c = distance;

        Decimal lat = parseDecimal(latitude);
        Decimal lng = parseDecimal(longitude);
        if (lat != null && lng != null) {
            visit.Check_Out_Geo__c = Location.newInstance(lat, lng);
        }

        update visit;
    }

    private static Boolean hasOpenVisit(String eventIdValue, Id userId) {
        return [
            SELECT COUNT()
            FROM Attendance_Log__c
            WHERE Event_Id__c = :eventIdValue
                AND OwnerId = :userId
                AND Status__c = :STATUS_CHECKED_IN
        ] > 0;
    }

    private static Id getTrackerId(String eventIdValue) {
        List<ActivityTracking__c> trackers = [
            SELECT Id
            FROM ActivityTracking__c
            WHERE Activity_Event_Task__c = :eventIdValue
            LIMIT 1
        ];
        return trackers.isEmpty() ? null : trackers[0].Id;
    }

    private static String buildVisitName() {
        return truncate(UserInfo.getName() + ' - Check In', NAME_MAX_LENGTH);
    }

    private static String buildName(SObject activity) {
        String objectLabel = activity.getSObjectType() == Event.SObjectType ? 'Event' : 'Task';
        String subject = (String) activity.get('Subject');
        String name = objectLabel + ' - ' + (String.isBlank(subject) ? String.valueOf(activity.Id) : subject.trim());
        return truncate(name, NAME_MAX_LENGTH);
    }

    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }

    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static String toString(Decimal value) {
        return value == null ? null : String.valueOf(value);
    }
}
