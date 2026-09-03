# Deploy Team Reports on Mobile My Day

Do **not** deploy `EnquiryMyDayController`. That class stays in the org unchanged.

## Deploy

```bash
sf project deploy start --metadata ApexClass:TeamReportsController,ApexClass:TeamReportsControllerTest,LightningComponentBundle:mobileMyDayScreen
```

`mobileMyDayScreen` in this repo is your existing My Day component **plus** the Team Reports section above Follow-ups. Follow-ups / Inspections / Assignments handlers are unchanged.

## Reports (exact list you sent)

Looked up by **DeveloperName**, then **Id**, then **Name**.

| Name | DeveloperName | Id | Type |
|---|---|---|---|
| My Team Token Achieved | My_Team_Token_Achieved_ISv | 00OOW00000Mq1GH2AZ | Metric |
| My Team Payments Report | My_Team_Payments_Report_FkC | 00OOW00000GfZBt2AN | Metric |
| My Team's Target Report | My_Teams_Target_Report_ZVQ | 00O9F000000JQqfUAG | Metric |
| Team's Outstanding Payment | Outstanding_Tqu | 00O9F000000JTUcUAO | Metric |
| Action Wise Conversion Report - Overview | Action_Wise_Conversion_Report_OjA | 00OOW000006EKY52AO | Funnel (D) |

## Clicks

- **View Report** → that Salesforce report
- **Funnel step or label** → same report with `fv0=<stage name>` (same idea as dashboard drill). If the report has no filter slot, add a filter on the grouping field in Report Builder so `fv0` maps.

## Sample data to prove the reports

The dashboard does **not** query `Enquiry__c` itself. It runs the five saved reports. To see which **object + fields + filters** each report uses, deploy `TeamReportSampleData` and run:

```apex
System.debug(TeamReportSampleData.inspect());
System.debug(TeamReportSampleData.createSamples());
// later
System.debug(TeamReportSampleData.deleteSamples());
```

`inspect()` prints source object, groupings, columns, and saved filters. `createSamples()` inserts `SAMPLE_TEAM_REPORT_*` rows on that object (conversion = one row per stage: Shown Interest → Token).

## Section scroll

Team Reports uses the same `scroll-cap roomy` height as Follow-ups. `VISIBLE_CAP_REPORTS = 3` — extra cards stay behind the fade and scroll inside the section.
