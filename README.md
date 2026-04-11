# QuickComm

A comprehensive Quick Commerce application suite including a customer app, a rider app, an administrative dashboard, and a robust backend.

## Project Structure

This repository is structured as a monorepo containing multiple interconnected applications and services:

*   **`apps/user_app`**: A Flutter mobile application for end-users to browse products, place orders, and track deliveries with real-time road routing.
*   **`apps/delivery_app`**: A Flutter mobile application for delivery riders to receive assigned orders, update order statuses, and broadcast their real-time location.
*   **`apps/admin_panel`**: A React + Vite web dashboard for administrators to monitor live orders, track riders on a map, and manage the product catalog.
*   **`backend`**: A FastAPI Python backend that provides APIs for complex business logic, routing, and system health checks.
*   **`supabase`**: Contains configuration and SQL migrations for the Supabase project, handling the PostgreSQL database, real-time channels, and edge functions.

## Getting Started

### Prerequisites
*   Node.js & npm (for the React Admin Panel)
*   Python 3.8+ (for the FastAPI Backend)
*   Flutter SDK (for User and Delivery Mobile Apps)
*   Supabase Account and Project

### Running the Services

Detailed startup commands can be found in `instructions.txt`.

#### 1. Backend (FastAPI)
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

#### 2. Admin Panel (React/Vite)
```bash
cd apps/admin_panel
npm install
npm run dev
```

#### 3. Mobile Apps (Flutter)
```bash
# Start the User application
cd apps/user_app
flutter run

# Start the Delivery rider application
cd apps/delivery_app
flutter run
```

*Note: For wireless debugging on Android devices, use `adb pair [IP_ADDRESS]` and `adb connect [IP_ADDRESS]`.*
