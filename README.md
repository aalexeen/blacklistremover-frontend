# Blacklist Remover

Web application for managing network device (MAC address) blacklists with role-based access control.

## Features

- View and remove blocked MAC addresses
- User authentication via Basic Auth
- Role-based access: **USER** and **ADMIN**
- Admin panel: manage users (add, edit, view)
- Toast notifications, pagination, search/filter

## Tech Stack

- **Vue 3** + Vite
- **Vue Router** with navigation guards
- **Axios** for HTTP requests
- **Tailwind CSS** + PrimeIcons
- **Vue Toastification**

## Getting Started

### Prerequisites

- Node.js 18+
- Backend API running on port `8080` at `/api/`

### Install dependencies

```sh
npm install
```

### Run development server

```sh
npm run dev        # App on http://localhost:3000
npm run server     # Mock API on http://localhost:8000 (json-server)
```

### Build for production

```sh
npm run build
npm run preview
```

## Project Structure

```
src/
├── api/          # Axios instances and endpoint modules
├── composables/  # useAuth, useMacAddresses — reactive state
├── services/     # Auth service (login, logout, Basic Auth logic)
├── router/       # Routes with auth and role guards
├── views/        # Page-level components
└── components/   # Reusable UI components
```

## Authentication

Uses HTTP Basic Auth. Credentials are stored in `localStorage` and injected into every request via axios interceptors. The backend is expected at `http://<host>:8080/api/`.
