import { NextResponse } from 'next/server';
import { query, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';
import { loadRequestForUser } from '@/lib/access';

export const dynamic = 'force-dynamic';

// GET /api/service-requests/:id : full detail of one request
export async function GET(request, { params }) {
  const auth = await requireRole(null);
  if (auth.error) return auth.error;
  const id = Number(params.id);
  if (!(await loadRequestForUser(id, auth.user))) {
    return NextResponse.json({ error: 'Request not found' }, { status: 404 });
  }

  const [detail] = await query(
    `SELECT sr.request_id, sr.request_date, sr.issue_type, sr.issue_description, sr.priority, sr.status, sr.closed_at,
            sc.center_code, sc.center_name, c.full_name AS customer_name, c.phone AS customer_phone,
            s.serial_no, pm.model_name, p.brand, p.category, rc.recall_code,
            fn_has_active_warranty(sr.serial_id, DATE(sr.request_date)) AS under_warranty
     FROM service_request sr
     JOIN service_center sc ON sc.center_id = sr.center_id
     JOIN customer c        ON c.customer_id = sr.customer_id
     JOIN serial_unit s     ON s.serial_id = sr.serial_id
     JOIN product_model pm  ON pm.model_id = s.model_id
     JOIN product p         ON p.product_id = pm.product_id
     LEFT JOIN recall_campaign rc ON rc.recall_id = sr.recall_id
     WHERE sr.request_id = ?`,
    [id]
  );
  const repairs = await query(
    `SELECT r.repair_id, r.status, r.assigned_at, r.completed_at, r.labour_charge, r.resolution_notes,
            t.full_name AS technician, fn_repair_cost(r.repair_id) AS total_cost,
            (SELECT GROUP_CONCAT(CONCAT(sp.part_name, ' x', rp.quantity) SEPARATOR ', ')
               FROM repair_part rp JOIN spare_part sp ON sp.part_id = rp.part_id
              WHERE rp.repair_id = r.repair_id) AS parts_used
     FROM repair r JOIN technician t ON t.technician_id = r.technician_id
     WHERE r.request_id = ? ORDER BY r.repair_id`,
    [id]
  );
  const claims = await query(
    `SELECT wc.claim_id, wc.claim_type, wc.status, wc.approved_amount, wc.claim_date, wc.remarks, wp.plan_code
     FROM warranty_claim wc
     JOIN warranty w ON w.warranty_id = wc.warranty_id
     JOIN warranty_plan wp ON wp.plan_id = w.plan_id
     WHERE wc.request_id = ?`,
    [id]
  );
  const log = await query(
    'SELECT old_status, new_status, changed_at, changed_by FROM service_status_log WHERE request_id = ? ORDER BY log_id',
    [id]
  );
  return NextResponse.json({ request: detail, repairs, claim: claims[0] || null, log });
}

// PATCH /api/service-requests/:id  { action: 'close' | 'cancel' }
// status workflow rules are enforced by trigger trg_sr_bu
export async function PATCH(request, { params }) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF', 'CUSTOMER']);
  if (auth.error) return auth.error;
  const id = Number(params.id);
  const sr = await loadRequestForUser(id, auth.user);
  if (!sr) return NextResponse.json({ error: 'Request not found' }, { status: 404 });

  const { action } = await request.json().catch(() => ({}));
  let newStatus;
  if (action === 'close' && auth.user.role !== 'CUSTOMER') {
    if (sr.status !== 'COMPLETED') return NextResponse.json({ error: 'Only completed requests can be closed' }, { status: 400 });
    newStatus = 'CLOSED';
  } else if (action === 'cancel') {
    if (sr.status !== 'OPEN') return NextResponse.json({ error: 'Only open requests can be cancelled' }, { status: 400 });
    newStatus = 'CANCELLED';
  } else {
    return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
  }
  try {
    await query('UPDATE service_request SET status = ? WHERE request_id = ?', [newStatus, id]);
    return NextResponse.json({ status: newStatus });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
