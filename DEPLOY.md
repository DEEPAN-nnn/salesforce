# Custom Highlights Panel — deploy & mobile setup

## Two components (+ Mark Dead)

| LWC | App Builder label | Form factor / use |
|-----|-------------------|-------------------|
| `customHighlightsPanel` | **Custom Highlights Panel** | Desktop |
| `customHighlightsPanelMobile` | **Custom Highlights Panel Mobile** | Phone |
| `markDeadButtonFlow` | (child) | Desktop Mark Dead (red rectangle) |
| `markDeadButtonFlowMobile` | (child) | Phone Mark Dead (red circle + X) |

## Deploy order

1. Apex `HighlightsPanelController` (if not already)
2. `markDeadButtonFlow` (desktop)
3. `markDeadButtonFlowMobile` (phone)
4. `customHighlightsPanel` (desktop)
5. `customHighlightsPanelMobile` (phone)
6. Flow `Request_Dead_Approval` must be **Active**

## App Builder setup

### Desktop
1. Edit Enquiry record page → **Desktop**
2. Keep / add **Custom Highlights Panel**
3. Remove standard Highlights Panel if needed

### Phone
1. Switch form factor to **Phone**
2. **Remove** the old desktop custom panel if still there
3. **Remove** standard Highlights Panel
4. Add **Custom Highlights Panel Mobile**
5. **Save** → **Activation** for Phone

## Mark Dead (mobile)

Separate LWC `markDeadButtonFlowMobile`:
- Red **36px** circle + white **X**
- Opens Screen Flow `Request_Dead_Approval` in a popup
- Auto-closes on finish
- Used as: `<c-mark-dead-button-flow-mobile record-id={recordId}></c-mark-dead-button-flow-mobile>`

## Visibility (both panels)

- Hide many actions for profile `Akshay Madane Profile`
- Assign Assistant: `Property_Sourcing_Assistance__c = false` and profile ≠ `Transaction Manager - HYD`
- Change Property Assistant: field = true and same profile restriction
- Merge Enquiry: System Administrator only
