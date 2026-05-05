## Sprint 4 - Analytics & Records

### (US16) As a Group Coordinator, I want to download bait station records as a CSV file so that data can be used externally.
- Given a Group Coordinator views the bait station records page
  When they apply filters and click Export
  Then a CSV file downloads containing only the filtered records
  And the file includes all [http://trap.nz|http://trap.nz|smart-link]  compatible field headers
  And CSV values match exactly what is shown on screen
  And headers are included even if no records match the filter
  
  Given a user who is not a Group Coordinator views the records page
  When they view any page
  Then no export option is visible

### (E2US11)
- nan

### (E2US12)
- Given I am logged in as a Group Member, when I navigate to the heatmap view, then I should see a heatmap overlaid on the group's operational area reflecting pest activity recorded by the group.
  
  Given the heatmap is displayed, when I apply a time period filter (e.g. last 30 days, last 3 months, custom range), then the heatmap should update to reflect only pest activity recorded within the selected period.
  
  Given that the heatmap is displayed, when I filter by species (e.g. rat, possum, stoat), then the heatmap should update to show activity data for the selected species only.
  
  Given that the heatmap is displayed, when I filter by trap line, then the heatmap should update to show activity only from assets belonging to the selected line.
  
  Given that one or more filters are active, when no pest activity data matches the selected criteria, then the heatmap should display an empty state with a message indicating no data is available for the current filters.
  
  Given I have applied multiple filters, when I reset all filters, then the heatmap should return to displaying all available pest activity data for the group.

### (E4US)
- nan

### (US46) As a developer, I want to contain at least 12 months of simulated predator control data so that analytics and charts display meaningful trends and patterns.
- nan

### (US47) As a Super Admin, I want to view and filter a cross-group analytics dashboard so that I can monitor overall platform performance and compare activity between groups.
- nan

### (US48) As a group member, I want to view and filter my group's analytics dashboard so that I can monitor predator control activity by date range, species, line, trap type, or bait type.
- nan

### (US49) As a group member, I want each chart to display an automatically generated text summary so that I can quickly understand the key insight without interpreting the data myself.
- nan

### (US50) As a Group Coordinator, I want to filter and export predator control data as a CSV file compatible with trap.nz so that only relevant records are included and can be used externally.
- nan

### (US51) As a user, I want to earn individual and group badges for reaching predator control milestones so that contributions are recognised and engagement is maintained.
- nan

### (US52) As a group member, I want to view a 30-day pest activity forecast for my group so that field operations can be planned in advance.
- nan

### (US53) As a Group Coordinator, I want to view predicted bait consumption for each station so that I can prepare adequate supplies before field visits.
- nan

### (US54) As a Super Admin, I want to view platform-wide pest activity forecasts so that I can identify groups that may need additional support.
- nan

### (US55) As a group member, I want forecast results to be accompanied by an automatically generated plain-language explanation so that I can understand predictions without interpreting raw data.
- nan

