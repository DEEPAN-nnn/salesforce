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
                    eventRecord.Start_Date_Time__c,
                    eventRecord.Start_Location_Address__c,
                    eventRecord.Current_Coordinates__c,
                    toString(eventRecord.Start_Location__Latitude__s),
                    toString(eventRecord.Start_Location__Longitude__s)
                );
            }

            if (oldEvent.End_Date_Time__c == null && eventRecord.End_Date_Time__c != null) {
                handleCheckOut(
                    eventRecord.Id,
                    eventRecord.End_Date_Time__c,
                    eventRecord.End_Location_Address__c,
                    eventRecord.Current_Coordinates__c,
                    eventRecord.Distance_Between_Check_In_and_Check_Out__c,
                    toString(eventRecord.End_Location__Latitude__s),
                    toString(eventRecord.End_Location__Longitude__s)
                );
            }
        }
    }

    public static void handleCheckIn(
        Id eventId,
        DateTime checkInTime,
        String address,
        String coordinatesJson,
        String latitude,
        String longitude
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
        visit = applyCoordinates(
            visit,
            'Check_In_Latitude__c',
            'Check_In_Longitude__c',
            'Check_In_Geo__c',
            parseDecimal(latitude),
            parseDecimal(longitude)
        );
        insert visit;
    }

    public static void handleCheckOut(
        Id eventId,
        DateTime checkOutTime,
        String address,
        String coordinatesJson,
        Decimal distance,
        String latitude,
        String longitude
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
        visit = applyCoordinates(
            visit,
            'Check_Out_Latitude__c',
            'Check_Out_Longitude__c',
            'Check_Out_Geo__c',
            parseDecimal(latitude),
            parseDecimal(longitude)
        );
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

    private static Attendance_Log__c applyCoordinates(
        Attendance_Log__c visit,
        String numberLatField,
        String numberLngField,
        String geoFieldApiName,
        Decimal lat,
        Decimal lng
    ) {
        putIfValid(visit, numberLatField, lat);
        putIfValid(visit, numberLngField, lng);
        if (visit == null || lat == null || lng == null || String.isBlank(geoFieldApiName)) {
            return visit;
        }

        String prefix = geoFieldApiName.removeEnd('__c');
        putIfValid(visit, prefix + '__Latitude__s', lat);
        putIfValid(visit, prefix + '__Longitude__s', lng);

        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(visit));
        raw.put(prefix + '__Latitude__s', lat);
        raw.put(prefix + '__Longitude__s', lng);
        return (Attendance_Log__c) JSON.deserialize(JSON.serialize(raw), Attendance_Log__c.class);
    }

    private static void putIfValid(SObject record, String fieldName, Object value) {
        if (record == null || String.isBlank(fieldName) || value == null) {
            return;
        }
        try {
            record.put(fieldName, value);
        } catch (Exception e) {
            return;
        }
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

    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
