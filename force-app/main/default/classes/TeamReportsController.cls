/**
 * Team Reports for Mobile My Day. New class only — does not change EnquiryMyDayController.
 *
 * Only the reports supplied from the org (Id + DeveloperName + Name).
 * Kind FUNNEL = Action Wise Conversion (option D). METRIC = number strip.
 */
public with sharing class TeamReportsController {
    public class ReportSpec {
        public String reportId;
        public String developerName;
        public String name;
        public String kind;
        public String shortLabel;
        public ReportSpec(
            String reportId,
            String developerName,
            String name,
            String kind,
            String shortLabel
        ) {
            this.reportId = reportId;
            this.developerName = developerName;
            this.name = name;
            this.kind = kind;
            this.shortLabel = shortLabel;
        }
    }

    public class FunnelStage {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String displayValue;
        @AuraEnabled public Decimal value;
    }

    public class TeamReportCard {
        @AuraEnabled public String id;
        @AuraEnabled public String reportId;
        @AuraEnabled public String name;
        @AuraEnabled public String kind;
        @AuraEnabled public Boolean isFunnel;
        @AuraEnabled public String displayValue;
        @AuraEnabled public String colorClass;
        @AuraEnabled public String sparkPoints;
        @AuraEnabled public List<FunnelStage> stages;
        @AuraEnabled public String displayName;
        @AuraEnabled public String warning;
    }

    /**
     * Only these five reports. Order is the list you sent.
     */
    @TestVisible
    private static List<ReportSpec> reportSpecs() {
        return new List<ReportSpec>{
            new ReportSpec(
                '00O9F000000JQqfUAG',
                'My_Teams_Target_Report_ZVQ',
                'My Team\'s Target Report',
                'METRIC',
                'Collection Target'
            ),
            new ReportSpec(
                '00OOW00000GfZBt2AN',
                'My_Team_Payments_Report_FkC',
                'My Team Payments Report',
                'METRIC',
                'My Collection Report'
            ),
            new ReportSpec(
                '00OOW00000Mq1GH2AZ',
                'My_Team_Token_Achieved_ISv',
                'My Team Token Achieved',
                'METRIC',
                'Token Achieved'
            ),
            new ReportSpec(
                '00O9F000000JTUcUAO',
                'Outstanding_Tqu',
                'Team\'s Outstanding Payment',
                'METRIC',
                'Billed & Outstanding'
            ),
            new ReportSpec(
                '00OOW000006EKY52AO',
                'Action_Wise_Conversion_Report_OjA',
                'Action Wise Conversion Report - Overview',
                'FUNNEL',
                'My Action Wise Conversion Report'
            )
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<TeamReportCard> getTeamReports() {
        List<ReportSpec> specs = reportSpecs();
        List<TeamReportCard> cards = new List<TeamReportCard>();
        if (!Schema.sObjectType.Report.isAccessible()) {
            return cards;
        }

        Set<Id> ids = new Set<Id>();
        Set<String> developerNames = new Set<String>();
        for (ReportSpec spec : specs) {
            if (String.isNotBlank(spec.reportId)) {
                ids.add((Id) spec.reportId);
            }
            if (String.isNotBlank(spec.developerName)) {
                developerNames.add(spec.developerName);
            }
        }

        List<Report> reports = [
            SELECT Id, Name, DeveloperName
            FROM Report
            WHERE Id IN :ids OR DeveloperName IN :developerNames
        ];

        for (ReportSpec spec : specs) {
            Report match = findReport(reports, spec);
            TeamReportCard card = new TeamReportCard();
            card.name = spec.name;
            card.displayName = spec.shortLabel;
            card.kind = spec.kind;
            card.isFunnel = spec.kind == 'FUNNEL';
            card.colorClass = colorClassFor(spec.name, spec.kind);
            card.stages = new List<FunnelStage>();
            card.sparkPoints = '0,20 20,16 40,18 60,14 80,12';
            card.displayValue = '—';
            if (match == null) {
                card.id = 'missing-' + spec.developerName;
                card.warning = 'Report not found: ' + spec.name;
                cards.add(card);
                continue;
            }
            card.id = match.Id;
            card.reportId = match.Id;
            if (String.isBlank(card.displayName)) {
                card.displayName = match.Name;
            }
            try {
                fillFromReport(card, match.Id, spec.kind);
            } catch (Exception e) {
                card.warning = e.getMessage();
            }
            cards.add(card);
        }
        return cards;
    }

    private static Report findReport(List<Report> reports, ReportSpec spec) {
        for (Report row : reports) {
            if (row.DeveloperName == spec.developerName) {
                return row;
            }
        }
        for (Report row : reports) {
            if (String.valueOf(row.Id) == spec.reportId) {
                return row;
            }
        }
        for (Report row : reports) {
            if (row.Name == spec.name) {
                return row;
            }
        }
        return null;
    }

    private static void fillFromReport(TeamReportCard card, Id reportId, String kind) {
        Reports.ReportResults results = Reports.ReportManager.runReport(reportId, false);
        if (kind == 'FUNNEL') {
            card.stages = groupingStages(results);
            if (!card.stages.isEmpty()) {
                card.displayValue = card.stages[0].displayValue;
            }
            card.sparkPoints = sparkFromStages(card.stages);
            return;
        }
        Decimal total = grandTotal(results);
        card.displayValue = formatNumber(total, card.name);
        List<FunnelStage> down = groupingStages(results);
        if (!down.isEmpty()) {
            card.sparkPoints = sparkFromStages(down);
        }
    }

    private static List<FunnelStage> groupingStages(Reports.ReportResults results) {
        List<FunnelStage> stages = new List<FunnelStage>();
        Reports.Dimension dim = results.getGroupingsDown();
        if (dim == null || dim.getGroupings() == null) {
            return stages;
        }
        Map<String, Reports.ReportFact> facts = results.getFactMap();
        Integer idx = 0;
        for (Reports.GroupingValue grouping : dim.getGroupings()) {
            FunnelStage stage = new FunnelStage();
            stage.label = grouping.getLabel();
            stage.key = grouping.getKey();
            if (String.isBlank(stage.key)) {
                stage.key = 'stage-' + idx;
            }
            Decimal val = firstAggregate(facts, grouping.getKey() + '!T');
            stage.value = val;
            stage.displayValue = formatPlain(val);
            stages.add(stage);
            idx++;
        }
        return stages;
    }

    private static Decimal grandTotal(Reports.ReportResults results) {
        return firstAggregate(results.getFactMap(), 'T');
    }

    private static Decimal firstAggregate(Map<String, Reports.ReportFact> facts, String key) {
        if (facts == null || !facts.containsKey(key)) {
            return 0;
        }
        Reports.ReportFact fact = facts.get(key);
        List<Reports.SummaryValue> aggs = fact.getAggregates();
        if (aggs == null || aggs.isEmpty() || aggs[0].getValue() == null) {
            return 0;
        }
        Object raw = aggs[0].getValue();
        if (raw instanceof Decimal) {
            return (Decimal) raw;
        }
        if (raw instanceof Integer) {
            return Decimal.valueOf((Integer) raw);
        }
        if (raw instanceof Long) {
            return Decimal.valueOf((Long) raw);
        }
        try {
            return Decimal.valueOf(String.valueOf(raw));
        } catch (Exception e) {
            return 0;
        }
    }

    private static String sparkFromStages(List<FunnelStage> stages) {
        if (stages == null || stages.isEmpty()) {
            return '0,20 80,20';
        }
        Decimal maxVal = 1;
        for (FunnelStage stage : stages) {
            if (stage.value != null && stage.value > maxVal) {
                maxVal = stage.value;
            }
        }
        List<String> pts = new List<String>();
        Integer n = stages.size();
        for (Integer i = 0; i < n; i++) {
            Decimal v = stages[i].value == null ? 0 : stages[i].value;
            Decimal x = n == 1 ? 40 : (80.0 * i / (n - 1));
            Decimal y = 22 - (18 * (v / maxVal));
            pts.add(String.valueOf(x.setScale(1)) + ',' + String.valueOf(y.setScale(1)));
        }
        return String.join(pts, ' ');
    }

    private static String formatNumber(Decimal val, String name) {
        if (val == null) {
            return '0';
        }
        String lower = name == null ? '' : name.toLowerCase();
        Boolean money =
            lower.contains('payment') ||
            lower.contains('outstanding') ||
            lower.contains('finalization') ||
            lower.contains('collection');
        String core = formatPlain(val);
        return money ? ('₹' + core) : core;
    }

    private static String formatPlain(Decimal val) {
        if (val == null) {
            return '0';
        }
        if (val == val.setScale(0)) {
            return val.setScale(0).format();
        }
        return String.valueOf(val.setScale(2));
    }

    private static String colorClassFor(String name, String kind) {
        if (kind == 'FUNNEL') {
            return 'card-report-blue';
        }
        String lower = name == null ? '' : name.toLowerCase();
        if (lower.contains('achieved') || lower.contains('finalization')) {
            return 'card-report-green';
        }
        if (lower.contains('token target')) {
            return 'card-report-amber';
        }
        if (
            lower.contains('collection') ||
            lower.contains('outstanding') ||
            lower.contains('payment') ||
            lower.contains('token')
        ) {
            return 'card-report-red';
        }
        return 'card-report-blue';
    }
}
