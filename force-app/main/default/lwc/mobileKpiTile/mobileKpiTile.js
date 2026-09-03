import { LightningElement, api } from "lwc";

export default class MobileKpiTile extends LightningElement {
  @api label;
  @api displayValue;
  @api tone;
  @api tileKey;

  get valueStyle() {
    const color = this.tone || "var(--fd-navy)";
    return `color:${color}`;
  }

  handleTap() {
    this.dispatchEvent(
      new CustomEvent("tiletap", {
        detail: { key: this.tileKey },
        bubbles: true,
        composed: true
      })
    );
  }
}
