// Developer Console → Debug → Open Execute Anonymous Window
// Run inspect_team_reports.apex first so you know which object each report uses.
// Then run this. Names start with SAMPLE_TEAM_REPORT_.
// Cleanup: System.debug(TeamReportSampleData.deleteSamples());

System.debug('\n' + TeamReportSampleData.createSamples());
