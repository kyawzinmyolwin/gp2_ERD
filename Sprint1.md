## Sprint 1 - Required Epic

### REQUIRED EPIC
- #  Rename the web application and create a multi conservation group application
  
  Rework the application so that it can be used by multiple different conservation groups (e.g.
  
  Darfield Possum Catch Group, West Melton Predator-Free, Springston conservation Group
  
  etc) so that each conservation group can have their separate ‘group site’:
  
  a. Rename the Web Application (its name should not relate to PF-LU).
  
  b. Create a new Home Page with a new revamped style and colour scheme. Groups can
  
  be either Public or Private. Public groups should be discoverable by browsers, with a
  
  tile/image and short information description. Private groups are visible but can only be
  
  accessed with permission.
  
  c. Users have a single login and password. If they belong to multiple groups, a successful
  
  login will prompt them to select which group they want to access.
  
  d. Upon login, they will go to the selected group’s site.
  
  #  Expand the system beyond its current Trap Lines to include Bait Station Lines
  
  a. b. Please see the additional data requirements listed earlier in this brief.
  
  Include all similar functionality as for Trap Lines for Bait Stations.
  
  #  Rework and enhance the System Roles and Access Control component
  
  a. Roles will be Super Admin, Group Coordinator, Operator and Observer. There is no
  
  longer an ‘Administrator role’.
  
  b. Super Admin Role
  
  The Super Admin has full system-level access and is responsible for the high-level
  
  management of the platform. Their responsibilities include:
  
   Creating and managing groups.
  
   Appointing Group Coordinators for each group.
  
   Managing the group information and group tile/image on the Home Page.
  
   Reviewing and approving (or rejecting) applications from users who wish to
  
  form new groups.
  
   To maintain accurate records compatible with [http://Trap.nz|http://Trap.nz|smart-link] , (Note: The Super
  
  Admin manages data records such as species name, trap name, bait names
  
  etc.)
  
  c. Group Coordinator Role
  
  A Group Coordinator oversees the activities and membership of a specific conservation
  
  group. Their responsibilities include:
  
   Creating and managing lines for their assigned group.
  
   Creating and managing traps and bait stations records for their assigned
  
  group.
  
   Assigning Operators to Lines.
  
   Set a group to Public or Private. (If Public, any user can join as an Observer,
  
  For Private, Observer needs to request to join).
  
   Approving or rejecting requests to join a Private group.
  
  6Notes:
  
   Multi-conservation group membership: Users may belong to multiple conservation
  
  groups and could have different roles in each group. E.g. I could be an observer in group A,
  
  an observer in group B, and a coordinator in group C.
  
   Group Creation: Users may apply to form new conservation groups. These applications
  
  must be reviewed and approved by the Super Admin. If approved, the participant may be
  
  appointed as the Group Coordinator (subject to Super Admin confirmation).

### (US1) As a visitor, I want to view a homepage showing all conservation groups so that I can discover groups and understand whether they are public or private.
- Given a visitor opens the homepage
  Then they can see all conservation groups listed
  And each public group displays a tile/image and short description
  And private groups are visible but marked as
  "Apply to Join" instead of being directly accessible
  And the page uses a new visual style and colour scheme
  unrelated to PF-LU
  
  Given that a visitor opens the homepage, when the page loads, they should see a list of all conservation groups.
  
  Given that conservation groups are displayed on the homepage, when a group is public, it should display a tile or image along with a short description.
  
  Given that conservation groups are displayed on the homepage, when a group is private, it should still be visible but marked as *“Apply to Join”* instead of being directly accessible.
  
  Given that a visitor views the homepage, when the page is rendered, it should use a new visual style and colour scheme that is unrelated to PF‑LU.

### (US2) As a visitor, I want to view a public group's detail page so that I can learn more about their activities before deciding to join.
- Given a visitor clicks on a public group on the homepage
  Then they can see the group name, logo, full description,
  operational area description and public activity information
  And they can see an option to join the group
  
  Given a visitor tries to access a private group
  When they click on the private group
  Then they are directed to an application page
  And they can submit a request to join the group
  And they are informed their request is pending approval

### (US3) As a user, I want to log in with a single account so that I can access all groups I belong to without separate credentials.
- Given a registered user enters their username and password
  When they submit the login form
  Then they are authenticated into the system
  And their session is established
  And they are redirected to the group selection page
  if they belong to multiple groups
  
  Given a user enters incorrect credentials
  When they submit the login form
  Then they see an error message
  And they are not granted access
  And their credentials are not exposed in the error message
  
  Given a user has forgotten their password
  When they click the forgot password link on the login page
  Then they are prompted to enter their registered email address
  And they receive a password reset email with a secure link
  And the link expires after a set time for security
  
  Given a user clicks the password reset link
  When the link is still valid
  Then they are directed to a page to set a new password
  And upon success they are redirected to the login page
  And the old password is no longer valid
  
  Given a user clicks an expired password reset link
  When they attempt to use it
  Then they are shown a message that the link has expired
  And they are given the option to request a new reset email
  
  Given a user wants an alternative login method
  When they choose "Login with Email Code"
  Then they enter their registered email address
  And they receive a 6-digit verification code
  And the code expires after 10 minutes
  And upon entering the correct code
  they are logged in successfully
  
  Given a user enters an incorrect or expired verification code
  When they submit the code
  Then they see an error message
  And they are given the option to request a new code

### (US4) As a user, I want to select which group to access after login so that I am directed to the correct group site.
- Given a user belongs to multiple groups
  When they successfully log in
  Then they are prompted to select which group
  they want to access
  And each group is listed with its name, logo
  and the user's role in that group
  
  Given a user selects a group
  When they confirm their selection
  Then they are directed to that group's site and dashboard
  
  Given a user belongs to only one group
  When they successfully log in
  Then they are directed straight to that group's site
  without being prompted to select
  
  Given a user is not a member of any group
  When they successfully log in
  Then they are directed to a page informing them
  they do not belong to any group yet
  And they are given the option to browse public groups
  or apply to create a new group

### (US5) As a user, I want to apply to create a new conservation group so that my group can use the platform.
- Given a logged-in user wants to create a new group
  When they submit a group creation application
  Then the application is sent to the Super Admin for review
  And the user receives confirmation that their application is pending
  
  Given a user submits a group creation application
  When they fill in the form
  Then they must provide a group name, description,
  and whether the group will be public or private
  
  Given a user's group creation application has been rejected
  When they choose to resubmit
  Then their original form is pre-filled with previous answers
  And they can edit specific fields based on the rejection reason
  And resubmit for Super Admin review

### (US6) As a Super Admin, I want to review group creation applications and appoint a Group Coordinator upon approval so that new groups are properly set up from the start.
- Given a user has submitted a group creation application
  When the Super Admin views the pending applications list
  Then they can see each application's group name, description, public/private setting, and applicant information
  And they can choose to approve or reject each application
  
  Given a Super Admin approves a group creation application
  When approval is confirmed
  Then the new group is created on the platform
  And the Super Admin is immediately prompted to appoint the applicant as Group Coordinator
  And if confirmed, the applicant is assigned the Group Coordinator role for that group
  And the applicant receives a single notification confirming both the approval and their appointment
  
  Given a Super Admin approves an application but chooses not to appoint the applicant as GC
  When they skip the appointment step
  Then the group is created with no Group Coordinator assigned
  And the group is flagged in the admin panel as needing a coordinator
  And the Super Admin can return to appoint one at any time
  
  Given a Super Admin rejects a group creation application
  When rejection is confirmed
  Then the group is not created
  And the applicant is notified of the rejection with a reason provided by the Super Admin
  And the applicant's original form is pre-filled for editing when they choose to resubmit

### (US7)As a Group Coordinator, I want to create a line with a name, type, colour and optional map path so that assets are spatially organised and visible on the group map.
- Given a Group Coordinator clicks Create on the Trap / Bait Station Lines tab
  When the form opens
  Then it is pre-set to that line type with no type selection required
  And they must provide:
  
  * a unique line name within the group
  * a colour for map display
  And the form cannot be submitted until both fields are filled
  
  Given a Group Coordinator submits the form with a duplicate line name or missing fields
  When validation fails
  Then the form remains open with all previously entered values intact
  And each invalid field is highlighted with a specific error message
  And no data is saved until all errors are resolved
  
  Given a user who is not a Group Coordinator is logged in
  When they view any page
  Then no option to create a line is visible

### (US8) As a Group Coordinator, I want to edit and retire lines so that line information stays accurate and inactive lines are reflected correctly on the map.
- Given a Group Coordinator opens an existing line
  When they choose to edit
  Then the form is pre-filled with current values
  And they can update:
  
  * line name (must remain unique within the group)
  * colour
  
  Given a Group Coordinator submits edits with a duplicate name or missing fields
  When validation fails
  Then the form remains open with all previously entered values intact
  And each invalid field is highlighted with a specific error message
  And no data is saved until all errors are resolved
  
  Given a Group Coordinator clicks Retire on a line
  When they confirm
  Then the line status becomes retired
  And it disappears from the active line list
  And all Operators assigned to that line are notified automatically
  
  Given a line is retired
  When viewed in history or admin mode
  Then all historical records remain readable but cannot be edited
  And no new records can be added to assets on that line

### (US9) As a Group Coordinator, I want to assign Operators to lines so that responsibilities are clearly defined.
- Given a Group Coordinator assigns an Operator to a line
  When they submit
  Then only same-group Operators appear in the selection list
  And lines already assigned to that Operator are not shown in the selection list
  And the assignment appears immediately
  And the Operator receives a Line Assignment badge notification
  And they can choose to display or hide the badge on their profile
  
  Given a Group Coordinator removes an Operator from a line
  When confirmed
  Then the Operator loses edit permissions immediately
  And their previously submitted records remain unchanged
  
  Given a line is retired
  When retirement is confirmed
  Then all Operator assignments for that line are removed automatically

### (US10) As a group member, I want to view all lines and the assets on each line so that I can understand the layout of the network.
- Given a group member opens the line list
  When the page loads
  Then lines are displayed in two tabs: Trap Lines and Bait Station Lines
  And each line shows its name and colour
  
  Given a group member opens a line detail
  When the page loads
  Then all associated traps / bait stations are listed in their set order
  And each asset shows its code and current status
  
  Given a line has no assets
  When the page loads
  Then a clear empty-state message is displayed
  
  Given a group member belongs to multiple groups
  When they view the line list
  Then only lines belonging to their currently selected group are shown
  
  Given a Group Coordinator views a line detail
  When they drag an asset to a new position
  Then the order updates immediately and is saved automatically
  And all group members see the updated order on their next view

### (US11) As a Group Coordinator, I want to create bait stations on a line so that bait assets can be tracked.
- Given a Group Coordinator opens a Bait Station line detail
  When they click Create Bait Station
  Then they must provide:
  
  * a unique code within the group
  * bait station type (from predefined list)
  * latitude and longitude
  And the form cannot be submitted until all required fields are filled
  
  Given "Other" is selected as the bait station type
  When the form is displayed
  Then a free-text sub-type field becomes required
  
  Given a Group Coordinator submits with a duplicate code or missing/invalid fields
  When validation fails
  Then the form remains open with all previously entered values intact
  And each invalid field is highlighted with a specific error message

### (US12) As a Group Coordinator, I want to edit and retire bait stations so that information stays accurate and inactive stations are removed from active use.
- Given a Group Coordinator opens a bait station
  When they choose to edit
  Then the form is pre-filled with current values
  And they can update:
  
  * bait station type
  * latitude and longitude
  And code cannot be changed
  
  Given a Group Coordinator submits invalid or missing fields
  When validation fails
  Then the form remains open with all previously entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given a Group Coordinator retires a bait station
  When they confirm
  Then the station disappears from active assignment and recording lists
  And no new records can be added
  
  Given a bait station is retired
  When viewed in history or admin mode
  Then all historical records remain readable but cannot be edited

### (US13) As an Operator, I want to add bait station records to the lines I am assigned to so that bait usage and pest activity are tracked.
- Given an Operator opens a bait station on a line they are assigned to
  When they choose to add a record
  Then they must provide:
  
  * date and time (ISO 8601 format)
  * target species
  * active ingredient
  * formulation
  * concentration
  * bait remaining (kg)
  And optional fields:
  * recorded by
  * bait removed (kg)
  * bait added (kg)
  * notes
  And the form cannot be submitted until all required fields are filled
  
  Given an Operator submits invalid or missing required fields
  When validation fails
  Then the form remains open with all previously entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given an Operator is not assigned to a line
  When they view that line's bait stations
  Then no option to add a record is visible
  
  Given a bait station is retired
  When any user views it
  Then no option to add a record is visible
  
  Given an Operator is offline
  When they attempt to add a record
  Then the form is not accessible
  And a message is shown: "You are offline. Records can be added once connection is restored."

### (US14) As an Operator, I want to edit my own bait station records so that any errors can be corrected.
- Given an Operator edit their own bait station record
  They can update any field in that record
  
  Given an Operator submits invalid or missing required fields
  When validation fails
  Then the form remains open with all previously entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given an Operator opens a bait station record submitted by another user
  When they view the record
  Then no edit option is visible
  
  Given a Group Coordinator opens any bait station record in their group
  When they choose to edit
  Then they can update or delete any record regardless of who submitted it
  
  Given an Operator is offline
  When they attempt to add a record
  Then the form is not accessible
  And a message is shown: "You are offline. Records can be added once connection is restored."

### (US15) As a group member, I want to view and filter bait station records so that I can monitor activity over time.
- Given a group member opens the bait station records page
  When the page loads
  Then records are listed in reverse chronological order with pagination
  And each record shows:
  
  * date and time
  * target species
  * active ingredient
  * bait remaining
  * recorded by
  
  Given a group member applies filters
  When they filter by date range / line / station / active ingredient / species
  Then only matching records are shown
  And a clear "no results" message is displayed if no records match
  
  Given a group member clears all filters
  When filters are reset
  Then all records are shown again
  
  Given a group member views bait station records
  When the page loads
  Then only records belonging to their currently selected group are shown

### (US17) As a Super Admin, I want to manage all groups and appoint Group Coordinators so that the platform stays accurate and every group has a designated manager
- Given a Super Admin opens the group management page
  Then all groups are listed with:
  
  * group name
  * public / private status
  * assigned Group Coordinator
  * current member count
  
  Given a Super Admin edits a group's information
  When they save valid changes
  Then updates to name, description, tile image and public/private status are reflected immediately on the homepage
  
  Given a Super Admin submits invalid or missing fields
  When validation fails
  Then the form remains open with entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given a Super Admin appoints a Group Coordinator for a group
  When they confirm the appointment
  Then the selected user is assigned the Group Coordinator role for that group
  And the appointed user is notified
  And the change is logged with actor and timestamp
  
  Given a Super Admin reassigns a Group Coordinator
  When they confirm
  Then the previous Coordinator loses their coordinator permissions for that group
  And both old and new Coordinator are notified
  And the change is logged with actor and timestamp
  
  Given a group has no assigned Group Coordinator
  Then the group is flagged as needing a coordinator

### (US18) As a Super Admin, I want to manage system-level data records so that all groups use consistent and accurate reference data.
- Given a Super Admin opens the reference data management page
  Then they can view and edit:
  
  * species names
  * trap types
  * bait types
  * active ingredients
  
  Given a Super Admin adds a new reference entry
  When they save
  Then the new option appears immediately in relevant forms across all groups
  
  Given a Super Admin edits an existing reference entry
  When they save valid changes
  Then the update is reflected immediately in all forms across all groups
  
  Given a Super Admin submits invalid or missing fields
  When validation fails
  Then the form remains open with entered values intact
  And each invalid field is highlighted with a specific error message
  
  Given a Super Admin deletes a reference entry that is currently in use
  When they attempt to delete
  Then they are warned that existing records reference this entry
  And they must confirm before deletion proceeds
  And existing records that reference it are not broken
  
  All reference data changes are logged with actor and timestamp

### (US19) As a Group Coordinator, I want to set my group as public or private so that access is appropriately controlled.
- Given a Group Coordinator opens their group settings
  When they toggle the group to Public
  Then any logged-in user can join as an Observer without approval
  And the group tile and description are discoverable on the homepage
  
  Given a Group Coordinator toggles their group to Private
  When they save
  Then new users must submit a join request for approval
  And the group remains visible on the homepage but marked as "Apply to Join"
  
  Given a group is switched from Public to Private
  When the change is saved
  Then existing members retain their current roles
  And the visibility change takes effect immediately
  And the change is logged with actor and timestamp

### (US20) As a Group Coordinator, I want to review and approve or reject requests to join my private group so that membership is controlled.
- Given a Group Coordinator opens their pending join requests
  Then each request shows:
  
  * applicant username
  * request message
  * date submitted
  
  Given a Group Coordinator approves a join request
  When they confirm
  Then the user is added to the group as an Observer
  And the user is notified of their approval
  
  Given a Group Coordinator rejects a join request
  When they confirm
  Then the user is not added to the group
  And the user is notified of the rejection with a reason
  And the user's original request is pre-filled for editing if they choose to resubmit
  
  Given a public group has no pending requests
  Then the join request section is not visible to the Group Coordinator

### (US21) As a Group Coordinator, I want to manage member roles within my group so that each member has appropriate permissions.
- Given a Group Coordinator opens their group's member list
  Then members are displayed in three tabs: Coordinators / Operators / Observers
  And each member shows their name and join date
  And promote / demote buttons are visible next to each member
  
  Given a Group Coordinator is the only Coordinator in the group
  Then the demote button for that member is disabled
  
  Given a Group Coordinator promotes an Observer to Operator or demotes an Operator to Observer
  When they confirm
  Then the member's permissions update immediately
  And the member is notified of their new role
  And the change is logged with actor and timestamp
  
  Given a Group Coordinator removes a member from the group
  When they confirm
  Then the member loses access to the group immediately
  And their previously submitted records remain intact
  
  Given a Group Coordinator views their own member entry
  Then no option to remove themselves is visible

