import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import USER_ID from "@salesforce/user/Id";
import FIRST_NAME_FIELD from "@salesforce/schema/User.FirstName";
import getMyDayData from "@salesforce/apex/EnquiryMyDayController.getMyDayData";
import getTeamReports from "@salesforce/apex/TeamReportsController.getTeamReports";

// Sections show at most this many cards before scrolling internally.
const VISIBLE_CAP = 2;
const VISIBLE_CAP_REPORTS = 3;

export default class MobileMyDayScreen extends NavigationMixin(
  LightningElement
) {
  followUps = [];
  inspections = [];
  newAssignments = [];
  teamReports = [];
  teamReportsReady = false;
  isLoading = true;
  error;

  @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME_FIELD] })
  userRecord;

  @wire(getMyDayData)
  wiredMyDay({ data, error }) {
    this.isLoading = false;
    if (data) {
      this.followUps = data.followUps.map((item) => ({
        ...item,
        telHref: item.phone ? `tel:${item.phone}` : undefined
      }));
      this.inspections = data.inspections;
      this.newAssignments = data.newAssignments;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.followUps = [];
      this.inspections = [];
      this.newAssignments = [];
    }
  }

  @wire(getTeamReports)
  wiredTeamReports({ data, error }) {
    this.teamReportsReady = true;
    if (data) {
      this.teamReports = data;
    } else if (error) {
      this.teamReports = [];
    }
  }

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

  get hasError() {
    return !!this.error;
  }

  get errorMessage() {
    return this.error?.body?.message || "Unable to load My Day data.";
  }

  get followUpsCount() {
    return this.followUps.length;
  }

  get inspectionsCount() {
    return this.inspections.length;
  }

  get newAssignmentsCount() {
    return this.newAssignments.length;
  }

  get teamReportsCount() {
    return this.teamReports.length;
  }

  get hasNoFollowUps() {
    return !this.isLoading && !this.hasError && this.followUps.length === 0;
  }

  get hasNoInspections() {
    return !this.isLoading && !this.hasError && this.inspections.length === 0;
  }

  get hasNoNewAssignments() {
    return (
      !this.isLoading && !this.hasError && this.newAssignments.length === 0
    );
  }

  get hasNoTeamReports() {
    return this.teamReportsReady && this.teamReports.length === 0;
  }

  get hasMoreFollowUps() {
    return this.followUps.length > VISIBLE_CAP;
  }

  get moreFollowUpsLabel() {
    return `+${this.followUps.length - VISIBLE_CAP} more · scroll within section`;
  }

  get followUpsInnerClass() {
    return this.hasMoreFollowUps
      ? "scroll-cap-inner"
      : "scroll-cap-inner no-fade";
  }

  get hasMoreInspections() {
    return this.inspections.length > VISIBLE_CAP;
  }

  get moreInspectionsLabel() {
    return `+${this.inspections.length - VISIBLE_CAP} more · scroll within section`;
  }

  get inspectionsInnerClass() {
    return this.hasMoreInspections
      ? "scroll-cap-inner"
      : "scroll-cap-inner no-fade";
  }

  get hasMoreNewAssignments() {
    return this.newAssignments.length > VISIBLE_CAP;
  }

  get moreNewAssignmentsLabel() {
    return `+${this.newAssignments.length - VISIBLE_CAP} more · scroll within section`;
  }

  get newAssignmentsInnerClass() {
    return this.hasMoreNewAssignments
      ? "scroll-cap-inner"
      : "scroll-cap-inner no-fade";
  }

  get hasMoreTeamReports() {
    return this.teamReports.length > VISIBLE_CAP_REPORTS;
  }

  get moreTeamReportsLabel() {
    return `+${this.teamReports.length - VISIBLE_CAP_REPORTS} more · scroll within section`;
  }

  get teamReportsInnerClass() {
    return this.hasMoreTeamReports
      ? "scroll-cap-inner"
      : "scroll-cap-inner no-fade";
  }

  handleCall(event) {
    // The Call button is a real <a href="tel:..."> now - Lightning Locker's
    // SecureWindow.open only allows http:/https:/mailto:/relative URLs, so
    // window.open("tel:...") is blocked on the Salesforce mobile app.
    // Native anchor navigation isn't subject to that restriction.
    const phone = event.currentTarget.dataset.phone;
    if (!phone) {
      event.preventDefault();
      this.showNoPhoneToast();
    }
  }

  handleWhatsApp(event) {
    const phone = event.currentTarget.dataset.phone;
    if (!phone) {
      this.showNoPhoneToast();
      return;
    }
    window.open(`https://wa.me/${phone.replace("+", "")}`, "_blank");
  }

  showNoPhoneToast() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "No phone on file",
        message:
          "Add a contact number to this enquiry before calling or messaging.",
        variant: "warning"
      })
    );
  }

  handleUpdate(event) {
    const recordId = event.currentTarget.dataset.id;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName: "Enquiry__c",
        actionName: "view"
      }
    });
  }

  handleInspect(event) {
    const name = event.currentTarget.dataset.name;
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Coming soon",
        message: `In production this opens the Inspection quick action for ${name}.`,
        variant: "info"
      })
    );
  }

  handleNavigate(event) {
    const location = event.currentTarget.dataset.location;
    if (!location) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "No location on file",
          message: "This enquiry has no building or city set to navigate to.",
          variant: "warning"
        })
      );
      return;
    }
    window.open(
      `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(location)}`,
      "_blank"
    );
  }

  handleViewReport(event) {
    const reportId = event.currentTarget.dataset.reportId;
    if (!reportId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Report not found",
          message: "This report is not in the org yet. Check the report name in TeamReportsController.",
          variant: "warning"
        })
      );
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: reportId,
        objectApiName: "Report",
        actionName: "view"
      }
    });
  }

  handleFunnelStage(event) {
    const reportId = event.currentTarget.dataset.reportId;
    const value = event.currentTarget.dataset.value;
    if (!reportId) {
      return;
    }
    if (!value) {
      this.handleViewReport(event);
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: `/lightning/r/Report/${reportId}/view?fv0=${encodeURIComponent(value)}`
      }
    });
  }
}
