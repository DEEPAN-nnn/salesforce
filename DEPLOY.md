# Custom Highlights Panel — deploy & mobile setup

## Two components

| LWC | App Builder label | Form factor |
|-----|-------------------|-------------|
| `customHighlightsPanel` | **Custom Highlights Panel** | **Desktop only** |
| `customHighlightsPanelMobile` | **Custom Highlights Panel Mobile** | **Phone only** |

Same actions and visibility rules. Different UI.

## Deploy order

1. Apex `HighlightsPanelController` (if not already)
2. `markDeadButtonFlow` (used by desktop panel)
3. `customHighlightsPanel` (desktop)
4. `customHighlightsPanelMobile` (phone)
5. Flow `Request_Dead_Approval` must be **Active**

## App Builder setup

### Desktop
1. Edit Enquiry record page → **Desktop**
2. Keep / add **Custom Highlights Panel**
3. Remove standard Highlights Panel if needed

### Phone
1. Switch form factor to **Phone**
2. **Remove** the old `Custom Highlights Panel` (desktop LWC) if it is still there
3. **Remove** standard Highlights Panel
4. Add **Custom Highlights Panel Mobile**
5. **Save** → **Activation** for Phone

## Mobile UI

- Circular actions only (no icon / record name / fields)
- **Mark Dead** = red circle + white X → Screen Flow modal
- Other actions = blue circles + white lightning
- **More** = bottom sheet with remaining actions (same colors/icons as Salesforce mobile)

## Visibility (both LWCs)

- Hide many actions for profile `Akshay Madane Profile`
- Assign Assistant: `Property_Sourcing_Assistance__c = false` and profile ≠ `Transaction Manager - HYD`
- Change Property Assistant: field = true and same profile restriction
- Merge Enquiry: System Administrator only
