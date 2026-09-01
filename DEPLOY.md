# Deploy Fairdeal Phone Home

## 1. Deploy metadata

```bash
sf project deploy start --manifest manifest/package.xml
```

Or deploy: Apex `FairdealHomeMobileController` (+ test), LWC `fairdealHomeMobile`, FlexiPage `Fairdeal_Mobile_Home`.

## 2. Activate Phone Home

1. **Setup → Lightning App Builder**
2. Open **Fairdeal Mobile Home** (or edit the existing Home page and switch to **Phone**)
3. Confirm **Fairdeal Home Mobile** is in the main region
4. **Activation**
   - App: **Fairdeal**
   - Form factor: **Phone**
   - Assign as org / app default for Phone
5. Leave the current two-column page as the **Desktop** Home

## 3. Check in the Salesforce mobile app

Open the **Fairdeal** app → **Home**. You should see a single column: greeting → follow-ups → inspections → assignments → prospects → My Leads.

Desktop browser Home should be unchanged.

## Data notes

Lists read **Enquiry__c** owned by the running user. Date, phone, status, location, and hot-flag fields are detected if they exist. If a section is empty after deploy, send the Enquiry field API names used on desktop Home and we will pin them.
