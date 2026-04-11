# AI Context & Progress Tracking

This folder (`.ai_context`) and this document are designed to store technical context, architectural decisions, and tasks in progress to assist AI tools in understanding the repository.

## Current State & Recent Accomplishments

*   **Realtime Tracking & OSRM Routing:** 
    *   The `user_app` currently successfully listens to Supabase Realtime Channels to fetch live location updates from the delivery rider.
    *   The map UI replacing straight-line paths with proper road-following polylines fetched via the Open Source Routing Machine (OSRM) API. 
    *   Poyline geometry logic has been stabilized.
*   **Monorepo Application Suite:**
    *   We have a FastAPI backend, a React `admin_panel` for overarching management, a Flutter `user_app` and a Flutter `delivery_app`. 

## Ongoing Tasks / Scratchpad
*(Use this section to outline the current feature being worked on, known bugs, or upcoming refactors)*

*   [x] Add road-route decoding in the User Flutter App.
*   [ ] (Add next technical requirements or open bugs here)

## Architecture Notes
*   **Database:** Supabase PostgreSQL.
*   **Auth/Realtime:** Handled by Supabase SDKs across React and Flutter apps.
*   **Maps:** 
    *   React Admin Panel uses `react-leaflet`.
    *   Flutter Apps use `flutter_map` accompanied by `latlong2`.
