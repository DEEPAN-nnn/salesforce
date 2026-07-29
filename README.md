# Custom Highlights Panel

LWC for `Enquiry__c` that looks like the standard highlight panel and opens **existing Quick Actions** already in your org.

## Mark Dead = existing LWC (not a Quick Action)

```html
<c-mark-dead-button-flow record-id={recordId}></c-mark-dead-button-flow>
```

`markDeadButtonFlow` must already exist in your org. Do not replace it with a Quick Action.

## Call other existing Quick Actions

```javascript
this[NavigationMixin.Navigate]({
    type: 'standard__quickAction',
    attributes: {
        apiName: 'Enquiry__c.Related_Property'
    },
    state: {
        recordId: this.recordId
    }
});
```

## Larger Quick Action modals

`NavigationMixin` often opens Quick Actions in a smaller panel than the standard Highlights Panel. This project loads static resource `highlightPanelWideModal` via `loadStyle` so action modals use ~90vw width / 90vh height.

## Deploy

```bash
sf project deploy start --manifest manifest/package.xml
```

Requires existing org LWC: `markDeadButtonFlow`.
