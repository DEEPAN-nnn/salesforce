/**
 * Team Reports for Mobile My Day. New class only — does not change EnquiryMyDayController.
 *
 * Edit REPORT_SPECS to choose which reports appear. NameMatch is matched against Report.Name
 * (contains, case-insensitive). Kind FUNNEL = Action Wise Conversion (option D). METRIC = number strip.
 */
public with sharing class TeamReportsController {
    public class ReportSpec {
        public String nameMatch;
        public String kind;
        public ReportSpec(String nameMatch, String kind) {
            this.nameMatch = nameMatch;
            this.kind = kind;
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
        @AuraEnabled public String warning;
    }

    /**
     * Only these reports are shown. Add/remove rows here — do not change Mobile My Day follow-ups.
     */
    @TestVisible
    private static List<ReportSpec> reportSpecs() {
        return new List<ReportSpec>{
            new ReportSpec('Action Wise Conversion', 'FUNNEL'),
            new ReportSpec('Collection Target', 'METRIC'),
            new ReportSpec('Payments Report', 'METRIC'),
            new ReportSpec('Token Target', 'METRIC'),
            new ReportSpec('Token Achieved', 'METRIC'),
            new ReportSpec('Outstanding Payment', 'METRIC')
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<TeamReportCard> getTeamReports() {
        List<ReportSpec> specs = reportSpecs();
        List<TeamReportCard> cards = new List<TeamReportCard>();
        if (!Schema.sObjectType.Report.isAccessible()) {
            return cards;
        }

        List<String> likeParts = new List<String>();
        for (ReportSpec spec : specs) {
            likeParts.add(
                'Name LIKE \'%' + String.escapeSingleQuotes(spec.nameMatch) + '%\''
            );
        }
        String soql =
            'SELECT Id, Name, DeveloperName FROM Report WHERE ' +
            String.join(likeParts, ' OR ') +
            ' LIMIT 200';
        List<Report> reports = Database.query(soql);

        for (ReportSpec spec : specs) {
            Report match = findReport(reports, spec.nameMatch);
            TeamReportCard card = new TeamReportCard();
            card.name = spec.nameMatch;
            card.kind = spec.kind;
            card.isFunnel = spec.kind == 'FUNNEL';
            card.colorClass = colorClassFor(spec.nameMatch, spec.kind);
            card.stages = new List<FunnelStage>();
            card.sparkPoints = '0,20 20,16 40,18 60,14 80,12';
            card.displayValue = '—';
            if (match == null) {
                card.id = 'missing-' + spec.nameMatch;
                card.warning = 'Report not found: ' + spec.nameMatch;
                cards.add(card);
                continue;
            }
            card.id = match.Id;
            card.reportId = match.Id;
            card.name = match.Name;
            try {
                fillFromReport(card, match.Id, spec.kind);
            } catch (Exception e) {
                card.warning = e.getMessage();
            }
            cards.add(card);
        }
        return cards;
    }

    private static Report findReport(List<Report> reports, String nameMatch) {
        String needle = nameMatch.toLowerCase();
        for (Report row : reports) {
            if (row.Name != null && row.Name.toLowerCase().contains(needle)) {
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
            return String.valueOf(val.longValue());
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
