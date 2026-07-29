import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import isFollowing from '@salesforce/apex/HighlightsPanelController.isFollowing';
import toggleFollow from '@salesforce/apex/HighlightsPanelController.toggleFollow';
import getCurrentUserProfileName from '@salesforce/apex/HighlightsPanelController.getCurrentUserProfileName';

import CONTACT_1_PHONE from '@salesforce/schema/Enquiry__c.Contact_1_Phone__c';
import REQUIREMENT from '@salesforce/schema/Enquiry__c.Requirement__c';
import SUB_LOCATION from '@salesforce/schema/Enquiry__c.Sub_Location__c';
import CURRENT_STATUS from '@salesforce/schema/Enquiry__c.Current_Status__c';
import STAGE from '@salesforce/schema/Enquiry__c.Stage__c';
import CHANNEL from '@salesforce/schema/Enquiry__c.Channel__c';
import NAME from '@salesforce/schema/Enquiry__c.Name';
import PROPERTY_SOURCING_ASSISTANCE from '@salesforce/schema/Enquiry__c.Property_Sourcing_Assistance__c';

const FIELDS = [
    CONTACT_1_PHONE,
    REQUIREMENT,
    SUB_LOCATION,
    CURRENT_STATUS,
    STAGE,
    CHANNEL,
    NAME,
    PROPERTY_SOURCING_ASSISTANCE
];

const OBJECT_API_NAME = 'Enquiry__c';
const HIDDEN_PROFILE = 'Akshay Madane Profile';
const RESTRICTED_ASSISTANT_PROFILE = 'Transaction Manager - HYD';

/** Built-in handlers (not Quick Action API names) */
const LOCAL_MENU_ACTIONS = new Set(['edit', 'clone', 'delete']);

/**
 * NavigationMixin opens Quick Actions in a smaller modal than the standard
 * Highlights Panel. Inject page-level CSS (no Static Resource) so QA modals
 * match the large standard size. No @salesforce/resourceUrl needed.
 */
const WIDE_MODAL_STYLE_ID = 'customHighlightsPanelWideModal';
const WIDE_MODAL_CSS = `
.slds-modal__container {
    width: 90vw !important;
    max-width: 90vw !important;
    min-width: 70vw !important;
    max-height: 90vh !important;
}
.slds-modal_small .slds-modal__container,
.slds-modal_medium .slds-modal__container,
.slds-modal_large .slds-modal__container {
    width: 90vw !important;
    max-width: 90vw !important;
    min-width: 70vw !important;
    max-height: 90vh !important;
}
.slds-modal__content {
    max-height: calc(90vh - 8rem) !important;
}
.runtime_platform_actionsQuickActionWrapper .slds-modal__container,
.forceModal .slds-modal__container,
.uiModal .modal-container,
.uiModal--horizontalForm .modal-container {
    width: 90vw !important;
    max-width: 90vw !important;
    min-width: 70vw !important;
    max-height: 90vh !important;
}
`;

export default class CustomHighlightsPanel extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName = OBJECT_API_NAME;
    @api iconName = 'standard:opportunity';
    @api iconColor = '#5867E8';

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

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordName = getFieldValue(data, NAME) || '';
            this.contactPhone = getFieldValue(data, CONTACT_1_PHONE) || '';
            this.requirement = getFieldValue(data, REQUIREMENT) || '';
            this.subLocation = getFieldValue(data, SUB_LOCATION) || '';
            this.currentStatus = getFieldValue(data, CURRENT_STATUS) || '';
            this.stage = getFieldValue(data, STAGE) || '';
            this.channel = getFieldValue(data, CHANNEL) || '';
            this.propertySourcingAssistance = !!getFieldValue(
                data,
                PROPERTY_SOURCING_ASSISTANCE
            );
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Record wire error:', error);
        }
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

    get iconContainerStyle() {
        return `background-color: ${this.iconColor};`;
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
        this.injectWideModalStyles();
        this.loadFollowState();
    }

    /**
     * Inject global CSS so Quick Action modals open large (like standard HP).
     * Avoids Static Resource / resourceUrl deploy errors.
     */
    injectWideModalStyles() {
        try {
            if (document.getElementById(WIDE_MODAL_STYLE_ID)) {
                return;
            }
            const styleEl = document.createElement('style');
            styleEl.id = WIDE_MODAL_STYLE_ID;
            styleEl.textContent = WIDE_MODAL_CSS;
            const parent = document.head || document.body;
            if (parent) {
                parent.appendChild(styleEl);
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Wide modal style inject failed:', e);
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

    /** Visible buttons: read data-action="Enquiry__c.Your_Action" */
    handleQuickAction(event) {
        const apiName =
            event.currentTarget?.dataset?.action ||
            event.target?.dataset?.action;
        this.invokeQuickAction(apiName);
    }

    /** Overflow menu: lightning-button-menu onselect → event.detail.value */
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

        this.invokeQuickAction(value);
    }

    /**
     * Opens an existing Quick Action already defined in the org.
     * apiName: Enquiry__c.Related_Property or Global.LogACall
     */
    invokeQuickAction(apiName) {
        if (!apiName) {
            this.showToast('Error', 'Quick Action API name is missing.', 'error');
            return;
        }
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

        // Ensure wide styles are present before the QA modal paints
        this.injectWideModalStyles();
        this.isActionLoading = true;

        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName
            },
            state: {
                recordId: this.recordId
            }
        });

        // Navigate does not always return a usable Promise in LEX
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
        if (!error) return '';
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (typeof error.body?.message === 'string') return error.body.message;
        if (typeof error.message === 'string') return error.message;
        return JSON.stringify(error);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
