import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PRIMARY_PICTURE_FIELD from '@salesforce/schema/Project__c.Primary_Picture__c';

export default class PropertyPrimaryPicture extends LightningElement {
    @api recordId;
    isEditing = false;

    @wire(getRecord, { recordId: '$recordId', fields: [PRIMARY_PICTURE_FIELD] })
    record;

    get pictureUrl() {
        return getFieldValue(this.record.data, PRIMARY_PICTURE_FIELD);
    }

    handleEdit() {
        this.isEditing = true;
    }

    handleCancel() {
        this.isEditing = false;
    }

    handleSuccess() {
        this.isEditing = false;
    }
}
