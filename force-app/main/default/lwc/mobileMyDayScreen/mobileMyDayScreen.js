import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getTeamReports from "@salesforce/apex/TeamReportsController.getTeamReports";

const VISIBLE_CAP_REPORTS = 3;

export default class MobileMyDayScreen extends NavigationMixin(
  LightningElement
) {
  teamReports = [];
  teamReportsReady = false;
  error;

  @wire(getTeamReports)
  wiredTeamReports({ data, error }) {
    this.teamReportsReady = true;
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

  get teamReportsCount() {
    return this.teamReports.length;
  }

  get hasNoTeamReports() {
    return this.teamReportsReady && this.teamReports.length === 0 && !this.hasError;
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

  decorateReportCard(card) {
    if (card.isFunnel && card.stages && card.stages.length) {
      const laid = this.layoutPoints(
        card.stages.map((stage) => stage.value),
        100,
        28
      );
      const stages = card.stages.map((stage, index) => ({
        ...stage,
        cx: laid[index].cx,
        cy: laid[index].cy
      }));
      return {
        ...card,
        stages,
        sparkPoints: laid.map((point) => `${point.cx},${point.cy}`).join(" ")
      };
    }
    const parsed = this.parseSpark(card.sparkPoints);
    const laid = parsed.length
      ? this.scalePoints(parsed, 100, 24)
      : this.layoutPoints([1, 1, 1, 1], 100, 24);
    return {
      ...card,
      sparkPoints: laid.map((point) => `${point.cx},${point.cy}`).join(" "),
      sparkDots: laid.map((point, index) => ({
        key: `d${index}`,
        cx: point.cx,
        cy: point.cy
      }))
    };
  }

  layoutPoints(values, width, height) {
    const list = values && values.length ? values : [0];
    let maxVal = 1;
    list.forEach((value) => {
      const num = Number(value) || 0;
      if (num > maxVal) {
        maxVal = num;
      }
    });
    const padX = 6;
    const padY = 6;
    const n = list.length;
    return list.map((value, index) => {
      const cx =
        n === 1
          ? width / 2
          : padX + ((width - 2 * padX) * index) / (n - 1);
      const cy =
        height - padY - ((height - 2 * padY) * ((Number(value) || 0) / maxVal));
      return { cx: cx.toFixed(1), cy: cy.toFixed(1) };
    });
  }

  parseSpark(sparkPoints) {
    if (!sparkPoints) {
      return [];
    }
    return sparkPoints
      .trim()
      .split(/\s+/)
      .map((pair) => {
        const parts = pair.split(",");
        return {
          x: Number(parts[0]),
          y: Number(parts[1])
        };
      })
      .filter((point) => !Number.isNaN(point.x) && !Number.isNaN(point.y));
  }

  scalePoints(points, width, height) {
    return points.map((point) => ({
      cx: ((point.x / 80) * width).toFixed(1),
      cy: ((point.y / 24) * height).toFixed(1)
    }));
  }

  handleViewReport(event) {
    const reportId = event.currentTarget.dataset.reportId;
    if (!reportId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Report not found",
          message:
            "This report is not in the org yet. Check TeamReportsController.",
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
