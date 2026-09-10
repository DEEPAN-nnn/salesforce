trigger EventActivityTrackingTrigger on Event (after insert) {
    ActivityTrackingService.createFromActivities(Trigger.new);
}
