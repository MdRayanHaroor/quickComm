# QuickComm → Supermarket/Kirana Upgrade

This folder contains all planning documents for the evolution of QuickComm from a single-restaurant delivery system into a full-featured **quick-commerce platform** for supermarkets and kirana stores (Blinkit/Zepto-style).

## Documents

| File | Purpose |
|---|---|
| [`00_current_state_audit.md`](./00_current_state_audit.md) | Deep audit of the existing codebase — what exists, what's broken, what's missing |
| [`01_db_schema_design.md`](./01_db_schema_design.md) | Complete new DB schema design with ERD, rationale, and migration strategy |
| [`02_backend_api_plan.md`](./02_backend_api_plan.md) | All new/updated FastAPI endpoints, Pydantic models, and storage strategy |
| [`03_admin_panel_ui_plan.md`](./03_admin_panel_ui_plan.md) | Phase-by-phase UI redesign plan for the admin panel (Blinkit-style) |
| [`04_user_app_plan.md`](./04_user_app_plan.md) | Flutter user app upgrade plan |
| [`05_rider_app_plan.md`](./05_rider_app_plan.md) | Rider app changes for supermarket context |
| [`06_execution_phases.md`](./06_execution_phases.md) | Master execution order — what to build in what order |

## Quick Reference: Execution Order

```
Phase 1 → DB Migration (new schema)
Phase 2 → Backend API (categories, products, variants, inventory)
Phase 3 → Admin Panel redesign + Product CRUD
Phase 4 → User App upgrade (browse, search, cart)
Phase 5 → Rider App changes
Phase 6 → Polish & production hardening
```
