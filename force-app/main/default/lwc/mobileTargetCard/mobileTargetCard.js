import { LightningElement, api } from "lwc";

export default class MobileTargetCard extends LightningElement {
  @api label;
  @api achievedDisplay;
  @api targetDisplay;
  @api variancePct;
  @api varianceDisplay;
  @api progressPct;
  @api tileKey;

  get fillStyle() {
    const pct = Math.max(0, Math.min(Number(this.progressPct) || 0, 100));
    return `width:${pct}%`;
  }

  get varianceClass() {
    const pct = this.variancePct;
    if (pct === null || pct === undefined) {
      return "tcard__var tcard__var--muted";
    }
    if (pct > 0) {
      return "tcard__var tcard__var--pos";
    }
    if (pct < 0) {
      return "tcard__var tcard__var--neg";
    }
    return "tcard__var";
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
