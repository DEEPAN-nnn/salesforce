# Deploy Team Reports on Mobile My Day

Do **not** deploy `EnquiryMyDayController`. That class stays in the org unchanged.

## Deploy

```bash
sf project deploy start --metadata ApexClass:TeamReportsController,ApexClass:TeamReportsControllerTest,LightningComponentBundle:mobileMyDayScreen
```

`mobileMyDayScreen` in this repo is your existing My Day component **plus** the Team Reports section above Follow-ups. Follow-ups / Inspections / Assignments handlers are unchanged.

## Report names

Edit `TeamReportsController.reportSpecs()` if a name does not match. Cards look up `Report.Name` with contains-match:

| Match | Type |
|---|---|
| Action Wise Conversion | Funnel (D) — names under stages |
| Collection Target | Metric |
| Payments Report | Metric |
| Token Target | Metric |
| Token Achieved | Metric |
| Outstanding Payment | Metric |

## Clicks

- **View Report** → that Salesforce report
- **Funnel step or label** → same report with `fv0=<stage name>` (same idea as dashboard drill). If the report has no filter slot, add a filter on the grouping field in Report Builder so `fv0` maps.

## Section scroll

Team Reports uses the same `scroll-cap roomy` height as Follow-ups. `VISIBLE_CAP_REPORTS = 3` — extra cards stay behind the fade and scroll inside the section.
