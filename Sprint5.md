## Sprint 5 - Donations & Support

### (US57) As a supporter, I want to provide my contact details and choose whether to remain anonymous so that I can receive a receipt and control my privacy.
- Given a supporter is completing
  a donation
  When they access more options
  Then they can provide:
  
  * Their name (optional unless
  tax receipt is requested)
  * Contact email address
  * An optional message of support
  * Anonymous donation preference
  
  Given a supporter requests a tax receipt
  When they tick the tax receipt option
  Then their name becomes a required field
  And they cannot proceed without
  providing their name
  
  Given a supporter chooses
  anonymous donation
  When the donation is submitted
  Then their name is flagged as anonymous
  And no receipt is generated or sent
  And the system confirms no receipt
  will be issued for anonymous donations
  
  Given an anonymous donation is made
  When the group's donation summary is viewed
  Then the donation amount is included
  in the total
  But the donor's name is not displayed
  anywhere on the platform

### (US56) As a supporter, I want to make a donation quickly with minimal steps so that I can contribute without feeling overwhelmed by choices.
- Given a visitor clicks any donation button
  When the donation page loads
  Then they see a simple amount selector
  ($5, $10, $20, $50, custom amount)
  And a single email field for receipt
  And a pay now button
  And no mandatory type selection required
  
  Given a visitor arrives from
  a specific group page
  When the donation page loads
  Then the group is automatically pre-selected
  And displayed as context:
  "Supporting [Group Name]"
  And the visitor can change this if desired
  
  Given a supporter wants more options
  When they click "More options"
  Then they can:
  
  * Dedicate to a specific group
  * Switch to Platform Support
  * Set up monthly giving
  * Request tax receipt
  * Add a message of support
  * Choose anonymous donation
  
  Given a supporter completes payment
  When the transaction is confirmed
  Then donation type is automatically set:
  
  * Group Donation if a group was selected
  * General Support if no group selected
  * Platform Support if explicitly chosen
  And they are directed to the
  mystery box reveal page

### (US58) As a supporter, I want to complete my donation through a secure online checkout so that my payment is processed safely.
- Given a supporter has entered
  their donation amount
  When they click pay now
  Then they are directed to a
  Stripe checkout page
  And the donation amount and
  group information are pre-filled
  
  Given a supporter completes
  payment on Stripe checkout
  When the transaction is successful
  Then Stripe sends a webhook event
  to the system
  And the system verifies the
  webhook signature
  And the donation record is created
  And the supporter is directed to
  the mystery box reveal page
  
  Given a supporter's payment fails
  on Stripe checkout
  When the transaction is unsuccessful
  Then they are notified of the failure
  And they are given the option to
  try again
  And no donation record is created
  
  Given a supporter abandons
  Stripe checkout
  When they leave without completing payment
  Then no donation record is created
  And their details are not stored
  
  [TEST MODE NOTE]
  During development and demonstration:
  Stripe test mode is used
  No real transactions are processed
  Test card: 4242 4242 4242 4242

### (US59) As a supporter, I want my receipt to clearly indicate whether my donation is eligible for a New Zealand tax credit.
- Given a donation is made to a group
  with registered charitable status
  When the receipt is generated
  Then the receipt includes:
  
  * The charity's registered name
  * Charity registration number
  * Donation amount and date
  * A statement confirming the donation
  is a voluntary gift
  And a note:
  "You may be eligible to claim 33.33%
  of this donation as a tax credit.
  Submit this receipt to IRD via IR526
  within 4 years of donation date."
  
  Given a donation is made to a group
  without registered charitable status
  When the receipt is generated
  Then the receipt clearly states:
  "This organisation is not an IRD-approved
  donee organisation. This donation is not
  eligible for a New Zealand tax credit."
  
  Given a Platform Support donation is made
  When the receipt is generated
  Then the receipt indicates whether
  the platform holds IRD donee status
  And includes the same tax credit
  information if applicable
  
  Given a General Support donation is made
  When the receipt is generated
  Then the receipt indicates
  tax credit eligibility
  based on the platform's donee status
  
  Given a donation is anonymous
  When the payment is confirmed
  Then no receipt is generated
  And the donor is informed they cannot
  claim a tax credit without a receipt

### (US60) As a supporter, I want to receive a donation receipt via email or download it from the platform so that I have a record of my contribution.
- Given a supporter completes a
  non-anonymous donation
  When the payment is confirmed
  Then the system automatically generates
  a donation receipt
  And sends it to their provided email
  
  Given a receipt is generated
  When the supporter views their
  confirmation page
  Then they can also download
  the receipt as a PDF
  
  Given a supporter requests a resend
  When they access their donation history
  Then they can resend the receipt
  to their registered email address
  
  Given a donation is anonymous
  When the payment is confirmed
  Then no receipt is generated or sent

### (US61) As a visitor, I want to easily find donation links on public group pages and in the navigation menu so that I can support conservation groups with minimal effort.
- Given any user or visitor views
  any page of the platform
  When the navigation menu loads
  Then a donation link is prominently
  displayed in the navigation menu
  
  Given a visitor views a public group page
  When the page loads
  Then a donation button is displayed
  And a brief description of how donations
  support that group's work is shown
  And the total donations received
  by that group is displayed
  
  Given a visitor views a private group page
  When the page loads
  Then no donation link or summary
  is displayed on the group page itself
  And the donation link is only accessible
  via the navigation menu
  
  Given a visitor clicks a group page
  donation button
  When they are directed to the donation page
  Then that group is automatically pre-selected

### (US62) As a Group Coordinator, I want to view donation summaries and receipts for my group so that I can monitor financial support and acknowledge donors.
- Given a Group Coordinator views
  their group's donation section
  When the page loads
  Then they can see:
  
  * Total donations received
  * Donation history with dates and amounts
  * Access to generated receipts
  * Optional supporter messages
  
  Given a Group Coordinator views
  donation history
  When they apply filters
  Then they can filter by date range
  and donation type
  
  Given an Operator or Observer
  is logged in
  When they view any page
  Then no donation summary, history
  or management options are visible
  in their interface
  
  Given a Group Coordinator views
  donor information
  When a donation was made anonymously
  Then the donor's name is not displayed
  And the amount is still included
  in the total

### (US63) As a Super Admin, I want to view and manage all donation records across the platform so that I can oversee financial activity and ensure accuracy.
- Given a Super Admin views
  the donations section
  When the page loads
  Then they can see all donation records
  across all groups on the platform
  And they can filter by group,
  donation type, and date range
  
  Given a Super Admin views
  a specific donation
  When they select it
  Then they can access the generated receipt
  And view all associated donor information
  where not anonymous
  
  Given a Super Admin views platform totals
  When the donations overview loads
  Then they can see:
  
  * Total platform-wide donations received
  * Breakdown by donation type
  * Breakdown by group

### (US64) As a supporter, I want my name to appear as a sponsor on the line detail page I am supporting so that my contribution is publicly recognised and others are inspired to sponsor.
- nan

### (US65) As a donor, I want to open mystery boxes after donating where the number of boxes is determined by my donation amount so that every contribution feels fair, exciting and rewarding.
- Given a supporter completes any donation
  When they are directed to the
  post-donation page
  Then they receive mystery boxes
  based on their donation amount:
  Every $5 donated = 1 mystery box
  $100+: bonus 1 guaranteed EN box
  $200+: bonus 1 guaranteed CR box
  
  Given a supporter opens a mystery box
  When the animation plays
  Then the species is drawn with
  fixed probabilities:
  
  * LC (Least Concern): 60%
  * NT (Near Threatened): 25%
  * VU (Vulnerable): 10%
  * EN (Endangered): 4%
  * CR (Critically Endangered): 1%
  And every box has the same probability
  regardless of donation amount
  
  Given a Group Donation is made
  When the mystery boxes are opened
  Then only species found within
  that group's operational area
  are included in the draw
  based on GBIF location data
  
  Given a Platform Support or
  General Support donation is made
  When the mystery boxes are opened
  Then species from across all
  of New Zealand are included
  in the draw
  
  Given a supporter has multiple boxes
  When they open them one by one
  Then each box opens with its own
  individual animation
  And their growing collection is shown
  after each reveal
  
  Given a supporter receives a CR reveal
  When the animation completes
  Then a special legendary animation plays
  And the card is marked as
  "Critically Endangered - 1% chance"
  
  Given a supporter donates multiple times
  When they open subsequent boxes
  Then species they have not yet collected
  have slightly higher probability
  to encourage collection completion
  
  Given a supporter receives their species
  When all boxes are opened
  Then they can share on social media:
  "I just discovered [species]
  while supporting NZ conservation! 🌿
  #PredatorFreeNZ"
  
  [TAX CREDIT REMINDER]
  Given a supporter completes a donation
  to a registered charitable group
  When all boxes are opened
  And the reveal page is complete
  Then a friendly reminder is displayed:
  "Your $[amount] donation to [group name]
  may be eligible for a
  $[amount x 0.3333] tax credit!
  Keep your receipt and submit to IRD
  via IR526 within 4 years."
  And a link to IRD's donation
  tax credit page is provided
  
  Given a supporter completes a
  Platform Support or General Support donation
  When the reveal page is complete
  Then the tax credit reminder is shown
  only if the platform holds
  IRD donee status

### (US66) As a visitor, I want to browse trap lines and see which native species they are protecting so that I can choose a line to sponsor that is meaningful to me.
- Given a supporter visits the
  Sponsor a Line page
  When the page loads
  Then they can see all sponsorable lines
  Each line displays:
  
  * Line name and location
  * Native species being protected
  sourced from GBIF based on coordinates
  * Primary predators being targeted
  based on Trap Catch Records
  * Current monthly sponsorship status
  
  Given a supporter selects a line
  When they view its detail
  Then they see a map of the line
  And a list of native species
  in that area with images
  And the predator catch history
  showing conservation impact
  And a "Sponsor this line" button
  
  Given the GBIF API returns
  species data for the line's coordinates
  When the page loads
  Then native species are displayed
  with common names and images
  And attribution reads:
  "Species data sourced from GBIF"

### (US67) As a supporter, I want to set up a monthly donation to sponsor a specific line so that I can provide ongoing support for predator control in that area.
- Given a supporter selects a line
  to sponsor
  When they proceed to set up sponsorship
  Then they can choose a monthly
  donation amount
  And they are shown what their
  monthly contribution supports
  And how many mystery boxes
  they will receive each month
  
  Given a supporter confirms
  their sponsorship
  When they complete the Stripe checkout
  Then a recurring monthly subscription
  is created via Stripe
  And their name appears as sponsor
  on the line detail page
  And they receive a confirmation email
  And they immediately receive their
  first month's mystery boxes
  
  Given a monthly subscription payment
  is processed
  When Stripe confirms the payment
  Then the donation record is updated
  for that month
  And the supporter receives their
  monthly mystery boxes
  And a monthly impact report is sent

### (US68) As a supporter, I want to manage my line sponsorship subscription including pausing or cancelling so that I have full control over my recurring donation.
- Given a supporter views their
  sponsorship dashboard
  When the page loads
  Then they can see their active
  sponsorships with:
  
  * Sponsored line name
  * Monthly amount
  * Start date
  * Next payment date
  * Mystery boxes received to date
  
  Given a supporter wants to pause
  their subscription
  When they select pause
  Then their subscription is paused
  via Stripe
  And their name is temporarily removed
  from the sponsored by section
  And they are notified of the pause
  
  Given a supporter wants to cancel
  their subscription
  When they confirm cancellation
  Then their subscription is cancelled
  via Stripe
  And their name is removed from
  the sponsored by section
  And they receive a cancellation
  confirmation email
  
  Given a supporter wants to resume
  a paused subscription
  When they select resume
  Then their subscription is reactivated
  via Stripe
  And their name reappears on
  the sponsored line page

