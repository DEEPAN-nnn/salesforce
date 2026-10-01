import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getDashboard from "@salesforce/apex/MobileMyDashboardController.getDashboard";
import getMyReportTree from "@salesforce/apex/MobileMyDashboardController.getMyReportTree";
import listTeamMembers from "@salesforce/apex/MobileMyDashboardController.listTeamMembers";
import getDirectReports from "@salesforce/apex/MobileMyDashboardController.getDirectReports";
import getTeamPickerTree from "@salesforce/apex/MobileMyDashboardController.getTeamPickerTree";

const LEVEL_INDIVIDUAL = "INDIVIDUAL";
const LEVEL_TEAM = "TEAM";

const TARGET_PAIRS = [
  {
    key: "collection",
    label: "Revenue Target",
    targetKey: "collectionTarget",
    achievedKey: "collectionAchieved"
  },
  {
    key: "token",
    label: "Token",
    targetKey: "tokenTarget",
    achievedKey: "tokenAchieved"
  }
];

const ALL_PEOPLE = "__ALL__";

const ROSTER_PREVIEW = 8;

const STANDALONE_TILES = ["billedOutstanding", "tokenBookings"];

const OUTSTANDING_AMBER = 500000;
const OUTSTANDING_RED = 1000000;

const TILE_BANDS = {
  billedOutstanding: (value) => {
    if (value >= OUTSTANDING_RED) {
      return "rag-red";
    }
    if (value >= OUTSTANDING_AMBER) {
      return "rag-amber";
    }
    return "rag-green";
  },
  tokenBookings: (value) => (value > 0 ? "rag-green" : "rag-red")
};

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

const FUNNEL_ORDER = [
  "Shown Interest",
  "Qualify Meet",
  "Inspection",
  "Site Shortlisted",
  "Token"
];

export default class MobileMyDashboard extends NavigationMixin(LightningElement) {
  isLoading = true;
  error;
  selectedRange = "THIS_MONTH";
  asOf;
  targetPairs = [];
  tiles = [];
  conversion = [];
  roster = [];

  accessLevel = LEVEL_INDIVIDUAL;
  activeTab = LEVEL_INDIVIDUAL;
  canViewTeam = false;
  isSystemAdmin = false;
  payloadByTab = {};
  teams = [];
  selectedTeamKey = null;
  selectedPerson = null;
  rosterFilter = "";
  rosterExpanded = false;
  reportIdsByKey = {};
  conversionReportId;
  problems = [];

  pickerOpen = false;
  searchText = "";
  expanded = {};
  reportTree = null;
  draftIds = {};
  pickerLabel = null;
  selectedMemberNames = null;

  connectedCallback() {
    this.loadData();
  }

  get dateRangeOptions() {
    return DATE_RANGE_OPTIONS;
  }

  get hasProblems() {
    return this.problems && this.problems.length > 0;
  }

  get conversionTitle() {
    return "Action Wise Conversion";
  }

  get showTabs() {
    return this.canViewTeam;
  }

  payloadKey(tab = this.activeTab) {
    return tab === LEVEL_TEAM
      ? `${LEVEL_TEAM}:${this.selectedTeamKey || ""}`
      : LEVEL_INDIVIDUAL;
  }

  get showTeamPicker() {
    return this.isTeamTab;
  }

  get singleTeam() {
    return this.teams.length === 1;
  }

  get teamOptions() {
    return this.teams.map((team) => ({ label: team.name, value: team.key }));
  }

  get selectedTeamValue() {
    return this.selectedTeamKey;
  }

  get rosterTitle() {
    const team = this.teams.find((t) => t.key === this.selectedTeamKey);
    return team ? team.name : "My Team";
  }

  handleTeamChange(event) {
    this.selectedTeamKey = event.detail.value;
    this.selectedPerson = null;
    this.selectedMemberNames = null;
    this.pickerLabel = null;
    this.rosterFilter = "";
    this.rosterExpanded = false;
    this.loadData();
  }

  get isTeamTab() {
    return this.activeTab === LEVEL_TEAM;
  }

  get myTabClass() {
    return this.isTeamTab ? "dash__tab" : "dash__tab dash__tab_on";
  }

  get teamTabClass() {
    return this.isTeamTab ? "dash__tab dash__tab_on" : "dash__tab";
  }

  handleTabSelect(event) {
    const tab = event.currentTarget.dataset.tab;
    if (tab === this.activeTab) {
      return;
    }
    this.activeTab = tab;
    this.selectedPerson = null;
    this.selectedMemberNames = null;
    this.pickerLabel = null;
    this.rosterFilter = "";
    this.rosterExpanded = false;
    this.loadData();
  }

  get showPicker() {
    return this.isTeamTab && this.personOptions.length > 1;
  }

  get personOptions() {
    const payload = this.payloadByTab[this.payloadKey(LEVEL_TEAM)];
    const people = (payload && payload.roster) || [];
    const total = payload && payload.memberCount;
    return [
      {
        label:
          total > people.length
            ? `All members · ${people.length} of ${total} with data`
            : `All members · ${people.length} ${people.length === 1 ? "person" : "people"}`,
        value: ALL_PEOPLE
      },
      ...people.map((member) => ({ label: member.name, value: member.name }))
    ];
  }

  get selectedPersonValue() {
    return this.selectedPerson || ALL_PEOPLE;
  }

  handlePersonChange(event) {
    const value = event.detail.value;
    this.selectedPerson = value === ALL_PEOPLE ? null : value;
    this.selectedMemberNames = null;
    this.pickerLabel = null;
    this.renderScope(this.payloadByTab[this.payloadKey()]);
  }

  get showRoster() {
    return this.isTeamTab && !this.selectedPerson && this.roster.length > 0;
  }

  get showRosterFilter() {
    return this.roster.length > ROSTER_PREVIEW;
  }

  get visibleRoster() {
    const term = this.rosterFilter.trim().toLowerCase();
    const matched = term
      ? this.roster.filter((member) => (member.name || "").toLowerCase().includes(term))
      : this.roster;
    return this.rosterExpanded ? matched : matched.slice(0, ROSTER_PREVIEW);
  }

  get hasHiddenReportees() {
    return !this.rosterExpanded && this.roster.length > ROSTER_PREVIEW;
  }

  get showAllLabel() {
    return `Show all ${this.roster.length}`;
  }

  handleRosterFilter(event) {
    this.rosterFilter = event.target.value || "";
  }

  handleShowAll() {
    this.rosterExpanded = true;
  }

  async loadData() {
    const cached = this.payloadByTab[this.payloadKey()];
    if (cached) {
      this.applyPayload(cached);
      return;
    }

    this.isLoading = true;
    this.error = undefined;
    try {
      const data = await getDashboard({
        dateRange: this.selectedRange,
        tab: this.activeTab,
        teamKey: this.activeTab === LEVEL_TEAM ? this.selectedTeamKey : null
      });
      if (data.accessLevel === LEVEL_TEAM) {
        this.selectedTeamKey = data.selectedTeamKey;
      }
      this.payloadByTab[this.payloadKey()] = data;
      this.applyPayload(data);
    } catch (err) {
      this.error = err;
      this.problems = [];
      this.targetPairs = [];
      this.tiles = [];
      this.conversion = [];
      this.roster = [];
    } finally {
      this.isLoading = false;
    }
  }

  applyPayload(data) {
    this.accessLevel = data.accessLevel === LEVEL_TEAM ? LEVEL_TEAM : LEVEL_INDIVIDUAL;
    this.canViewTeam = data.canViewTeam === true;
    this.isSystemAdmin = data.isSystemAdmin === true;
    this.teams = data.teams || [];

    if (this.activeTab === LEVEL_TEAM && this.accessLevel !== LEVEL_TEAM) {
      this.activeTab = LEVEL_INDIVIDUAL;
    }

    this.asOf = this.formatAsOf(data.asOf);
    this.problems = data.problems || [];
    this.renderScope(data);
    this.isLoading = false;
  }

  renderScope(data) {
    if (this.selectedMemberNames && this.selectedMemberNames.length > 1) {
      this.renderSelectedMembers(this.selectedMemberNames);
      return;
    }

    if (this.selectedPerson) {
      this.renderPerson(data);
      return;
    }

    const byKey = {};
    data.tiles.forEach((tile) => {
      byKey[tile.key] = tile;
    });
    this.reportIdsByKey = byKey;
    this.targetPairs = this.buildPairs(byKey);
    this.tiles = STANDALONE_TILES.map((key) => byKey[key])
      .filter((tile) => tile !== undefined)
      .map((tile) => this.decorateTile(this.withBand(tile)));
    this.conversion = this.orderFunnel(data.conversion || []);
    this.conversionReportId = data.conversionReportId;
    this.roster = (data.roster || []).map((member) => this.decorateMember(member));
  }

  renderPerson(data) {
    const row = (data.roster || []).find((member) => member.name === this.selectedPerson) || {
      name: this.selectedPerson,
      collectionTarget: 0,
      collectionValue: 0,
      tokenTarget: 0,
      tokenAchieved: 0,
      outstanding: 0,
      underFinalization: 0,
      conversion: []
    };

    this.targetPairs = [
      this.decorateTargetPair({
        key: "collection",
        label: "Revenue Target",
        target: row.collectionTarget || 0,
        achieved: row.collectionValue || 0,
        displayUnits: "Auto",
        isCurrency: true
      }),
      this.decorateTargetPair({
        key: "token",
        label: "Token",
        target: row.tokenTarget || 0,
        achieved: row.tokenAchieved || 0,
        displayUnits: "Integer",
        isCurrency: false
      })
    ];
    this.tiles = [
      this.decorateTile(
        this.withBand({
          key: "billedOutstanding",
          label: "Outstanding Payment",
          value: row.outstanding || 0,
          displayUnits: "Auto",
          isCurrency: true
        })
      ),
      this.decorateTile(
        this.withBand({
          key: "tokenBookings",
          label: "Under Finalization",
          value: row.underFinalization || 0,
          displayUnits: "Integer",
          isCurrency: false
        })
      )
    ];
    this.conversion = this.orderFunnel(row.conversion || []);
    this.roster = [];
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
        label: spec.label,
        target: target.value || 0,
        achieved: achieved.value || 0,
        displayUnits: target.displayUnits,
        isCurrency: target.isCurrency
      });
    }).filter((pair) => pair !== undefined);
  }

  withBand(tile) {
    return {
      ...tile,
      band: TILE_BANDS[tile.key] ? TILE_BANDS[tile.key](tile.value || 0) : "rag-green"
    };
  }

  orderFunnel(rows) {
    return FUNNEL_ORDER.map((label) => rows.find((row) => row.label === label)).filter(
      (row) => row !== undefined
    );
  }

  decorateTargetPair(pair) {
    const { target, achieved } = pair;
    const gap = achieved - target;
    const hasTarget = target > 0;
    return {
      ...pair,
      achievedDisplay: this.formatValue({ ...pair, value: achieved }),
      targetDisplay: this.formatValue({ ...pair, value: target }),
      varianceDisplay: this.varianceLabel(pair, gap, hasTarget),
      attainmentPct: hasTarget ? (achieved / target) * 100 : null
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
    const displayValue = this.formatValue(tile);
    if (tile.pairValue === null || tile.pairValue === undefined) {
      return { ...tile, displayValue };
    }
    const pairDisplay = this.formatValue({
      value: tile.pairValue,
      displayUnits: tile.isCurrency ? "Integer" : "Auto",
      isCurrency: !tile.isCurrency
    });
    const countDisplay = tile.isCurrency ? pairDisplay : displayValue;
    const amountDisplay = tile.isCurrency ? displayValue : pairDisplay;
    return { ...tile, displayValue: `${countDisplay} | ${amountDisplay}` };
  }

  decorateMember(member) {
    const target = Math.round(Number(member.tokenTarget) || 0);
    const achieved = Math.round(Number(member.tokenAchieved) || 0);
    return {
      id: member.id,
      name: member.name,
      tokenAchieved: achieved,
      tokenTarget: target,
      collectionDisplay: this.formatValue({
        value: member.collectionValue || 0,
        displayUnits: "Auto",
        isCurrency: true
      }),
      progressPct: target > 0 ? (achieved / target) * 100 : 0
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
    this.payloadByTab = {};
    this.loadData();
  }

  handleRefresh() {
    this.payloadByTab = {};
    this.reportTree = null;
    this.loadData();
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

  handleMemberTap(event) {
    const { userId } = event.detail;
    if (!userId || !userId.startsWith("005")) {
      return;
    }
    this.navigateToRecord(userId);
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

  get pickerExpanded() {
    return this.pickerOpen ? "true" : "false";
  }

  get fieldChevron() {
    return this.pickerOpen ? "utility:chevronup" : "utility:chevrondown";
  }

  get pickerSummary() {
    if (this.pickerLabel) {
      return this.pickerLabel;
    }
    if (this.isSystemAdmin) {
      const team = this.teams.find((item) => item.key === this.selectedTeamKey);
      return team ? team.name : "All teams";
    }
    return "My team";
  }

  get visibleRows() {
    if (!this.reportTree) {
      return [
        {
          id: "loading-tree",
          isNote: true,
          name: "Loading your team…",
          rowStyle: "padding-left: 0.35rem"
        }
      ];
    }
    if (this.reportTree.length === 0) {
      return [
        {
          id: "empty-tree",
          rowKey: "empty-tree",
          isNote: true,
          name: this.isSystemAdmin ? "No teams are available" : "No one reports to you",
          rowStyle: "padding-left: 0.35rem"
        }
      ];
    }
    const rows = [];
    this.walkTree(this.reportTree, 0, rows, (this.searchText || "").trim().toLowerCase());
    return rows;
  }

  get noSearchResults() {
    const query = (this.searchText || "").trim();
    return (
      this.pickerOpen &&
      !!query &&
      this.reportTree &&
      this.reportTree.length > 0 &&
      this.visibleRows.length === 0
    );
  }

  walkTree(nodes, depth, rows, query) {
    (nodes || []).forEach((node) => {
      const name = (node.name || "").toLowerCase();
      const selfMatch = !query || name.includes(query);
      const childMatch = !!query && this.descendantMatch(node, query);
      if (query && !selfMatch && !childMatch) {
        return;
      }
      const children = node.children;
      const pendingTeam = node.kind === "team" && children == null;
      const hasChildren =
        pendingTeam ||
        node.expandable === true ||
        (children || []).length > 0;
      const expanded =
        !pendingTeam && (query ? selfMatch || childMatch : !!this.expanded[node.id]);
      const row = this.toPersonRow(node, depth, hasChildren, expanded);
      row.rowKey = `${rows.length}-${node.id}`;
      rows.push(row);
      if (hasChildren && expanded) {
        this.walkTree(children, depth + 1, rows, selfMatch ? "" : query);
      }
    });
  }

  descendantMatch(node, query) {
    return (node.children || []).some((child) => {
      return (child.name || "").toLowerCase().includes(query) || this.descendantMatch(child, query);
    });
  }

  handleFieldClick() {
    if (this.pickerOpen) {
      this.cancelPicker();
      return;
    }
    this.openPicker();
  }

  async openPicker() {
    this.searchText = "";
    this.pickerOpen = true;
    if (!this.reportTree) {
      if (this.isSystemAdmin && this.teams.length) {
        try {
          this.reportTree = this.cloneTree((await getTeamPickerTree()) || []);
        } catch (err) {
          this.reportTree = this.teams.map((team) => ({
            id: `team:${team.key}`,
            name: team.name,
            kind: "team",
            sourceKey: team.key,
            expandable: false,
            children: null
          }));
        }
      } else {
        try {
          this.reportTree = this.cloneTree((await getMyReportTree()) || []);
        } catch (err) {
          this.reportTree = [];
        }
      }
    }
    this.seedDraft();
  }

  cancelPicker() {
    this.pickerOpen = false;
    this.searchText = "";
  }

  handleSearch(event) {
    this.searchText = event.target.value || "";
  }

  seedDraft() {
    const ids = {};
    const all = this.flatten(this.reportTree);
    if (this.isSystemAdmin && this.teams.length) {
      if (this.selectedMemberNames && this.selectedMemberNames.length) {
        all.forEach((node) => {
          if (this.selectedMemberNames.includes(node.name)) {
            ids[node.id] = true;
          }
        });
      } else if (this.selectedPerson) {
        all.forEach((node) => {
          if (node.name === this.selectedPerson) {
            ids[node.id] = true;
          }
        });
      } else if (this.selectedTeamKey) {
        ids[`team:${this.selectedTeamKey}`] = true;
      }
      this.draftIds = ids;
      return;
    }
    if (this.selectedMemberNames && this.selectedMemberNames.length) {
      all.forEach((node) => {
        if (this.selectedMemberNames.includes(node.name)) {
          ids[node.id] = true;
        }
      });
    } else if (this.selectedPerson) {
      all.forEach((node) => {
        if (node.name === this.selectedPerson) {
          ids[node.id] = true;
        }
      });
    } else {
      all.forEach((node) => {
        ids[node.id] = true;
      });
    }
    this.draftIds = ids;
  }

  async toggleExpand(event) {
    event.stopPropagation();
    const el = event.currentTarget;
    const id =
      (el.dataset && (el.dataset.nodeId || el.dataset.id || el.dataset.team)) ||
      el.getAttribute("data-node-id") ||
      el.getAttribute("data-id") ||
      el.getAttribute("data-team");
    if (!id) {
      return;
    }
    const node = this.findNode(id, this.reportTree);
    const opening = !this.expanded[id];
    const childCount = node && node.children ? node.children.length : 0;
    const needsLoad =
      opening &&
      node &&
      childCount === 0 &&
      (node.children == null || node.expandable === true || node.kind === "team");
    if (needsLoad) {
      try {
        const loaded =
          node.kind === "team"
            ? await listTeamMembers({
                teamKey: node.sourceKey || String(node.id).replace(/^team:/, "")
              })
            : await getDirectReports({ managerId: node.id });
        const members = this.cloneTree(loaded || []);
        this.tagSource(members, node.sourceKey);
        this.reportTree = this.replaceChildren(this.reportTree, id, members);
      } catch (err) {
        return;
      }
    }
    this.expanded = { ...this.expanded, [id]: opening };
  }

  cloneTree(nodes) {
    return (nodes || []).map((node) => ({
      id: node.id,
      name: node.name,
      kind:
        node.kind ||
        (String(node.id || "").startsWith("team:") ? "team" : "person"),
      sourceKey: node.sourceKey || null,
      expandable: node.expandable === true,
      children: node.children == null ? null : this.cloneTree(node.children)
    }));
  }

  replaceChildren(nodes, id, children) {
    return (nodes || []).map((node) => {
      if (node.id === id) {
        return { ...node, children, expandable: false };
      }
      if (node.children && node.children.length) {
        return {
          ...node,
          children: this.replaceChildren(node.children, id, children)
        };
      }
      return node;
    });
  }

  tagSource(nodes, sourceKey) {
    (nodes || []).forEach((node) => {
      node.sourceKey = sourceKey;
      node.kind = node.kind || "person";
      this.tagSource(node.children, sourceKey);
    });
  }

  handleCheck(event) {
    event.stopPropagation();
    const node = this.findNode(event.currentTarget.dataset.id, this.reportTree);
    if (!node) {
      return;
    }
    const select = this.nodeState(node) !== "all";
    const ids = { ...this.draftIds };
    if (this.isSystemAdmin && select && node.sourceKey) {
      Object.keys(ids).forEach((userId) => {
        const other = this.findNode(userId, this.reportTree);
        if (other && other.sourceKey && other.sourceKey !== node.sourceKey) {
          delete ids[userId];
        }
      });
    }
    this.subtreeIds(node).forEach((userId) => {
      if (select) {
        ids[userId] = true;
      } else {
        delete ids[userId];
      }
    });
    this.draftIds = ids;
  }

  handleNameClick(event) {
    event.stopPropagation();
    const node = this.findNode(event.currentTarget.dataset.id, this.reportTree);
    if (!node) {
      return;
    }
    this.showNode(node);
  }

  showNode(node) {
    const ids = {};
    this.subtreeIds(node).forEach((id) => {
      ids[id] = true;
    });
    this.draftIds = ids;
    this.rosterFilter = "";
    this.rosterExpanded = false;
    this.pickerOpen = false;
    this.searchText = "";

    if (node.kind === "team") {
      this.selectedTeamKey = node.sourceKey;
      this.selectedPerson = null;
      this.selectedMemberNames = null;
      this.pickerLabel = node.name;
      this.loadData();
      return;
    }

    const names = this.flatten([node])
      .filter((item) => item.kind !== "team")
      .map((item) => item.name);

    if (this.isSystemAdmin && node.sourceKey && node.sourceKey !== this.selectedTeamKey) {
      this.selectedTeamKey = node.sourceKey;
    }

    this.pickerLabel = node.name;
    if (names.length <= 1) {
      this.selectedMemberNames = null;
      this.selectedPerson = names[0] || node.name;
      this.loadData();
      return;
    }
    this.selectedPerson = null;
    this.selectedMemberNames = names;
    this.loadData().then(() => this.renderSelectedMembers(names));
  }

  clearDraft() {
    this.draftIds = {};
    this.selectedPerson = null;
    this.selectedMemberNames = null;
    this.pickerLabel = null;
    const data = this.payloadByTab[this.payloadKey()];
    if (data) {
      this.renderScope(data);
    }
  }

  applyPicker() {
    if (this.isSystemAdmin && this.teams.length) {
      this.applyAdminPicker();
      return;
    }
    const selected = this.flatten(this.reportTree).filter((node) => this.draftIds[node.id]);
    if (!selected.length) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Select a team member",
          message: "Choose at least one person, then tap Apply.",
          variant: "warning"
        })
      );
      return;
    }
    const names = selected.map((node) => node.name);
    this.selectedPerson = null;
    this.rosterFilter = "";
    this.rosterExpanded = false;
    this.pickerOpen = false;
    this.searchText = "";
    if (names.length === 1) {
      this.selectedMemberNames = null;
      this.selectedPerson = names[0];
      this.pickerLabel = names[0];
      this.loadData();
      return;
    }
    this.selectedMemberNames = names;
    this.pickerLabel =
      names.length === this.flatten(this.reportTree).length
        ? "My team"
        : `${names.length} members selected`;
    this.loadData().then(() => this.renderSelectedMembers(names));
  }

  applyAdminPicker() {
    const selected = this.flatten(this.reportTree).filter((node) => this.draftIds[node.id]);
    const keys = [];
    selected.forEach((node) => {
      if (node.sourceKey && !keys.includes(node.sourceKey)) {
        keys.push(node.sourceKey);
      }
    });
    if (keys.length !== 1) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Select one team",
          message: "Choose one team, then tap Apply.",
          variant: "warning"
        })
      );
      return;
    }
    const key = keys[0];
    const teamNode = this.findNode(`team:${key}`, this.reportTree);
    const teamName = teamNode ? teamNode.name : key;
    const members = this.flatten(teamNode && teamNode.children ? teamNode.children : []).filter(
      (node) => node.kind !== "team"
    );
    const picked = members.filter((node) => this.draftIds[node.id]);
    const wholeTeam =
      !teamNode ||
      teamNode.children == null ||
      picked.length === 0 ||
      picked.length === members.length;

    this.selectedTeamKey = key;
    this.rosterFilter = "";
    this.rosterExpanded = false;
    this.pickerOpen = false;
    this.searchText = "";

    if (wholeTeam) {
      this.selectedPerson = null;
      this.selectedMemberNames = null;
      this.pickerLabel = teamName;
      this.loadData();
      return;
    }
    if (picked.length === 1) {
      this.selectedMemberNames = null;
      this.selectedPerson = picked[0].name;
      this.pickerLabel = picked[0].name;
      this.loadData();
      return;
    }
    const names = picked.map((node) => node.name);
    this.selectedPerson = null;
    this.selectedMemberNames = names;
    this.pickerLabel = `${names.length} members selected`;
    this.loadData().then(() => this.renderSelectedMembers(names));
  }

  renderSelectedMembers(names) {
    const data = this.payloadByTab[this.payloadKey()];
    if (!data) {
      return;
    }
    const wanted = {};
    names.forEach((name) => {
      wanted[name] = true;
    });
    const rows = (data.roster || []).filter((row) => wanted[row.name]);
    const sum = (field) => rows.reduce((total, row) => total + (Number(row[field]) || 0), 0);
    const byLabel = {};
    rows.forEach((row) => {
      (row.conversion || []).forEach((stage) => {
        byLabel[stage.label] = (byLabel[stage.label] || 0) + (Number(stage.value) || 0);
      });
    });
    this.targetPairs = [
      this.decorateTargetPair({
        key: "collection",
        label: "Revenue Target",
        target: sum("collectionTarget"),
        achieved: sum("collectionValue"),
        displayUnits: "Auto",
        isCurrency: true
      }),
      this.decorateTargetPair({
        key: "token",
        label: "Token",
        target: sum("tokenTarget"),
        achieved: sum("tokenAchieved"),
        displayUnits: "Integer",
        isCurrency: false
      })
    ];
    this.tiles = [
      this.decorateTile(
        this.withBand({
          key: "billedOutstanding",
          label: "Outstanding Payment",
          value: sum("outstanding"),
          displayUnits: "Auto",
          isCurrency: true
        })
      ),
      this.decorateTile(
        this.withBand({
          key: "tokenBookings",
          label: "Under Finalization",
          value: sum("underFinalization"),
          displayUnits: "Integer",
          isCurrency: false
        })
      )
    ];
    this.conversion = this.orderFunnel(
      Object.keys(byLabel).map((label) => ({ label, value: byLabel[label] }))
    );
    this.roster = rows.map((member) => this.decorateMember(member));
  }

  toPersonRow(node, depth, hasChildren, expanded) {
    const state = this.nodeState(node);
    return {
      id: node.id,
      teamKey: node.id,
      kind: "person",
      name: node.name,
      isNote: false,
      hasChildren,
      rowStyle: `padding-left: ${Math.min(depth, 4) * 0.7}rem`,
      chevronMark: expanded ? "▾" : "▸",
      chevronIcon: expanded ? "utility:chevrondown" : "utility:chevronright",
      expandLabel: `${expanded ? "Collapse" : "Expand"} ${node.name}`,
      showCheck: state === "all",
      showMinus: state === "some",
      ariaChecked: state === "all" ? "true" : state === "some" ? "mixed" : "false",
      boxClass: state === "none" ? "team-picker__box" : "team-picker__box team-picker__box_on"
    };
  }

  nodeState(node) {
    const ids = this.subtreeIds(node);
    const selected = ids.filter((id) => this.draftIds[id]).length;
    if (selected === 0) {
      return "none";
    }
    if (selected === ids.length) {
      return "all";
    }
    return "some";
  }

  subtreeIds(node) {
    const ids = [node.id];
    (node.children || []).forEach((child) => {
      this.subtreeIds(child).forEach((id) => ids.push(id));
    });
    return ids;
  }

  findNode(id, nodes) {
    for (const node of nodes || []) {
      if (node.id === id) {
        return node;
      }
      const found = this.findNode(id, node.children);
      if (found) {
        return found;
      }
    }
    return undefined;
  }

  flatten(nodes, acc = []) {
    (nodes || []).forEach((node) => {
      acc.push(node);
      this.flatten(node.children, acc);
    });
    return acc;
  }
}
