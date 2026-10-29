// Row-level access rules for service requests, shared by the service API routes.
import { query } from './mysql';

// Returns the request row if this user may see it, otherwise null.
export async function loadRequestForUser(requestId, user) {
  const rows = await query(
    `SELECT sr.*, (SELECT r.technician_id FROM repair r
                    WHERE r.request_id = sr.request_id
                    ORDER BY r.repair_id DESC LIMIT 1) AS technician_id
     FROM service_request sr WHERE sr.request_id = ?`,
    [requestId]
  );
  const r = rows[0];
  if (!r) return null;
  if (user.role === 'ADMIN') return r;
  if (user.role === 'SERVICE_STAFF' && r.center_id === user.centerId) return r;
  if (user.role === 'TECHNICIAN' && r.technician_id === user.technicianId) return r;
  if (user.role === 'CUSTOMER' && r.customer_id === user.customerId) return r;
  return null;
}
