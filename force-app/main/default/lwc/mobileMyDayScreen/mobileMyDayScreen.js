import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getMyDayData from "@salesforce/apex/EnquiryMyDayController.getMyDayData";

const VISIBLE_CAP = 2;

export default class MobileMyDayScreen extends NavigationMixin(
  LightningElement
) {
  followUps = [];
  inspections = [];
  newAssignments = [];
  isLoading = true;
  error;

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

  handleCall(event) {
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
}
