// axios base configuration - 1st step
import axios from "axios";

const getBaseURL = () => {
  // Always use a relative path so requests go through Nginx on whatever
  // port the page was loaded from. Nginx proxies /api/ → backend.
  return "/api/";
};

const baseURL = getBaseURL();
console.log('Using API baseURL:', baseURL); // Debug log


// Get Basic Auth credentials if available
const getBasicAuthHeader = () => {
  const email = localStorage.getItem("email");
  const password = localStorage.getItem("password");
  const isAuthenticated = localStorage.getItem("isAuthenticated");

  if (isAuthenticated && email && password) {
    const credentials = btoa(`${email}:${password}`);
    return `Basic ${credentials}`;
  }
  return null;
};

const userInstance = axios.create({
  //baseURL: "http://localhost:8080/api/",
  baseURL: `${baseURL}user/`,
  // Send credentials with requests
  // This is important for cookies and session management
  withCredentials: true,
  headers: {
    Accept: "application/json",
  },
});

const adminInstance = axios.create({
  baseURL: `${baseURL}admin/`,
  withCredentials: true,
  headers: {
    Accept: "application/json",
  },
});

const authInstance = axios.create({
  baseURL: `${baseURL}`,
  withCredentials: true,
  headers: {
    Accept: "application/json",
  },
});

const blockedMacsInstance = axios.create({
  baseURL: `${baseURL}`,  // Direct to /api/
  withCredentials: true,
  headers: {
    Accept: "application/json",
  },
});


// Add request interceptors to automatically include Basic Auth headers
userInstance.interceptors.request.use(
  (config) => {
    const authHeader = getBasicAuthHeader();
    if (authHeader) {
      config.headers.Authorization = authHeader;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

adminInstance.interceptors.request.use(
  (config) => {
    const authHeader = getBasicAuthHeader();
    if (authHeader) {
      config.headers.Authorization = authHeader;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

authInstance.interceptors.request.use(
  (config) => {
    const authHeader = getBasicAuthHeader();
    if (authHeader) {
      config.headers.Authorization = authHeader;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

blockedMacsInstance.interceptors.request.use(
  (config) => {
    const authHeader = getBasicAuthHeader();
    if (authHeader) {
      config.headers.Authorization = authHeader;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

export default {
  user: userInstance,
  admin: adminInstance,
  authentification: authInstance,
  blockedMacs: blockedMacsInstance,
};
