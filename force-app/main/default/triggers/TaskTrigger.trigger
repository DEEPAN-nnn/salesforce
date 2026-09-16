trigger TaskTrigger on Task (after insert) {
    TaskTriggerHandler.insertTask(Trigger.new);
    ActivityTrackingService.createFromActivities(Trigger.new);
}
