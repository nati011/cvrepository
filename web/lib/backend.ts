export function backendBase(): string {
  const u = process.env.API_URL;
  if (!u || u.trim() === "") {
    throw new Error("API_URL must be set (e.g. http://localhost:8080)");
  }
  return u.replace(/\/$/, "");
}
