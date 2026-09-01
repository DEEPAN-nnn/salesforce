# Fairdeal mobile Home

The screenshot you sent is the **desktop Lightning Home** in a browser (wide two-column layout, full Fairdeal nav). The Salesforce **mobile app does not reuse that layout**. Phone Home is a separate form factor of a Lightning Home page.

## How desktop Home becomes Phone Home

1. **Setup → Lightning App Builder → Home page** (the current Fairdeal Home).
2. Top-right form factor: **Desktop** vs **Phone**.
3. Desktop can keep today’s two columns (follow-ups left, prospects right).
4. Phone is **one column**. Drag the same components into a stack, **or** drop **Fairdeal Home Mobile** (`fairdealHomeMobile`) as the only body component.
5. **Save → Activation → Phone** (and the Fairdeal app). Desktop activation stays on the existing page.

If Phone still shows the stretched desktop page, the Phone form factor was never activated — the mobile app then falls back to Desktop Home.

## What this branch adds

| Asset | Role |
|---|---|
| `fairdealHomeMobile` | Phone-stacked UI matching the current Home: greeting, today’s follow-ups, inspections, new assignments, prospects pipeline, My Leads filters |
| `FairdealHomeMobileController` | Greeting + Enquiry__c lists (field names resolved by describe) |
| `Fairdeal_Mobile_Home` | Lightning Home FlexiPage to assign to **Phone** |

## Deploy

See `DEPLOY.md`.

## Changes you can send next

Reply with the edits you want on this Phone Home, for example:

- Hide Prospects until after follow-ups
- Change Call / WA / Update behavior
- Different lead filters
- Match exact Enquiry field API names if a list is empty after deploy
