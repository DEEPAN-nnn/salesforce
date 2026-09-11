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
        Decimal checkInLat = parseDecimal(latitude);
        Decimal checkInLng = parseDecimal(longitude);
        putIfValid(visit, 'Check_In_Latitude__c', checkInLat);
        putIfValid(visit, 'Check_In_Longitude__c', checkInLng);
        setGeo(visit, 'Check_In_Geo__c', checkInLat, checkInLng);
        putIfValid(visit, 'Source__c', resolveSource());
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
        Decimal checkOutLat = parseDecimal(latitude);
        Decimal checkOutLng = parseDecimal(longitude);
        putIfValid(visit, 'Check_Out_Latitude__c', checkOutLat);
        putIfValid(visit, 'Check_Out_Longitude__c', checkOutLng);
        setGeo(visit, 'Check_Out_Geo__c', checkOutLat, checkOutLng);
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

    private static void setGeo(SObject record, String geoFieldApiName, Decimal lat, Decimal lng) {
        if (record == null || String.isBlank(geoFieldApiName) || lat == null || lng == null) {
            return;
        }
        String baseName = geoFieldApiName.endsWith('__c')
            ? geoFieldApiName.substring(0, geoFieldApiName.length() - 3)
            : geoFieldApiName;
        try {
            record.put(baseName + '__Latitude__s', lat);
            record.put(baseName + '__Longitude__s', lng);
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

    private static String resolveSource() {
        for (Schema.PicklistEntry entry : Attendance_Log__c.Source__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String pickValue = entry.getValue();
            String label = entry.getLabel();
            String combined = (pickValue + ' ' + label).toLowerCase();
            if (combined.contains('mobile') || combined.contains('button') ||
                combined.contains('check in') || combined.contains('check-in') ||
                combined.contains('app')) {
                return pickValue;
            }
        }
        return null;
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
