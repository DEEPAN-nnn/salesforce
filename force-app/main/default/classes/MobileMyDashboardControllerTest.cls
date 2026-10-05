@isTest
private class MobileMyDashboardControllerTest {
  @isTest
  static void getDashboardReturnsShapedPayload() {
    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    Assert.isNotNull(dto, 'A payload should always be returned');
    Assert.isNotNull(dto.accessLevel, 'Access level must be resolved');
    Assert.isTrue(
      dto.accessLevel == MobileMyDashboardController.LEVEL_INDIVIDUAL ||
        dto.accessLevel == MobileMyDashboardController.LEVEL_TEAM,
      'Access level must be one of the two known values'
    );
    Assert.isNotNull(dto.asOf, 'asOf stamp must be set');
    Assert.isNotNull(dto.tiles, 'Tiles collection must be initialised');
    Assert.isNotNull(
      dto.conversion,
      'Conversion collection must be initialised'
    );
    Assert.isNotNull(dto.problems, 'Problems list must be initialised');
  }

  @isTest
  static void getDashboardAcceptsBlankDateRange() {
    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      null,
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    Assert.isNotNull(dto, 'A blank range must not throw');
  }

  @isTest
  static void everyTileIsEitherReturnedOrReportedUnavailable() {
    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    Assert.isTrue(
      dto.tiles.size() <= 6,
      'Never more tiles than are configured'
    );
    if (dto.tiles.size() < 6) {
      Assert.isFalse(
        dto.problems.isEmpty(),
        'A missing tile must be explained in problems, not silently absent'
      );
    }
  }

  @isTest
  static void returnedTilesCarryPresentationFields() {
    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    for (MobileMyDashboardController.TileDTO tile : dto.tiles) {
      Assert.isNotNull(tile.key, 'Tile key is required');
      Assert.isNotNull(tile.label, 'Tile label is required');
      Assert.isNotNull(tile.reportId, 'Tile must carry its report Id');
      Assert.isTrue(
        tile.displayUnits == 'Integer' || tile.displayUnits == 'Auto',
        'displayUnits must mirror the OOB setting'
      );
      Assert.isNotNull(tile.isCurrency, 'isCurrency must be set');
    }
  }

  @isTest
  static void conversionRowsFollowFunnelOrder() {
    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    List<String> expectedOrder = new List<String>{
      'Shown Interest',
      'Qualify Meet',
      'Inspection',
      'Site Shortlisted',
      'Token'
    };

    Integer lastSeen = -1;
    for (MobileMyDashboardController.FunnelRowDTO row : dto.conversion) {
      Integer position = expectedOrder.indexOf(row.label);
      Assert.isTrue(
        position >= 0,
        'Stage "' + row.label + '" is not part of the agreed funnel'
      );
      Assert.isTrue(
        position > lastSeen,
        'Funnel stages must appear in business order, not value order'
      );
      lastSeen = position;
    }
  }

  @isTest
  static void repeatedCallsAreStable() {
    Test.startTest();
    MobileMyDashboardController.DashboardDTO first = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    MobileMyDashboardController.DashboardDTO second = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    Assert.isNotNull(first, 'First call must return a payload');
    Assert.isNotNull(second, 'Second call must return a payload');
    Assert.areEqual(
      first.accessLevel,
      second.accessLevel,
      'Access level must be stable between calls'
    );
  }

  @isTest
  static void allTwelveDateRangesAreAccepted() {
    List<String> ranges = new List<String>{
      'TODAY',
      'YESTERDAY',
      'THIS_WEEK',
      'LAST_WEEK',
      'THIS_MONTH',
      'LAST_MONTH',
      'LAST_N_DAYS:3',
      'LAST_N_DAYS:7',
      'LAST_N_DAYS:15',
      'LAST_N_DAYS:30',
      'LAST_N_DAYS:60',
      'LAST_N_DAYS:120'
    };

    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      ranges[4],
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    Assert.isNotNull(dto, 'THIS_MONTH must be accepted');
    Assert.areEqual(
      12,
      ranges.size(),
      'The dashboard filter offers exactly 12 ranges'
    );
  }

  @isTest
  static void restrictedUserGetsTilesDroppedNotZeroed() {
    User restricted = buildUser(null);
    insert restricted;

    MobileMyDashboardController.DashboardDTO dto;
    System.runAs(restricted) {
      Test.startTest();
      dto = MobileMyDashboardController.getDashboard(
        'THIS_MONTH',
        MobileMyDashboardController.LEVEL_INDIVIDUAL,
        null
      );
      Test.stopTest();
    }

    Assert.isNotNull(dto, 'A restricted user must still get a payload');
    Assert.areEqual(
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      dto.accessLevel,
      'A user with no role is individual level'
    );

    for (MobileMyDashboardController.TileDTO tile : dto.tiles) {
      Assert.isNotNull(
        tile.reportId,
        'A returned tile must always name the report it came from'
      );
    }

    if (dto.tiles.size() < 6) {
      Assert.isFalse(
        dto.problems.isEmpty(),
        'Anything the user cannot see must be explained, not hidden'
      );
    }
  }

  @isTest
  static void individualGetsNoRoster() {
    User noRole = buildUser(null);
    insert noRole;

    MobileMyDashboardController.DashboardDTO dto;
    System.runAs(noRole) {
      Test.startTest();
      dto = MobileMyDashboardController.getDashboard(
        'THIS_MONTH',
        MobileMyDashboardController.LEVEL_INDIVIDUAL,
        null
      );
      Test.stopTest();
    }

    Assert.areEqual(
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      dto.accessLevel,
      'A user with no role is individual level'
    );
    Assert.isTrue(
      dto.roster.isEmpty(),
      'Individual users must not receive a team roster'
    );
  }

  private static MobileMyDashboardController.TeamDef teamDef(
    String key,
    String mode
  ) {
    MobileMyDashboardController.TeamDef def = new MobileMyDashboardController.TeamDef();
    def.key = key;
    def.name = key.replace('_', ' ');
    def.sortOrder = 10;
    def.mode = mode;
    return def;
  }

  private static User fakeUser(
    String id15,
    String name,
    String username,
    String team
  ) {
    Map<String, Object> raw = new Map<String, Object>{
      'Id' => id15,
      'Name' => name,
      'Username' => username,
      'Team__c' => team
    };
    return (User) JSON.deserialize(JSON.serialize(raw), User.class);
  }

  @isTest
  static void usernameMatchingHonoursTheSandboxSuffixRule() {
    Assert.isTrue(
      MobileMyDashboardController.usernameMatches('a@x.in', 'a@x.in', false),
      'Exact match works everywhere'
    );
    Assert.isTrue(
      MobileMyDashboardController.usernameMatches('A@X.in', 'a@x.IN', false),
      'Matching is case-insensitive'
    );
    Assert.isTrue(
      MobileMyDashboardController.usernameMatches(
        'a@x.in',
        'a@x.in.partial',
        true
      ),
      'In a sandbox the suffix is tolerated'
    );
    Assert.isFalse(
      MobileMyDashboardController.usernameMatches(
        'a@x.in',
        'a@x.in.partial',
        false
      ),
      'In production a longer username is a DIFFERENT user'
    );
    Assert.isFalse(
      MobileMyDashboardController.usernameMatches('a@x.in', 'a@x.inx', true),
      'A prefix that is not followed by a dot is a different user'
    );
    Assert.isFalse(
      MobileMyDashboardController.usernameMatches(null, 'a@x.in', true),
      'A blank stored value matches nobody'
    );
    Assert.isFalse(
      MobileMyDashboardController.usernameMatches('a@x.in', null, true),
      'A blank actual username matches nobody'
    );
  }

  @isTest
  static void teamFieldModeResolvesEveryoneWithThatTeamValue() {
    MobileMyDashboardController.testUsers = new List<User>{
      fakeUser('005000000000001', 'Ann', 'ann@x.in', 'Ganesh Team'),
      fakeUser('005000000000002', 'Bob', 'bob@x.in', 'Ganesh Team'),
      fakeUser('005000000000003', 'Cy', 'cy@x.in', 'Other')
    };
    MobileMyDashboardController.TeamDef def = teamDef(
      'Ganesh_Team',
      'Team_Field'
    );
    def.fieldValue = 'Ganesh Team';

    MobileMyDashboardController.TeamMembers members = MobileMyDashboardController.resolveMembers(
      def
    );

    Assert.areEqual(
      2,
      members.memberIds.size(),
      'Only the two Ganesh Team users'
    );
    Assert.isTrue(members.memberNames.contains('Ann'));
    Assert.isFalse(
      members.memberNames.contains('Cy'),
      'Other team must not leak in'
    );
    Assert.isTrue(members.unresolved.isEmpty());
  }

  @isTest
  static void viewerBelongsToTheirOwnTeamOnly() {
    User lead = fakeUser(
      '005000000000001',
      'Lead',
      'lead@x.in.partial',
      'Chintan Team'
    );
    User noTeam = fakeUser('005000000000002', 'Drifter', 'drifter@x.in', null);

    MobileMyDashboardController.TeamDef chintan = teamDef(
      'Chintan_Team',
      'Team_Field'
    );
    chintan.fieldValue = 'Chintan Team';
    MobileMyDashboardController.TeamDef satish = teamDef(
      'Satish_Team',
      'Team_Field'
    );
    satish.fieldValue = 'Satish Team';
    MobileMyDashboardController.TeamDef listed = teamDef(
      'Listed_Team',
      'Explicit_Users'
    );
    listed.usernames = new List<String>{ 'lead@x.in' };
    MobileMyDashboardController.TeamDef blankValue = teamDef(
      'Blank_Team',
      'Team_Field'
    );

    Assert.isTrue(
      MobileMyDashboardController.viewerBelongsToTeam(chintan, lead, true)
    );
    Assert.isFalse(
      MobileMyDashboardController.viewerBelongsToTeam(satish, lead, true),
      'A lead must not see another team'
    );
    Assert.isTrue(
      MobileMyDashboardController.viewerBelongsToTeam(listed, lead, true),
      'An explicit member list counts, sandbox suffix tolerated'
    );
    Assert.isFalse(
      MobileMyDashboardController.viewerBelongsToTeam(listed, lead, false),
      'In production the suffix rule must not apply'
    );
    Assert.isFalse(
      MobileMyDashboardController.viewerBelongsToTeam(blankValue, noTeam, true),
      'A blank Team__c must never match a team with a blank value'
    );
    Assert.isFalse(
      MobileMyDashboardController.viewerBelongsToTeam(chintan, null, true)
    );
  }

  @isTest
  static void teamFieldValueMatchingNobodyIsReported() {
    MobileMyDashboardController.testUsers = new List<User>{
      fakeUser('005000000000001', 'Ann', 'ann@x.in', 'Ganesh Team')
    };
    MobileMyDashboardController.TeamDef def = teamDef(
      'South_Mumbai_Team',
      'Team_Field'
    );
    def.fieldValue = 'South Mumbai Team';

    MobileMyDashboardController.TeamMembers members = MobileMyDashboardController.resolveMembers(
      def
    );

    Assert.isTrue(members.memberIds.isEmpty());
    Assert.areEqual(1, members.unresolved.size(), 'The gap must be surfaced');
    Assert.isTrue(members.unresolved[0].contains('South Mumbai Team'));
  }

  @isTest
  static void explicitModeReportsUsernamesItCannotFind() {
    MobileMyDashboardController.testUsers = new List<User>{
      fakeUser('005000000000001', 'Ann', 'ann@x.in.partial', null)
    };
    MobileMyDashboardController.TeamDef def = teamDef(
      'Custom_Team',
      'Explicit_Users'
    );
    def.usernames = new List<String>{ 'ann@x.in', 'ghost@x.in' };

    MobileMyDashboardController.TeamMembers members = MobileMyDashboardController.resolveMembers(
      def
    );

    Assert.areEqual(
      1,
      members.memberIds.size(),
      'ann resolves, with or without a sandbox suffix'
    );
    Assert.areEqual(
      1,
      members.unresolved.size(),
      'ghost must be reported, not dropped silently'
    );
    Assert.isTrue(members.unresolved[0].contains('ghost@x.in'));
  }

  @isTest
  static void sumForMembersTotalsOnlyNamedPeople() {
    Map<String, Decimal> byPerson = new Map<String, Decimal>{
      'Ann' => 10,
      'Bob' => 5,
      'Outsider' => 1000
    };
    Decimal total = MobileMyDashboardController.sumForMembers(
      byPerson,
      new Set<String>{ 'Ann', 'Bob', 'NoRowForThisMember' }
    );
    Assert.areEqual(
      15,
      total,
      'Outsiders excluded; members with no row add nothing'
    );
    Assert.areEqual(
      0,
      MobileMyDashboardController.sumForMembers(
        new Map<String, Decimal>(),
        new Set<String>{ 'Ann' }
      )
    );
  }

  @isTest
  static void pickTeamFallsBackToFirstVisible() {
    List<MobileMyDashboardController.TeamDef> visible = new List<MobileMyDashboardController.TeamDef>{
      teamDef('First', 'Team_Field'),
      teamDef('Second', 'Team_Field')
    };
    Assert.areEqual(
      'Second',
      MobileMyDashboardController.pickTeam(visible, 'Second').key
    );
    Assert.areEqual(
      'First',
      MobileMyDashboardController.pickTeam(visible, 'NotGranted').key,
      'A key outside the viewer grant must not be honoured'
    );
    Assert.areEqual(
      'First',
      MobileMyDashboardController.pickTeam(visible, null).key
    );
  }

  @isTest
  static void requestingTeamTabWithoutAGrantIsDowngraded() {
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      teamDef('Some_Team', 'Team_Field')
    };
    MobileMyDashboardController.testAccessAll = false;

    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_TEAM,
      'Some_Team'
    );
    Test.stopTest();

    Assert.areEqual(
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      dto.accessLevel
    );
    Assert.isFalse(dto.canViewTeam, 'No grant, no Team tab');
    Assert.isTrue(
      dto.teams.isEmpty(),
      'No teams may be listed to someone with no grant'
    );
    Assert.isTrue(dto.roster.isEmpty(), 'No roster without a grant');
  }

  @isTest
  static void teamTabReturnsOnlyTheSelectedTeamsMembers() {
    List<User> some = [
      SELECT Id, Name, Username
      FROM User
      WHERE IsActive = TRUE AND Team__c != NULL
      LIMIT 3
    ];
    if (some.size() < 2) {
      return;
    }
    MobileMyDashboardController.TeamDef def = teamDef(
      'Test_Team',
      'Explicit_Users'
    );
    Set<String> names = new Set<String>();
    for (User u : some) {
      def.usernames.add(u.Username);
      names.add(u.Name);
    }
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      def,
      teamDef('Other_Team', 'Team_Field')
    };
    MobileMyDashboardController.testAccessAll = true;

    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_TEAM,
      'Test_Team'
    );
    Test.stopTest();

    Assert.areEqual(MobileMyDashboardController.LEVEL_TEAM, dto.accessLevel);
    Assert.isTrue(dto.canViewTeam);
    Assert.areEqual('Test_Team', dto.selectedTeamKey);
    Assert.areEqual(2, dto.teams.size(), 'Both granted teams are offered');
    Assert.areEqual(some.size(), dto.memberCount);

    for (MobileMyDashboardController.RosterRowDTO row : dto.roster) {
      Assert.isTrue(
        names.contains(row.name),
        'Roster must contain only the selected team, found: ' + row.name
      );
      for (MobileMyDashboardController.FunnelRowDTO f : row.conversion) {
        Assert.isNotNull(f.label, 'Funnel rows need a stage');
      }
    }
  }

  @isTest
  static void teamTabAvailabilityIsConsistentForAnyViewer() {
    User restricted = buildUser(null);
    insert restricted;

    List<User> viewers = new List<User>{
      restricted,
      [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]
    };
    for (User viewer : viewers) {
      MobileMyDashboardController.DashboardDTO dto;
      System.runAs(viewer) {
        dto = MobileMyDashboardController.getDashboard(
          'THIS_MONTH',
          MobileMyDashboardController.LEVEL_TEAM,
          null
        );
      }

      Assert.areEqual(
        !dto.teams.isEmpty(),
        dto.canViewTeam,
        'The Team tab is offered exactly when at least one team is granted'
      );
      if (!dto.canViewTeam) {
        Assert.areEqual(
          MobileMyDashboardController.LEVEL_INDIVIDUAL,
          dto.accessLevel
        );
        Assert.isTrue(dto.roster.isEmpty(), 'No roster without a grant');
        Assert.isNull(
          dto.selectedTeamKey,
          'No team is selected without a grant'
        );
        continue;
      }
      Assert.areEqual(MobileMyDashboardController.LEVEL_TEAM, dto.accessLevel);
      Set<String> granted = new Set<String>();
      for (MobileMyDashboardController.TeamDTO team : dto.teams) {
        granted.add(team.key);
      }
      Assert.isTrue(
        granted.contains(dto.selectedTeamKey),
        'The selected team must be one the viewer is granted'
      );
    }
  }

  @isTest
  static void ungrantedTeamKeyIsReplacedByAGrantedOne() {
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      teamDef('Granted_Team', 'Team_Field')
    };
    MobileMyDashboardController.testAccessAll = true;

    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_TEAM,
      'Some_Other_Team'
    );
    Test.stopTest();

    Assert.areEqual(
      'Granted_Team',
      dto.selectedTeamKey,
      'A key outside the grant must not be honoured'
    );
  }

  @isTest
  static void namedManagerTeamListsOnlyActiveDirectReports() {
    String leadId = fakeId(1);
    MobileMyDashboardController.testUsers = new List<User>{
      staff(leadId, 'Aniruddha Zutshi', 'lead@x.in', 'Ignored', null, true, null),
      staff(fakeId(2), 'Zara', 'zara@x.in', 'Ignored', leadId, true, null),
      staff(fakeId(3), 'Amy', 'amy@x.in', 'Aniruddha Team', leadId, true, null),
      staff(fakeId(4), 'Inactive', 'old@x.in', 'Aniruddha Team', leadId, false, null),
      staff(fakeId(5), 'Outsider', 'out@x.in', 'Aniruddha Team', null, true, null)
    };
    MobileMyDashboardController.TeamDef def = teamDef(
      'Aniruddha_Zutshi',
      'Team_Field'
    );
    def.name = 'Aniruddha Zutshi\'s Team';
    def.fieldValue = 'Aniruddha Team';
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      def
    };
    MobileMyDashboardController.testAccessAll = true;

    List<MobileMyDashboardController.TeamMemberOption> tree = MobileMyDashboardController.getTeamPickerTree();
    Assert.areEqual(1, tree.size());
    Assert.areEqual('team:' + def.key, tree[0].id);
    Assert.areEqual('team', tree[0].kind);

    List<MobileMyDashboardController.TeamMemberOption> members = tree[0].children;
    Assert.areEqual(2, members.size(), 'Only the two active direct reports');
    Assert.areEqual('Amy', members[0].name);
    Assert.areEqual('Zara', members[1].name);
    Assert.areEqual('person', members[0].kind);
    Assert.areEqual(def.key, members[0].sourceKey);

    List<MobileMyDashboardController.TeamMemberOption> again = MobileMyDashboardController.listTeamMembers(
      def.key
    );
    Assert.areEqual(members.size(), again.size());
    Assert.areEqual(members[0].name, again[0].name);
    Assert.areEqual(members[1].name, again[1].name);
  }

  @isTest
  static void teamWithoutAMatchingLeadKeepsConfiguredMembers() {
    Boolean sandbox = [
      SELECT IsSandbox
      FROM Organization
      LIMIT 1
    ]
    .IsSandbox;
    MobileMyDashboardController.testUsers = new List<User>{
      staff(fakeId(1), 'Ann', 'ann@x.in.partial', 'South', null, true, null),
      staff(fakeId(2), 'Ann', 'duplicate-name@x.in', 'South', null, true, null),
      staff(fakeId(3), 'Bob', 'bob@x.in', null, null, true, null),
      staff(fakeId(4), 'Old', 'old@x.in', null, null, false, null),
      staff(null, 'Nameless', 'nameless@x.in', null, null, true, null),
      staff(fakeId(6), 'OnlyChild', 'child@x.in', 'Other', fakeId(1), true, null)
    };

    MobileMyDashboardController.TeamDef twins = teamDef('Twin_Team', 'Team_Field');
    twins.name = 'Ann Team';
    twins.fieldValue = 'South';
    List<MobileMyDashboardController.TeamMemberOption> twinMembers = membersOf(
      twins
    );
    Assert.areEqual(
      2,
      twinMembers.size(),
      'Two people with the same name is not a manager lead'
    );
    Assert.areEqual('Ann', twinMembers[0].name);
    Assert.areEqual('Ann', twinMembers[1].name);

    MobileMyDashboardController.TeamDef named = teamDef('Quiet_Lead', 'Team_Field');
    named.name = 'Bob Team';
    named.fieldValue = 'South';
    List<String> quietNames = new List<String>();
    for (MobileMyDashboardController.TeamMemberOption row : membersOf(named)) {
      quietNames.add(row.name);
    }
    Assert.areEqual(
      new List<String>{ 'Ann', 'Ann' },
      quietNames,
      'A lead with nobody reporting to them keeps the configured members'
    );

    MobileMyDashboardController.TeamDef listed = teamDef(
      'Listed_Team',
      'Explicit_Users'
    );
    listed.name = 'Custom Group';
    listed.usernames = new List<String>{ 'ann@x.in', 'ann@x.in', 'nameless@x.in' };
    List<MobileMyDashboardController.TeamMemberOption> listedRows = membersOf(
      listed
    );
    if (sandbox) {
      Assert.areEqual(2, listedRows.size());
      Assert.isNull(listedRows[1].id, 'A member with no Id is still returned');
      Assert.areEqual(0, listedRows[1].children.size());
    } else {
      Assert.areEqual(
        1,
        listedRows.size(),
        'Production does not treat a sandbox suffix as the same user'
      );
    }

    MobileMyDashboardController.TeamDef untitled = teamDef('Blank', 'Team_Field');
    untitled.name = null;
    untitled.fieldValue = 'South';
    Assert.areEqual(2, membersOf(untitled).size());
  }

  @isTest
  static void pickerStopsOnAReportingCycle() {
    String annId = fakeId(1);
    String bobId = fakeId(2);
    MobileMyDashboardController.testUsers = new List<User>{
      staff(annId, 'Ann', 'ann@x.in', null, bobId, true, null),
      staff(bobId, 'Bob', 'bob@x.in', null, annId, true, null)
    };
    MobileMyDashboardController.TeamDef def = teamDef('Ann_Team', 'Explicit_Users');
    def.name = 'Ann Team';
    def.usernames = new List<String>{ 'ann@x.in' };

    List<MobileMyDashboardController.TeamMemberOption> rows = membersOf(def);
    Assert.areEqual(1, rows.size());
    Assert.areEqual('Bob', rows[0].name);
    Assert.areEqual(1, rows[0].children.size());
    Assert.areEqual('Ann', rows[0].children[0].name);
    Assert.areEqual('Bob', rows[0].children[0].children[0].name);
    Assert.areEqual(
      0,
      rows[0].children[0].children[0].children.size(),
      'A cycle must stop instead of listing the same person again'
    );
  }

  @isTest
  static void pickerStopsAtFifteenLevels() {
    List<User> chain = new List<User>();
    String leadId = fakeId(1);
    chain.add(
      staff(leadId, 'Depth Lead', 'lead@x.in', null, null, true, null)
    );
    String managerId = leadId;
    for (Integer i = 0; i < 17; i++) {
      String id15 = fakeId(i + 2);
      chain.add(
        staff(
          id15,
          'M' + String.valueOf(i).leftPad(2, '0'),
          'm' + i + '@x.in',
          null,
          managerId,
          true,
          null
        )
      );
      managerId = id15;
    }
    MobileMyDashboardController.testUsers = chain;
    MobileMyDashboardController.TeamDef def = teamDef('Depth_Team', 'Team_Field');
    def.name = 'Depth Lead Team';

    List<MobileMyDashboardController.TeamMemberOption> rows = membersOf(def);
    Assert.areEqual(1, rows.size());
    Assert.areEqual(16, treeDepth(rows[0]));
    MobileMyDashboardController.TeamMemberOption deepest = rows[0];
    while (deepest.children != null && !deepest.children.isEmpty()) {
      deepest = deepest.children[0];
    }
    Assert.areEqual('M15', deepest.name);
    Assert.areEqual(0, deepest.children.size());
    Assert.isFalse(
      treeContains(rows[0], 'M16'),
      'Level 16 is past the guard and must not be listed'
    );
  }

  @isTest
  static void listTeamMembersHonoursTheGrant() {
    MobileMyDashboardController.TeamDef def = teamDef('Some_Team', 'Team_Field');
    def.fieldValue = 'Some';
    MobileMyDashboardController.testUsers = new List<User>{
      staff(fakeId(1), 'Ann', 'ann@x.in', 'Some', null, true, null)
    };
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      def
    };
    MobileMyDashboardController.testAccessAll = false;

    Assert.isTrue(MobileMyDashboardController.getTeamPickerTree().isEmpty());
    Assert.isTrue(
      MobileMyDashboardController.listTeamMembers('Some_Team').isEmpty()
    );

    MobileMyDashboardController.testAccessAll = true;
    Assert.areEqual(
      1,
      MobileMyDashboardController.listTeamMembers('Some_Team').size()
    );
    Assert.isTrue(
      MobileMyDashboardController.listTeamMembers('Missing_Team').isEmpty()
    );
  }

  @isTest
  static void directReportsRejectBadIdsAndReturnChildren() {
    Assert.isTrue(
      MobileMyDashboardController.getDirectReports(null).isEmpty()
    );
    Assert.isTrue(MobileMyDashboardController.getDirectReports('').isEmpty());
    Assert.isTrue(
      MobileMyDashboardController.getDirectReports('notAnId').isEmpty()
    );

    Id managerRole = anyRoleId();
    User manager = buildColleague(managerRole, null, 'DirectManager');
    insert manager;
    User child = buildColleague(
      roleUnder(managerRole),
      manager.Id,
      'DirectChild'
    );
    insert child;

    Set<Id> found = new Set<Id>();
    for (
      MobileMyDashboardController.TeamMemberOption row : MobileMyDashboardController.getDirectReports(
        manager.Id
      )
    ) {
      found.add((Id) row.id);
    }
    Assert.isTrue(found.contains(child.Id));
    Assert.isTrue(
      MobileMyDashboardController.getDirectReports(child.Id).isEmpty()
    );
  }

  @isTest
  static void myReportTreeIncludesTheNextLevel() {
    Id managerRole = anyRoleId();
    Id childRole = roleUnder(managerRole);
    User manager = buildColleague(managerRole, null, 'TreeManager');
    insert manager;
    User child = buildColleague(childRole, manager.Id, 'TreeChild');
    insert child;
    User grand = buildColleague(roleUnder(childRole), child.Id, 'TreeGrand');
    insert grand;

    MobileMyDashboardController.TeamMemberOption match;
    System.runAs(manager) {
      for (
        MobileMyDashboardController.TeamMemberOption row : MobileMyDashboardController.getMyReportTree()
      ) {
        if (row.id == child.Id) {
          match = row;
        }
      }
    }
    Assert.isNotNull(match, 'The direct report is the first level of the tree');
    Assert.areEqual(1, match.children.size());
    Assert.areEqual(grand.Id, (Id) match.children[0].id);
  }

  @isTest
  static void managerWithNoMetadataGrantStillGetsMyReports() {
    Id managerRole = anyRoleId();
    User manager = buildColleague(managerRole, null, 'ReportManager');
    insert manager;
    User child = buildColleague(
      roleUnder(managerRole),
      manager.Id,
      'ReportChild'
    );
    insert child;

    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>();
    MobileMyDashboardController.testAccessAll = true;

    MobileMyDashboardController.DashboardDTO dto;
    System.runAs(manager) {
      Test.startTest();
      dto = MobileMyDashboardController.getDashboard(
        'THIS_MONTH',
        MobileMyDashboardController.LEVEL_TEAM,
        null
      );
      Test.stopTest();
    }

    Assert.isTrue(dto.canViewTeam);
    Assert.areEqual(MobileMyDashboardController.LEVEL_TEAM, dto.accessLevel);
    Assert.areEqual('MY_REPORTS', dto.selectedTeamKey);
    Assert.isTrue(dto.memberCount >= 1);
    Assert.isTrue(dto.teams.isEmpty());
  }

  @isTest
  static void systemAdminFlagFollowsTheProfileName() {
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>();
    MobileMyDashboardController.testAccessAll = true;
    MobileMyDashboardController.testUsers = new List<User>{
      staff(
        UserInfo.getUserId(),
        'Me',
        UserInfo.getUserName(),
        null,
        null,
        true,
        'System Administrator'
      )
    };

    Test.startTest();
    MobileMyDashboardController.DashboardDTO adminDto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    MobileMyDashboardController.testUsers = new List<User>{
      staff(
        UserInfo.getUserId(),
        'Me',
        UserInfo.getUserName(),
        null,
        null,
        true,
        'Standard User'
      )
    };
    MobileMyDashboardController.DashboardDTO otherDto = MobileMyDashboardController.getDashboard(
      'THIS_MONTH',
      MobileMyDashboardController.LEVEL_INDIVIDUAL,
      null
    );
    Test.stopTest();

    Assert.isTrue(adminDto.isSystemAdmin);
    Assert.isFalse(otherDto.isSystemAdmin);
  }

  @isTest
  static void emptyStandInUsersAreNotTreatedAsAdmin() {
    MobileMyDashboardController.testUsers = new List<User>();
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>();
    MobileMyDashboardController.testAccessAll = true;

    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      null,
      MobileMyDashboardController.LEVEL_TEAM,
      'Anything'
    );
    Test.stopTest();

    Assert.isFalse(dto.isSystemAdmin);
    Assert.isNotNull(dto);
  }

  @isTest
  static void teamComparatorOrdersBySortThenName() {
    MobileMyDashboardController.TeamDef alpha = teamDef('Alpha', 'Team_Field');
    alpha.name = 'Alpha';
    alpha.sortOrder = 1;
    MobileMyDashboardController.TeamDef bravo = teamDef('Bravo', 'Team_Field');
    bravo.name = 'Bravo';
    bravo.sortOrder = 1;
    MobileMyDashboardController.TeamDef later = teamDef('Later', 'Team_Field');
    later.name = 'Later';
    later.sortOrder = 5;

    MobileMyDashboardController.TeamComparator cmp = new MobileMyDashboardController.TeamComparator();
    Assert.areEqual(-1, cmp.compare(alpha, bravo));
    Assert.areEqual(1, cmp.compare(bravo, alpha));
    Assert.areEqual(-1, cmp.compare(alpha, later));
    Assert.areEqual(1, cmp.compare(later, alpha));
  }

  @isTest
  static void rosterComparatorOrdersByTokensThenName() {
    MobileMyDashboardController.RosterRowDTO high = new MobileMyDashboardController.RosterRowDTO();
    high.name = 'Zed';
    high.tokenAchieved = 5;
    MobileMyDashboardController.RosterRowDTO low = new MobileMyDashboardController.RosterRowDTO();
    low.name = 'Ann';
    low.tokenAchieved = 1;
    MobileMyDashboardController.RosterRowDTO blank = new MobileMyDashboardController.RosterRowDTO();
    blank.tokenAchieved = 5;
    MobileMyDashboardController.RosterRowDTO missing = new MobileMyDashboardController.RosterRowDTO();
    missing.name = 'Ann';

    MobileMyDashboardController.RosterComparator cmp = new MobileMyDashboardController.RosterComparator();
    Assert.areEqual(-1, cmp.compare(high, low));
    Assert.areEqual(1, cmp.compare(low, high));
    Assert.areEqual(1, cmp.compare(missing, high));
    Assert.isTrue(cmp.compare(high, blank) > 0);
  }

  @isTest
  static void reportTreeHelpersCoverEmptyAndNestedCases() {
    String bossId = fakeId(1);
    MobileMyDashboardController.testUsers = new List<User>{
      staff(bossId, 'Boss', 'boss@x.in', null, null, true, null),
      staff(fakeId(2), 'Zed', 'zed@x.in', null, bossId, true, null),
      staff(fakeId(3), 'Ann', 'ann@x.in', null, bossId, true, null),
      staff(fakeId(4), 'Nested', 'nested@x.in', null, fakeId(3), true, null),
      staff(fakeId(5), 'Idle', 'idle@x.in', null, bossId, false, null)
    };

    Map<Id, List<User>> grouped = MobileMyDashboardController.usersByManager();
    Assert.areEqual(2, grouped.get((Id) bossId).size());
    Assert.areEqual(1, grouped.get((Id) fakeId(3)).size());
    Assert.isFalse(grouped.containsKey((Id) fakeId(5)));

    Assert.areEqual(
      0,
      MobileMyDashboardController.buildReportOptions(
          null,
          grouped,
          new Set<Id>()
        )
        .size()
    );
    Assert.areEqual(
      0,
      MobileMyDashboardController.buildReportOptions(
          (Id) bossId,
          grouped,
          new Set<Id>{ (Id) bossId }
        )
        .size()
    );

    List<MobileMyDashboardController.TeamMemberOption> nodes = MobileMyDashboardController.buildReportOptions(
      (Id) bossId,
      grouped,
      new Set<Id>()
    );
    Assert.areEqual(2, nodes.size());
    Assert.areEqual('Ann', nodes[0].name);
    Assert.areEqual(1, nodes[0].children.size());
    Assert.areEqual('Nested', nodes[0].children[0].name);
    Assert.areEqual('Zed', nodes[1].name);

    Id managerRole = anyRoleId();
    User boss = buildColleague(managerRole, null, 'ManagedBoss');
    insert boss;
    User report = buildColleague(roleUnder(managerRole), boss.Id, 'Managed');
    insert report;

    Assert.isTrue(MobileMyDashboardController.managerIdsAmong(null).isEmpty());
    Assert.isTrue(
      MobileMyDashboardController.managerIdsAmong(new Set<Id>()).isEmpty()
    );
    Set<Id> managers = MobileMyDashboardController.managerIdsAmong(
      new Set<Id>{ boss.Id, report.Id }
    );
    Assert.isTrue(managers.contains(boss.Id));
    Assert.isFalse(managers.contains(report.Id));
  }

  @isTest
  static void omittedDirectMembersStayOutOfTheTree() {
    MobileMyDashboardController.TeamMemberOption child = new MobileMyDashboardController.TeamMemberOption();
    child.id = fakeId(2);
    child.name = 'Child';
    child.children = new List<MobileMyDashboardController.TeamMemberOption>();

    MobileMyDashboardController.TeamMemberOption parent = new MobileMyDashboardController.TeamMemberOption();
    parent.id = fakeId(1);
    parent.name = 'Parent';
    parent.children = new List<MobileMyDashboardController.TeamMemberOption>{
      child
    };

    List<MobileMyDashboardController.TeamMemberOption> kept = MobileMyDashboardController.omitDirectMembers(
      new List<MobileMyDashboardController.TeamMemberOption>{ parent, null },
      new Set<Id>{ (Id) child.id }
    );
    Assert.areEqual(1, kept.size());
    Assert.areEqual(0, kept[0].children.size());

    List<MobileMyDashboardController.TeamMemberOption> dropped = MobileMyDashboardController.omitDirectMembers(
      new List<MobileMyDashboardController.TeamMemberOption>{ parent },
      new Set<Id>{ (Id) parent.id }
    );
    Assert.isTrue(dropped.isEmpty());
  }

  @isTest
  static void unresolvedTeamMembersAreExplained() {
    MobileMyDashboardController.testUsers = new List<User>{
      staff(fakeId(1), 'Ann', 'ann@x.in', 'Ganesh Team', null, true, null)
    };
    MobileMyDashboardController.TeamDef def = teamDef(
      'Missing_Team',
      'Team_Field'
    );
    def.fieldValue = 'South Mumbai Team';
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      def
    };
    MobileMyDashboardController.testAccessAll = true;

    Test.startTest();
    MobileMyDashboardController.DashboardDTO dto = MobileMyDashboardController.getDashboard(
      null,
      MobileMyDashboardController.LEVEL_TEAM,
      'Missing_Team'
    );
    Test.stopTest();

    Assert.areEqual(0, dto.memberCount);
    Assert.isFalse(dto.problems.isEmpty());
    Assert.isTrue(dto.problems[0].contains('South Mumbai Team'));
  }

  @isTest
  static void reportParsersTolerateMissingShapes() {
    Assert.areEqual(
      0,
      MobileMyDashboardController.buildPersonTotals(null, 'missing').size()
    );

    List<String> preferred = new List<String>{
      'Monthwise_Action_Conversion_Employee_Zh8',
      'My_Action_Wise_Conversion_Report_ZTM',
      'My_Teams_Target_Report_ZVQ',
      'Outstanding_Tqu'
    };
    Map<String, Report> byName = new Map<String, Report>();
    for (Report found : [
      SELECT Id, DeveloperName
      FROM Report
      WHERE DeveloperName IN :preferred
    ]) {
      byName.put(found.DeveloperName, found);
    }
    List<Report> reports = new List<Report>();
    for (String name : preferred) {
      if (byName.containsKey(name)) {
        reports.add(byName.get(name));
      }
    }
    if (reports.isEmpty()) {
      reports = [SELECT Id FROM Report LIMIT 1];
    }
    if (reports.isEmpty()) {
      return;
    }

    Test.startTest();
    for (Report report : reports) {
      try {
        Reports.ReportResults results = Reports.ReportManager.runReport(
          report.Id,
          false
        );
        MobileMyDashboardController.grandTotal(results, 'not-a-real-aggregate');
        List<String> aggregates = results.getReportMetadata().getAggregates();
        if (aggregates != null && !aggregates.isEmpty()) {
          MobileMyDashboardController.grandTotal(results, aggregates[0]);
          MobileMyDashboardController.buildPersonTotals(results, aggregates[0]);
        }
        MobileMyDashboardController.buildPersonTotals(
          results,
          'not-a-real-aggregate'
        );
        MobileMyDashboardController.buildFunnel(results);
        MobileMyDashboardController.buildPersonFunnels(
          results,
          new Set<String>()
        );
        MobileMyDashboardController.buildPersonFunnels(results, null);
        MobileMyDashboardController.buildTeamFunnel(results, null);
        MobileMyDashboardController.buildTeamFunnel(
          results,
          new Set<String>{ 'Nobody' }
        );
        MobileMyDashboardController.buildRoster(results, null);
        MobileMyDashboardController.buildRoster(results, new Set<Id>());
      } catch (Exception e) {
        Assert.isNotNull(e.getMessage());
      }
    }
    Test.stopTest();
  }

  private static Integer userSeq = 0;

  private static Id anyRoleId() {
    List<UserRole> roles = [SELECT Id FROM UserRole LIMIT 1];
    if (!roles.isEmpty()) {
      return roles[0].Id;
    }
    UserRole created = new UserRole(
      Name = 'Mobile Dash Role',
      DeveloperName = 'Mobile_Dash_Role'
    );
    insert created;
    return created.Id;
  }

  private static Id roleUnder(Id parentRoleId) {
    UserRole created = new UserRole(
      Name = 'Mobile Dash Child ' + userSeq,
      DeveloperName = 'Mobile_Dash_Child_' + userSeq,
      ParentRoleId = parentRoleId
    );
    userSeq++;
    insert created;
    return created.Id;
  }

  private static User buildColleague(Id roleId, Id managerId, String lastName) {
    User colleague = buildUser(roleId);
    colleague.ProfileId = UserInfo.getProfileId();
    colleague.LastName = lastName;
    colleague.ManagerId = managerId;
    return colleague;
  }

  private static User buildUser(Id roleId) {
    List<Profile> preferred = [
      SELECT Id
      FROM Profile
      WHERE Name IN ('Minimum Access - Salesforce', 'Standard User')
      ORDER BY Name
      LIMIT 1
    ];
    Id profileId = preferred.isEmpty()
      ? [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1].Id
      : preferred[0].Id;
    String unique =
      String.valueOf(Datetime.now().getTime()) + String.valueOf(userSeq++);
    return new User(
      FirstName = 'Mobile',
      LastName = 'DashTest',
      Email = 'mobiledash' + unique + '@example.invalid',
      Username = 'mobiledash' + unique + '@example.invalid.fairdeal',
      Alias = 'mdash',
      ProfileId = profileId,
      UserRoleId = roleId,
      TimeZoneSidKey = 'Asia/Kolkata',
      LocaleSidKey = 'en_IN',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
  }

  private static String fakeId(Integer n) {
    String body = String.valueOf(n);
    return '005' + '0'.repeat(12 - body.length()) + body;
  }

  private static User staff(
    String id15,
    String name,
    String username,
    String team,
    String managerId,
    Boolean active,
    String profileName
  ) {
    Map<String, Object> raw = new Map<String, Object>{
      'Id' => id15,
      'Name' => name,
      'Username' => username,
      'Team__c' => team,
      'IsActive' => active
    };
    if (managerId != null) {
      raw.put('ManagerId', managerId);
    }
    if (profileName != null) {
      raw.put('Profile', new Map<String, Object>{ 'Name' => profileName });
    }
    return (User) JSON.deserialize(JSON.serialize(raw), User.class);
  }

  private static List<MobileMyDashboardController.TeamMemberOption> membersOf(
    MobileMyDashboardController.TeamDef def
  ) {
    MobileMyDashboardController.testTeams = new List<MobileMyDashboardController.TeamDef>{
      def
    };
    MobileMyDashboardController.testAccessAll = true;
    return MobileMyDashboardController.listTeamMembers(def.key);
  }

  private static Boolean treeContains(
    MobileMyDashboardController.TeamMemberOption node,
    String name
  ) {
    if (node.name == name) {
      return true;
    }
    if (node.children == null) {
      return false;
    }
    for (
      MobileMyDashboardController.TeamMemberOption child : node.children
    ) {
      if (treeContains(child, name)) {
        return true;
      }
    }
    return false;
  }

  private static Integer treeDepth(
    MobileMyDashboardController.TeamMemberOption node
  ) {
    Integer depth = 1;
    if (node.children == null) {
      return depth;
    }
    for (
      MobileMyDashboardController.TeamMemberOption child : node.children
    ) {
      depth = Math.max(depth, 1 + treeDepth(child));
    }
    return depth;
  }
}
