import { LightningElement, api } from "lwc";

export default class MobileConversionChart extends LightningElement {
  @api title;
  @api rows = [];

  get hasRows() {
    return this.rows && this.rows.length > 0;
  }

  handleTap() {
    this.dispatchEvent(
      new CustomEvent("charttap", {
        bubbles: true,
        composed: true
      })
    );
  }
}
