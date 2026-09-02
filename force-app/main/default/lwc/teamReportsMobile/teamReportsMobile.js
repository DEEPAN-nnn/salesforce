import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getTeamReports from "@salesforce/apex/TeamReportsController.getTeamReports";

export default class TeamReportsMobile extends NavigationMixin(LightningElement) {
  teamReports = [];
  teamReportsReady = false;
  error;
  wiredResult;

  @wire(getTeamReports)
  wiredTeamReports(result) {
    this.wiredResult = result;
    this.teamReportsReady = true;
    const { data, error } = result;
    if (data) {
      this.teamReports = data.map((card) => this.decorateReportCard(card));
      this.error = undefined;
    } else if (error) {
      this.teamReports = [];
      this.error = error;
    }
  }

  get hasError() {
    return !!this.error;
  }

  get errorMessage() {
    return this.error?.body?.message || "Unable to load team reports.";
  }

  get hasNoTeamReports() {
    return this.teamReportsReady && this.teamReports.length === 0 && !this.hasError;
  }

  get asOfLabel() {
    const stamp = new Date().toLocaleString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true
    });
    return "As of " + stamp;
  }

  get metricCards() {
    return this.teamReports.filter((card) => !card.isFunnel);
  }

  get conversionCard() {
    return this.teamReports.find((card) => card.isFunnel);
  }

  decorateReportCard(card) {
    const displayName = card.displayName || card.name;
    const numeric = this.parseAmount(card.displayValue);
    const numberClass = numeric === 0 ? "metric-num num-red" : "metric-num num-green";
    if (card.isFunnel && card.stages && card.stages.length) {
      let maxVal = 1;
      card.stages.forEach((stage) => {
        const value = Number(stage.value) || 0;
        if (value > maxVal) {
          maxVal = value;
        }
      });
      const stages = card.stages.map((stage) => {
        const value = Number(stage.value) || 0;
        return {
          ...stage,
          barStyle: "width:" + Math.round((value / maxVal) * 100) + "%"
        };
      });
      return { ...card, displayName, stages, numberClass };
    }
    return { ...card, displayName, numberClass };
  }

  parseAmount(displayValue) {
    if (!displayValue) {
      return 0;
    }
    const cleaned = String(displayValue).replace(/[^0-9.-]/g, "");
    const num = Number(cleaned);
    return Number.isNaN(num) ? 0 : num;
  }

  handleRefresh() {
    if (this.wiredResult) {
      refreshApex(this.wiredResult);
    }
  }

  handleConversionDate() {
    const conversion = this.conversionCard;
    if (conversion && conversion.reportId) {
      this.openReport(conversion.reportId);
      return;
    }
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Conversion report",
        message: "Action Wise Conversion is not available.",
        variant: "info"
      })
    );
  }

  handleViewReport(event) {
    this.openReport(event.currentTarget.dataset.reportId);
  }

  openReport(reportId) {
    if (!reportId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Report not found",
          message: "Check TeamReportsController for this report Id.",
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
      this.openReport(reportId);
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
