/**
 * Removes Event invitees who have not responded (Status = New / No Response)
 * for more than 24 hours after they were invited. Does not remove the Event owner.
 */
public with sharing class EventNoResponseInviteeCleanup implements Schedulable, Database.Batchable<SObject> {
    private static final Integer HOURS_UNTIL_REMOVAL = 24;
    private static final Integer BATCH_SIZE = 200;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, BATCH_SIZE);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime cutoff = Datetime.now().addHours(-HOURS_UNTIL_REMOVAL);
        return Database.getQueryLocator(
            [
                SELECT Id, RelationId, Event.OwnerId
                FROM EventRelation
                WHERE IsInvitee = TRUE
                    AND Status = 'New'
                    AND CreatedDate < :cutoff
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<EventRelation> scope) {
        List<EventRelation> toDelete = new List<EventRelation>();
        for (EventRelation invitee : scope) {
            if (invitee.RelationId == invitee.Event.OwnerId) {
                continue;
            }
            toDelete.add(invitee);
        }
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}
