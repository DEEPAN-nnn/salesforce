public with sharing class MobileMyDashboardController {
  public static final String LEVEL_INDIVIDUAL = 'INDIVIDUAL';
  public static final String LEVEL_TEAM = 'TEAM';

  private class TileDef {
    String key;
    String label;
    String reportDeveloperName;
    String aggregate;
    String displayUnits;
    Boolean isCurrency;
    String pairAggregate;

    TileDef(
      String key,
      String label,
      String reportDeveloperName,
      String aggregate,
      String displayUnits,
      Boolean isCurrency
    ) {
      this(
        key,
        label,
        reportDeveloperName,
        aggregate,
        displayUnits,
        isCurrency,
        null
      );
    }

    TileDef(
      String key,
      String label,
      String reportDeveloperName,
      String aggregate,
      String displayUnits,
      Boolean isCurrency,
      String pairAggregate
    ) {
      this.key = key;
      this.label = label;
      this.reportDeveloperName = reportDeveloperName;
      this.aggregate = aggregate;
      this.displayUnits = displayUnits;
      this.isCurrency = isCurrency;
      this.pairAggregate = pairAggregate;
    }
  }

  private static List<TileDef> individualTiles() {
    return new List<TileDef>{
      new TileDef(
        'collectionTarget',
        'Collection Target',
        'My_Target_Report_UXk',
        's!Target_and_Incentives__c.CF_Collection_Target__c',
        'Auto',
        true
      ),
      new TileDef(
        'collectionAchieved',
        'My Collection Report',
        'My_Collection_Report_fq0',
        's!Payment__c.Payment_Amount__c',
        'Auto',
        true
      ),
      new TileDef(
        'tokenTarget',
        'Token Target',
        'My_Target_Report_gRz',
        's!Target_and_Incentives__c.Token_Target__c',
        'Integer',
        false
      ),
      new TileDef(
        'tokenAchieved',
        'Token Achieved',
        'My_Token_Achieved_AAl',
        AGG_ROW_COUNT,
        'Integer',
        false
      ),
      new TileDef(
        'billedOutstanding',
        'Billed & Outstanding',
        'Copy_of_Indiviual_Outstanding_Payment_eFe',
        's!Account_Transaction__c.Total_Brokerage_Amount__c',
        'Auto',
        true
      ),
      new TileDef(
        'tokenBookings',
        'Token & Bookings',
        'My_Under_Finalization_Prospect_uGG',
        's!Enquiry__c.Estimate_Revenue__c',
        'Auto',
        true
      )
    };
  }

  private static List<TileDef> teamTiles() {
    return new List<TileDef>{
      new TileDef(
        'collectionTarget',
        'Team\'s Collection Target',
        ROSTER_REPORT,
        AGG_COLLECTION_TARGET,
        'Auto',
        true
      ),
      new TileDef(
        'collectionAchieved',
        'Team\'s Collection Achieved',
        ROSTER_REPORT,
        AGG_COLLECTION_ACHIEVED,
        'Auto',
        true
      ),
      new TileDef(
        'tokenTarget',
        'Team\'s Token Target',
        ROSTER_REPORT,
        AGG_TOKEN_TARGET,
        'Integer',
        false
      ),
      new TileDef(
        'tokenAchieved',
        'Team\'s Token Achieved',
        ROSTER_REPORT,
        AGG_TOKEN_ACHIEVED,
        'Integer',
        false
      ),
      new TileDef(
        'billedOutstanding',
        'Team\'s Outstanding Payment',
        OUTSTANDING_REPORT,
        AGG_OUTSTANDING,
        'Auto',
        true,
        'u!Enquiry__c.Id'
      ),
      new TileDef(
        'tokenBookings',
        'Under Finalization',
        UNDER_FINALIZATION_REPORT,
        AGG_ROW_COUNT,
        'Integer',
        false,
        's!Enquiry__c.Brokerage_Pending__c'
      )
    };
  }

  private static List<TileDef> tilesFor(String level) {
    return level == LEVEL_TEAM ? teamTiles() : individualTiles();
  }

  private static final String CONVERSION_REPORT = 'My_Action_Wise_Conversion_Report_ZTM';
  private static final String TEAM_CONVERSION_REPORT = 'Monthwise_Action_Conversion_Employee_Zh8';
  private static final String CONVERSION_AGGREGATE = 'u!CUST_ID';

  private static final String ROSTER_REPORT = 'My_Teams_Target_Report_ZVQ';
  private static final String OUTSTANDING_REPORT = 'Outstanding_Tqu';
  private static final String UNDER_FINALIZATION_REPORT = 'Under_Fin_o2N';

  private static final String AGG_COLLECTION_TARGET = 's!Target_and_Incentives__c.CF_Collection_Target__c';
  private static final String AGG_TOKEN_ACHIEVED = 's!Target_and_Incentives__c.Token_Achived__c';
  private static final String AGG_TOKEN_TARGET = 's!Target_and_Incentives__c.Token_Target__c';
  private static final String AGG_COLLECTION_ACHIEVED = 's!Target_and_Incentives__c.Collection_Achived__c';
  private static final String AGG_OUTSTANDING = 's!Account_Transaction__c.Total_Remaining_Amount__c';
  private static final String AGG_ROW_COUNT = 'RowCount';

  private static final List<String> FUNNEL_ORDER = new List<String>{
    'Shown Interest',
    'Qualify Meet',
    'Inspection',
    'Site Shortlisted',
    'Token'
  };

  public class TeamDTO {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String name;
  }

  public class TeamMemberOption {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Boolean expandable;
    @AuraEnabled
    public String kind;
    @AuraEnabled
    public String sourceKey;
    @AuraEnabled
    public List<TeamMemberOption> children;
  }

  public class DashboardDTO {
    @AuraEnabled
    public String accessLevel;
    @AuraEnabled
    public List<TeamDTO> teams = new List<TeamDTO>();
    @AuraEnabled
    public String selectedTeamKey;
    @AuraEnabled
    public Integer memberCount;
    @AuraEnabled
    public Datetime asOf;
    @AuraEnabled
    public List<TileDTO> tiles = new List<TileDTO>();
    @AuraEnabled
    public List<FunnelRowDTO> conversion = new List<FunnelRowDTO>();
    @AuraEnabled
    public List<String> problems = new List<String>();
    @AuraEnabled
    public Id conversionReportId;
    @AuraEnabled
    public List<RosterRowDTO> roster = new List<RosterRowDTO>();
    @AuraEnabled
    public Boolean canViewTeam = false;
    @AuraEnabled
    public Boolean isSystemAdmin = false;
  }

  public class TileDTO {
    @AuraEnabled
    public String key;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Decimal value;
    @AuraEnabled
    public String displayUnits;
    @AuraEnabled
    public Boolean isCurrency;
    @AuraEnabled
    public Id reportId;
    @AuraEnabled
    public Decimal pairValue;
  }

  public class FunnelRowDTO {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Decimal value;
  }

  public class RosterRowDTO {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Decimal tokenAchieved;
    @AuraEnabled
    public Decimal tokenTarget;
    @AuraEnabled
    public Decimal collectionValue;
    @AuraEnabled
    public Decimal collectionTarget;
    @AuraEnabled
    public Decimal outstanding;
    @AuraEnabled
    public Decimal underFinalization;
    @AuraEnabled
    public List<FunnelRowDTO> conversion = new List<FunnelRowDTO>();
  }

  @AuraEnabled(cacheable=true)
  public static DashboardDTO getDashboard(
    String dateRange,
    String tab,
    String teamKey
  ) {
    DashboardDTO dto = new DashboardDTO();

    List<TeamDef> visible = visibleTeams();
    Boolean managesPeople = hasDirectReports();
    dto.canViewTeam = !visible.isEmpty() || managesPeople;
    dto.isSystemAdmin = isSystemAdmin();
    for (TeamDef def : visible) {
      TeamDTO option = new TeamDTO();
      option.key = def.key;
      option.name = def.name;
      dto.teams.add(option);
    }
    dto.accessLevel = (tab == LEVEL_TEAM && dto.canViewTeam)
      ? LEVEL_TEAM
      : LEVEL_INDIVIDUAL;
    dto.asOf = Datetime.now();

    Boolean isTeam = dto.accessLevel == LEVEL_TEAM;
    TeamMembers team = null;
    if (isTeam) {
      if (!visible.isEmpty()) {
        TeamDef selected = pickTeam(visible, teamKey);
        dto.selectedTeamKey = selected.key;
        team = resolveMembers(selected);
        for (String issue : team.unresolved) {
          dto.problems.add(selected.name + ': ' + issue);
        }
      } else {
        dto.selectedTeamKey = 'MY_REPORTS';
        team = membersUnderManager(UserInfo.getUserId());
        for (String issue : team.unresolved) {
          dto.problems.add(issue);
        }
      }
      dto.memberCount = team.memberIds.size();
    }

    Map<String, Report> reportsByName = reportsByDeveloperName();
    Map<String, List<FunnelRowDTO>> personFunnels = new Map<String, List<FunnelRowDTO>>();
    Map<String, Reports.ReportResults> runCache = new Map<String, Reports.ReportResults>();

    for (TileDef def : tilesFor(dto.accessLevel)) {
      Report rpt = reportsByName.get(def.reportDeveloperName);
      if (rpt == null) {
        dto.problems.add(
          def.label +
            ': report "' +
            def.reportDeveloperName +
            '" not found or not visible to you'
        );
        continue;
      }
      try {
        Reports.ReportResults results = cachedRun(
          runCache,
          def.reportDeveloperName,
          rpt.Id,
          dateRange,
          isTeam
        );
        TileDTO tile = new TileDTO();
        tile.key = def.key;
        tile.label = def.label;
        tile.displayUnits = def.displayUnits;
        tile.isCurrency = def.isCurrency;
        tile.reportId = rpt.Id;
        tile.value = grandTotal(results, def.aggregate);
        if (tile.value == null) {
          dto.problems.add(
            def.label +
              ': aggregate "' +
              def.aggregate +
              '" is not on that report'
          );
        }
        if (def.pairAggregate != null) {
          tile.pairValue = grandTotal(results, def.pairAggregate);
        }
        if (isTeam) {
          if (tile.value != null) {
            tile.value = sumForMembers(
              buildPersonTotals(results, def.aggregate),
              team.memberNames
            );
          }
          if (tile.pairValue != null) {
            tile.pairValue = sumForMembers(
              buildPersonTotals(results, def.pairAggregate),
              team.memberNames
            );
          }
        }
        dto.tiles.add(tile);
      } catch (Exception e) {
        dto.problems.add(def.label + ': ' + e.getMessage());
      }
    }

    String conversionName = isTeam ? TEAM_CONVERSION_REPORT : CONVERSION_REPORT;
    Report conversionReport = reportsByName.get(conversionName);

    if (conversionReport == null) {
      dto.problems.add('Action Wise Conversion: report not visible to you');
    } else {
      try {
        Reports.ReportResults conv = runReport(conversionReport.Id, dateRange);
        dto.conversionReportId = conversionReport.Id;
        if (isTeam) {
          personFunnels = buildPersonFunnels(conv, team.memberNames);
          dto.conversion = buildTeamFunnel(conv, team.memberNames);
        } else {
          dto.conversion = buildFunnel(conv);
        }
      } catch (Exception e) {
        dto.problems.add('Action Wise Conversion: ' + e.getMessage());
      }
    }

    if (isTeam) {
      Reports.ReportResults rosterRun = runCache.get(ROSTER_REPORT);
      if (rosterRun == null) {
        dto.problems.add('My Team: roster report not visible to you');
      } else {
        try {
          dto.roster = buildRoster(rosterRun, team.memberIds);
          Map<String, Decimal> targets = buildPersonTotals(
            rosterRun,
            AGG_COLLECTION_TARGET
          );
          Map<String, Decimal> owed = buildPersonTotals(
            runCache.get(OUTSTANDING_REPORT),
            AGG_OUTSTANDING
          );
          Map<String, Decimal> underFin = buildPersonTotals(
            runCache.get(UNDER_FINALIZATION_REPORT),
            AGG_ROW_COUNT
          );

          for (RosterRowDTO row : dto.roster) {
            if (personFunnels.containsKey(row.name)) {
              row.conversion = personFunnels.get(row.name);
            }
            row.collectionTarget = targets.get(row.name);
            row.outstanding = owed.get(row.name);
            row.underFinalization = underFin.get(row.name);
          }
        } catch (Exception e) {
          dto.problems.add('My Team: ' + e.getMessage());
        }
      }
    }

    return dto;
  }

  @AuraEnabled(cacheable=true)
  public static List<TeamMemberOption> getTeamPickerTree() {
    List<TeamMemberOption> teams = new List<TeamMemberOption>();
    for (TeamDef def : visibleTeams()) {
      TeamMemberOption team = new TeamMemberOption();
      team.id = 'team:' + def.key;
      team.name = def.name;
      team.kind = 'team';
      team.sourceKey = def.key;
      team.expandable = false;
      team.children = memberOptions(def);
      teams.add(team);
    }
    return teams;
  }

  @AuraEnabled(cacheable=true)
  public static List<TeamMemberOption> listTeamMembers(String teamKey) {
    for (TeamDef def : visibleTeams()) {
      if (def.key == teamKey) {
        return memberOptions(def);
      }
    }
    return new List<TeamMemberOption>();
  }

  private static List<TeamMemberOption> memberOptions(TeamDef selected) {
    List<TeamMemberOption> options = new List<TeamMemberOption>();
    if (selected == null) {
      return options;
    }
    Map<Id, List<User>> byManager = reportsByManager();
    Set<Id> stack = new Set<Id>();
    for (User member : usersForTeam(selected)) {
      options.add(personNode(member, selected.key, byManager, stack, 0));
    }
    options.sort(new MemberOptionComparator());
    return options;
  }

  private static List<User> usersForTeam(TeamDef selected) {
    List<User> matched = new List<User>();
    Set<Id> seen = new Set<Id>();
    Boolean sandbox = isSandbox();
    if (selected.mode == 'Team_Field') {
      for (User u : activeUsers()) {
        if (u.IsActive == true && u.Team__c == selected.fieldValue && seen.add(u.Id)) {
          matched.add(u);
        }
      }
    } else {
      for (String stored : selected.usernames) {
        for (User u : activeUsers()) {
          if (u.IsActive == true && usernameMatches(stored, u.Username, sandbox) && seen.add(u.Id)) {
            matched.add(u);
            break;
          }
        }
      }
    }
    User lead = findLeadUser(selected);
    if (lead != null) {
      List<User> reports = new List<User>();
      Set<Id> reportIds = new Set<Id>();
      for (User u : activeUsers()) {
        if (u.IsActive == true && u.ManagerId == lead.Id && reportIds.add(u.Id)) {
          reports.add(u);
        }
      }
      if (!reports.isEmpty()) {
        return reports;
      }
    }
    return matched;
  }

  private static User findLeadUser(TeamDef selected) {
    String leadName = leadHint(selected);
    if (String.isBlank(leadName)) {
      return null;
    }
    String wanted = leadName.toLowerCase();
    User found;
    for (User u : activeUsers()) {
      if (u.IsActive == true && u.Name != null && u.Name.toLowerCase() == wanted) {
        if (found != null) {
          return null;
        }
        found = u;
      }
    }
    return found;
  }

  private static String leadHint(TeamDef selected) {
    String label = selected.name == null ? '' : selected.name.trim();
    if (label.toLowerCase().endsWith(' team')) {
      label = label.substring(0, label.length() - 5).trim();
    }
    if (label.endsWith('\'s')) {
      label = label.substring(0, label.length() - 2).trim();
    }
    return label;
  }

  private static TeamMemberOption personNode(
    User member,
    String sourceKey,
    Map<Id, List<User>> byManager,
    Set<Id> stack,
    Integer depth
  ) {
    TeamMemberOption option = new TeamMemberOption();
    option.id = member.Id;
    option.name = member.Name;
    option.kind = 'person';
    option.sourceKey = sourceKey;
    option.expandable = false;
    option.children = new List<TeamMemberOption>();
    if (member.Id == null || depth >= 15 || stack.contains(member.Id)) {
      return option;
    }
    stack.add(member.Id);
    List<User> reports = byManager.get(member.Id);
    if (reports != null) {
      for (User report : reports) {
        option.children.add(personNode(report, sourceKey, byManager, stack, depth + 1));
      }
      option.children.sort(new MemberOptionComparator());
    }
    stack.remove(member.Id);
    return option;
  }

  private static Map<Id, List<User>> reportsByManager() {
    Map<Id, List<User>> byManager = new Map<Id, List<User>>();
    for (User member : activeUsers()) {
      if (member.IsActive != true || member.ManagerId == null) {
        continue;
      }
      if (!byManager.containsKey(member.ManagerId)) {
        byManager.put(member.ManagerId, new List<User>());
      }
      byManager.get(member.ManagerId).add(member);
    }
    return byManager;
  }

  @AuraEnabled(cacheable=true)
  public static List<TeamMemberOption> getDirectReports(String managerId) {
    List<TeamMemberOption> options = new List<TeamMemberOption>();
    if (String.isBlank(managerId)) {
      return options;
    }
    Id manager;
    try {
      manager = (Id) managerId;
    } catch (Exception e) {
      return options;
    }
    List<User> people = [
      SELECT Id, Name
      FROM User
      WHERE IsActive = TRUE AND ManagerId = :manager
      ORDER BY Name
    ];
    Map<Id, List<User>> byManager = reportsByManager();
    Set<Id> stack = new Set<Id>{ manager };
    for (User person : people) {
      options.add(personNode(person, null, byManager, stack, 0));
    }
    options.sort(new MemberOptionComparator());
    return options;
  }

  @TestVisible
  private static Set<Id> managerIdsAmong(Set<Id> userIds) {
    Set<Id> managers = new Set<Id>();
    if (userIds == null || userIds.isEmpty()) {
      return managers;
    }
    for (AggregateResult row : [
      SELECT ManagerId mid
      FROM User
      WHERE IsActive = TRUE AND ManagerId IN :userIds
      GROUP BY ManagerId
    ]) {
      managers.add((Id) row.get('mid'));
    }
    return managers;
  }

  private static Boolean isSystemAdmin() {
    User viewer = currentViewer();
    return viewer != null &&
      viewer.Profile != null &&
      viewer.Profile.Name == 'System Administrator';
  }

  @TestVisible
  private static Map<Id, List<User>> usersByManager() {
    Map<Id, List<User>> byManager = new Map<Id, List<User>>();
    for (User member : activeUsers()) {
      if (member.IsActive != true || member.ManagerId == null) {
        continue;
      }
      if (!byManager.containsKey(member.ManagerId)) {
        byManager.put(member.ManagerId, new List<User>());
      }
      byManager.get(member.ManagerId).add(member);
    }
    return byManager;
  }

  @TestVisible
  private static List<TeamMemberOption> buildReportOptions(
    Id managerId,
    Map<Id, List<User>> byManager,
    Set<Id> stack
  ) {
    List<TeamMemberOption> nodes = new List<TeamMemberOption>();
    if (managerId == null || stack.contains(managerId)) {
      return nodes;
    }
    stack.add(managerId);
    List<User> members = byManager.get(managerId);
    if (members != null) {
      for (User member : members) {
        TeamMemberOption node = new TeamMemberOption();
        node.id = member.Id;
        node.name = member.Name;
        node.children = buildReportOptions(member.Id, byManager, stack);
        nodes.add(node);
      }
    }
    stack.remove(managerId);
    nodes.sort(new MemberOptionComparator());
    return nodes;
  }

  @TestVisible
  private static List<TeamMemberOption> omitDirectMembers(
    List<TeamMemberOption> nodes,
    Set<Id> directIds
  ) {
    List<TeamMemberOption> kept = new List<TeamMemberOption>();
    for (TeamMemberOption node : nodes) {
      if (node == null || directIds.contains((Id) node.id)) {
        continue;
      }
      node.children = omitDirectMembers(node.children, directIds);
      kept.add(node);
    }
    return kept;
  }

  @AuraEnabled(cacheable=true)
  public static List<TeamMemberOption> getMyReportTree() {
    Id rootId = UserInfo.getUserId();
    Map<Id, List<User>> byManager = new Map<Id, List<User>>();
    Set<Id> managers = new Set<Id>{ rootId };
    Set<Id> seen = new Set<Id>();
    Integer guard = 0;

    while (!managers.isEmpty() && guard < 15) {
      guard++;
      Set<Id> nextManagers = new Set<Id>();
      for (User member : [
        SELECT Id, Name, ManagerId
        FROM User
        WHERE IsActive = TRUE AND ManagerId IN :managers
        ORDER BY Name
      ]) {
        if (seen.contains(member.Id)) {
          continue;
        }
        seen.add(member.Id);
        if (!byManager.containsKey(member.ManagerId)) {
          byManager.put(member.ManagerId, new List<User>());
        }
        byManager.get(member.ManagerId).add(member);
        nextManagers.add(member.Id);
      }
      managers = nextManagers;
    }
    return buildReportOptions(rootId, byManager);
  }

  private static Boolean hasDirectReports() {
    return ![
        SELECT Id
        FROM User
        WHERE IsActive = TRUE AND ManagerId = :UserInfo.getUserId()
        LIMIT 1
      ]
      .isEmpty();
  }

  private static TeamMembers membersUnderManager(Id managerId) {
    TeamMembers result = new TeamMembers();
    Set<Id> frontier = new Set<Id>{ managerId };
    Set<Id> seen = new Set<Id>();
    Integer guard = 0;
    while (!frontier.isEmpty() && guard < 15) {
      guard++;
      Set<Id> nextManagers = new Set<Id>();
      for (User member : [
        SELECT Id, Name
        FROM User
        WHERE IsActive = TRUE AND ManagerId IN :frontier
      ]) {
        if (seen.contains(member.Id)) {
          continue;
        }
        seen.add(member.Id);
        result.memberIds.add(member.Id);
        result.memberNames.add(member.Name);
        nextManagers.add(member.Id);
      }
      frontier = nextManagers;
    }
    if (result.memberIds.isEmpty()) {
      result.unresolved.add('no active user reports to you');
    }
    return result;
  }

  private static List<TeamMemberOption> buildReportOptions(
    Id managerId,
    Map<Id, List<User>> byManager
  ) {
    List<TeamMemberOption> nodes = new List<TeamMemberOption>();
    List<User> members = byManager.get(managerId);
    if (members == null) {
      return nodes;
    }
    for (User member : members) {
      TeamMemberOption node = new TeamMemberOption();
      node.id = member.Id;
      node.name = member.Name;
      node.children = buildReportOptions(member.Id, byManager);
      nodes.add(node);
    }
    return nodes;
  }

  private class MemberOptionComparator implements Comparator<TeamMemberOption> {
    public Integer compare(TeamMemberOption a, TeamMemberOption b) {
      String left = a.name == null ? '' : a.name;
      String right = b.name == null ? '' : b.name;
      return left.compareTo(right);
    }
  }

  @TestVisible
  private class TeamDef {
    public String key;
    public String name;
    public Decimal sortOrder;
    public String mode;
    public String fieldValue;
    public List<String> usernames = new List<String>();
  }

  @TestVisible
  private class TeamMembers {
    public Set<Id> memberIds = new Set<Id>();
    public Set<String> memberNames = new Set<String>();
    public List<String> unresolved = new List<String>();
  }

  @TestVisible
  private static List<TeamDef> testTeams;
  @TestVisible
  private static List<User> testUsers;
  @TestVisible
  private static Boolean testAccessAll;

  private static List<User> cachedUsers;
  private static Boolean cachedIsSandbox;

  private static List<User> activeUsers() {
    if (testUsers != null) {
      return testUsers;
    }
    if (cachedUsers == null) {
      cachedUsers = [
        SELECT Id, Name, Username, Team__c, ManagerId, IsActive, Profile.Name
        FROM User
        WHERE IsActive = TRUE
      ];
    }
    return cachedUsers;
  }

  private static Boolean isSandbox() {
    if (cachedIsSandbox == null) {
      cachedIsSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }
    return cachedIsSandbox;
  }

  @TestVisible
  private static Boolean usernameMatches(
    String stored,
    String actual,
    Boolean sandbox
  ) {
    if (String.isBlank(stored) || String.isBlank(actual)) {
      return false;
    }
    String wanted = stored.trim().toLowerCase();
    String have = actual.toLowerCase();
    return have == wanted || (sandbox && have.startsWith(wanted + '.'));
  }

  @TestVisible
  private static List<TeamDef> visibleTeams() {
    if (testTeams != null) {
      return testAccessAll == false ? new List<TeamDef>() : testTeams;
    }
    List<TeamDef> all = loadTeams();
    if (all.isEmpty()) {
      return all;
    }

    Set<String> allowed = new Set<String>();
    Boolean everyTeam = false;
    Boolean ownTeams = false;
    for (Mobile_Dashboard_Team_Access__mdt row : [
      SELECT Team__r.DeveloperName, Access_Type__c, Access_Value__c
      FROM Mobile_Dashboard_Team_Access__mdt
    ]) {
      if (row.Access_Type__c == 'Own_Team') {
        ownTeams =
          ownTeams ||
          String.isBlank(row.Access_Value__c) ||
          viewerMatches('Profile', row.Access_Value__c);
        continue;
      }
      if (!viewerMatches(row.Access_Type__c, row.Access_Value__c)) {
        continue;
      }
      if (row.Team__c == null) {
        everyTeam = true;
      } else {
        allowed.add(row.Team__r.DeveloperName);
      }
    }
    User viewer = ownTeams ? currentViewer() : null;
    Boolean sandbox = ownTeams ? isSandbox() : false;
    List<TeamDef> visible = new List<TeamDef>();
    for (TeamDef def : all) {
      if (
        everyTeam ||
        allowed.contains(def.key) ||
        (ownTeams && viewerBelongsToTeam(def, viewer, sandbox))
      ) {
        visible.add(def);
      }
    }
    return visible;
  }

  private static User currentViewer() {
    Id me = UserInfo.getUserId();
    for (User u : activeUsers()) {
      if (u.Id == me) {
        return u;
      }
    }
    return null;
  }

  @TestVisible
  private static Boolean viewerBelongsToTeam(
    TeamDef def,
    User viewer,
    Boolean sandbox
  ) {
    if (viewer == null) {
      return false;
    }
    if (def.mode == 'Team_Field') {
      return !String.isBlank(viewer.Team__c) &&
        viewer.Team__c == def.fieldValue;
    }
    for (String stored : def.usernames) {
      if (usernameMatches(stored, viewer.Username, sandbox)) {
        return true;
      }
    }
    return false;
  }

  private static Boolean viewerMatches(String accessType, String accessValue) {
    if (accessType == 'Everyone') {
      return true;
    }
    Id me = UserInfo.getUserId();
    if (accessType == 'Profile') {
      User viewer = currentViewer();
      return viewer != null &&
        viewer.Profile != null &&
        viewer.Profile.Name == accessValue;
    }
    if (accessType == 'User') {
      return usernameMatches(accessValue, UserInfo.getUserName(), isSandbox());
    }
    if (accessType == 'Permission_Set') {
      return ![
          SELECT Id
          FROM PermissionSetAssignment
          WHERE AssigneeId = :me AND PermissionSet.Name = :accessValue
          LIMIT 1
        ]
        .isEmpty();
    }
    return false;
  }

  private static List<TeamDef> loadTeams() {
    Map<String, List<String>> usernamesByTeam = new Map<String, List<String>>();
    for (Mobile_Dashboard_Team_Member__mdt m : [
      SELECT Team__r.DeveloperName, Member_Username__c
      FROM Mobile_Dashboard_Team_Member__mdt
      WHERE Is_Active__c = TRUE
    ]) {
      String key = m.Team__r.DeveloperName;
      if (!usernamesByTeam.containsKey(key)) {
        usernamesByTeam.put(key, new List<String>());
      }
      usernamesByTeam.get(key).add(m.Member_Username__c);
    }

    List<TeamDef> defs = new List<TeamDef>();
    for (
      Mobile_Dashboard_Team__mdt t : Mobile_Dashboard_Team__mdt.getAll()
        .values()
    ) {
      if (t.Is_Active__c != true) {
        continue;
      }
      TeamDef def = new TeamDef();
      def.key = t.DeveloperName;
      def.name = t.Display_Name__c;
      def.sortOrder = t.Sort_Order__c == null ? 9999 : t.Sort_Order__c;
      def.mode = t.Membership_Mode__c;
      def.fieldValue = t.Team_Field_Value__c;
      if (usernamesByTeam.containsKey(def.key)) {
        def.usernames = usernamesByTeam.get(def.key);
      }
      defs.add(def);
    }
    defs.sort(new TeamComparator());
    return defs;
  }

  @TestVisible
  private class TeamComparator implements Comparator<TeamDef> {
    public Integer compare(TeamDef a, TeamDef b) {
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder < b.sortOrder ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    }
  }

  @TestVisible
  private static TeamDef pickTeam(List<TeamDef> visible, String teamKey) {
    for (TeamDef def : visible) {
      if (def.key == teamKey) {
        return def;
      }
    }
    return visible[0];
  }

  @TestVisible
  private static TeamMembers resolveMembers(TeamDef def) {
    TeamMembers result = new TeamMembers();
    List<User> users = activeUsers();

    if (def.mode == 'Team_Field') {
      for (User u : users) {
        if (u.Team__c == def.fieldValue) {
          result.memberIds.add(u.Id);
          result.memberNames.add(u.Name);
        }
      }
      if (result.memberIds.isEmpty()) {
        result.unresolved.add(
          'no active user has Team = "' + def.fieldValue + '"'
        );
      }
      return result;
    }

    Boolean sandbox = isSandbox();
    for (String stored : def.usernames) {
      Boolean found = false;
      for (User u : users) {
        if (usernameMatches(stored, u.Username, sandbox)) {
          result.memberIds.add(u.Id);
          result.memberNames.add(u.Name);
          found = true;
          break;
        }
      }
      if (!found) {
        result.unresolved.add('member "' + stored + '" not found or inactive');
      }
    }
    return result;
  }

  @TestVisible
  private static Decimal sumForMembers(
    Map<String, Decimal> byPerson,
    Set<String> memberNames
  ) {
    Decimal total = 0;
    for (String name : memberNames) {
      if (byPerson.containsKey(name)) {
        total += byPerson.get(name);
      }
    }
    return total;
  }

  private static Map<String, Report> reportsByDeveloperName() {
    Set<String> names = new Set<String>{
      CONVERSION_REPORT,
      TEAM_CONVERSION_REPORT,
      ROSTER_REPORT
    };
    for (TileDef def : individualTiles()) {
      names.add(def.reportDeveloperName);
    }
    for (TileDef def : teamTiles()) {
      names.add(def.reportDeveloperName);
    }

    Map<String, Report> byName = new Map<String, Report>();
    for (Report r : [
      SELECT Id, DeveloperName
      FROM Report
      WHERE DeveloperName IN :names
    ]) {
      byName.put(r.DeveloperName, r);
    }
    return byName;
  }

  private static Reports.ReportResults runReport(
    Id reportId,
    String dateRange
  ) {
    return runReport(reportId, dateRange, false);
  }

  @TestVisible
  private static Reports.ReportResults runReport(
    Id reportId,
    String dateRange,
    Boolean widenScope
  ) {
    if (String.isBlank(dateRange) && widenScope != true) {
      return Reports.ReportManager.runReport(reportId, false);
    }
    Reports.ReportDescribeResult describe = Reports.ReportManager.describeReport(
      reportId
    );
    Reports.ReportMetadata md = describe.getReportMetadata();

    if (!String.isBlank(dateRange)) {
      try {
        Reports.StandardDateFilter dateFilter = md.getStandardDateFilter();
        if (dateFilter != null) {
          dateFilter.setDurationValue(dateRange);
          md.setStandardDateFilter(dateFilter);
        }
      } catch (Exception e) {
        // The report keeps its saved date filter.
      }
    }
    if (widenScope == true) {
      md.setScope('organization');
    }
    return Reports.ReportManager.runReport(reportId, md, false);
  }

  @TestVisible
  private static Decimal grandTotal(
    Reports.ReportResults results,
    String aggregateName
  ) {
    List<String> aggregates = results.getReportMetadata().getAggregates();
    Integer index = aggregates == null ? -1 : aggregates.indexOf(aggregateName);
    if (index < 0) {
      return null;
    }

    Reports.ReportFact fact = results.getFactMap().get('T!T');
    if (fact == null || fact.getAggregates().size() <= index) {
      return null;
    }

    Object raw = fact.getAggregates()[index].getValue();
    if (raw == null) {
      return null;
    }
    return Decimal.valueOf(String.valueOf(raw));
  }

  @TestVisible
  private static List<FunnelRowDTO> buildFunnel(Reports.ReportResults results) {
    Map<String, Decimal> byLabel = new Map<String, Decimal>();

    List<String> aggregates = results.getReportMetadata().getAggregates();
    Integer index = aggregates == null
      ? -1
      : aggregates.indexOf(CONVERSION_AGGREGATE);
    if (index < 0) {
      return new List<FunnelRowDTO>();
    }

    Reports.Dimension down = results.getGroupingsDown();
    if (down != null && down.getGroupings() != null) {
      for (Reports.GroupingValue gv : down.getGroupings()) {
        Reports.ReportFact fact = results.getFactMap().get(gv.getKey() + '!T');
        if (fact == null || fact.getAggregates().size() <= index) {
          continue;
        }
        Object raw = fact.getAggregates()[index].getValue();
        if (raw == null) {
          continue;
        }
        byLabel.put(gv.getLabel(), Decimal.valueOf(String.valueOf(raw)));
      }
    }

    List<FunnelRowDTO> rows = new List<FunnelRowDTO>();
    for (String stage : FUNNEL_ORDER) {
      if (!byLabel.containsKey(stage)) {
        continue;
      }
      FunnelRowDTO row = new FunnelRowDTO();
      row.label = stage;
      row.value = byLabel.get(stage);
      rows.add(row);
    }
    return rows;
  }

  private static Reports.ReportResults cachedRun(
    Map<String, Reports.ReportResults> cache,
    String developerName,
    Id reportId,
    String dateRange,
    Boolean widenScope
  ) {
    if (!cache.containsKey(developerName)) {
      cache.put(developerName, runReport(reportId, dateRange, widenScope));
    }
    return cache.get(developerName);
  }

  @TestVisible
  private static Map<String, Decimal> buildPersonTotals(
    Reports.ReportResults results,
    String aggregateName
  ) {
    Map<String, Decimal> byPerson = new Map<String, Decimal>();
    if (results == null) {
      return byPerson;
    }

    List<String> aggregates = results.getReportMetadata().getAggregates();
    Integer index = aggregates == null ? -1 : aggregates.indexOf(aggregateName);
    if (index < 0) {
      return byPerson;
    }

    Reports.Dimension down = results.getGroupingsDown();
    if (down == null || down.getGroupings() == null) {
      return byPerson;
    }

    for (Reports.GroupingValue person : down.getGroupings()) {
      Reports.ReportFact fact = results.getFactMap()
        .get(person.getKey() + '!T');
      if (fact == null || fact.getAggregates().size() <= index) {
        continue;
      }
      Object raw = fact.getAggregates()[index].getValue();
      if (raw != null) {
        byPerson.put(person.getLabel(), Decimal.valueOf(String.valueOf(raw)));
      }
    }
    return byPerson;
  }

  @TestVisible
  private static List<FunnelRowDTO> buildTeamFunnel(
    Reports.ReportResults results,
    Set<String> onlyNames
  ) {
    Map<String, Decimal> totals = new Map<String, Decimal>();
    for (
      List<FunnelRowDTO> rows : buildPersonFunnels(results, onlyNames).values()
    ) {
      for (FunnelRowDTO row : rows) {
        Decimal running = totals.containsKey(row.label)
          ? totals.get(row.label)
          : 0;
        totals.put(row.label, running + row.value);
      }
    }
    return orderedFunnel(totals);
  }

  @TestVisible
  private static Map<String, List<FunnelRowDTO>> buildPersonFunnels(
    Reports.ReportResults results,
    Set<String> onlyNames
  ) {
    Map<String, List<FunnelRowDTO>> byPerson = new Map<String, List<FunnelRowDTO>>();

    List<String> aggregates = results.getReportMetadata().getAggregates();
    Integer index = aggregates == null
      ? -1
      : aggregates.indexOf(CONVERSION_AGGREGATE);
    if (index < 0) {
      return byPerson;
    }

    Reports.Dimension down = results.getGroupingsDown();
    if (down == null || down.getGroupings() == null) {
      return byPerson;
    }

    for (Reports.GroupingValue person : down.getGroupings()) {
      if (onlyNames != null && !onlyNames.contains(person.getLabel())) {
        continue;
      }
      Map<String, Decimal> totals = new Map<String, Decimal>();
      collectStages(results, person, index, totals);
      if (!totals.isEmpty()) {
        byPerson.put(person.getLabel(), orderedFunnel(totals));
      }
    }
    return byPerson;
  }

  private static void collectStages(
    Reports.ReportResults results,
    Reports.GroupingValue node,
    Integer index,
    Map<String, Decimal> totals
  ) {
    List<Reports.GroupingValue> children = node.getGroupings();
    if (children == null || children.isEmpty()) {
      Reports.ReportFact fact = results.getFactMap().get(node.getKey() + '!T');
      if (fact == null || fact.getAggregates().size() <= index) {
        return;
      }
      Object raw = fact.getAggregates()[index].getValue();
      if (raw == null) {
        return;
      }
      String stage = node.getLabel();
      Decimal running = totals.containsKey(stage) ? totals.get(stage) : 0;
      totals.put(stage, running + Decimal.valueOf(String.valueOf(raw)));
      return;
    }
    for (Reports.GroupingValue child : children) {
      collectStages(results, child, index, totals);
    }
  }

  @TestVisible
  private static List<FunnelRowDTO> orderedFunnel(Map<String, Decimal> totals) {
    List<FunnelRowDTO> rows = new List<FunnelRowDTO>();
    for (String stage : FUNNEL_ORDER) {
      if (!totals.containsKey(stage)) {
        continue;
      }
      FunnelRowDTO row = new FunnelRowDTO();
      row.label = stage;
      row.value = totals.get(stage);
      rows.add(row);
    }
    return rows;
  }

  @TestVisible
  private static List<RosterRowDTO> buildRoster(
    Reports.ReportResults results,
    Set<Id> memberIds
  ) {
    List<RosterRowDTO> rows = new List<RosterRowDTO>();

    List<String> aggregates = results.getReportMetadata().getAggregates();
    if (aggregates == null) {
      return rows;
    }
    Integer tokenAchievedIdx = aggregates.indexOf(AGG_TOKEN_ACHIEVED);
    Integer tokenTargetIdx = aggregates.indexOf(AGG_TOKEN_TARGET);
    Integer collectionIdx = aggregates.indexOf(AGG_COLLECTION_ACHIEVED);

    Reports.Dimension down = results.getGroupingsDown();
    if (down == null || down.getGroupings() == null) {
      return rows;
    }

    for (Reports.GroupingValue gv : down.getGroupings()) {
      Reports.ReportFact fact = results.getFactMap().get(gv.getKey() + '!T');
      if (fact == null) {
        continue;
      }

      if (memberIds != null && !memberIds.contains(asId(gv.getValue()))) {
        continue;
      }

      RosterRowDTO row = new RosterRowDTO();
      row.id = String.valueOf(gv.getValue());
      row.name = gv.getLabel();
      row.tokenAchieved = aggregateAt(fact, tokenAchievedIdx);
      row.tokenTarget = aggregateAt(fact, tokenTargetIdx);
      row.collectionValue = aggregateAt(fact, collectionIdx);

      Boolean allEmpty =
        zeroIfNull(row.tokenAchieved) == 0 &&
        zeroIfNull(row.tokenTarget) == 0 &&
        zeroIfNull(row.collectionValue) == 0;
      if (allEmpty) {
        continue;
      }
      rows.add(row);
    }

    rows.sort(new RosterComparator());
    return rows;
  }

  private static Decimal aggregateAt(Reports.ReportFact fact, Integer index) {
    if (index == null || index < 0 || fact.getAggregates().size() <= index) {
      return null;
    }
    Object raw = fact.getAggregates()[index].getValue();
    return raw == null ? null : Decimal.valueOf(String.valueOf(raw));
  }

  @TestVisible
  private static Decimal zeroIfNull(Decimal value) {
    return value == null ? 0 : value;
  }

  @TestVisible
  private static Id asId(Object groupingValue) {
    try {
      return groupingValue == null
        ? null
        : Id.valueOf(String.valueOf(groupingValue));
    } catch (Exception e) {
      return null;
    }
  }

  @TestVisible
  private class RosterComparator implements Comparator<RosterRowDTO> {
    public Integer compare(RosterRowDTO a, RosterRowDTO b) {
      Decimal left = a.tokenAchieved == null ? 0 : a.tokenAchieved;
      Decimal right = b.tokenAchieved == null ? 0 : b.tokenAchieved;
      if (left > right) {
        return -1;
      }
      if (left < right) {
        return 1;
      }
      String an = a.name == null ? '' : a.name;
      String bn = b.name == null ? '' : b.name;
      return an.compareTo(bn);
    }
  }
}
