import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

/**
 * Custom Mark Dead button — opens your existing Screen Flow in a medium modal.
 * Set flowApiName to your Flow’s API name (Setup → Flows).
 */
export default class MarkDeadButtonFlow extends LightningElement {
    @api recordId;
    /** Override in App Builder / parent if your flow API name differs */
    @api flowApiName = 'Mark_Dead';

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

    get flowClass() {
        return this.showSpinner ? 'flow-hidden' : '';
    }

    handleClick() {
        if (!this.recordId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Record Id is missing.',
                    variant: 'error'
                })
            );
            return;
        }
        this.showSpinner = true;
        this.showModal = true;
        this.isBusy = true;
    }

    handleFlowStatusChange(event) {
        const status = event.detail.status;

        // Flow UI is ready / running — hide loading spinner
        if (status === 'STARTED' || status === 'PAUSED') {
            this.showSpinner = false;
        }

        if (status === 'ERROR') {
            this.showSpinner = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Mark Dead flow failed to run.',
                    variant: 'error'
                })
            );
            return;
        }

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeModal();
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Mark Dead completed.',
                    variant: 'success'
                })
            );
        }
    }

    closeModal() {
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
}
