/**
 * Inspect the five dashboard reports and create SAMPLE_* records that should
 * appear in them. Run from Developer Console → Anonymous Apex:
 *
 *   System.debug(TeamReportSampleData.whatToCreate());
 *   System.debug(TeamReportSampleData.inspect());
 *   System.debug(TeamReportSampleData.createSamples());
 *   System.debug(TeamReportSampleData.deleteSamples());
 *
 * Reports are org metadata. This class does not guess prod Ids as the only key;
 * it reuses the same DeveloperName / Id / Name lookup as TeamReportsController.
 */
public with sharing class TeamReportSampleData {
    public class Spec {
        public String reportId;
        public String developerName;
        public String name;
        public Spec(String reportId, String developerName, String name) {
            this.reportId = reportId;
            this.developerName = developerName;
            this.name = name;
        }
    }

    private static final String SAMPLE_PREFIX = 'SAMPLE_TEAM_REPORT_';
    private static final List<String> FUNNEL_STAGES = new List<String>{
        'Shown Interest',
        'Qualify Meet',
        'Inspection',
        'Site Shortlisted',
        'Token'
    };
    private static final List<String> STATUS_FIELDS = new List<String>{
        'Status__c',
        'Stage__c',
        'Enquiry_Status__c',
        'Action__c',
        'Current_Status__c',
        'Status'
    };
    private static final List<String> DATE_FIELDS = new List<String>{
        'Edit_Date__c',
        'Conversion_Date__c',
        'Payment_Date__c',
        'Token_Date__c',
        'Follow_Up_Date__c',
        'Next_Follow_Up_Date__c',
        'Due_Date__c',
        'CloseDate',
        'CreatedDate'
    };
    private static final List<String> AMOUNT_FIELDS = new List<String>{
        'Amount__c',
        'Amount_Paid__c',
        'Collection_Amount__c',
        'Payment_Amount__c',
        'Target_Amount__c',
        'Outstanding__c',
        'Outstanding_Amount__c',
        'Balance__c',
        'Token_Amount__c',
        'Amount'
    };

    public static List<Spec> specs() {
        return new List<Spec>{
            new Spec(
                '00O9F000000JQqfUAG',
                'My_Teams_Target_Report_ZVQ',
                'My Team\'s Target Report'
            ),
            new Spec(
                '00OOW00000GfZBt2AN',
                'My_Team_Payments_Report_FkC',
                'My Team Payments Report'
            ),
            new Spec(
                '00OOW00000Mq1GH2AZ',
                'My_Team_Token_Achieved_ISv',
                'My Team Token Achieved'
            ),
            new Spec(
                '00O9F000000JTUcUAO',
                'Outstanding_Tqu',
                'Team\'s Outstanding Payment'
            ),
            new Spec(
                '00OOW000006EKY52AO',
                'Action_Wise_Conversion_Report_OjA',
                'Action Wise Conversion Report - Overview'
            )
        };
    }

    /**
     * Prints which report was found, the report type / source object,
     * groupings, columns, and saved filters. That is the list of records
     * the dashboard actually reads.
     */
    public static String inspect() {
        List<String> lines = new List<String>();
        lines.add('Run as: ' + UserInfo.getUserName() + ' (' + UserInfo.getUserId() + ')');
        lines.add('Org: ' + UserInfo.getOrganizationId());
        lines.add('');

        Map<String, Report> found = loadReports();
        for (Spec spec : specs()) {
            Report match = found.get(spec.developerName);
            lines.add('======== ' + spec.name + ' ========');
            lines.add('Hardcoded prod Id: ' + spec.reportId);
            lines.add('DeveloperName: ' + spec.developerName);
            if (match == null) {
                lines.add('NOT FOUND in this org. Dashboard tile will be empty.');
                lines.add('');
                continue;
            }
            lines.add('Found Id: ' + match.Id);
            lines.add('Found Name: ' + match.Name);
            lines.add(
                'Id matches prod hardcoded value: ' +
                    String.valueOf(match.Id == spec.reportId)
            );
            try {
                Reports.ReportDescribeResult described = Reports.ReportManager.describeReport(
                    match.Id
                );
                Reports.ReportMetadata meta = described.getReportMetadata();
                Reports.ReportType rType = meta.getReportType();
                lines.add(
                    'Report type: ' +
                        (rType == null ? '(none)' : rType.getType() + ' / ' + rType.getLabel())
                );
                String source = sourceFromMeta(
                    meta,
                    rType == null ? null : rType.getType()
                );
                lines.addAll(createThisRecordLines(source));
                lines.add('Scope: ' + String.valueOf(meta.getScope()));
                Reports.StandardDateFilter sdf = meta.getStandardDateFilter();
                if (sdf != null) {
                    lines.add(
                        'Standard date filter: column=' +
                            sdf.getColumn() +
                            ' duration=' +
                            sdf.getDurationValue()
                    );
                } else {
                    lines.add('Standard date filter: (none)');
                }
                lines.add('Groupings down:');
                if (meta.getGroupingsDown() == null || meta.getGroupingsDown().isEmpty()) {
                    lines.add('  (none — metric/grand total report)');
                } else {
                    for (Reports.GroupingInfo g : meta.getGroupingsDown()) {
                        lines.add('  - ' + g.getName() + ' sort=' + g.getSortOrder());
                    }
                }
                lines.add('Detail columns:');
                if (meta.getDetailColumns() == null || meta.getDetailColumns().isEmpty()) {
                    lines.add('  (none)');
                } else {
                    for (String col : meta.getDetailColumns()) {
                        lines.add('  - ' + col);
                    }
                }
                lines.add('Aggregates:');
                if (meta.getAggregates() == null || meta.getAggregates().isEmpty()) {
                    lines.add('  (none)');
                } else {
                    for (String agg : meta.getAggregates()) {
                        lines.add('  - ' + agg);
                    }
                }
                lines.add('Saved filters (these ARE used by the LWC):');
                List<Reports.ReportFilter> filters = meta.getReportFilters();
                if (filters == null || filters.isEmpty()) {
                    lines.add('  (none)');
                } else {
                    Integer i = 1;
                    for (Reports.ReportFilter f : filters) {
                        lines.add(
                            '  ' +
                                i +
                                '. ' +
                                f.getColumn() +
                                ' ' +
                                f.getOperator() +
                                ' ' +
                                f.getValue()
                        );
                        i++;
                    }
                }
                lines.add('Filter logic: ' + meta.getReportBooleanFilter());
            } catch (Exception e) {
                lines.add('Describe failed: ' + e.getMessage());
            }
            lines.add('');
        }
        return String.join(lines, '\n');
    }

    /**
     * Short list: which existing Salesforce record to click New on.
     * This does not create a custom object. The object already exists in the org.
     */
    public static String whatToCreate() {
        List<String> lines = new List<String>();
        lines.add(
            'You do NOT create a new object in Setup. Each report already runs on an existing record (Enquiry, Payment, Target, …).'
        );
        lines.add(
            'Find it in the UI: App Launcher → Reports → open the report name → Edit. The report type at the top is the record you must create.'
        );
        lines.add('');
        Map<String, Report> found = loadReports();
        for (Spec spec : specs()) {
            lines.add('======== ' + spec.name + ' ========');
            Report match = found.get(spec.developerName);
            if (match == null) {
                lines.add(
                    'Report not in this org. Search Reports for "' +
                        spec.name +
                        '". If missing, copy it from prod; do not create a new object.'
                );
                lines.add('');
                continue;
            }
            try {
                Reports.ReportDescribeResult described = Reports.ReportManager.describeReport(
                    match.Id
                );
                Reports.ReportMetadata meta = described.getReportMetadata();
                Reports.ReportType rType = meta.getReportType();
                String source = sourceFromMeta(
                    meta,
                    rType == null ? null : rType.getType()
                );
                lines.addAll(createThisRecordLines(source));
                if (rType != null && String.isNotBlank(rType.getLabel())) {
                    lines.add('Report type (UI name): ' + rType.getLabel());
                }
                String grouping = firstGroupingField(meta);
                if (String.isNotBlank(grouping)) {
                    lines.add('Set this field on the record: ' + grouping);
                    if (spec.developerName == 'Action_Wise_Conversion_Report_OjA') {
                        lines.add(
                            'Create 5 records, one for each value: Shown Interest, Qualify Meet, Inspection, Site Shortlisted, Token'
                        );
                    }
                }
                Reports.StandardDateFilter sdf = meta.getStandardDateFilter();
                if (sdf != null && String.isNotBlank(sdf.getColumn())) {
                    lines.add(
                        'Set date field ' +
                            sdf.getColumn() +
                            ' to TODAY so it passes "' +
                            sdf.getDurationValue() +
                            '"'
                    );
                }
                lines.add('Owner: you (' + UserInfo.getName() + ')');
            } catch (Exception e) {
                lines.add('Could not read report: ' + e.getMessage());
                lines.add(
                    'Manual: Reports → ' +
                        spec.name +
                        ' → Edit → note the report type → App Launcher → New on that item.'
                );
            }
            lines.add('');
        }
        lines.add(
            'To insert SAMPLE_TEAM_REPORT_* rows automatically after this: System.debug(TeamReportSampleData.createSamples());'
        );
        return String.join(lines, '\n');
    }

    /**
     * Creates SAMPLE_TEAM_REPORT_* rows on the source object of each report.
     * Conversion report gets one Enquiry (or source object) per funnel stage.
     * Metric reports get one currency/count row owned by the running user, dated today.
     */
    public static String createSamples() {
        List<String> lines = new List<String>();
        Map<String, Report> found = loadReports();
        Set<String> createdKeys = new Set<String>();

        for (Spec spec : specs()) {
            Report match = found.get(spec.developerName);
            lines.add('-------- ' + spec.name + ' --------');
            if (match == null) {
                lines.add('Skip: report not in this org.');
                continue;
            }
            String objectApi;
            String groupingField;
            try {
                Reports.ReportDescribeResult described = Reports.ReportManager.describeReport(
                    match.Id
                );
                Reports.ReportMetadata meta = described.getReportMetadata();
                objectApi = sourceFromMeta(
                    meta,
                    meta.getReportType() == null ? null : meta.getReportType().getType()
                );
                groupingField = firstGroupingField(meta);
                lines.add('Object: ' + objectApi);
                lines.add('Grouping field: ' + groupingField);
                Reports.StandardDateFilter sdf = meta.getStandardDateFilter();
                if (sdf != null) {
                    lines.add(
                        'Must match date filter ' +
                            sdf.getColumn() +
                            ' = ' +
                            sdf.getDurationValue() +
                            ' (samples use TODAY)'
                    );
                }
            } catch (Exception e) {
                lines.add('Describe failed: ' + e.getMessage());
                continue;
            }
            if (String.isBlank(objectApi) || !Schema.getGlobalDescribe().containsKey(objectApi)) {
                lines.add(
                    'Skip create: could not resolve a writable object from the report type. Open the report in Setup and insert a row on that object manually.'
                );
                continue;
            }
            Boolean isFunnel = spec.developerName == 'Action_Wise_Conversion_Report_OjA';
            try {
                if (isFunnel) {
                    for (String stage : FUNNEL_STAGES) {
                        String key = objectApi + ':' + stage;
                        if (createdKeys.contains(key)) {
                            continue;
                        }
                        Id recId = insertSample(objectApi, groupingField, stage, 1);
                        createdKeys.add(key);
                        lines.add('Created ' + recId + ' stage=' + stage);
                    }
                } else {
                    String key = objectApi + ':metric:' + spec.developerName;
                    if (!createdKeys.contains(key)) {
                        Decimal amount = spec.developerName.contains('Target')
                            ? 1000000
                            : spec.developerName.contains('Outstanding')
                                  ? 250000
                                  : spec.developerName.contains('Token') ? 3 : 400000;
                        Id recId = insertSample(
                            objectApi,
                            groupingField,
                            spec.developerName.contains('Token') ? 'Token' : null,
                            amount
                        );
                        createdKeys.add(key);
                        lines.add('Created ' + recId + ' amount-like value=' + amount);
                    } else {
                        lines.add('Already created a sample on ' + objectApi);
                    }
                }
            } catch (Exception e) {
                lines.add('Insert failed on ' + objectApi + ': ' + e.getMessage());
                lines.add(
                    'Open the report → Show Me / Filters, then create that object in the UI with those field values.'
                );
            }
        }
        lines.add('');
        lines.add(
            'Next: open each report as the same user. If still zero, the saved filter (My Team / role / record type) is excluding SAMPLE_* rows. Inspect() prints those filters.'
        );
        return String.join(lines, '\n');
    }

    public static String deleteSamples() {
        List<String> lines = new List<String>();
        Set<String> objects = new Set<String>();
        Map<String, Report> found = loadReports();
        for (Spec spec : specs()) {
            Report match = found.get(spec.developerName);
            if (match == null) {
                continue;
            }
            try {
                Reports.ReportDescribeResult described = Reports.ReportManager.describeReport(
                    match.Id
                );
                Reports.ReportMetadata meta = described.getReportMetadata();
                String objectApi = sourceFromMeta(
                    meta,
                    meta.getReportType() == null ? null : meta.getReportType().getType()
                );
                if (objectApi != null) {
                    objects.add(objectApi);
                }
            } catch (Exception e) {
                lines.add('Describe failed: ' + e.getMessage());
            }
        }
        if (Schema.getGlobalDescribe().containsKey('Enquiry__c')) {
            objects.add('Enquiry__c');
        }
        for (String objectApi : objects) {
            try {
                String nameField = nameFieldFor(objectApi);
                if (nameField == null) {
                    lines.add('Skip delete on ' + objectApi + ': no Name-like field');
                    continue;
                }
                String soql =
                    'SELECT Id, ' +
                    nameField +
                    ' FROM ' +
                    objectApi +
                    ' WHERE ' +
                    nameField +
                    ' LIKE \'' +
                    SAMPLE_PREFIX +
                    '%\'';
                List<SObject> rows = Database.query(soql);
                Integer n = rows.size();
                if (n > 0) {
                    delete rows;
                }
                lines.add('Deleted ' + n + ' from ' + objectApi);
            } catch (Exception e) {
                lines.add('Delete failed on ' + objectApi + ': ' + e.getMessage());
            }
        }
        return String.join(lines, '\n');
    }

    private static Map<String, Report> loadReports() {
        Set<Id> ids = new Set<Id>();
        Set<String> developerNames = new Set<String>();
        Set<String> names = new Set<String>();
        for (Spec spec : specs()) {
            ids.add((Id) spec.reportId);
            developerNames.add(spec.developerName);
            names.add(spec.name);
        }
        Map<String, Report> byDev = new Map<String, Report>();
        List<Report> rows = [
            SELECT Id, Name, DeveloperName
            FROM Report
            WHERE Id IN :ids OR DeveloperName IN :developerNames OR Name IN :names
        ];
        for (Spec spec : specs()) {
            Report match;
            for (Report row : rows) {
                if (row.DeveloperName == spec.developerName) {
                    match = row;
                    break;
                }
            }
            if (match == null) {
                for (Report row : rows) {
                    if (String.valueOf(row.Id) == spec.reportId) {
                        match = row;
                        break;
                    }
                }
            }
            if (match == null) {
                for (Report row : rows) {
                    if (row.Name == spec.name) {
                        match = row;
                        break;
                    }
                }
            }
            if (match != null) {
                byDev.put(spec.developerName, match);
            }
        }
        return byDev;
    }

    private static List<String> createThisRecordLines(String source) {
        List<String> lines = new List<String>();
        if (String.isBlank(source)) {
            lines.add(
                'CREATE THIS RECORD: (unknown) — open the report → Edit and read the report type.'
            );
            return lines;
        }
        String label = objectLabel(source);
        String plural = objectPlural(source);
        lines.add('CREATE THIS RECORD: ' + label);
        lines.add('API name: ' + source);
        lines.add(
            'How: App Launcher → search "' +
                (String.isBlank(plural) ? label : plural) +
                '" → New. Do not create a custom object in Setup.'
        );
        return lines;
    }

    private static String sourceFromMeta(Reports.ReportMetadata meta, String reportType) {
        String fromColumn = objectFromColumns(meta);
        if (String.isNotBlank(fromColumn)) {
            return fromColumn;
        }
        return sourceObject(reportType);
    }

    private static String objectFromColumns(Reports.ReportMetadata meta) {
        if (meta == null) {
            return null;
        }
        List<String> names = new List<String>();
        if (meta.getGroupingsDown() != null) {
            for (Reports.GroupingInfo g : meta.getGroupingsDown()) {
                names.add(g.getName());
            }
        }
        if (meta.getDetailColumns() != null) {
            names.addAll(meta.getDetailColumns());
        }
        if (meta.getAggregates() != null) {
            names.addAll(meta.getAggregates());
        }
        for (String raw : names) {
            if (String.isBlank(raw) || !raw.contains('.')) {
                continue;
            }
            String first = raw.substringBefore('.');
            if (first == 'CUST_NAME' || first == 'CUST' || first.startsWith('Bucket')) {
                continue;
            }
            if (Schema.getGlobalDescribe().containsKey(first)) {
                return first;
            }
        }
        return null;
    }

    private static String objectLabel(String api) {
        if (String.isBlank(api) || !Schema.getGlobalDescribe().containsKey(api)) {
            return api;
        }
        return Schema.getGlobalDescribe().get(api).getDescribe().getLabel();
    }

    private static String objectPlural(String api) {
        if (String.isBlank(api) || !Schema.getGlobalDescribe().containsKey(api)) {
            return api;
        }
        return Schema.getGlobalDescribe().get(api).getDescribe().getLabelPlural();
    }

    private static String sourceObject(String reportType) {
        if (String.isBlank(reportType)) {
            return null;
        }
        // CustomEntity$Enquiry__c  or  Enquiry__c@Enquiry__c  or  Opportunity
        if (reportType.contains('$')) {
            List<String> parts = reportType.split('\\$');
            return parts[parts.size() - 1];
        }
        if (reportType.contains('@')) {
            return reportType.split('@')[0];
        }
        if (reportType.contains('__c')) {
            return reportType.substringBefore('/');
        }
        if (reportType == 'Opportunity' || reportType == 'Account' || reportType == 'Lead') {
            return reportType;
        }
        return reportType;
    }

    private static String firstGroupingField(Reports.ReportMetadata meta) {
        if (meta.getGroupingsDown() == null || meta.getGroupingsDown().isEmpty()) {
            return null;
        }
        String raw = meta.getGroupingsDown()[0].getName();
        if (String.isBlank(raw)) {
            return null;
        }
        // Enquiry__c.Status__c or Status__c
        if (raw.contains('.')) {
            return raw.substringAfterLast('.');
        }
        return raw;
    }

    private static Id insertSample(
        String objectApi,
        String groupingField,
        String stage,
        Decimal amount
    ) {
        Schema.SObjectType token = Schema.getGlobalDescribe().get(objectApi);
        Schema.DescribeSObjectResult describeResult = token.getDescribe();
        if (!describeResult.isCreateable()) {
            throw new AuraHandledException(objectApi + ' is not createable for this user');
        }
        Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
        SObject rec = token.newSObject();
        String nameField = nameFieldFor(objectApi);
        if (nameField != null && fieldMap.get(nameField).getDescribe().isCreateable()) {
            String label = stage == null ? 'metric' : stage;
            rec.put(nameField, (SAMPLE_PREFIX + label).left(80));
        }
        if (fieldMap.containsKey('OwnerId') && fieldMap.get('OwnerId').getDescribe().isUpdateable()) {
            rec.put('OwnerId', UserInfo.getUserId());
        }
        putIfCreateable(rec, fieldMap, groupingField, stage);
        if (stage != null) {
            for (String statusField : STATUS_FIELDS) {
                if (statusField != groupingField) {
                    putIfCreateable(rec, fieldMap, statusField, stage);
                }
            }
        }
        Date today = Date.today();
        for (String dateField : DATE_FIELDS) {
            if (dateField == 'CreatedDate') {
                continue;
            }
            putIfCreateable(rec, fieldMap, dateField, today);
        }
        for (String amountField : AMOUNT_FIELDS) {
            putIfCreateable(rec, fieldMap, amountField, amount);
        }
        insert rec;
        return rec.Id;
    }

    private static void putIfCreateable(
        SObject rec,
        Map<String, Schema.SObjectField> fieldMap,
        String fieldName,
        Object value
    ) {
        if (String.isBlank(fieldName) || value == null || !fieldMap.containsKey(fieldName)) {
            return;
        }
        Schema.DescribeFieldResult fd = fieldMap.get(fieldName).getDescribe();
        if (!fd.isCreateable() || fd.isCalculated() || fd.isAutoNumber()) {
            return;
        }
        Schema.DisplayType dt = fd.getType();
        if (value instanceof String && (dt == Schema.DisplayType.PICKLIST || dt == Schema.DisplayType.STRING || dt == Schema.DisplayType.TEXTAREA)) {
            rec.put(fieldName, value);
        } else if (value instanceof Date && (dt == Schema.DisplayType.DATE || dt == Schema.DisplayType.DATETIME)) {
            rec.put(fieldName, value);
        } else if (
            value instanceof Decimal &&
            (dt == Schema.DisplayType.CURRENCY ||
            dt == Schema.DisplayType.DOUBLE ||
            dt == Schema.DisplayType.INTEGER ||
            dt == Schema.DisplayType.PERCENT)
        ) {
            rec.put(fieldName, value);
        }
    }

    private static String nameFieldFor(String objectApi) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
            .get(objectApi)
            .getDescribe()
            .fields.getMap();
        if (fieldMap.containsKey('Name')) {
            return 'Name';
        }
        for (String candidate : new List<String>{
            'Enquiry_Name__c',
            'Customer_Name__c',
            'Subject__c'
        }) {
            if (fieldMap.containsKey(candidate)) {
                return candidate;
            }
        }
        return null;
    }
}
