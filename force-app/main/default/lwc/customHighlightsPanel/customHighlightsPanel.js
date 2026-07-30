import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import FORM_FACTOR from '@salesforce/client/formFactor';

import isFollowing from '@salesforce/apex/HighlightsPanelController.isFollowing';
import toggleFollow from '@salesforce/apex/HighlightsPanelController.toggleFollow';
import getCurrentUserProfileName from '@salesforce/apex/HighlightsPanelController.getCurrentUserProfileName';
import createFeedPost from '@salesforce/apex/HighlightsPanelController.createFeedPost';
import createFeedPoll from '@salesforce/apex/HighlightsPanelController.createFeedPoll';

const OBJECT_API_NAME = 'Enquiry__c';

/* App Builder visibility */
const HIDDEN_PROFILE = 'Akshay Madane Profile';
const RESTRICTED_ASSISTANT_PROFILE = 'Transaction Manager - HYD';

const LOCAL_MENU_ACTIONS = new Set(['edit', 'clone', 'delete', 'post', 'poll']);

const WIDE_MODAL_STYLE_ID = 'customHighlightsPanelWideModal';
const WIDE_MODAL_CSS =
    '.slds-modal__container{width:90vw!important;max-width:90vw!important;min-width:70vw!important;max-height:90vh!important;}' +
    '.slds-modal__content{max-height:calc(90vh - 8rem)!important;}';

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

    /* Inline string fields — avoids schema-import deploy failures in LWC editor */
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

    /* Phone icon in App Builder = mobile only */
    get showPostPoll() {
        return FORM_FACTOR === 'Small';
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
            event.currentTarget.dataset.action ||
            event.target.dataset.action;
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
        const next = [];
        for (let i = 0; i < this.pollChoices.length; i++) {
            const choice = this.pollChoices[i];
            if (i === index) {
                next.push({
                    key: choice.key,
                    label: choice.label,
                    value: value
                });
            } else {
                next.push(choice);
            }
        }
        this.pollChoices = next;
    }

    addPollChoice() {
        if (!this.canAddPollChoice) {
            return;
        }
        const next = this.pollChoices.length;
        this.pollChoices = this.pollChoices.concat([
            {
                key: 'c' + String(Date.now()),
                label: 'Choice ' + String(next + 1),
                value: ''
            }
        ]);
    }

    submitPost() {
        const body = (this.postBody || '').trim();
        if (!body) {
            this.showToast('Error', 'Enter text to share.', 'error');
            return;
        }
        this.isChatterSaving = true;
        createFeedPost({ recordId: this.recordId, body: body })
            .then(() => {
                this.showToast('Success', 'Post shared.', 'success');
                this.closeChatterModals();
            })
            .catch((error) => {
                this.showToast(
                    'Error creating post',
                    this.reduceError(error) || 'Unknown error',
                    'error'
                );
            })
            .finally(() => {
                this.isChatterSaving = false;
            });
    }

    submitPoll() {
        const question = (this.pollQuestion || '').trim();
        if (!question) {
            this.showToast('Error', 'Enter a poll question.', 'error');
            return;
        }
        const choices = [];
        for (let i = 0; i < this.pollChoices.length; i++) {
            const v = (this.pollChoices[i].value || '').trim();
            if (v) {
                choices.push(v);
            }
        }
        if (choices.length < 2) {
            this.showToast('Error', 'Add at least 2 choices.', 'error');
            return;
        }
        this.isChatterSaving = true;
        createFeedPoll({
            recordId: this.recordId,
            question: question,
            choicesJson: JSON.stringify(choices)
        })
            .then(() => {
                this.showToast('Success', 'Poll posted.', 'success');
                this.closeChatterModals();
            })
            .catch((error) => {
                this.showToast(
                    'Error creating poll',
                    this.reduceError(error) || 'Unknown error',
                    'error'
                );
            })
            .finally(() => {
                this.isChatterSaving = false;
            });
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
        this.dispatchEvent(new ShowToastEvent({ title: title, message: message, variant: variant }));
    }
}
