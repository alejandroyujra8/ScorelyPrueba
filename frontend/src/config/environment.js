const truthy = new Set(["true", "1", "yes", "si", "sí"]);
const viteEnv = import.meta.env || {};

function readText(name, fallback = "") {
  const value = viteEnv[name];
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function readBoolean(name, fallback = false) {
  const value = readText(name);
  return value ? truthy.has(value.toLowerCase()) : fallback;
}

export const environment = Object.freeze({
  apiUrl: readText("VITE_API_URL", "http://127.0.0.1:8000").replace(/\/+$/, ""),
  useMocks: readBoolean("VITE_USE_MOCKS", false),
  mockDelay: 280,
});

export const usarMocks = () => environment.useMocks;
