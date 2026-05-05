## Sprint 3 - InventoryManagement

### (US35) As a Group Coordinator, I want to create and manage storage areas for my group so that equipment locations are clearly recorded and identifiable.
- Given a Group Coordinator navigates to the storage areas page
  Then storage areas are displayed in two tabs: Has Assets / Empty
  And each storage area automatically appears in the correct tab based on its current asset count
  And each storage area shows:
  
  * name
  * location description
  * current asset count
  
  Given assets are added to or removed from a storage area
  Then the storage area automatically moves to the correct tab
  And the asset count updates immediately
  
  Given a Group Coordinator creates a new storage area
  When they submit the form
  Then they must provide a unique name within the group
  And an optional location description
  And the storage area appears immediately in the Empty tab
  
  Given a Group Coordinator submits with a duplicate name or missing fields
  When validation fails
  Then the form remains open with entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given a Group Coordinator edits a storage area
  When they save valid changes
  Then updates are reflected immediately across all associated asset records
  
  Given a Group Coordinator opens a storage area
  Then they can see all traps and bait stations currently stored there
  And each asset shows its code, type and status
  
  Given a Group Coordinator archives a storage area that contains assets
  When they initiate the action
  Then they see a list of all assets in that storage area
  And for each asset they must choose:
  
  * Transfer to another storage area
  * Deploy to Line
  And after all assets are handled the storage area is archived
  
  Given a Group Coordinator archives a storage area in the Empty tab
  When they confirm
  Then it is archived immediately
  And historical records referencing it remain intact

### (US36) As a Group Coordinator or Operator, I want to view all storage areas and their current contents so that I know where each piece of equipment is located.
- Given a Group Coordinator or Operator opens a storage area
  Then they can see all traps and bait stations currently stored there
  And each asset shows:
  
  * code
  * type
  * status
  * date last moved
  
  Given a Group Coordinator or Operator views the storage areas page
  Then they can see the total number of assets across all storage areas
  And assets not assigned to any storage area are listed separately as "Unassigned"
  
  Given an Observer is logged in
  Then no storage area or inventory information is visible in their interface

### (US37) As a Group Coordinator, I want to add newly purchased traps and bait stations to the group inventory so that all equipment is tracked from the moment of acquisition.
- Given a Group Coordinator clicks Create in the Traps / Bait Stations tab
  When the form opens
  Then it is pre-set to that asset type with no type selection required
  And they must provide:
  
  * code (unique within the group, e.g. T-001 or BS-001)
  * purchase date
  * assigned storage area
  * bait station type if creating a bait station (Other requires sub-type description)
  
  Given a Group Coordinator submits with a duplicate code or missing fields
  When validation fails
  Then the form remains open with entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given a new asset is successfully created
  Then the asset detail page opens showing:
  
  * code and type in the header
  * status: In storage (grey dot)
  * current location: selected storage area
  * available actions: Deploy to Line / Send for Repair / Retire
  * history: "Added to inventory by [user] at [time]"
  And a map showing the storage area location if coordinates are available

### (US38) As a Group Coordinator, I want to change the status and location of a trap or bait  station (deploy, return to storage, or send for repair) so that inventory records always reflect the current state of each asset.
- Given a Group Coordinator navigates to the inventory page
  Then assets are displayed in four tabs:
  🟢 Active / ⚫ In Storage / 🟠 Under Repair / 🔴 Retired
  And each tab shows the asset count
  And assets automatically move to the correct tab when status changes
  And each asset shows:
  
  * code
  * type
  * current location (line name or storage area name)
  And clicking an asset opens its detail page
  
  Given a Group Coordinator opens an asset detail page
  Then the header shows:
  
  * code and type
  * current status as a colour dot
  * current location: line name or storage area name
  And if the asset is in the field, the map shows its position on the line
  And if the asset is in storage, the map shows the storage area location
  And action buttons depend on current status:
  
  Active (in field) →
  
  * Return to Storage
  * Send for Repair
  * Retire
  
  Under Repair (in field) →
  
  * Mark as Fixed (→ Active)
  * Return to Storage
  * Retire
  
  In Storage →
  
  * Deploy to Line (→ Active)
  * Send for Repair
  * Retire
  
  Retired (in field) →
  
  * Return to Storage
  
  Given a Group Coordinator clicks Deploy to Line
  When they select a line and confirm
  Then status → Active (🟢)
  And asset appears on group map on that line
  And history records the change with performed by and timestamp
  
  Given a Group Coordinator clicks Return to Storage
  When they select a storage area and confirm
  Then status → In Storage (⚫)
  And asset is removed from group map
  And storage area contents update immediately
  And history records the change
  
  Given a Group Coordinator clicks Send for Repair
  When they confirm
  Then status → Under Repair (🟠)
  And asset remains on group map at current location
  And marker colour updates to orange
  And history records the change
  
  Given a Group Coordinator clicks Mark as Fixed
  When they confirm
  Then status → Active (🟢)
  And asset remains on group map at current location
  And marker colour updates to green
  And history records the change
  
  Given a Group Coordinator clicks Retire
  When they confirm
  Then status → Retired (🔴)
  And asset marker turns red on group map
  And marker is hidden by default
  And can be shown via layer toggle
  And history records the change

### (US39) As a Group Coordinator, I want to retire a trap or bait station so that permanently decommissioned equipment is removed from active inventory while its historical records remain accessible.
- Given a Group Coordinator clicks Retire on an asset detail page
  When they confirm
  Then status → Retired (🔴)
  And the asset marker turns red on the group map
  And the marker is hidden by default
  And can be shown via the Retired layer toggle
  And no action buttons remain except Return to Storage
  
  Given a retired asset is still in the field
  When a Group Coordinator clicks Return to Storage
  Then status → In Storage
  And the asset is removed from the group map
  And they must select a storage area
  
  Given a trap or bait station is retired
  Then all associated records remain visible but cannot be edited
  And no new records can be added
  
  Given a retired asset has an active line sponsorship
  When it is retired
  Then the sponsor is notified
  And their subscription is automatically paused
  And they are given the option to redirect to another active line
  
  Given a Group Coordinator views a retired asset
  Then the full history timeline remains visible
  And a note is shown: "This asset has been retired"

### (US40) As an Operator, I want to update the status  and record the movement of a trap or bait station during field operations so that inventory records reflect day-to-day changes accurately.
- Given an Operator opens an asset detail page
  Then they can see:
  
  * current status dot and location
  * map showing asset's current position
  And available actions depend on current status:
  
  Active (in field) →
  
  * Return to Storage
  * Send for Repair
  
  Under Repair (in field) →
  
  * Mark as Fixed (→ Active)
  * Return to Storage
  
  In Storage →
  
  * Deploy to Line (→ Active)
  
  Given an Operator clicks an available action and confirms
  Then status and location update immediately
  And the map marker updates accordingly
  And the history timeline records the change with performed by and timestamp
  
  Given an Operator views a retired asset
  Then no action buttons are visible
  And all records are read-only
  
  Given an Observer is logged in
  Then no inventory actions are visible in their interface

### (US41) As a Group Coordinator, I want to track  bait and toxin stock levels and receive alerts when stock falls below a threshold so that supplies never run out unexpectedly.
- Given a Group Coordinator or Operator views the bait stock page
  Then only Low and Out of Stock items are shown by default:
  
  * 🟠 Low: below threshold, highlighted
  * 🔴 Out of Stock: zero remaining, prominently flagged
  And a "View all stock" toggle shows OK items in a muted style
  
  Given all stock levels are OK
  Then a single message is shown: "All supplies are sufficiently stocked"
  And no individual items are listed unless "View all stock" is toggled
  
  Given a Group Coordinator sets a threshold for a bait type
  When they save
  Then the system monitors stock automatically
  And status updates immediately when levels change
  
  Given stock falls below threshold or reaches zero
  Then the Group Coordinator receives an in-system notification
  And the item appears in the default view immediately
  
  Given a Group Coordinator or Operator records bait added or removed
  When they save
  Then stock level and status update immediately
  
  Given an Operator views the bait stock page
  Then they can update stock levels
  And they cannot edit thresholds

### (US42) As a Group Coordinator, I want to view the full history of any trap or bait station including all status changes, movements, and the user who performed each action so that accountability is maintained.
- Given a Group Coordinator views an asset detail page
  Then the history timeline is shown at the bottom
  And entries are listed in reverse chronological order
  And each entry shows:
  
  * action performed
  * from location → to location
  * performed by
  * date and time
  
  Given a Group Coordinator filters the history timeline
  When they filter by action type or date range
  Then only matching entries are shown
  And a clear "no results" message is shown if nothing matches
  
  Given an asset has no history beyond creation
  Then the timeline shows only:
  "Added to inventory by [user] at [time]"

### (US43) As a Super Admin, I want to view inventory records across all groups so that I have platform-wide oversight of equipment and supplies.
- Given a Super Admin views the inventory section
  Then they can see inventory records from all groups
  And they can filter by group, status or asset type
  And any changes are logged with a Super Admin flag
  And a warning is shown: "Day-to-day inventory management should be performed by Group Coordinators"
  
  Given a Group Coordinator views the inventory section
  Then they can only see inventory records belonging to their own group
  And records from other groups are not accessible or visible
  
  Given an Operator views the inventory section
  Then they can only see inventory records belonging to their own group
  And they cannot modify group-level settings
  
  Given an Observer is logged in When they view any page of the platform Then the inventory section is not visible in the navigation menu And no inventory-related links or buttons are displayed to them

### (US44) As a group member, I want to view the inventory status of each trap and bait station on the map so that I can quickly identify active and inactive assets in the field.
- Given a group member views the group map
  Then asset markers are displayed as circles with white borders
  And marker colour indicates status:
  🟢 Green: active and deployed
  🟠 Orange: under repair
  🔴 Red: retired (hidden by default)
  And In Storage assets are not displayed on the map
  
  Given a group member clicks on a marker
  When the asset detail popup opens
  Then the current inventory status is displayed
  And the last status change date and the user who made the change are shown
  
  Given a Group Coordinator updates an asset's inventory status
  When the change is saved
  Then the map marker colour updates immediately without page refresh
  
  Given an asset is marked as retired
  When the map is viewed
  Then the retired asset marker is hidden by default
  And can be shown via a "Show retired assets" toggle

### (US45) As a Group Coordinator, I want to view inventory analytics including device activity rates and maintenance frequency so that I can make informed procurement and operational decisions.
- Given a Group Coordinator views the inventory analytics section
  Then they can see:
  
  * total devices by status (Active / In Storage / Under Repair / Retired)
  * device activity rate per line
  * average time between maintenance events
  * most frequently repaired device types
  * stock level trends for Low and Out of Stock items over time
  
  Given a Group Coordinator applies a filter by date range
  Then all metrics update to reflect the selected period
  
  Given a device has been repaired more than a threshold number of times
  Then that device is highlighted as a candidate for retirement
  
  Given a Super Admin views inventory analytics
  Then they can see cross-group inventory metrics
  And compare device activity rates between groups

