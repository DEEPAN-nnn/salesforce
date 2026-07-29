# Custom Highlights Panel — actions & visibility

## Actions imported from your standard Highlights Panel

| Standard action | In custom panel | How it runs |
|---|---|---|
| Mark dead | Yes | Existing LWC `c-mark-dead-button-flow` |
| Generate Proposal | Yes | Quick Action `Enquiry__c.Generate_Proposal` |
| Related Property | Yes | Quick Action `Enquiry__c.Related_Property` |
| Assign Assistant | Yes | Quick Action `Enquiry__c.Assign_Assistant` |
| Change Property Assistant | Yes | Quick Action `Enquiry__c.Change_Property_Assistant` |
| Update Location | Yes | Quick Action `Enquiry__c.Update_Location` |
| Delete Related List | Yes (overflow) | Quick Action `Enquiry__c.Delete_Related_List` |
| Edit | Yes (overflow) | Standard record edit |
| Clone | Yes (overflow) | Standard record clone |
| Merge Enquiry | Yes (overflow) | Quick Action `Enquiry__c.Merge_Enquiry` |
| New Event | Yes (overflow) | `Global.NewEvent` |
| New Task | Yes (overflow) | `Global.NewTask` |
| Log a Call | Yes (overflow) | `Global.LogACall` |
| Sharing | Yes (overflow) | Quick Action `Enquiry__c.Sharing` |
| Delete | Yes (overflow) | `deleteRecord` |
| Post / Poll | **No** | Chatter publisher actions — not available via `NavigationMixin` Quick Action |

(+ Follow is extra on the custom panel.)

Confirm Quick Action API names in **Setup → Object Manager → Enquiry → Buttons, Links, and Actions** if any button does nothing.

## Visibility conditions — where they came from

**We did not import the orange eye filters from App Builder.**  
Those filters live only on the Lightning page and cannot be read by LWC.

Visibility in this component came from **your original LWC code** you pasted earlier:

| Action | Custom panel rule (from your JS) |
|---|---|
| Generate Proposal, Related Property, Update Location, Delete Related List, Edit, Clone | Hidden when profile = `Akshay Madane Profile` |
| Assign Assistant | Shown when `Property_Sourcing_Assistance__c` is false AND profile ≠ `Transaction Manager - HYD` |
| Change Property Assistant | Shown when `Property_Sourcing_Assistance__c` is true AND profile ≠ `Transaction Manager - HYD` |
| Merge Enquiry | Shown only for `System Administrator` |
| Mark dead, New Event/Task, Log a Call, Sharing, Delete | Always shown (same as no eye icon on standard) |

If App Builder filters are different, open each action’s filter in App Builder and update the matching getter in `customHighlightsPanel.js`.
