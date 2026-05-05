### Sprint2_LOCATION_FEATURES

Predator Free activities are inherently location‐based. Traps, bait stations, monitoring areas, and group operations all take place in specific physical environments such as reserves, farmland, urban green spaces, and forests.

This epic introduces interactive, map‐based features that allow users to define operational areas and manage predator control assets spatially. These features improve accuracy, usability, and situational awareness while keeping all tools free and open‐source.

1. Group Operational Area
- Each group has one defined operational area.
- A group coordinator can:
    - Define the group’s area by drawing boundaries on a map.
    - Edit or update the boundaries at any time.
- All group members can:
    - View the group’s operational area on a map.
- Assumptions
    - One group corresponds to a single area.
    - Operational areas are for visualisation and context only (no enforcement logic of
lat/long co-ordinates is required)

2. Trap and Bait Station Location Management
- Each trap and bait station already has recorded latitude and longitude values.
- This epic enhances these records with map-based interaction:

- Create (Group Coordinator)
    - Place traps or bait stations by clicking on a map.
    - This is an alternative to manually entering latitude and longitude.
- Edit (Group Coordinator)
    - Update a trap or bait station’s position using the map.
- View (All group members)
    - Traps and bait stations are displayed as markers on a map.
    - Selecting a marker shows relevant record details.

3. Implementation Notes (for Students):
- Use Leaflet.js with OpenStreetMap – this is free and works well with PythonAnywhere.
- Store coordinates in a standard format (latitude/longitude), and allow reverse lookups (e.g., showing location names in tooltips or map pins).
- Create a reusable map component.
- Cache frequently used map data where possible for better performance.

Note: Only use free frameworks to add location features. Do not use frameworks that require
commercial API keys. Make sure whatever you use works with PythonAnywhere. We strongly
recommend using OpenStreetMap with the open-source JavaScript library Leaflet. A good

tutorial for using Leaflet with Flask is available at https://medium.com/geekculture/how-to-
make-a-web-map-with-pythons-flask-and-leaflet-9318c73c67c3