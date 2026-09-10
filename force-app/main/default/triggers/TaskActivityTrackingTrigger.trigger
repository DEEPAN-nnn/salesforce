trigger TaskActivityTrackingTrigger on Task (after insert) {
    ActivityTrackingService.createFromActivities(Trigger.new);
}
