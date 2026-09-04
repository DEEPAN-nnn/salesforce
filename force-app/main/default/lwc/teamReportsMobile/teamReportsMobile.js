import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getTeamReports from "@salesforce/apex/TeamReportsController.getTeamReports";

/**
 * teamReportsMobile
 * -----------------
 * Phone-first "My Dashboard". Layout, tokens, and tap-through follow the
 * mobileMyDashboard pattern: header + date range + target cards + KPI grid +
 * conversion chart.
 *
 * Data still comes from TeamReportsController (the five org reports). There is
 * no Token Target report in this org, so Token is a standalone count tile.
 * There is no team roster payload yet, so that block is omitted.
 *
 * Presentation children (c-mobile-target-card, c-mobile-kpi-tile,
 * c-mobile-conversion-chart) already exist in the org and are not modified
 * here. This bundle only changes teamReportsMobile + Apex.
 */

const TARGET_PAIRS = [
  {
    key: "collection",
    targetKey: "collectionTarget",
    achievedKey: "collectionAchieved"
  }
];

const STANDALONE_TILES = ["tokenAchieved", "billedOutstanding"];

const DATE_RANGE_OPTIONS = [
  { label: "Today", value: "TODAY" },
  { label: "Yesterday", value: "YESTERDAY" },
  { label: "This Week", value: "THIS_WEEK" },
  { label: "Last Week", value: "LAST_WEEK" },
  { label: "This Month", value: "THIS_MONTH" },
  { label: "Last Month", value: "LAST_MONTH" },
  { label: "Last 3 Days", value: "LAST_N_DAYS:3" },
  { label: "Last 7 Days", value: "LAST_N_DAYS:7" },
  { label: "Last 15 Days", value: "LAST_N_DAYS:15" },
  { label: "Last 30 Days", value: "LAST_N_DAYS:30" },
  { label: "Last 60 Days", value: "LAST_N_DAYS:60" },
  { label: "Last 120 Days", value: "LAST_N_DAYS:120" }
];

const TONE_POSITIVE = "#64c864";
const TONE_NEGATIVE = "#fa1602";

const FUNNEL_ORDER = [
  "Shown Interest",
  "Qualify Meet",
  "Inspection",
  "Site Shortlisted",
  "Token"
];

export default class TeamReportsMobile extends NavigationMixin(
  LightningElement
) {
  isLoading = true;
  error;
  selectedRange = "THIS_MONTH";
  asOf;
  targetPairs = [];
  tiles = [];
  conversion = [];
  conversionTitle = "Action Wise Conversion Report - Overview";
  reportIdsByKey = {};
  conversionReportId;
  problems = [];
  wiredResult;

  @wire(getTeamReports, { dateRange: "$selectedRange" })
  wiredTeamReports(result) {
    this.wiredResult = result;
    const { data, error } = result;
    if (data) {
      this.applyPayload(data);
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.problems = [];
      this.targetPairs = [];
      this.tiles = [];
      this.conversion = [];
    }
    if (data || error) {
      this.isLoading = false;
    }
  }

  get dateRangeOptions() {
    return DATE_RANGE_OPTIONS;
  }

  get hasError() {
    return !!this.error;
  }

  get hasProblems() {
    return this.problems && this.problems.length > 0;
  }

  applyPayload(cards) {
    this.asOf = this.formatAsOf(new Date().toISOString());
    this.conversion = [];
    this.conversionReportId = undefined;
    this.conversionTitle = "Action Wise Conversion Report - Overview";
    const byKey = {};
    const problems = [];
    (cards || []).forEach((card) => {
      const key = this.keyFor(card);
      if (key) {
        byKey[key] = {
          key,
          label: card.name || card.displayName,
          value: Number(card.metricValue) || 0,
          displayUnits: card.isCurrency ? "Auto" : "Integer",
          isCurrency: !!card.isCurrency,
          reportId: card.reportId,
          warning: card.warning
        };
      }
      if (this.valueKindOf(card) === "CHART") {
        this.conversionTitle =
          card.name ||
          card.displayName ||
          "Action Wise Conversion Report - Overview";
        this.conversionReportId = card.reportId;
        this.conversion = this.orderFunnel(card.stages || []).map((row) => {
          const value = Number(row.value) || 0;
          return { ...row, value };
        });
        if (card.warning) {
          problems.push(card.warning);
        }
      } else if (card.warning) {
        problems.push(card.warning);
      }
    });
    this.reportIdsByKey = byKey;
    this.problems = problems.map((text, index) => ({
      id: "p-" + index,
      text
    }));
    this.targetPairs = this.buildPairs(byKey);
    this.tiles = STANDALONE_TILES.map((key) => byKey[key])
      .filter((tile) => tile !== undefined)
      .map((tile) => this.decorateTile(this.withTone(tile)));
    this.conversion = this.withBarWidths(this.conversion);
  }

  keyFor(card) {
    if (card.tileKey) {
      return card.tileKey;
    }
    if (this.valueKindOf(card) === "CHART") {
      return "conversion";
    }
    return undefined;
  }

  valueKindOf(card) {
    if (card.valueKind) {
      return card.valueKind;
    }
    if (card.isFunnel) {
      return "CHART";
    }
    return "COUNT";
  }

  buildPairs(byKey) {
    return TARGET_PAIRS.map((spec) => {
      const target = byKey[spec.targetKey];
      const achieved = byKey[spec.achievedKey];
      if (!target || !achieved) {
        return undefined;
      }
      return this.decorateTargetPair({
        key: spec.key,
        label: achieved.label,
        target: target.value || 0,
        achieved: achieved.value || 0,
        displayUnits: target.displayUnits,
        isCurrency: target.isCurrency
      });
    }).filter((pair) => pair !== undefined);
  }

  withTone(tile) {
    return {
      ...tile,
      tone: (tile.value || 0) > 0 ? TONE_POSITIVE : TONE_NEGATIVE
    };
  }

  orderFunnel(rows) {
    return FUNNEL_ORDER.map((label) =>
      rows.find((row) => row.label === label)
    ).filter((row) => row !== undefined);
  }

  withBarWidths(rows) {
    let maxVal = 1;
    rows.forEach((row) => {
      const value = Number(row.value) || 0;
      if (value > maxVal) {
        maxVal = value;
      }
    });
    return rows.map((row) => {
      const value = Number(row.value) || 0;
      const pct = Math.max(8, Math.round((value / maxVal) * 100));
      return { ...row, barStyle: `width:${pct}%` };
    });
  }

  decorateTargetPair(pair) {
    const { target, achieved } = pair;
    const gap = achieved - target;
    const hasTarget = target > 0;
    return {
      ...pair,
      achievedDisplay: this.formatValue({ ...pair, value: achieved }),
      targetDisplay: this.formatValue({ ...pair, value: target }),
      variancePct: hasTarget ? (gap / target) * 100 : null,
      varianceDisplay: this.varianceLabel(pair, gap, hasTarget),
      progressPct: hasTarget
        ? Math.max(0, Math.min((achieved / target) * 100, 100))
        : 0
    };
  }

  varianceLabel(pair, gap, hasTarget) {
    if (!hasTarget) {
      return "No target set";
    }
    if (gap === 0) {
      return "On target";
    }
    const magnitude = this.formatValue({ ...pair, value: Math.abs(gap) });
    return gap > 0 ? `${magnitude} ahead` : `${magnitude} short`;
  }

  decorateTile(tile) {
    return {
      ...tile,
      displayValue: this.formatValue(tile)
    };
  }

  formatValue(tile) {
    const { value, displayUnits, isCurrency } = tile;
    const symbol = isCurrency ? "₹" : "";
    const num = Number(value) || 0;

    if (displayUnits === "Integer") {
      return symbol + num.toLocaleString("en-IN");
    }

    const abs = Math.abs(num);
    if (abs >= 10000000) {
      return `${symbol}${this.trim(num / 10000000)}Cr`;
    }
    if (abs >= 100000) {
      return `${symbol}${this.trim(num / 100000)}L`;
    }
    if (abs >= 1000) {
      return `${symbol}${this.trim(num / 1000)}k`;
    }
    return symbol + num.toLocaleString("en-IN");
  }

  trim(num) {
    return Number(num.toFixed(1)).toString();
  }

  formatAsOf(iso) {
    const date = new Date(iso);
    return date.toLocaleString("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit"
    });
  }

  handleRangeChange(event) {
    this.selectedRange = event.detail.value;
    this.isLoading = true;
  }

  async handleRefresh() {
    this.isLoading = true;
    try {
      if (this.wiredResult) {
        await refreshApex(this.wiredResult);
      }
      const fresh = await getTeamReports({ dateRange: this.selectedRange });
      this.applyPayload(fresh || []);
      this.error = undefined;
    } catch (err) {
      this.error = err;
    } finally {
      this.isLoading = false;
    }
  }

  handleTileTap(event) {
    const { key } = event.detail;
    const pair = TARGET_PAIRS.find((spec) => spec.key === key);
    const lookupKey = pair ? pair.achievedKey : key;
    const tile = this.reportIdsByKey[lookupKey];
    if (!tile || !tile.reportId) {
      this.showUnavailable();
      return;
    }
    this.navigateToRecord(tile.reportId);
  }

  handleChartTap() {
    if (!this.conversionReportId) {
      this.showUnavailable();
      return;
    }
    this.navigateToRecord(this.conversionReportId);
  }

  showUnavailable() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Report unavailable",
        message: "You do not have access to the report behind this tile.",
        variant: "warning"
      })
    );
  }

  navigateToRecord(recordId) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: { recordId, actionName: "view" }
    });
  }
}
