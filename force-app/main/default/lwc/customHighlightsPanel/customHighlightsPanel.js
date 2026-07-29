import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { RefreshEvent } from 'lightning/refresh';

import isFollowing from '@salesforce/apex/HighlightsPanelController.isFollowing';
import toggleFollow from '@salesforce/apex/HighlightsPanelController.toggleFollow';
import getCurrentUserProfileName from '@salesforce/apex/HighlightsPanelController.getCurrentUserProfileName';
import createFeedPost from '@salesforce/apex/HighlightsPanelController.createFeedPost';
import createFeedPoll from '@salesforce/apex/HighlightsPanelController.createFeedPoll';

/**
 * Use string field API names (not @salesforce/schema imports) so deploy does not
 * fail when a field API name differs or the LWC editor schema check is strict.
 * Put less-certain fields in OPTIONAL_FIELDS so missing ones do not break the wire.
 *
 * Verify exact API names in Setup → Object Manager → Enquiry → Fields.
 * If Sub-Location uses a different API name, update SUB_LOCATION_FIELD below.
 */
const OBJECT = 'Enquiry__c';
const NAME_FIELD = `${OBJECT}.Name`;
const CONTACT_PHONE_FIELD = `${OBJECT}.Contact_1_Phone__c`;
const REQUIREMENT_FIELD = `${OBJECT}.Requirement__c`;
const SUB_LOCATION_FIELD = `${OBJECT}.Sub_Location__c`; // change if Object Manager shows another name
const CURRENT_STATUS_FIELD = `${OBJECT}.Current_Status__c`;
const STAGE_FIELD = `${OBJECT}.Stage__c`;
const CHANNEL_FIELD = `${OBJECT}.Channel__c`;
const PROPERTY_SOURCING_FIELD = `${OBJECT}.Property_Sourcing_Assistance__c`;

const FIELDS = [NAME_FIELD];

const OPTIONAL_FIELDS = [
    CONTACT_PHONE_FIELD,
    REQUIREMENT_FIELD,
    SUB_LOCATION_FIELD,
    CURRENT_STATUS_FIELD,
    STAGE_FIELD,
    CHANNEL_FIELD,
    PROPERTY_SOURCING_FIELD
];


const OBJECT_API_NAME = 'Enquiry__c';

/**
 * VISIBILITY — matched to Lightning App Builder action filters:
 *
 * Generate Proposal / Related Property / Update Location /
 * Delete Related List / Edit / Clone:
 *   User > Profile > Name Not Equal "Akshay Madane Profile"
 *
 * Assign Assistant (ALL filters true):
 *   Record > Property Sourcing Assistance Equal false
 *   User > Profile > Name Not Equal "Transaction Manager - HYD"
 *
 * Change Property Assistant (ALL filters true):
 *   Record > Property Sourcing Assistance Equal true
 *   User > Profile > Name Not Equal "Transaction Manager - HYD"
 *
 * Merge Enquiry:
 *   User > Profile > Name Equal "System Administrator"
 *
 * Post / Poll:
 *   Mobile only (App Builder phone icon = Form Factor Phone).
 *   FORM_FACTOR: Small=Phone, Medium=Tablet, Large=Desktop
 *
 * Mark dead / New Event / New Task / Log a Call / Sharing / Delete:
 *   No visibility filter (always shown)
 */
const HIDDEN_PROFILE = 'Akshay Madane Profile';
const RESTRICTED_ASSISTANT_PROFILE = 'Transaction Manager - HYD';

/** Built-in handlers (not Quick Action API names) */
const LOCAL_MENU_ACTIONS = new Set(['edit', 'clone', 'delete', 'post', 'poll']);

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

function newPollChoices() {
    return [
        { key: 'c0', label: 'Choice 1', value: '' },
        { key: 'c1', label: 'Choice 2', value: '' }
    ];
}

export default class CustomHighlightsPanel extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName = OBJECT_API_NAME;
    @api iconName = 'standard:opportunity';

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

    @track showPostModal = false;
    @track showPollModal = false;
    @track postBody = '';
    @track pollQuestion = '';
    @track pollChoices = newPollChoices();
    @track isChatterSaving = false;

    @wire(getCurrentUserProfileName)
    wiredProfile({ data, error }) {
        if (data) {
            this.profileName = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Profile fetch error:', error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS, optionalFields: OPTIONAL_FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordName = getFieldValue(data, NAME_FIELD) || '';
            this.contactPhone = getFieldValue(data, CONTACT_PHONE_FIELD) || '';
            this.requirement = getFieldValue(data, REQUIREMENT_FIELD) || '';
            this.subLocation = getFieldValue(data, SUB_LOCATION_FIELD) || '';
            this.currentStatus = getFieldValue(data, CURRENT_STATUS_FIELD) || '';
            this.stage = getFieldValue(data, STAGE_FIELD) || '';
            this.channel = getFieldValue(data, CHANNEL_FIELD) || '';
            this.propertySourcingAssistance = !!getFieldValue(
                data,
                PROPERTY_SOURCING_FIELD
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

    /** App Builder: Post/Poll phone icon = mobile form factor only */
    get showPostPoll() {
        return FORM_FACTOR === 'Small';
    }

    get isDesktop() {
        return FORM_FACTOR === 'Large';
    }

    get canAddPollChoice() {
        return this.pollChoices.length < 10;
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

    handleQuickAction(event) {
        const apiName =
            event.currentTarget?.dataset?.action ||
            event.target?.dataset?.action;
        this.invokeQuickAction(apiName);
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
            else if (value === 'post') this.openPostModal();
            else if (value === 'poll') this.openPollModal();
            return;
        }

        this.invokeQuickAction(value);
    }

    openPostModal() {
        this.postBody = '';
        this.showPollModal = false;
        this.showPostModal = true;
    }

    openPollModal() {
        this.pollQuestion = '';
        this.pollChoices = newPollChoices();
        this.showPostModal = false;
        this.showPollModal = true;
    }

    closeChatterModals() {
        this.showPostModal = false;
        this.showPollModal = false;
        this.isChatterSaving = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handlePostBodyChange(event) {
        this.postBody = event.target.value;
    }

    handlePollQuestionChange(event) {
        this.pollQuestion = event.target.value;
    }

    handlePollChoiceChange(event) {
        const index = Number(event.target.dataset.index);
        const value = event.target.value;
        this.pollChoices = this.pollChoices.map((choice, i) =>
            i === index ? { ...choice, value } : choice
        );
    }

    addPollChoice() {
        if (!this.canAddPollChoice) {
            return;
        }
        const next = this.pollChoices.length;
        this.pollChoices = [
            ...this.pollChoices,
            {
                key: `c${Date.now()}`,
                label: `Choice ${next + 1}`,
                value: ''
            }
        ];
    }

    async submitPost() {
        if (!this.postBody?.trim()) {
            this.showToast('Error', 'Enter text to share.', 'error');
            return;
        }
        this.isChatterSaving = true;
        try {
            await createFeedPost({
                recordId: this.recordId,
                body: this.postBody
            });
            this.showToast('Success', 'Post shared.', 'success');
            this.closeChatterModals();
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.showToast(
                'Error creating post',
                this.reduceError(error) || 'Unknown error',
                'error'
            );
        } finally {
            this.isChatterSaving = false;
        }
    }

    async submitPoll() {
        if (!this.pollQuestion?.trim()) {
            this.showToast('Error', 'Enter a poll question.', 'error');
            return;
        }
        const choices = this.pollChoices
            .map((c) => (c.value || '').trim())
            .filter((v) => v);
        if (choices.length < 2) {
            this.showToast('Error', 'Add at least 2 choices.', 'error');
            return;
        }
        this.isChatterSaving = true;
        try {
            await createFeedPoll({
                recordId: this.recordId,
                question: this.pollQuestion,
                choicesJson: JSON.stringify(choices)
            });
            this.showToast('Success', 'Poll posted.', 'success');
            this.closeChatterModals();
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.showToast(
                'Error creating poll',
                this.reduceError(error) || 'Unknown error',
                'error'
            );
        } finally {
            this.isChatterSaving = false;
        }
    }

    invokeQuickAction(apiName) {
        if (!apiName) {
            this.showToast('Error', 'Quick Action API name is missing.', 'error');
            return;
        }
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }

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
