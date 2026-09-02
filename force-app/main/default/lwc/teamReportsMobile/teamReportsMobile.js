import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTeamReports from "@salesforce/apex/TeamReportsController.getTeamReports";

const VISIBLE_CAP_REPORTS = 3;

export default class TeamReportsMobile extends NavigationMixin(LightningElement) {
  teamReports = [];
  teamReportsReady = false;
  error;

  @wire(getTeamReports)
  wiredTeamReports({ data, error }) {
    this.teamReportsReady = true;
    if (data) {
      this.teamReports = data;
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

  get metrics() {
    return this.teamReports.filter((card) => !card.isFunnel);
  }

  get conversionRaw() {
    return this.teamReports.find((card) => card.isFunnel);
  }

  get compareCards() {
    const metrics = this.metrics;
    const cards = [];
    if (metrics.length >= 2) {
      cards.push(this.buildCompareCard("collection", "Collection", metrics[0], metrics[1]));
    } else if (metrics.length === 1) {
      cards.push(this.buildActualCard(metrics[0], metrics[0].displayName || metrics[0].name));
    }
    if (metrics.length >= 3) {
      cards.push(this.buildActualCard(metrics[2], "Token"));
    }
    return cards;
  }

  get extraCards() {
    const metrics = this.metrics;
    if (metrics.length < 4) {
      return [];
    }
    return [this.buildActualCard(metrics[3], metrics[3].displayName || "Billed & Outstanding")];
  }

  get conversionCard() {
    const card = this.conversionRaw;
    if (!card) {
      return null;
    }
    const stages = card.stages || [];
    let maxVal = 1;
    stages.forEach((stage) => {
      const value = Number(stage.value) || 0;
      if (value > maxVal) {
        maxVal = value;
      }
    });
    return {
      title: "Action Wise Conversion",
      reportId: card.reportId,
      warning: card.warning,
      stages: stages.map((stage) => {
        const value = Number(stage.value) || 0;
        const px = Math.max(4, Math.round((value / maxVal) * 70));
        return {
          ...stage,
          barStyle: "height:" + px + "px"
        };
      })
    };
  }

  get sectionCount() {
    return this.compareCards.length + (this.conversionCard ? 1 : 0) + this.extraCards.length;
  }

  get hasNoTeamReports() {
    return this.teamReportsReady && this.sectionCount === 0 && !this.hasError;
  }

  get hasMoreTeamReports() {
    return this.sectionCount > VISIBLE_CAP_REPORTS;
  }

  get moreTeamReportsLabel() {
    return `+${this.sectionCount - VISIBLE_CAP_REPORTS} more · scroll within section`;
  }

  get teamReportsInnerClass() {
    return this.hasMoreTeamReports
      ? "scroll-cap-inner"
      : "scroll-cap-inner no-fade";
  }

  buildCompareCard(id, title, targetCard, actualCard) {
    const targetNum = this.parseAmount(targetCard.displayValue);
    const actualNum = this.parseAmount(actualCard.displayValue);
    const percent = targetNum > 0 ? Math.round((actualNum / targetNum) * 100) : 0;
    const zero = actualNum === 0;
    return {
      id,
      title,
      hasTarget: true,
      targetDisplay: targetCard.displayValue || "—",
      actualDisplay: actualCard.displayValue || "—",
      percentLabel: percent + "%",
      percentClass: zero ? "big bad" : "big ok",
      actualClass: zero ? "score-value bad" : "score-value ok",
      targetReportId: targetCard.reportId,
      actualReportId: actualCard.reportId,
      viewReportId: actualCard.reportId,
      warning: [targetCard.warning, actualCard.warning].filter(Boolean).join(" · ")
    };
  }

  buildActualCard(card, title) {
    const actualNum = this.parseAmount(card.displayValue);
    return {
      id: card.id || title,
      title,
      hasTarget: false,
      actualDisplay: card.displayValue || "—",
      actualClass: actualNum === 0 ? "metric-number bad" : "metric-number ok",
      viewReportId: card.reportId,
      warning: card.warning
    };
  }

  parseAmount(displayValue) {
    if (!displayValue) {
      return 0;
    }
    const cleaned = String(displayValue).replace(/[^0-9.-]/g, "");
    const num = Number(cleaned);
    return Number.isNaN(num) ? 0 : num;
  }

  handleViewReport(event) {
    const reportId = event.currentTarget.dataset.reportId;
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
