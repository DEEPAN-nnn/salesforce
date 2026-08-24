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

## Mobile shows standard Highlights Panel (but web shows custom)

Salesforce keeps **Desktop** and **Phone** layouts separate. Adding the LWC on web does **not** add it on mobile.

### Fix in Lightning App Builder
1. Open the **Enquiry__c** Lightning record page → **Edit**.
2. Top of App Builder: switch form factor from **Desktop** to **Phone** (phone icon).
3. On the Phone canvas:
   - **Remove** (or hide) the standard **Highlights Panel** / Dynamic Highlights Panel.
   - **Add** your custom component: **Custom Highlights Panel** (`customHighlightsPanel` / `c-custom-highlights-panel`).
4. Click **Save**.
5. Click **Activation** → make sure this page is assigned for **Phone** (and Desktop) for the right apps / profiles / record types.
6. In Salesforce mobile app: pull to refresh or reopen the Enquiry record.

Optional: on Desktop canvas, set a visibility filter on the **standard** Highlights Panel to Device = Phone only if you still keep it somewhere — usually better to remove it from Phone and leave only the custom LWC.

### Still wrong after that?
- Confirm you edited the **same** Lightning page that mobile uses (check Activation → Phone assignments).
- Clear Salesforce mobile cache / reinstall if the old page is cached.
