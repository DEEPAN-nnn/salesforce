import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import FORM_FACTOR from '@salesforce/client/formFactor';

/**
 * Mark Dead button:
 * - Desktop: red rectangular button with X
 * - Phone: red circle with white X (standard mobile action size)
 * - Click → popup modal + Screen Flow; auto-closes on finish
 */
export default class MarkDeadButtonFlow extends LightningElement {
    @api recordId;
    @api flowApiName = 'Request_Dead_Approval';
    /** Optional override: 'mobile' | 'circle' | 'default' */
    @api variant = 'default';

    @track showModal = false;
    @track showSpinner = true;
    @track isBusy = false;

    /**
     * Prefer explicit variant; also auto-detect phone so App Builder / mobile
     * never fall back to the rectangular button by mistake.
     */
    get isMobileVariant() {
        if (this.variant === 'mobile' || this.variant === 'circle') {
            return true;
        }
        if (this.variant === 'desktop' || this.variant === 'default') {
            // Still force circle on real phone / App Builder Phone canvas
            return FORM_FACTOR === 'Small';
        }
        return FORM_FACTOR === 'Small';
    }

    get containerClass() {
        return this.isMobileVariant
            ? 'button-container button-container_mobile'
            : 'button-container';
    }

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
        this.closeModal();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
