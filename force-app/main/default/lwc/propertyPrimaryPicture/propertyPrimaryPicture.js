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
    isLoading = false;

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
        if (!this.canEdit || this.isLoading) {
            return;
        }
        this.isEditing = true;
    }

    handleSubmit() {
        this.isLoading = true;
    }

    handleError() {
        this.isLoading = false;
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
        this.isLoading = true;
        this.isEditing = false;

        const refreshes = [];
        if (this.projectWire) {
            refreshes.push(refreshApex(this.projectWire));
        }
        if (this.userWire) {
            refreshes.push(refreshApex(this.userWire));
        }
        await Promise.all(refreshes);

        this.isLoading = false;
    }
}
