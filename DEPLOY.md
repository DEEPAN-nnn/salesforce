# Fix "Deployment failed • LineNumber: UNKNOWN • undefined"

That message from the LWC editor usually means a dependency failed, not a bad field name.

## Deploy in this order

### 1) Deploy Apex FIRST
In Setup → Apex Classes, update `HighlightsPanelController` so it includes:
- `isFollowing`
- `toggleFollow`
- `getCurrentUserProfileName`
- `createFeedPost`
- `createFeedPoll`

If those last two methods are missing, the LWC import fails with a vague UNKNOWN error.

### 2) Then deploy the LWC
In the LWC editor:
1. Check **Enable Standard Deployment** (bottom right)
2. Deploy `customHighLightPanel`

### 3) Confirm child LWC exists
HTML uses:
```html
<c-mark-dead-button-flow record-id={recordId}></c-mark-dead-button-flow>
```
The bundle API name must be exactly `markDeadButtonFlow`.

## Quick test if Apex is the problem
Temporarily comment these two lines in JS and deploy again:
```javascript
// import createFeedPost from '@salesforce/apex/HighlightsPanelController.createFeedPost';
// import createFeedPoll from '@salesforce/apex/HighlightsPanelController.createFeedPoll';
```
If deploy succeeds, Apex was the issue — deploy Apex methods, then uncomment.

## Mobile (Salesforce phone app)

1. In App Builder → Enquiry record page → switch to **Phone** form factor → add `customHighlightsPanel` (hide the standard Highlights Panel if needed).
2. Deploy the latest LWC (same actions/visibility as desktop; phone-friendly layout + full-width modals only).
3. If actions don’t open after deploy: clear Salesforce mobile cache (or reinstall), then reopen the record.
