public with sharing class AmountPaidRollupInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id workOrderId;
    }

    @InvocableMethod(
        label='Roll up Payment Amount Paid to Work Order'
        description='Sets Work Order Amount Paid to the SUM of related Payment Record Amount Paid values.'
    )
    public static void rollup(List<Request> requests) {
        Set<Id> workOrderIds = new Set<Id>();
        if (requests != null) {
            for (Request request : requests) {
                if (request != null && request.workOrderId != null) {
                    workOrderIds.add(request.workOrderId);
                }
            }
        }
        AmountPaidRollup.rollup(workOrderIds);
    }
}
