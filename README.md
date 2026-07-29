# Custom Highlights Panel

## Deploy error fixed

Do **not** import `@salesforce/resourceUrl/highlightPanelWideModal`.
That caused: `Invalid reference highlightPanelWideModal of type resourceUrl`.

Wide modals are done by injecting CSS in JS (no Static Resource).

## What to update in your org component

In `customHighLightPanel.js` (your org name), **remove these lines** if present:

```javascript
import { loadStyle } from 'lightning/platformResourceLoader';
import HIGHLIGHT_PANEL_WIDE_MODAL from '@salesforce/resourceUrl/highlightPanelWideModal';
```

And replace the `loadStyle(...)` / `loadWideModalStyles` logic with `injectWideModalStyles()` from the repo JS.

## Why standard is big and custom was small

`NavigationMixin` + `standard__quickAction` opens a smaller modal than the standard Highlights Panel. The panel injects CSS so `.slds-modal__container` uses ~90vw (large).

## Mark Dead

```html
<c-mark-dead-button-flow record-id={recordId}></c-mark-dead-button-flow>
```

## Deploy only the LWC (+ Apex if needed)

```bash
sf project deploy start --source-dir force-app/main/default/lwc/customHighlightsPanel
```
