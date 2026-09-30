import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import ENQUIRY_OBJECT from "@salesforce/schema/Enquiry__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFunnelList from "@salesforce/apex/EnquiryFunnelListController.getFunnelList";

/**
 * Sales Funnel list view for the phone.
 *
 * Smart container: owns the design tokens, the fetching, every display string
 * the card renders, and all navigation. mobileLeadCard holds no state.
 */

const PAGE_SIZE = 20;
const SEARCH_DEBOUNCE_MS = 300;
const MIN_SEARCH_LENGTH = 2;

// Existing global actions in the org. Names are the standard publisher actions.
const LOG_A_CALL = "Global.LogACall";
const NEW_EVENT = "Global.NewEvent";

// Keys must match TAG_KEYS in EnquiryFunnelListController.
const TAGS = [
  { key: "all", label: "All" },
  { key: "new24", label: "New Assigned (24h)" },
  { key: "qualifyMeet", label: "At Qualify Meet" },
  { key: "inspection", label: "At Inspection" },
  { key: "siteShortlisted", label: "At Site Shortlisted" },
  { key: "finalisation", label: "Under Finalisation" }
];

// Business sequence, not a sort.
const STAGES = ["Pre Enquiry", "Enquiry", "Lead", "Prospect"];

const SORTS = [
  { key: "dueDate", label: "Due date" },
  { key: "assigned", label: "Newest assigned" },
  { key: "lastModified", label: "Last modified" },
  { key: "budget", label: "Budget" },
  { key: "quiet", label: "Days since activity" }
];

const ANY = "any";

// Property_Sourcing_Assistance__c is a checkbox, so this is the whole set.
const ASSISTANCE_OPTIONS = [
  { label: "Any", value: ANY },
  { label: "With assistance", value: "yes" },
  { label: "Without assistance", value: "no" }
];

export default class MobileSalesFunnelList extends NavigationMixin(
  LightningElement
) {
  @track rows = [];
  @track problems = [];
  @track teamMembers = [];

  scope = "mine";
  triage = "all";
  stage = null;
  sortBy = "dueDate";
  searchTerm = "";
  ownerFilter = "";

  // Secondary filters; "" means no filter.
  channel = "";
  wantTo = "";
  lookingFor = "";
  assistance = "";
  filterOptions = {};

  pageNumber = 1;
  hasMore = false;
  isLoading = true;
  showSortOptions = false;
  showFilters = false;

  totalInScope = 0;
  matchingCount = 0;
  triageCounts = {};
  stageCounts = {};
  resolvedScope = "mine";

  searchTimer;

  connectedCallback() {
    this.load();
  }

  disconnectedCallback() {
    window.clearTimeout(this.searchTimer);
  }

  // ------------------------------------------------------------- fetching

  load(append = false) {
    this.isLoading = true;
    getFunnelList({
      scope: this.scope,
      triage: this.triage === "all" ? null : this.triage,
      stage: this.stage,
      searchTerm: this.searchTerm,
      sortBy: this.sortBy,
      pageSize: PAGE_SIZE,
      pageNumber: this.pageNumber,
      ownerId: this.ownerFilter || null,
      channel: this.channel || null,
      wantTo: this.wantTo || null,
      lookingFor: this.lookingFor || null,
      assistance: this.assistance || null
    })
      .then((result) => {
        // The card shows an owner only when the list mixes people. In My
        // Enquiries every row is yours, so the line would be noise.
        const showOwner = result.resolvedScope === "team";
        const rows = (result.rows || []).map((r) => ({
          ...r,
          ownerNameForScope: showOwner ? r.ownerName : undefined
        }));
        this.teamMembers = result.teamMembers || [];
        this.filterOptions = result.filterOptions || {};
        this.rows = append ? [...this.rows, ...rows] : rows;
        this.triageCounts = result.triageCounts || {};
        this.stageCounts = result.stageCounts || {};
        this.totalInScope = result.totalInScope;
        this.matchingCount = result.matchingCount;
        this.hasMore = result.hasMore;
        this.resolvedScope = result.resolvedScope;
        this.problems = result.problems || [];
        // A resolved scope narrower than the one requested is a real state,
        // not a silent fallback - Apex reports it in problems.
        this.scope = result.resolvedScope;
        this.isLoading = false;
      })
      .catch((error) => {
        // Never a fabricated empty list - say what failed.
        this.problems = [
          error?.body?.message || "Could not load the funnel. Try refreshing."
        ];
        if (!append) {
          this.rows = [];
        }
        this.hasMore = false;
        this.isLoading = false;
      });
  }

  reload() {
    this.pageNumber = 1;
    this.load(false);
  }

  // -------------------------------------------------------------- getters

  get countLabel() {
    if (this.isLoading && !this.rows.length) {
      return "Loading...";
    }
    if (this.hasSearch) {
      return `${this.matchingCount} ${
        this.matchingCount === 1 ? "result" : "results"
      } for "${this.searchTerm}"`;
    }
    if (this.matchingCount === this.totalInScope) {
      return `${this.totalInScope} records`;
    }
    return `${this.matchingCount} of ${this.totalInScope} records`;
  }

  get triageChips() {
    return TAGS.map((chip) => {
      const count = this.triageCounts[chip.key];
      return {
        key: chip.key,
        label: count === undefined ? chip.label : `${chip.label} ${count}`,
        cssClass: chip.key === this.triage ? "chip chip--on" : "chip"
      };
    });
  }

  get stageChips() {
    return STAGES.map((name) => {
      const count = this.stageCounts[name];
      return {
        key: name,
        label: count === undefined ? name : `${name} ${count}`,
        cssClass: name === this.stage ? "chip chip--on" : "chip"
      };
    });
  }

  /** Only worth showing once the list actually mixes people. */
  get showOwnerPicker() {
    return this.scope === "team" && this.teamMembers.length > 1;
  }

  /** Combobox needs a value matching an option; "" means Everyone. */
  get ownerPickerValue() {
    return this.ownerFilter || "all";
  }

  /**
   * The count rides in the label because lightning-combobox renders one line
   * per option - and "who is carrying what" is the question the picker exists
   * to answer, so it should not need a second tap to find out.
   */
  get ownerOptions() {
    const total = this.teamMembers.reduce((sum, m) => sum + m.count, 0);
    return [
      { label: `Everyone (${total})`, value: "all" },
      ...this.teamMembers.map((m) => ({
        label: `${m.name} (${m.count})`,
        value: m.value
      }))
    ];
  }

  // Picklist options come from the org's describe, via Apex, so a value added
  // in Setup appears without a deploy.
  withAny(list) {
    return [{ label: "Any", value: ANY }, ...(list || [])];
  }

  get channelOptions() {
    return this.withAny(this.filterOptions.channel);
  }

  get wantToOptions() {
    return this.withAny(this.filterOptions.wantTo);
  }

  get lookingForOptions() {
    return this.withAny(this.filterOptions.lookingFor);
  }

  get assistanceOptions() {
    return ASSISTANCE_OPTIONS;
  }

  get channelValue() {
    return this.channel || ANY;
  }

  get wantToValue() {
    return this.wantTo || ANY;
  }

  get lookingForValue() {
    return this.lookingFor || ANY;
  }

  get assistanceValue() {
    return this.assistance || ANY;
  }

  get activeFilterCount() {
    return [this.channel, this.wantTo, this.lookingFor, this.assistance].filter(
      Boolean
    ).length;
  }

  /** The count on the button is the only trace of a filter once it closes. */
  get filterToggleLabel() {
    if (this.showFilters) {
      return "Done";
    }
    return this.activeFilterCount
      ? `Filters (${this.activeFilterCount})`
      : "Filters";
  }

  get sortOptions() {
    return SORTS.map((opt) => ({
      ...opt,
      cssClass: opt.key === this.sortBy ? "chip chip--on" : "chip"
    }));
  }

  get sortLabel() {
    const match = SORTS.find((s) => s.key === this.sortBy);
    return `Sorted by ${match ? match.label.toLowerCase() : "due date"}`;
  }

  get sortToggleLabel() {
    return this.showSortOptions ? "Done" : "Sort";
  }

  get mineClass() {
    return this.scope === "mine" ? "scope__btn scope__btn--on" : "scope__btn";
  }

  get teamClass() {
    return this.scope === "team" ? "scope__btn scope__btn--on" : "scope__btn";
  }

  get hasSearch() {
    return this.searchTerm.length >= MIN_SEARCH_LENGTH;
  }

  get hasProblems() {
    return this.problems.length > 0;
  }

  get isEmpty() {
    return !this.isLoading && this.rows.length === 0;
  }

  get emptyTitle() {
    return this.hasSearch ? "Nothing matches" : "No records here";
  }

  get emptyHint() {
    if (this.hasSearch) {
      return `No record in this filter matches "${this.searchTerm}". Clear the search, or widen the filter.`;
    }
    if (this.triage !== "all" || this.stage || this.activeFilterCount) {
      return "Nothing matches these filters right now. Tap All, or clear the filters.";
    }
    return "You have no open records in this scope.";
  }

  get loadMoreLabel() {
    const left = this.matchingCount - this.rows.length;
    return left > PAGE_SIZE ? `Load ${PAGE_SIZE} more` : `Load ${left} more`;
  }

  // ------------------------------------------------------------- handlers

  handleSearchInput(event) {
    const value = event.target.value;
    window.clearTimeout(this.searchTimer);
    // One query per pause, not one per keystroke.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.searchTimer = window.setTimeout(() => {
      this.searchTerm = value;
      this.reload();
    }, SEARCH_DEBOUNCE_MS);
  }

  handleClearSearch() {
    window.clearTimeout(this.searchTimer);
    this.searchTerm = "";
    this.reload();
  }

  handleScope(event) {
    this.scope = event.currentTarget.dataset.scope;
    // Leaving team scope must drop the person filter, or My Enquiries would
    // silently stay narrowed to a colleague.
    this.ownerFilter = "";
    this.reload();
  }

  handleOwnerChange(event) {
    this.ownerFilter = event.detail.value === "all" ? "" : event.detail.value;
    this.reload();
  }

  handleTriage(event) {
    const key = event.currentTarget.dataset.key;
    // Tapping the active chip clears it.
    this.triage = this.triage === key ? "all" : key;
    this.reload();
  }

  handleStage(event) {
    const key = event.currentTarget.dataset.key;
    this.stage = this.stage === key ? null : key;
    this.reload();
  }

  handleToggleFilters() {
    this.showFilters = !this.showFilters;
    this.showSortOptions = false;
  }

  handleFilterChange(event) {
    const field = event.target.dataset.filter;
    const value = event.detail.value;
    this[field] = value === ANY ? "" : value;
    this.reload();
  }

  handleClearFilters() {
    this.channel = "";
    this.wantTo = "";
    this.lookingFor = "";
    this.assistance = "";
    this.reload();
  }

  handleToggleSort() {
    this.showSortOptions = !this.showSortOptions;
    this.showFilters = false;
  }

  handleSort(event) {
    this.sortBy = event.currentTarget.dataset.key;
    this.showSortOptions = false;
    this.reload();
  }

  handleLoadMore() {
    this.pageNumber += 1;
    this.load(true);
  }

  /** Shown only to users the platform says can create an Enquiry__c. */
  canCreate = false;

  @wire(getObjectInfo, { objectApiName: ENQUIRY_OBJECT })
  wiredObjectInfo({ data }) {
    this.canCreate = !!data?.createable;
  }

  /**
   * Opens the platform's own New flow rather than a custom form, so the user
   * gets exactly what the standard button gives them: the record types they
   * are assigned, the page layout for that type, and field-level security.
   *
   * useRecordTypeCheck is required - without it NavigationMixin silently skips
   * the record-type picker and creates against the default type.
   */
  handleNew() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: "Enquiry__c",
        actionName: "new"
      },
      state: {
        useRecordTypeCheck: 1
      }
    });
  }

  handleRefresh() {
    this.reload();
  }

  // Only the container navigates.
  handleOpenRecord(event) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: event.detail.recordId,
        objectApiName: "Enquiry__c",
        actionName: "view"
      }
    });
  }

  handleWhatsApp(event) {
    const phone = event.detail.phone;
    window.open(`https://wa.me/${phone.replace(/[^0-9]/g, "")}`, "_blank");
  }

  handleLogCall(event) {
    this.openGlobalAction(LOG_A_CALL, event.detail.recordId);
  }

  handleNewEvent(event) {
    this.openGlobalAction(NEW_EVENT, event.detail.recordId);
  }

  /**
   * Same navigation as customHighlightsPanelMobile.invokeQuickAction:
   * Global.LogACall and Global.NewEvent, with this enquiry as recordId.
   */
  openGlobalAction(apiName, recordId) {
    if (!recordId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Record Id is missing.",
          variant: "error"
        })
      );
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__quickAction",
      attributes: { apiName },
      state: { recordId }
    });
  }

  handleNoPhone() {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "No phone on file",
        message:
          "Add a contact number to this enquiry before calling or messaging.",
        variant: "warning"
      })
    );
  }
}
