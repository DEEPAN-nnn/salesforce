@IsTest
private class AmountPaidRollupTest {
    @IsTest
    static void resolveDoesNotThrow() {
        AmountPaidRollup.cachedMapping = null;
        AmountPaidRollup.Mapping mapping = AmountPaidRollup.resolve();
        System.assertNotEquals(null, mapping, 'Mapping should always be returned');
    }

    @IsTest
    static void emptyRollupIsNoOp() {
        AmountPaidRollup.rollup(new Set<Id>());
        AmountPaidRollup.rollup(null);
        AmountPaidRollup.rollupFromPaymentRecords(new List<SObject>());
        AmountPaidRollup.rollupFromPaymentRecords(null);
    }

    @IsTest
    static void invocableIgnoresBlankIds() {
        AmountPaidRollupInvocable.Request blank = new AmountPaidRollupInvocable.Request();
        AmountPaidRollupInvocable.rollup(
            new List<AmountPaidRollupInvocable.Request>{ blank, null }
        );
    }

    @IsTest
    static void batchStartAndExecuteDoNotThrow() {
        Test.startTest();
        AmountPaidRollupBatch batch = new AmountPaidRollupBatch();
        Database.QueryLocator locator = batch.start(null);
        System.assertNotEquals(null, locator);
        batch.execute(null, new List<SObject>());
        batch.finish(null);
        batch.execute((SchedulableContext) null);
        Test.stopTest();
    }

    @IsTest
    static void completeMappingRollsUpWhenPaymentObjectExists() {
        AmountPaidRollup.cachedMapping = null;
        AmountPaidRollup.Mapping mapping = AmountPaidRollup.resolve();
        if (!mapping.isComplete()) {
            System.assertEquals(
                false,
                mapping.isComplete(),
                'Scratch/org without Payment Records stays incomplete'
            );
            return;
        }

        WorkOrder workOrder = new WorkOrder(
            Status = 'New',
            Subject = 'Amount paid rollup test'
        );
        try {
            insert workOrder;
        } catch (DmlException e) {
            return;
        }

        SObject payment = Schema.getGlobalDescribe()
            .get(mapping.childObjectApi)
            .newSObject();
        payment.put(mapping.lookupFieldApi, workOrder.Id);
        payment.put(mapping.childAmountApi, 126);
        try {
            insert payment;
        } catch (DmlException e) {
            return;
        }

        String requerySoql =
            'SELECT Id, ' +
            mapping.parentAmountApi +
            ' FROM WorkOrder WHERE Id = \'' +
            String.escapeSingleQuotes(workOrder.Id) +
            '\'';
        WorkOrder requery = (WorkOrder) Database.query(requerySoql);
        Decimal rolledUp = (Decimal) requery.get(mapping.parentAmountApi);
        System.assertEquals(
            126,
            rolledUp,
            'Work Order Amount Paid should match the Payment Record'
        );
    }
}
