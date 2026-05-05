Sprint 3 Requirements

Create a system that maintains an inventory of traps, bait stations, and bait supplies for each group. Traps and bait stations are added to the inventory when first purchased and may later be installed on a line, returned to storage, sent for repair, or retired when damaged or permanently removed from service. Each trap and bait station has a status (for example: active, in storage, under repair, or retired).

Each group has designated and identifiable storage areas, which are recorded within the system. The system records the current location of each trap and bait station, including whether it is in storage (and which storage area) or deployed in the field.

The system tracks storage levels, locations, and usage of bait station toxins and trap baits, and sends alerts when stock is low or reaches a specified threshold.

The inventory management system maintains accurate and up-to-date records for each group.
Inventory records are group-specific and are not visible to other groups.

Where traps and bait stations are moved, deployed, or retired, the system records when changes occur and which user performed the action, to support accountability and auditing.

Inventory management is controlled through role-based access:

- The Group Coordinator is responsible for overall management and oversight of the group’s
inventory, including adding or retiring traps and bait stations and managing storage areas.
- Operators can update and maintain inventory records as part of day‐to‐day operations (for
example, recording deployment, movement, or use of traps and bait).
- An Observer cannot view inventory information.
- A Super Admin role exists for the overall system. The Super Admin has site-wide access to
all groups and inventory records for oversight and administration but does not generally
manage day-to-day inventory operations within individual groups (unless required).

When a trap or bait station is retired or removed from service, all associated trap catches and bait stations monitoring records remain active and accessible (but not editable) within the system.