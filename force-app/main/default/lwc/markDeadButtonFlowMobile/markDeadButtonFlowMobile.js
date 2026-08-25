import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

/**
 * Mobile-only Mark Dead:
 * - Red 36px circle + white X (same look on bar and in More)
 * - Opens Screen Flow in a popup modal
 * - Auto-closes on FINISHED / FINISHED_SCREEN
 *
 * Flow API name: Request_Dead_Approval (must be Active)
 * Flow input: recordId (Text)
 */
export default class MarkDeadButtonFlowMobile extends LightningElement {
    @api recordId;
    @api flowApiName = 'Request_Dead_Approval';

    @track showModal = false;
    @track showSpinner = true;
    @track isBusy = false;
    @track flowInstanceKey = 0;

    get flowInputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    get flowWrapperClass() {
        return this.showSpinner ? 'mdm-flow mdm-flow_hidden' : 'mdm-flow';
    }

    /**
     * Public API — used by the bar button and by More → Mark dead.
     * Always remounts the flow so reopening from More works every time.
     */
    @api
    openFlow() {
        if (!this.recordId) {
            this.toast('Error', 'Record Id is missing.', 'error');
            return;
        }
        if (!this.flowApiName) {
            this.toast('Error', 'Flow API name is missing.', 'error');
            return;
        }

        if (this._spinnerTimer) {
            window.clearTimeout(this._spinnerTimer);
            this._spinnerTimer = null;
        }
        if (this._openTimer) {
            window.clearTimeout(this._openTimer);
            this._openTimer = null;
        }

        // Tear down any existing modal/flow, then remount fresh
        this.showModal = false;
        this.showSpinner = true;
        this.isBusy = false;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._openTimer = window.setTimeout(() => {
            this._openTimer = null;
            this.flowInstanceKey += 1;
            this.isBusy = true;
            this.showSpinner = true;
            this.showModal = true;

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._spinnerTimer = window.setTimeout(() => {
                this.showSpinner = false;
                this._spinnerTimer = null;
            }, 500);
        }, 30);
    }

    handleFlowStatusChange(event) {
        const status = event.detail.status;

        if (this._spinnerTimer) {
            window.clearTimeout(this._spinnerTimer);
            this._spinnerTimer = null;
        }

        if (
            status === 'STARTED' ||
            status === 'PAUSED' ||
            status === 'FINISHED' ||
            status === 'FINISHED_SCREEN' ||
            status === 'ERROR'
        ) {
            this.showSpinner = false;
        }

        if (status === 'ERROR') {
            this.isBusy = false;
            this.toast('Error', 'Mark Dead flow failed to start.', 'error');
            return;
        }

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeModal();
            this.dispatchEvent(new RefreshEvent());
            this.toast('Success', 'Mark Dead completed.', 'success');
        }
    }

    closeModal() {
        if (this._spinnerTimer) {
            window.clearTimeout(this._spinnerTimer);
            this._spinnerTimer = null;
        }
        if (this._openTimer) {
            window.clearTimeout(this._openTimer);
            this._openTimer = null;
        }
        this.showModal = false;
        this.showSpinner = true;
        this.isBusy = false;
    }

    handleBackdropClick() {
        this.closeModal();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
