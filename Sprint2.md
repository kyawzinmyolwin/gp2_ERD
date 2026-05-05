## Sprint 2 - Location Feature

### (E2US1) As a Group Coordinator, I want to define my group's operational area by drawing boundaries on a map so that the area can be visualised by all members.
- Given a Group Coordinator navigates to the group map page
  And no operational area has been defined yet
  Then automatically requests GPS location → if granted, centres on user's current location
  → if denied or unavailable, displays New Zealand at overview zoom level
  In both cases → search bar is always visible and available for manual location search at any time
  And a "Draw Area" button is visible
  And existing line paths and asset markers are displayed if any exist
  
  Given a Group Coordinator searches for a location
  When they enter a place name or address and select a result
  Then the map centres and zooms to that location
  
  Given a Group Coordinator clicks "Draw Area"
  When they click to place points on the map
  Then each click adds a vertex connected to the previous by a straight line
  And double-clicking the final point closes and completes the polygon
  And the polygon displays as a semi-transparent fill during drawing
  
  Given a polygon has been completed
  When the Group Coordinator clicks Save
  Then the operational area is saved
  And it appears as a semi-transparent polygon beneath line paths and asset markers
  And all group members see it on their next map view
  
  Given a Group Coordinator clicks Cancel before saving
  Then no boundary is saved
  And the map returns to its previous state
  
  Given a Group Coordinator is placing points on the map
  When fewer than 3 points have been placed
  Then vertices appear dimmed and no polygon fill is shown
  
  Given a Group Coordinator places a 3rd point
  When each subsequent point is added
  Then vertices become bright
  And the polygon fill appears in real time as a semi-transparent overlay
  And the enclosed area is displayed on the map as points are added
  
  Given a Group Coordinator attempts to close the polygon
  When fewer than 3 points have been placed
  Then the polygon does not close
  And a friendly hint is shown: "Keep adding points — you need at least 3 to define an area"

### (E2US2) As a Group Coordinator, I want to edit my group's operational area so that boundaries stay up to date.
- Given a Group Coordinator navigates to the group map page
  And an operational area has already been defined
  Then the existing boundary is displayed on the map
  And an "Edit Area" button is visible
  
  Given a Group Coordinator clicks "Edit Area"
  Then each vertex of the polygon becomes a draggable handle
  And midpoints between vertices are shown as smaller handles for adding new vertices
  
  Given a Group Coordinator drags a vertex to a new position
  Then the polygon updates in real time to reflect the new shape
  
  Given a Group Coordinator clicks a midpoint handle
  Then a new vertex is inserted at that position and becomes draggable
  
  Given a Group Coordinator saves the edited boundary
  When they click Save
  Then the updated boundary replaces the previous one
  And all group members see the updated boundary on their next map view
  
  Given a Group Coordinator clicks Cancel during editing
  Then all changes are discarded
  And the original boundary is restored on the map
  
  Given editing would reduce the polygon to fewer than 3 vertices
  Then the vertex cannot be deleted
  And a friendly hint is shown: "An area needs at least 3 points"

### (E2US3) As a group member, I want to view my group's operational area on a map so that I understand the spatial context of our activities.
- Given a group member navigates to the group map page
  When the page loads
  Then the map centres on the group's existing data in order of priority:
  operational area → line paths → assets
  And if no group data exists, automatically requests GPS location
  And if GPS is denied or unavailable, displays New Zealand at overview zoom level
  And a search bar is always visible and available for manual location search at any time
  
  Given the group has a defined operational area
  Then it is displayed as a semi-transparent polygon as the bottom layer
  
  Given the group has line paths defined
  Then each line is displayed as a polyline in its assigned colour above the operational area
  
  Given the group has assets deployed in the field
  Then each asset is displayed as a circular marker above the line paths
  And marker colour indicates status:
  🟢 Active / 🟠 Under Repair / 🔴 Retired
  And all markers have a white border to distinguish from line colours
  
  Given a group member uses the layer control panel
  Then they can toggle:
  ☑ Operational Area
  ☑ Trap Lines
  ☑ Bait Station Lines
  ☑ Active Assets (🟢)
  ☑ Under Repair Assets (🟠)
  ☐ Retired Assets (🔴, off by default)
  And In Storage assets are never shown on the group map
  And the map updates immediately when any layer is toggled
  
  Given no operational area has been defined
  Then the map displays without a polygon
  And a message indicates no operational area has been set
  And line paths and asset markers are still displayed if they exist
  
  Given a group member views the map
  Then only data belonging to their currently selected group is visible
  And no edit or draw options are visible

### (E2US4) As a Group Coordinator, I want to place traps and bait stations by clicking on a map so that coordinates are captured accurately without manual entry.
- Given a Group Coordinator is creating a new trap or bait station
  When the form loads
  Then a map is displayed alongside the form
  And the map centres on the group's existing data in order of priority:
  operational area → line paths → assets
  And if no group data exists, automatically requests GPS location
  And if GPS is denied or unavailable, displays New Zealand at overview zoom level
  And a search bar is always visible and available for manual location search at any time
  
  Given a Group Coordinator clicks a location on the map
  Then the latitude and longitude fields in the form are automatically populated
  And a marker appears at the clicked location
  
  Given a Group Coordinator manually enters coordinates in the form
  Then the marker on the map moves to the entered coordinates
  And the map centres on that location
  
  Given a Group Coordinator saves the record
  Then the asset is saved with the selected coordinates
  And the marker appears on the group map immediately
  
  Given a Group Coordinator has not selected a location
  When they attempt to submit the form
  Then the form remains open
  And the location field is highlighted with a specific error message

### (E2US5) As a Group Coordinator, I want to update trap and bait station positions on a map so that location data stays accurate.
- Given a Group Coordinator opens an existing trap or bait station to edit
  Then the map displays the asset's current marker position
  
  Given a Group Coordinator drags the marker to a new position
  Then the latitude and longitude fields update automatically in real time
  
  Given a Group Coordinator manually updates the coordinates in the form
  Then the marker moves to the new position on the map
  And the map centres on the new location
  
  Given a Group Coordinator saves
  Then the marker appears at the updated position on the group map immediately
  
  Given a Group Coordinator clicks Cancel
  Then the marker remains at its original position

### (E2US6) As a group member, I want to view traps and bait stations as markers on a map so that I can locate and navigate to them easily.
- Given a group member views the group map
  Then all active traps and bait stations are displayed as markers
  And trap markers and bait station markers are visually differentiated
  And retired asset markers are displayed in grey
  
  Given a group member clicks on a marker
  Then a popup appears showing:
  
  * asset code
  * type
  * current status
  * line it belongs to
  
  Given a marker is displayed on the map
  Then a tooltip shows the location name based on the asset's coordinates
  
  [ENHANCED]
  Given a group member selects "Navigate to this location" from the popup
  And they are on an iOS mobile device
  Then they are redirected to Apple Maps with the asset's coordinates as the destination
  
  [ENHANCED]
  Given a group member selects "Navigate to this location" from the popup
  And they are on a non-iOS mobile device
  Then they are redirected to Google Maps app with the asset's coordinates as the destination
  
  [ENHANCED]
  Given a group member selects "Navigate to this location" from the popup
  And they are on a desktop device
  Then Google Maps opens in a new browser tab with the asset's coordinates as the destination
  
  [ENHANCED]
  Given a group member has no internet connection
  When they select "Navigate to this location"
  Then the asset's coordinates are displayed on screen
  And a "Copy coordinates" button is available
  And a hint is shown: "Save these coordinates to your offline maps app for navigation without internet"

### (E2US7) As a group member, I want to click on a map marker to view asset details so that I can inspect relevant information in the field.
- Given a group member clicks on a marker
  Then a popup appears showing:
  
  * asset code
  * type
  * current status
  * line it belongs to
  * date last checked
  And "Previous" and "Next" buttons are shown to navigate between assets on the same line
  And the map automatically pans to the selected asset
  
  Given a group member clicks "Next" or "Previous"
  Then the popup updates to show the next or previous asset on the same line in position order
  And the map pans to that asset's location
  
  Given a group member reaches the last asset on a line
  When they click "Next"
  Then the "Next" button is disabled
  And a message is shown: "End of [Line Name]"
  And a dropdown appears showing nearby lines sorted by distance
  And selecting a line pans the map to that line's first asset
  And the popup updates to show that asset's details
  
  Given a group member reaches the first asset on a line
  When they click "Previous"
  Then the "Previous" button is disabled
  And a message is shown: "Start of [Line Name]"
  
  Given the asset belongs to a retired line
  Then the popup shows all details
  And displays a note: "This asset belongs to a retired line"
  
  Given a group member is offline
  Then the popup still displays asset details from cached data
  And a note indicates: "You are offline — showing cached data"
  
  Given a group member views the popup on a mobile device
  Then the detail panel is legible and usable without horizontal scrolling

### (E2US8) As a visitor, I want to view all conservation groups' operational areas on a homepage map so that I can discover groups and understand their coverage before joining.
- Given a visitor opens the homepage
  When the map loads
  Then all groups with defined operational areas are displayed as polygons on the map
  And groups without defined operational areas appear in a sidebar list only
  And the map displays New Zealand at an overview zoom level
  
  Given a visitor clicks on a group's operational area
  Then a popup appears showing:
  
  * group name
  * short description
  * number of members
  * public or private status
  And a "Learn more" button linking to that group's detail page
  
  Given a visitor uses the search bar or filters
  When they search by group name or filter by region or public/private status
  Then the map updates to show only matching groups
  And the sidebar list updates accordingly
  And clearing search or filters returns the map to showing all groups
  
  Given a visitor clicks on a group popup
  When they click "Learn more"
  Then they are directed to that group's detail page

### (E2US9) As a group member, I want to view a filtered pest activity heatmap for my group so that I can identify high-activity areas by time period, species, and line.
- [ENHANCED]
  Given a group member navigates to the heatmap view
  Then a heatmap is displayed overlaid on the group map reflecting pest activity
  And line paths and asset markers remain visible beneath the heatmap
  
  [ENHANCED]
  Given a group member applies filters
  When they filter by time period / species / line
  Then the heatmap updates to reflect only matching activity
  And if no data matches, an empty state message is shown
  
  [ENHANCED]
  Given a group member resets all filters
  Then the heatmap returns to showing all available activity data
  
  [ENHANCED]
  Given a Super Admin or non-member attempts to access this view
  Then it is not visible in their interface

### (E2US10) As a Super Admin, I want to view a cross-group pest activity heatmap so that I can monitor pest pressure across the entire platform.
- [ENHANCED]
  Given a Super Admin navigates to the platform heatmap view
  Then a heatmap is displayed showing pest activity aggregated across all groups
  And each group's operational area is visible as context
  
  [ENHANCED]
  Given a Super Admin applies filters
  When they filter by group / time period / species
  Then the heatmap updates to reflect only matching activity
  And if no data matches, an empty state message is shown
  
  [ENHANCED]
  Given a Super Admin resets all filters
  Then the heatmap returns to showing all activity across all groups
  
  [ENHANCED]
  Given a group member or Group Coordinator attempts to access the platform heatmap
  Then it is not visible in their interface

