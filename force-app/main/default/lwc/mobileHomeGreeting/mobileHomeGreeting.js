import { LightningElement, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import USER_ID from "@salesforce/user/Id";
import FIRST_NAME_FIELD from "@salesforce/schema/User.FirstName";

export default class MobileHomeGreeting extends LightningElement {
  @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME_FIELD] })
  userRecord;

  get userFirstName() {
    return getFieldValue(this.userRecord?.data, FIRST_NAME_FIELD) || "there";
  }

  get greetingPhrase() {
    const hour = new Date().getHours();
    if (hour < 12) {
      return "Good Morning";
    }
    if (hour < 17) {
      return "Good Afternoon";
    }
    return "Good Evening";
  }

  get today() {
    return new Date().toLocaleDateString("en-IN", {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric"
    });
  }
}
