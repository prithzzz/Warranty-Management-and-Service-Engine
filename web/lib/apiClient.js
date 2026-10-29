// Small fetch helper for client components.
export async function api(path, options = {}) {
  const res = await fetch(path, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
  return data;
}

export function formatMoney(n) {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 2 });
}
