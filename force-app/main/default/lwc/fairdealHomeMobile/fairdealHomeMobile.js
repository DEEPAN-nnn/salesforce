import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHomePayload from '@salesforce/apex/FairdealHomeMobileController.getHomePayload';

const STAGE_CLASS = {
    on: 'pipe pipe-on',
    off: 'pipe pipe-off'
};

export default class FairdealHomeMobile extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track loadError;
    @track warning;
    @track greeting = '';
    @track dateLabel = '';
    @track followUps = [];
    @track followUpHiddenCount;
    @track inspectionCount = 0;
    @track newAssignmentCount = 0;
    @track inspectionEmpty = '';
    @track assignmentEmpty = '';
    @track prospects = [];
    @track prospectHeadline = '';
    @track leads = [];
    @track leadFilter = 'dueToday';

    @wire(getHomePayload)
    wiredHome({ data, error }) {
        this.isLoading = false;
        if (error) {
            this.loadError = this.reduceError(error);
            return;
        }
        if (!data) {
            return;
        }
        this.warning = data.warning;
        this.greeting = data.greeting;
        this.dateLabel = data.dateLabel;
        this.followUps = data.followUps || [];
        this.followUpHiddenCount = data.followUpHiddenCount || 0;
        this.inspectionCount = data.inspectionCount || 0;
        this.newAssignmentCount = data.newAssignmentCount || 0;
        this.inspectionEmpty = data.inspectionEmpty;
        this.assignmentEmpty = data.assignmentEmpty;
        this.prospectHeadline = data.prospectHeadline;
        this.prospects = (data.prospects || []).map((item) => this.decorateProspect(item));
        this.leads = data.leads || [];
    }

    get noFollowUps() {
        return !this.followUps.length;
    }

    get noInspections() {
        return this.inspectionCount === 0;
    }

    get noAssignments() {
        return this.newAssignmentCount === 0;
    }

    get noProspects() {
        return !this.prospects.length;
    }

    get prospectCount() {
        return this.prospects.length;
    }

    get overdueLeadCount() {
        return this.leads.filter((item) => item.overdue).length;
    }

    get hotLeadCount() {
        return this.leads.filter((item) => item.hot).length;
    }

    get allLeadCount() {
        return this.leads.length;
    }

    get visibleLeads() {
        if (this.leadFilter === 'overdue') {
            return this.leads.filter((item) => item.overdue);
        }
        if (this.leadFilter === 'hot') {
            return this.leads.filter((item) => item.hot);
        }
        if (this.leadFilter === 'all') {
            return this.leads;
        }
        return this.leads.filter((item) => item.dueToday);
    }

    get noVisibleLeads() {
        return !this.visibleLeads.length;
    }

    get dueTodayFilterClass() {
        return this.filterClass('dueToday');
    }

    get overdueFilterClass() {
        return this.filterClass('overdue');
    }

    get hotFilterClass() {
        return this.filterClass('hot');
    }

    get allFilterClass() {
        return this.filterClass('all');
    }

    filterClass(name) {
        return this.leadFilter === name ? 'chip chip-on' : 'chip';
    }

    decorateProspect(item) {
        const stage = item.currentStage || 'shortlist';
        return {
            ...item,
            shortlistClass: stage === 'shortlist' ? STAGE_CLASS.on : STAGE_CLASS.off,
            traceClass: stage === 'trace' ? STAGE_CLASS.on : STAGE_CLASS.off,
            legalClass: stage === 'legal' ? STAGE_CLASS.on : STAGE_CLASS.off,
            registrationClass: stage === 'registration' ? STAGE_CLASS.on : STAGE_CLASS.off
        };
    }

    handleFilter(event) {
        this.leadFilter = event.currentTarget.dataset.filter;
    }

    handleOpenRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'Enquiry__c',
                actionName: 'view'
            }
        });
    }

    handleCall(event) {
        const phone = this.digits(event.currentTarget.dataset.phone);
        if (!phone) {
            return;
        }
        window.open('tel:' + phone, '_self');
    }

    handleWhatsApp(event) {
        const phone = this.digits(event.currentTarget.dataset.phone);
        if (!phone) {
            return;
        }
        window.open('https://wa.me/' + phone, '_blank');
    }

    digits(value) {
        return value ? String(value).replace(/\D/g, '') : '';
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        return 'Unable to load the mobile home page.';
    }
}
