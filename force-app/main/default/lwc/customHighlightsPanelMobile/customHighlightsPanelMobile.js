import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import isFollowing from '@salesforce/apex/HighlightsPanelController.isFollowing';
import toggleFollow from '@salesforce/apex/HighlightsPanelController.toggleFollow';
import getCurrentUserProfileName from '@salesforce/apex/HighlightsPanelController.getCurrentUserProfileName';
import createFeedPost from '@salesforce/apex/HighlightsPanelController.createFeedPost';
import createFeedPoll from '@salesforce/apex/HighlightsPanelController.createFeedPoll';

const OBJECT_API_NAME = 'Enquiry__c';
const HIDDEN_PROFILE = 'Akshay Madane Profile';
const RESTRICTED_ASSISTANT_PROFILE = 'Transaction Manager - HYD';
const LOCAL_MENU_ACTIONS = new Set(['edit', 'clone', 'delete', 'post', 'poll']);
const MODAL_STYLE_ID = 'customHighlightsPanelMobileModalSize';
const PHONE_MODAL_CSS =
    '.slds-modal__container{width:100%!important;max-width:100%!important;min-width:0!important;max-height:100%!important;margin:0!important;}' +
    '.slds-modal__content{max-height:calc(100vh - 6rem)!important;}';

const SVG = {
    lightning: 'M11 2L5 13h5v9l7-12h-5l4-8z',
    edit: 'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34a.9959.9959 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z',
    copy: 'M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z',
    event: 'M19 4h-1V2h-2v2H8V2H6v2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10zm0-12H5V6h14v2zM7 12h5v5H7z',
    task: 'M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-9 14l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z',
    call: 'M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z',
    chat: 'M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H5.17L4 17.17V4h16v12z',
    chart: 'M3.5 18.49l6-6.01 4 4L22 6.92l-1.41-1.41-7.09 7.97-4-4L2 16.99z',
    adduser:
        'M15 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm-9-2V7H4v3H1v2h3v3h2v-3h3v-2H6zm9 4c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
    delete: 'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z'
};

function moreItem(key, value, label, svgPath, circleClass) {
    return { key, value, label, svgPath, circleClass };
}

function newPollChoices() {
    return [
        { key: 'c0', label: 'Choice 1', value: '' },
        { key: 'c1', label: 'Choice 2', value: '' }
    ];
}

/**
 * Phone-only Highlights Panel — same visibility / actions as desktop.
 * Mark Dead uses child LWC: markDeadButtonFlowMobile
 */
export default class CustomHighlightsPanelMobile extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName = OBJECT_API_NAME;
    @api markDeadFlowApiName = 'Request_Dead_Approval';

    lightningPath = SVG.lightning;

    @track isActionLoading = false;
    @track isFollowLoading = false;
    @track following = false;
    @track profileName = '';
    @track propertySourcingAssistance = false;

    @track showMore = false;

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

    @wire(getRecord, {
        recordId: '$recordId',
        fields: ['Enquiry__c.Name'],
        optionalFields: ['Enquiry__c.Property_Sourcing_Assistance__c']
    })
    wiredRecord({ error, data }) {
        if (data) {
            this.propertySourcingAssistance = !!getFieldValue(
                data,
                'Enquiry__c.Property_Sourcing_Assistance__c'
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

    get followLabel() {
        return this.following ? 'Following' : '+ Follow';
    }

    get primaryActions() {
        const candidates = [];
        if (this.showRelatedPropertyBtn) {
            candidates.push({
                key: 'related',
                label: 'Related Property',
                apiName: 'Enquiry__c.Related_Property'
            });
        }
        if (this.showGenerateProposalBtn) {
            candidates.push({
                key: 'proposal',
                label: 'Generate Proposal',
                apiName: 'Enquiry__c.Generate_Proposal'
            });
        }
        if (this.showAssignAssistant) {
            candidates.push({
                key: 'assign',
                label: 'Assign Assistant',
                apiName: 'Enquiry__c.Assign_Assistant'
            });
        }
        if (this.showChangePropertyAssistant) {
            candidates.push({
                key: 'change',
                label: 'Change Property Assistant',
                apiName: 'Enquiry__c.Change_Property_Assistant'
            });
        }
        if (this.showUpdateLocationBtn) {
            candidates.push({
                key: 'location',
                label: 'Update Location',
                apiName: 'Enquiry__c.Update_Location'
            });
        }
        return candidates.slice(0, 2);
    }

    get primaryApiNames() {
        return new Set(this.primaryActions.map((a) => a.apiName));
    }

    get moreActions() {
        const items = [];
        const primary = this.primaryApiNames;
        const qa = 'mhp-more-circle mhp-more-circle-blue';

        if (this.showGenerateProposalBtn && !primary.has('Enquiry__c.Generate_Proposal')) {
            items.push(moreItem('proposal', 'Enquiry__c.Generate_Proposal', 'Generate Proposal', SVG.lightning, qa));
        }
        if (this.showRelatedPropertyBtn && !primary.has('Enquiry__c.Related_Property')) {
            items.push(moreItem('related', 'Enquiry__c.Related_Property', 'Related Property', SVG.lightning, qa));
        }
        if (this.showAssignAssistant && !primary.has('Enquiry__c.Assign_Assistant')) {
            items.push(moreItem('assign', 'Enquiry__c.Assign_Assistant', 'Assign Assistant', SVG.lightning, qa));
        }
        if (this.showChangePropertyAssistant && !primary.has('Enquiry__c.Change_Property_Assistant')) {
            items.push(
                moreItem(
                    'change',
                    'Enquiry__c.Change_Property_Assistant',
                    'Change Property Assistant',
                    SVG.lightning,
                    qa
                )
            );
        }
        if (this.showUpdateLocationBtn && !primary.has('Enquiry__c.Update_Location')) {
            items.push(moreItem('location', 'Enquiry__c.Update_Location', 'Update Location', SVG.lightning, qa));
        }
        if (this.showDeleteRelatedListItem) {
            items.push(
                moreItem('deleteRelated', 'Enquiry__c.Delete_Related_List', 'Delete Related List', SVG.lightning, qa)
            );
        }
        if (this.showEditItem) {
            items.push(moreItem('edit', 'edit', 'Edit', SVG.edit, 'mhp-more-circle mhp-more-circle-green'));
        }
        if (this.showCloneItem) {
            items.push(moreItem('clone', 'clone', 'Clone', SVG.copy, qa));
        }
        if (this.showMergeEnquiry) {
            items.push(moreItem('merge', 'Enquiry__c.Merge_Enquiry', 'Merge Enquiry', SVG.lightning, qa));
        }

        items.push(
            moreItem('event', 'Global.NewEvent', 'New Event', SVG.event, 'mhp-more-circle mhp-more-circle-pink'),
            moreItem('task', 'Global.NewTask', 'New Task', SVG.task, 'mhp-more-circle mhp-more-circle-green'),
            moreItem('call', 'Global.LogACall', 'Log a Call', SVG.call, 'mhp-more-circle mhp-more-circle-teal'),
            moreItem('post', 'post', 'Post', SVG.chat, qa),
            moreItem('poll', 'poll', 'Poll', SVG.chart, qa),
            moreItem('sharing', 'Enquiry__c.Sharing', 'Sharing', SVG.lightning, qa),
            moreItem('follow', 'follow', this.followLabel, SVG.adduser, qa),
            moreItem('delete', 'delete', 'Delete', SVG.delete, 'mhp-more-circle mhp-more-circle-red')
        );

        return items;
    }

    get canAddPollChoice() {
        return this.pollChoices.length < 10;
    }

    connectedCallback() {
        this.applyPhoneModalCss();
        this.loadFollowState();
    }

    applyPhoneModalCss() {
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
            styleEl.textContent = PHONE_MODAL_CSS;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Mobile modal CSS inject failed:', e);
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

    openMore() {
        this.showMore = true;
    }

    closeMore() {
        this.showMore = false;
    }

    handleMoreSelect(event) {
        const value = event.currentTarget.dataset.value;
        this.closeMore();
        if (!value) {
            return;
        }
        if (value === 'follow') {
            this.handleFollow();
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

    handleQuickAction(event) {
        const apiName = (event.currentTarget || event.target).dataset.action;
        this.invokeQuickAction(apiName);
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
        this.applyPhoneModalCss();
        this.isActionLoading = true;
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: { apiName: apiName },
            state: { recordId: this.recordId }
        });
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.isActionLoading = false;
        }, 800);
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
                next.push({ key: choice.key, label: choice.label, value: value });
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
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
