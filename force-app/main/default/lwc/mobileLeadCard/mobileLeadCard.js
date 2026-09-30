import { LightningElement, api } from "lwc";

/**
 * One record row, shared by the mobile funnel screens.
 *
 * Dumb child: holds no state, fetches nothing, formats nothing, and never
 * navigates. Every value arrives as a display-ready string from the
 * container, and every intent leaves as a CustomEvent.
 */
export default class MobileLeadCard extends LightningElement {
  @api recordId;
  @api name;
  @api action;
  @api stage;
  @api requirement;
  @api note;
  @api phone;
  @api badge;
  @api ownerName;

  /** One of: over30, over8, over1, upcoming, none. */
  @api band = "none";

  get cardClass() {
    return `card card--${this.band}`;
  }

  get openLabel() {
    return `Open ${this.name}`;
  }

  get callLabel() {
    return `Call ${this.name}`;
  }

  get telHref() {
    return this.phone ? `tel:${this.phone}` : "#";
  }

  handleOpen() {
    this.fire("opencard");
  }

  /**
   * Call stays a real <a href="tel:..."> - Lightning Locker's SecureWindow
   * blocks window.open("tel:...") on the Salesforce mobile app. The click
   * handler only intercepts the no-phone case.
   */
  handleCall(event) {
    if (!this.phone) {
      event.preventDefault();
      this.fire("nophone");
    }
  }

  handleWhatsApp() {
    if (!this.phone) {
      this.fire("nophone");
      return;
    }
    this.fire("whatsapp");
  }

  handleLogCall() {
    this.fire("logcall");
  }

  handleNewEvent() {
    this.fire("newevent");
  }

  fire(type) {
    this.dispatchEvent(
      new CustomEvent(type, {
        detail: { recordId: this.recordId, name: this.name, phone: this.phone }
      })
    );
  }
}
