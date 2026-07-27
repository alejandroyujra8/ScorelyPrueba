import { environment } from "../config/environment";
import { ApiError } from "../services/api";

export const clone = (value) => structuredClone(value);
export const wait = (ms = environment.mockDelay) => new Promise((resolve) => setTimeout(resolve, ms));

export async function mockResult(value) {
  await wait();
  return clone(typeof value === "function" ? value() : value);
}

export function mockError(message, status = 422, data = null) {
  throw new ApiError(message, { status, data: data || { detail: message }, code: `MOCK_${status}` });
}

export function filterText(value, query) {
  return String(value || "").toLocaleLowerCase("es").includes(String(query || "").toLocaleLowerCase("es"));
}
