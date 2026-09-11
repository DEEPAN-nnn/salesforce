trigger EventTrigger on Event (after insert, after update) {
    if (Trigger.isInsert) {
        ActivityTrackingService.createFromActivities(Trigger.new);
    }
    if (Trigger.isUpdate) {
        ActivityTrackingService.syncVisitsFromEventUpdates(Trigger.new, Trigger.oldMap);
    }
}
