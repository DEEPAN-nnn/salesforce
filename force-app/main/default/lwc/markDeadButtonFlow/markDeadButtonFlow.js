import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

/**
 * Mark Dead button:
 * - Custom red button (panel-sized)
 * - Click → popup modal + brief spinner
 * - Screen Flow runs INSIDE the modal (not a new page)
 * - Auto-closes when flow finishes
 *
 * Flow API name from your org: Request_Dead_Approval
 * Flow input variable: recordId (Text)
 * Flow must be Active (your XML showed status Obsolete).
 */
export default class MarkDeadButtonFlow extends LightningElement {
    @api recordId;
    /** Must match Flow API Name in Setup → Flows */
    @api flowApiName = 'Request_Dead_Approval';

    @track showModal = false;
    @track showSpinner = true;
    @track isBusy = false;

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
        return this.showSpinner ? 'flow-wrap flow-wrap_hidden' : 'flow-wrap';
    }

    openFlow() {
        if (this.isBusy) {
            return;
        }
        if (!this.recordId) {
            this.toast('Error', 'Record Id is missing.', 'error');
            return;
        }
        if (!this.flowApiName) {
            this.toast('Error', 'Flow API name is missing.', 'error');
            return;
        }

        this.isBusy = true;
        this.showSpinner = true;
        this.showModal = true;

        // Fallback: if STARTED never fires, still reveal the flow after a short delay
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._spinnerTimer = window.setTimeout(() => {
            this.showSpinner = false;
        }, 600);
    }

    handleFlowStatusChange(event) {
        const status = event.detail.status;

        if (this._spinnerTimer) {
            window.clearTimeout(this._spinnerTimer);
            this._spinnerTimer = null;
        }

        // Flow UI is ready — hide spinner, show screens in the modal
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
            this.toast('Error', 'Mark Dead flow failed to start.', 'error');
            return;
        }

        // Auto-close popup when the screen flow completes
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
        this.showModal = false;
        this.showSpinner = true;
        this.isBusy = false;
    }

    handleBackdropClick() {
        // Optional: close on backdrop click. Comment out if you want forced finish.
        this.closeModal();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
