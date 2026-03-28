# Blacklist Remover — Frontend

Vue 3 SPA for managing network device (MAC address) blacklists with role-based access control.

## Features

- View and remove blocked MAC addresses (table view with pagination and search)
- MAC deletion history with filters by user, date, MAC, reason
- User authentication via Basic Auth
- Role-based access: **USER** and **ADMIN**
- Admin panel: manage users (add, edit, enable/disable)
- Responsive navbar with mobile hamburger menu
- Toast notifications, pagination, search/filter

## Tech Stack

- **Vue 3** + Vite
- **Vue Router** with auth and role navigation guards
- **Axios** with Basic Auth interceptors
- **Tailwind CSS** + PrimeIcons
- **Vue Toastification**

## Getting Started

### Prerequisites

- Node.js 18+
- Backend API running (see `blacklistremover-backend` repo)

### Install dependencies

```sh
npm install
```

### Run development server

```sh
npm run dev        # App on http://localhost:3000, proxies /api → localhost:8080
npm run server     # Mock API on http://localhost:8000 (json-server)
```

The dev proxy is configured in `vite.config.js` (section `server.proxy`).

### Build for production

```sh
npm run build
npm run preview
```

For production builds the `deploy.sh` script automatically swaps `vite.config.js`
with `vite.config.prod.js` (no dev server / proxy section) before building.

## Production Deployment

Deployment is handled by `deploy.sh` in this repository.
It builds the frontend, copies static files to Nginx, and optionally builds and deploys the backend.

```bash
./deploy.sh configure   # set ports, DB credentials, WLC settings → saved to .deploy.conf
./deploy.sh setup       # first-time: install deps, configure Nginx + systemd
./deploy.sh full        # build and deploy backend + frontend
./deploy.sh frontend    # frontend only
./deploy.sh backend     # backend only
./deploy.sh status      # show service and Nginx status
```

Configuration is stored in `.deploy.conf` (not committed — contains secrets).

## Project Structure

```
src/
├── api/          # Axios instances and endpoint modules
├── composables/  # useAuth, useMacAddresses — reactive singleton state
├── services/     # Auth service (login, logout, Basic Auth logic)
├── router/       # Routes with auth and role guards
├── views/        # Page-level components
└── components/   # Reusable UI components (Navbar, etc.)
```

## Authentication

Uses HTTP Basic Auth. Credentials are stored in `localStorage` and injected into every
request via Axios interceptors (`src/api/instance.js`).
On production the frontend is served by Nginx, which proxies `/api/` to the Spring Boot backend.
