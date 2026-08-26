/**
 * Nightly/on-demand backfill for Work Orders whose Amount Paid drifted
 * (Payment Records created after export, failed parent updates, etc.).
 */
public with sharing class AmountPaidRollupBatch implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(new AmountPaidRollupBatch(), 50);
    }

    public Database.QueryLocator start(Database.BatchableContext ctx) {
        AmountPaidRollup.Mapping mapping = AmountPaidRollup.resolve();
        if (!mapping.isComplete()) {
            return Database.getQueryLocator(
                'SELECT Id FROM WorkOrder WHERE Id = null'
            );
        }
        String soql =
            'SELECT Id FROM WorkOrder WHERE Id IN (SELECT ' +
            mapping.lookupFieldApi +
            ' FROM ' +
            mapping.childObjectApi +
            ')';
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext ctx, List<SObject> scope) {
        Set<Id> workOrderIds = new Set<Id>();
        for (SObject record : scope) {
            workOrderIds.add(record.Id);
        }
        AmountPaidRollup.rollup(workOrderIds);
    }

    public void finish(Database.BatchableContext ctx) {
    }
}
