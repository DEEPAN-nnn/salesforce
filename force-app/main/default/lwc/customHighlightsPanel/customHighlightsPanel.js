import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import isFollowing from '@salesforce/apex/HighlightsPanelController.isFollowing';
import toggleFollow from '@salesforce/apex/HighlightsPanelController.toggleFollow';
import getCurrentUserProfileName from '@salesforce/apex/HighlightsPanelController.getCurrentUserProfileName';

const OBJECT_API_NAME = 'Enquiry__c';
const HIDDEN_PROFILE = 'Akshay Madane Profile';
const RESTRICTED_ASSISTANT_PROFILE = 'Transaction Manager - HYD';
const LOCAL_MENU_ACTIONS = new Set(['edit', 'clone', 'delete']);
const MEDIUM_MODAL_ACTIONS = new Set(['Enquiry__c.Mark_Dead']);
const MODAL_STYLE_ID = 'customHighlightsPanelModalSize';
const LARGE_MODAL_CSS =
    '.slds-modal__container{width:90vw!important;max-width:90vw!important;min-width:70vw!important;max-height:90vh!important;}' +
    '.slds-modal__content{max-height:calc(90vh - 8rem)!important;}';
const MEDIUM_MODAL_CSS =
    '.slds-modal__container{width:70%!important;max-width:50rem!important;min-width:20rem!important;max-height:80vh!important;}' +
    '.slds-modal__content{max-height:calc(80vh - 8rem)!important;}';

/**
 * Desktop Highlights Panel.
 * Phone uses separate LWC: customHighlightsPanelMobile
 */
export default class CustomHighlightsPanel extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName = OBJECT_API_NAME;

    @track isFollowLoading = false;
    @track isActionLoading = false;
    @track contactPhone = '';
    @track requirement = '';
    @track subLocation = '';
    @track currentStatus = '';
    @track stage = '';
    @track channel = '';
    @track following = false;
    @track recordName = '';
    @track profileName = '';
    @track propertySourcingAssistance = false;

    @wire(getCurrentUserProfileName)
    wiredProfile({ data, error }) {
        if (data) {
            this.profileName = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Profile fetch error:', error);
        }
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: ['Enquiry__c.Name'],
        optionalFields: [
            'Enquiry__c.Contact_1_Phone__c',
            'Enquiry__c.Requirement__c',
            'Enquiry__c.Sub_Location__c',
            'Enquiry__c.Current_Status__c',
            'Enquiry__c.Stage__c',
            'Enquiry__c.Channel__c',
            'Enquiry__c.Property_Sourcing_Assistance__c'
        ]
    })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordName = getFieldValue(data, 'Enquiry__c.Name') || '';
            this.contactPhone =
                getFieldValue(data, 'Enquiry__c.Contact_1_Phone__c') || '';
            this.requirement =
                getFieldValue(data, 'Enquiry__c.Requirement__c') || '';
            this.subLocation =
                getFieldValue(data, 'Enquiry__c.Sub_Location__c') || '';
            this.currentStatus =
                getFieldValue(data, 'Enquiry__c.Current_Status__c') || '';
            this.stage = getFieldValue(data, 'Enquiry__c.Stage__c') || '';
            this.channel = getFieldValue(data, 'Enquiry__c.Channel__c') || '';
            this.propertySourcingAssistance = !!getFieldValue(
                data,
                'Enquiry__c.Property_Sourcing_Assistance__c'
            );
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Record wire error:', error);
        }
    }

    displayOrBlank(value) {
        const v = value === null || value === undefined ? '' : String(value).trim();
        return v || '';
    }

    get contactPhoneDisplay() {
        return this.displayOrBlank(this.contactPhone);
    }
    get requirementDisplay() {
        return this.displayOrBlank(this.requirement);
    }
    get subLocationDisplay() {
        return this.displayOrBlank(this.subLocation);
    }
    get currentStatusDisplay() {
        return this.displayOrBlank(this.currentStatus);
    }
    get stageDisplay() {
        return this.displayOrBlank(this.stage);
    }
    get channelDisplay() {
        return this.displayOrBlank(this.channel);
    }

    get isHiddenProfile() {
        return this.profileName === HIDDEN_PROFILE;
    }

    get showAssignAssistant() {
        return (
            !this.propertySourcingAssistance &&
            this.profileName !== RESTRICTED_ASSISTANT_PROFILE
        );
    }

    get showChangePropertyAssistant() {
        return (
            this.propertySourcingAssistance &&
            this.profileName !== RESTRICTED_ASSISTANT_PROFILE
        );
    }

    get showMergeEnquiry() {
        return this.profileName === 'System Administrator';
    }

    get showGenerateProposalBtn() {
        return !this.isHiddenProfile;
    }
    get showRelatedPropertyBtn() {
        return !this.isHiddenProfile;
    }
    get showUpdateLocationBtn() {
        return !this.isHiddenProfile;
    }
    get showDeleteRelatedListItem() {
        return !this.isHiddenProfile;
    }
    get showEditItem() {
        return !this.isHiddenProfile;
    }
    get showCloneItem() {
        return !this.isHiddenProfile;
    }

    get followLabel() {
        return this.following ? 'Following' : '+ Follow';
    }

    get followClass() {
        return this.following
            ? 'hp-btn hp-btn-following'
            : 'hp-btn hp-btn-follow';
    }

    connectedCallback() {
        this.applyModalSize('large');
        this.loadFollowState();
    }

    applyModalSize(size) {
        try {
            let styleEl = document.getElementById(MODAL_STYLE_ID);
            if (!styleEl) {
                styleEl = document.createElement('style');
                styleEl.id = MODAL_STYLE_ID;
                const parent = document.head || document.body;
                if (parent) {
                    parent.appendChild(styleEl);
                }
            }
            styleEl.textContent =
                size === 'medium' ? MEDIUM_MODAL_CSS : LARGE_MODAL_CSS;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Modal size style inject failed:', e);
        }
    }

    loadFollowState() {
        if (!this.recordId) {
            return;
        }
        isFollowing({ recordId: this.recordId })
            .then((result) => {
                this.following = result;
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error('Follow check failed:', error);
            });
    }

    handleFollow() {
        if (!this.recordId || this.isFollowLoading) {
            return;
        }
        this.isFollowLoading = true;
        toggleFollow({ recordId: this.recordId })
            .then((result) => {
                this.following = result;
                this.showToast(
                    result ? 'Following' : 'Unfollowed',
                    result
                        ? 'You are now following this record.'
                        : 'You have unfollowed this record.',
                    'success'
                );
            })
            .catch((error) => {
                this.showToast(
                    'Error',
                    this.reduceError(error) || 'Could not update follow status.',
                    'error'
                );
            })
            .finally(() => {
                this.isFollowLoading = false;
            });
    }

    handleQuickAction(event) {
        const target = event.currentTarget || event.target;
        const apiName = target.dataset.action;
        const modalSize = target.dataset.modalSize || 'large';
        this.invokeQuickAction(apiName, modalSize);
    }

    handleMenuSelect(event) {
        const value = event.detail.value;
        if (!value) {
            return;
        }

        if (LOCAL_MENU_ACTIONS.has(value)) {
            if (value === 'edit') this.handleEdit();
            else if (value === 'clone') this.handleClone();
            else if (value === 'delete') this.handleDelete();
            return;
        }

        const modalSize = MEDIUM_MODAL_ACTIONS.has(value) ? 'medium' : 'large';
        this.invokeQuickAction(value, modalSize);
    }

    invokeQuickAction(apiName, modalSize) {
        if (!apiName) {
            this.showToast('Error', 'Quick Action API name is missing.', 'error');
            return;
        }
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

        const size =
            modalSize ||
            (MEDIUM_MODAL_ACTIONS.has(apiName) ? 'medium' : 'large');
        this.applyModalSize(size);
        this.isActionLoading = true;

        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: apiName
            },
            state: {
                recordId: this.recordId
            }
        });

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.isActionLoading = false;
        }, 800);
    }

    handleEdit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: this.objectApiName || OBJECT_API_NAME,
                actionName: 'edit'
            }
        });
    }

    handleClone() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: this.objectApiName || OBJECT_API_NAME,
                actionName: 'clone'
            }
        });
    }

    async handleDelete() {
        const confirmed = await LightningConfirm.open({
            message: 'Are you sure you want to delete this record?',
            label: 'Delete Record',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }

        try {
            await deleteRecord(this.recordId);
            this.showToast('Success', 'Record deleted.', 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: this.objectApiName || OBJECT_API_NAME,
                    actionName: 'list'
                },
                state: { filterName: 'Recent' }
            });
        } catch (error) {
            this.showToast(
                'Error deleting record',
                this.reduceError(error) || 'Unknown error',
                'error'
            );
        }
    }

    reduceError(error) {
        if (!error) {
            return '';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return JSON.stringify(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title: title, message: message, variant: variant })
        );
    }
}
