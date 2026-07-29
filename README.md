# Custom Highlights Panel — actions & visibility

## What the mobile icon means (Post / Poll)

In App Builder, the **phone icon** means that action is set for **Phone form factor only**.
It will not show on desktop in the standard Highlights Panel.

In our LWC we mirror that with:

```javascript
import FORM_FACTOR from '@salesforce/client/formFactor';
// Small = Phone, Medium = Tablet, Large = Desktop
get showPostPoll() {
    return FORM_FACTOR === 'Small';
}
```

So **Post / Poll appear only on mobile** in the custom panel too.

## Visibility conditions (from your App Builder screenshots)

| Action | App Builder filter | Implemented as |
|---|---|---|
| Generate Proposal | Profile ≠ Akshay Madane Profile | `!isHiddenProfile` |
| Related Property | Profile ≠ Akshay Madane Profile | `!isHiddenProfile` |
| Update Location | Profile ≠ Akshay Madane Profile | `!isHiddenProfile` |
| Delete Related List | Profile ≠ Akshay Madane Profile | `!isHiddenProfile` |
| Edit | Profile ≠ Akshay Madane Profile | `!isHiddenProfile` |
| Clone | Profile ≠ Akshay Madane Profile | `!isHiddenProfile` |
| Assign Assistant | Property Sourcing Assistance = false **AND** Profile ≠ Transaction Manager - HYD | `showAssignAssistant` |
| Change Property Assistant | Property Sourcing Assistance = true **AND** Profile ≠ Transaction Manager - HYD | `showChangePropertyAssistant` |
| Merge Enquiry | Profile = System Administrator | `showMergeEnquiry` |
| Post / Poll | Phone form factor only | `showPostPoll` (FORM_FACTOR === 'Small') |
| Mark dead, New Event/Task, Log a Call, Sharing, Delete | No filter | Always shown |

## Deploy

Redeploy LWC `customHighlightsPanel` (+ Apex if Post/Poll composers not deployed yet).
