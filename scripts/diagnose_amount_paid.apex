/**
 * Anonymous Apex: print how Amount Paid would resolve in this org.
 * Developer Console → Debug → Open Execute Anonymous Window.
 */
AmountPaidRollup.cachedMapping = null;
AmountPaidRollup.Mapping mapping = AmountPaidRollup.resolve();
System.debug('parentAmountApi=' + mapping.parentAmountApi);
System.debug('childObjectApi=' + mapping.childObjectApi);
System.debug('lookupFieldApi=' + mapping.lookupFieldApi);
System.debug('childAmountApi=' + mapping.childAmountApi);
System.debug('relationshipName=' + mapping.relationshipName);
System.debug('isComplete=' + mapping.isComplete());

if (mapping.isComplete()) {
    AmountPaidRollup.rollup(
        new Map<Id, WorkOrder>(
            [SELECT Id FROM WorkOrder WHERE WorkOrderNumber = '05101444']
        )
            .keySet()
    );
}
