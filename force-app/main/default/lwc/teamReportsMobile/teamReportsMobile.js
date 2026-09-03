import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getTeamReports from "@salesforce/apex/TeamReportsController.getTeamReports";

const VISIBLE_CAP_REPORTS = 3;

export default class TeamReportsMobile extends NavigationMixin(LightningElement) {
  teamReports = [];
  teamReportsReady = false;
  error;
  wiredResult;
  isRefreshing = false;
  asOfMs = Date.now();

  @wire(getTeamReports)
  wiredTeamReports(result) {
    this.wiredResult = result;
    this.teamReportsReady = true;
    const { data, error } = result;
    if (data) {
      this.teamReports = data;
      this.error = undefined;
      if (!this.isRefreshing) {
        this.asOfMs = Date.now();
      }
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

  get asOfLabel() {
    const stamp = new Date(this.asOfMs).toLocaleString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true
    });
    return "As of " + stamp;
  }

  get refreshClass() {
    return this.isRefreshing ? "dash-refresh is-loading" : "dash-refresh";
  }

  get dashClass() {
    return this.isRefreshing ? "dash is-loading" : "dash";
  }

  get metrics() {
    return this.teamReports.filter((card) => this.valueKindOf(card) !== "CHART");
  }

  get amountMetrics() {
    return this.metrics.filter((card) => this.valueKindOf(card) === "AMOUNT");
  }

  get countMetrics() {
    return this.metrics.filter((card) => this.valueKindOf(card) === "COUNT");
  }

  get progressCards() {
    const cards = [];
    const amounts = this.amountMetrics;
    if (amounts.length >= 2) {
      cards.push(this.buildProgressCard(amounts[0], amounts[1]));
    }
    this.countMetrics.forEach((card) => {
      cards.push(this.buildKpiCard(card));
    });
    return cards;
  }

  get splitCards() {
    const amounts = this.amountMetrics;
    if (amounts.length < 3) {
      return amounts.length === 1 ? [this.buildKpiCard(amounts[0])] : [];
    }
    return amounts.slice(2).map((card) => this.buildKpiCard(card));
  }

  get hasSplitRow() {
    return this.splitCards.length > 1;
  }

  get fullKpiCards() {
    return this.splitCards.length === 1 ? this.splitCards : [];
  }

  get conversionCard() {
    const card = this.teamReports.find((row) => this.valueKindOf(row) === "CHART");
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
      title: this.reportLabel(card),
      reportId: card.reportId,
      warning: card.warning,
      stages: stages.map((stage) => {
        const value = Number(stage.value) || 0;
        const pct = Math.max(8, Math.round((value / maxVal) * 100));
        return {
          ...stage,
          barStyle: "width:" + pct + "%"
        };
      })
    };
  }

  get sectionCount() {
    return this.progressCards.length + this.splitCards.length + (this.conversionCard ? 1 : 0);
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

  valueKindOf(card) {
    if (card.valueKind) {
      return card.valueKind;
    }
    if (card.isFunnel) {
      return "CHART";
    }
    if (String(card.displayValue || "").includes("₹")) {
      return "AMOUNT";
    }
    return "COUNT";
  }

  reportLabel(card) {
    return card.displayName || card.name || "Report";
  }

  buildProgressCard(targetCard, actualCard) {
    const targetNum = this.parseAmount(targetCard.displayValue);
    const actualNum = this.parseAmount(actualCard.displayValue);
    const achieved = targetNum > 0 ? Math.round((actualNum / targetNum) * 100) : 0;
    const behind = targetNum > 0 && actualNum < targetNum;
    const shortPct = targetNum > 0 ? Math.round(((targetNum - actualNum) / targetNum) * 100) : 0;
    const tone = behind ? "down" : "up";
    return {
      id: "pair-" + (actualCard.id || "amount"),
      hasTarget: true,
      title: this.reportLabel(actualCard),
      titleClass: "title " + tone,
      heroClass: "hero " + tone,
      badgeClass: "badge " + tone,
      barClass: "bar " + tone,
      percentLabel: behind ? "~" + Math.abs(shortPct) + "%" : achieved + "%",
      actualDisplay: actualCard.displayValue || "—",
      targetDisplay: targetCard.displayValue || "—",
      gapLabel: this.gapLabel(targetNum, actualNum, targetCard.displayValue, actualCard.displayValue),
      barStyle: "width:" + Math.min(100, Math.max(4, achieved)) + "%",
      viewReportId: actualCard.reportId,
      warning: [targetCard.warning, actualCard.warning].filter(Boolean).join(" · ")
    };
  }

  buildKpiCard(card) {
    const actualNum = this.parseAmount(card.displayValue);
    const tone = actualNum === 0 ? "down" : "up";
    return {
      id: card.id || this.reportLabel(card),
      hasTarget: false,
      title: this.reportLabel(card),
      titleClass: "title " + tone,
      heroClass: "hero " + tone,
      actualDisplay: card.displayValue || "—",
      gapLabel: "",
      viewReportId: card.reportId,
      warning: card.warning
    };
  }

  gapLabel(targetNum, actualNum, targetDisplay, actualDisplay) {
    const gap = targetNum - actualNum;
    if (!targetNum) {
      return "";
    }
    const money = String(targetDisplay).includes("₹") || String(actualDisplay).includes("₹");
    const suffix = this.unitSuffix(targetDisplay) || this.unitSuffix(actualDisplay);
    const abs = Math.abs(gap);
    const n = Number.isInteger(abs) ? String(abs) : abs.toFixed(1);
    const value = (money ? "₹" : "") + n + suffix;
    if (gap > 0) {
      return value + " short";
    }
    if (gap < 0) {
      return value + " ahead";
    }
    return "On target";
  }

  unitSuffix(displayValue) {
    const match = String(displayValue || "").match(/L|Cr/i);
    return match ? match[0] : "";
  }

  parseAmount(displayValue) {
    if (!displayValue) {
      return 0;
    }
    const cleaned = String(displayValue).replace(/[^0-9.-]/g, "");
    const num = Number(cleaned);
    return Number.isNaN(num) ? 0 : num;
  }

  async handleRefresh() {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    try {
      if (this.wiredResult) {
        await refreshApex(this.wiredResult);
      }
      const fresh = await getTeamReports();
      this.teamReports = fresh || [];
      this.error = undefined;
    } catch (e) {
      this.error = e;
    } finally {
      this.asOfMs = Date.now();
      this.isRefreshing = false;
    }
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
