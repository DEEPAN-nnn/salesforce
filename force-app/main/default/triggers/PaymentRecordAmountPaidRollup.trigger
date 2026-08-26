trigger PaymentRecordAmountPaidRollup on Payment_Record__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    List<SObject> records = Trigger.isDelete ? Trigger.old : Trigger.new;
    Set<Id> workOrderIds = new Set<Id>();
    AmountPaidRollup.Mapping mapping = AmountPaidRollup.resolve();

    if (!mapping.isComplete()) {
        AmountPaidRollup.rollupFromPaymentRecords(records);
        return;
    }

    if (Trigger.isUpdate) {
        for (Integer i = 0; i < Trigger.new.size(); i++) {
            SObject newer = Trigger.new[i];
            SObject older = Trigger.old[i];
            Id newWo = (Id) newer.get(mapping.lookupFieldApi);
            Id oldWo = (Id) older.get(mapping.lookupFieldApi);
            Decimal newAmt = (Decimal) newer.get(mapping.childAmountApi);
            Decimal oldAmt = (Decimal) older.get(mapping.childAmountApi);
            if (newWo != oldWo || newAmt != oldAmt) {
                if (newWo != null) {
                    workOrderIds.add(newWo);
                }
                if (oldWo != null) {
                    workOrderIds.add(oldWo);
                }
            }
        }
        AmountPaidRollup.rollup(workOrderIds);
        return;
    }

    AmountPaidRollup.rollupFromPaymentRecords(records);
}
