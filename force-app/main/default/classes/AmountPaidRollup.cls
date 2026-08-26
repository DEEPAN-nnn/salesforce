/**
 * Copies SUM(Payment Record "Amount Paid") onto Work Order "Amount Paid".
 *
 * Why this exists:
 * Work Order Amount Paid is a writable currency field (inline-edit pencil).
 * It is not a formula or roll-up summary, so Payment Record amounts do not
 * sync unless automation writes the parent field.
 *
 * Object/field API names are resolved from labels so this still works if the
 * payment object is Payment_Record__c or a similarly labeled custom object.
 */
public with sharing class AmountPaidRollup {
    public class Mapping {
        public String childObjectApi;
        public String lookupFieldApi;
        public String childAmountApi;
        public String parentAmountApi;
        public String relationshipName;

        public Boolean isComplete() {
            return String.isNotBlank(childObjectApi) &&
                String.isNotBlank(lookupFieldApi) &&
                String.isNotBlank(childAmountApi) &&
                String.isNotBlank(parentAmountApi);
        }
    }

    @TestVisible
    static Mapping cachedMapping;

    public static Mapping resolve() {
        if (cachedMapping != null) {
            return cachedMapping;
        }

        Mapping mapping = new Mapping();
        mapping.parentAmountApi = findCurrencyFieldByLabel(
            WorkOrder.SObjectType,
            'Amount Paid'
        );

        for (
            Schema.ChildRelationship rel : WorkOrder.SObjectType.getDescribe()
                .getChildRelationships()
        ) {
            if (rel.getChildSObject() == null || rel.getField() == null) {
                continue;
            }
            Schema.DescribeSObjectResult childDescribe = rel.getChildSObject()
                .getDescribe();
            if (!isPaymentRecordObject(childDescribe)) {
                continue;
            }

            String amountApi = findCurrencyFieldByLabel(
                rel.getChildSObject(),
                'Amount Paid'
            );
            if (String.isBlank(amountApi)) {
                continue;
            }

            mapping.childObjectApi = childDescribe.getName();
            mapping.lookupFieldApi = rel.getField().getDescribe().getName();
            mapping.relationshipName = rel.getRelationshipName();
            mapping.childAmountApi = amountApi;
            break;
        }

        cachedMapping = mapping;
        return mapping;
    }

    public static void rollupFromPaymentRecords(List<SObject> records) {
        Mapping mapping = resolve();
        if (!mapping.isComplete() || records == null || records.isEmpty()) {
            return;
        }

        Set<Id> workOrderIds = new Set<Id>();
        for (SObject record : records) {
            Id workOrderId = (Id) record.get(mapping.lookupFieldApi);
            if (workOrderId != null) {
                workOrderIds.add(workOrderId);
            }
        }
        rollup(workOrderIds);
    }

    public static void rollup(Set<Id> workOrderIds) {
        Mapping mapping = resolve();
        if (!mapping.isComplete() || workOrderIds == null || workOrderIds.isEmpty()) {
            return;
        }

        workOrderIds.remove(null);
        if (workOrderIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (Id workOrderId : workOrderIds) {
            totals.put(workOrderId, 0);
        }

        String soql =
            'SELECT ' +
            mapping.lookupFieldApi +
            ', ' +
            mapping.childAmountApi +
            ' FROM ' +
            mapping.childObjectApi +
            ' WHERE ' +
            mapping.lookupFieldApi +
            ' IN :workOrderIds';

        for (SObject payment : Database.query(soql)) {
            Id workOrderId = (Id) payment.get(mapping.lookupFieldApi);
            Decimal amount = (Decimal) payment.get(mapping.childAmountApi);
            if (workOrderId == null) {
                continue;
            }
            Decimal current = totals.containsKey(workOrderId)
                ? totals.get(workOrderId)
                : 0;
            totals.put(workOrderId, current + (amount == null ? 0 : amount));
        }

        List<WorkOrder> updates = new List<WorkOrder>();
        for (Id workOrderId : totals.keySet()) {
            WorkOrder workOrder = new WorkOrder(Id = workOrderId);
            workOrder.put(mapping.parentAmountApi, totals.get(workOrderId));
            updates.add(workOrder);
        }

        if (updates.isEmpty()) {
            return;
        }

        // Partial success: Exported WOs may have validation that blocks edits.
        Database.SaveResult[] results = Database.update(updates, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'AmountPaidRollup failed for Work Order ' +
                    updates[i].Id +
                    ': ' +
                    results[i].getErrors()
                );
            }
        }
    }

    static Boolean isPaymentRecordObject(Schema.DescribeSObjectResult childDescribe) {
        String label = childDescribe.getLabel() == null
            ? ''
            : childDescribe.getLabel();
        String plural = childDescribe.getLabelPlural() == null
            ? ''
            : childDescribe.getLabelPlural();
        String api = childDescribe.getName() == null ? '' : childDescribe.getName();
        return label.equalsIgnoreCase('Payment Record') ||
            plural.equalsIgnoreCase('Payment Records') ||
            api.containsIgnoreCase('Payment_Record');
    }

    static String findCurrencyFieldByLabel(
        Schema.SObjectType objectType,
        String label
    ) {
        Map<String, Schema.SObjectField> fields = objectType.getDescribe()
            .fields.getMap();
        for (Schema.SObjectField field : fields.values()) {
            Schema.DescribeFieldResult describe = field.getDescribe();
            if (
                describe.getLabel() == label &&
                describe.getType() == Schema.DisplayType.Currency
            ) {
                return describe.getName();
            }
        }
        return null;
    }
}
