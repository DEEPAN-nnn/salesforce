import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import PRIMARY_PICTURE_FIELD from '@salesforce/schema/Project__c.Primary_Picture__c';

// Replace with the exact Profile Name values from Setup → Profiles
const PROFILES_THAT_CAN_EDIT = [
    'System Administrator',
    'Profile Two',
    'Profile Three'
];

export default class PropertyPrimaryPicture extends LightningElement {
    @api recordId;

    isEditing = false;
    isReady = true;

    projectWire;
    userWire;

    @wire(getRecord, { recordId: '$recordId', fields: [PRIMARY_PICTURE_FIELD] })
    wiredProject(result) {
        this.projectWire = result;
    }

    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD] })
    wiredUser(result) {
        this.userWire = result;
    }

    get pictureUrl() {
        return getFieldValue(this.projectWire?.data, PRIMARY_PICTURE_FIELD);
    }

    get canEdit() {
        const profileName = getFieldValue(this.userWire?.data, PROFILE_NAME_FIELD);
        return PROFILES_THAT_CAN_EDIT.includes(profileName);
    }

    handleEdit() {
        if (!this.canEdit) {
            return;
        }
        this.isEditing = true;
    }

    handleCancel() {
        this.refreshComponent();
    }

    async handleSuccess() {
        if (this.recordId) {
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        }
        await this.refreshComponent();
    }

    async refreshComponent() {
        this.isEditing = false;
        this.isReady = false;

        const refreshes = [];
        if (this.projectWire) {
            refreshes.push(refreshApex(this.projectWire));
        }
        if (this.userWire) {
            refreshes.push(refreshApex(this.userWire));
        }
        await Promise.all(refreshes);

        // Remount this component's body only (not the whole page)
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.isReady = true;
        }, 0);
    }
}
