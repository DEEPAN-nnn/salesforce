# Salesforce

Field Service org automation. This repository is incremental metadata, not a full org retrieve.

## Amount Paid (Work Order vs Payment Record)

Work Order **Amount Paid** does not auto-update from Payment Records. Flow **Work Order: Client PO Status Changed** only creates notes after Amount Paid already changes, and it skips `Status = Exported`. Investigation: [docs/AMOUNT_PAID_INVESTIGATION.md](docs/AMOUNT_PAID_INVESTIGATION.md). Deploy: [DEPLOY.md](DEPLOY.md).
