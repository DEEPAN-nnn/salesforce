# Custom Highlights Panel

LWC for `Enquiry__c` that looks like the standard highlight panel and opens **existing Quick Actions** already in your org.

## Call an existing Quick Action (the important part)

```javascript
this[NavigationMixin.Navigate]({
    type: 'standard__quickAction',
    attributes: {
        apiName: 'Enquiry__c.Related_Property' // ObjectApiName.ActionApiName
    },
    state: {
        recordId: this.recordId // required for record-context actions
    }
});
```

| Action type | `apiName` example |
|---|---|
| Object Quick Action | `Enquiry__c.Related_Property` |
| Global Quick Action | `Global.LogACall` / `Global.NewTask` / `Global.NewEvent` |

Find the exact API name: **Setup → Object Manager → Enquiry → Buttons, Links, and Actions**.

### Button in HTML

```html
<button
    class="hp-btn hp-btn-standard"
    data-action="Enquiry__c.Related_Property"
    onclick={handleQuickAction}
>
    Related Property
</button>
```

### Overflow menu (use `onselect`, not `onclick` on each item)

```html
<lightning-button-menu onselect={handleMenuSelect}>
    <lightning-menu-item value="Enquiry__c.Sharing" label="Sharing"></lightning-menu-item>
    <lightning-menu-item value="Global.LogACall" label="Log a Call"></lightning-menu-item>
</lightning-button-menu>
```

## Why the old panel broke

1. `onclick` on `lightning-menu-item` does **not** pass `value` / `data-action` reliably — use `onselect` on `lightning-button-menu`.
2. Quick Action navigate was missing `state.recordId`, so the action often did nothing.

## What you must change

In `customHighlightsPanel.html`, replace placeholder action API names with your **real** org names, for example:

- `Enquiry__c.Mark_Dead`
- `Enquiry__c.Generate_Proposal`
- `Enquiry__c.Related_Property`
- `Enquiry__c.Assign_Assistant`
- `Enquiry__c.Change_Property_Assistant`
- `Enquiry__c.Update_Location`
- `Enquiry__c.Delete_Related_List`
- `Enquiry__c.Merge_Enquiry`
- `Enquiry__c.Sharing`

Edit / Clone / Delete stay as standard record navigation (not Quick Actions).

## Deploy

```bash
sf project deploy start \
  --source-dir force-app/main/default/lwc/customHighlightsPanel \
  --source-dir force-app/main/default/classes/HighlightsPanelController.cls \
  --source-dir force-app/main/default/classes/HighlightsPanelController.cls-meta.xml \
  --source-dir force-app/main/default/classes/HighlightsPanelControllerTest.cls \
  --source-dir force-app/main/default/classes/HighlightsPanelControllerTest.cls-meta.xml
```

Then on the Enquiry Lightning record page: remove the standard Highlights Panel (optional), add **Custom Highlights Panel**.

## Follow button

Requires Chatter feed tracking enabled on `Enquiry__c`. Apex: `HighlightsPanelController`.
