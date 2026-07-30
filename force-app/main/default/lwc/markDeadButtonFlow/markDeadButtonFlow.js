import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/** Short pause so the spinner is visible before the flow opens */
const SPINNER_DELAY_MS = 250;

/**
 * Custom Mark Dead button.
 * Click → brief spinner → open Screen Flow (no custom modal).
 *
 * Set flowApiName to your Flow API name (Setup → Flows → API Name).
 * Flow should accept input variable: recordId
 */
export default class MarkDeadButtonFlow extends NavigationMixin(LightningElement) {
    @api recordId;
    @api flowApiName = 'Mark_Dead';

    @track isLoading = false;

    handleClick() {
        if (this.isLoading) {
            return;
        }
        if (!this.recordId) {
            this.showToast('Error', 'Record Id is missing.', 'error');
            return;
        }
        if (!this.flowApiName) {
            this.showToast('Error', 'Flow API name is missing.', 'error');
            return;
        }

        this.isLoading = true;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.openScreenFlow();
        }, SPINNER_DELAY_MS);
    }

    openScreenFlow() {
        // Opens the Screen Flow in Lightning (native flow runtime — no custom modal)
        const url =
            '/lightning/flow/' +
            encodeURIComponent(this.flowApiName) +
            '?recordId=' +
            encodeURIComponent(this.recordId);

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url
            }
        });

        // Reset spinner after navigate kicks off
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.isLoading = false;
        }, 400);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
