import { NextResponse } from 'next/server';
import { query, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';
import { syncRequestEmbedding } from '@/lib/similarity';

export const dynamic = 'force-dynamic';

// GET /api/service-requests?scope=open|all
//   admin: every center, staff: own center, customer: own requests
export async function GET(request) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF', 'CUSTOMER']);
  if (auth.error) return auth.error;
  const user = auth.user;
  const scope = new URL(request.url).searchParams.get('scope') || 'open';

  const where = [];
  const params = [];
  if (scope === 'open') where.push("sr.status IN ('OPEN','ASSIGNED','IN_PROGRESS')");
  if (user.role === 'SERVICE_STAFF') { where.push('sr.center_id = ?'); params.push(user.centerId); }
  if (user.role === 'CUSTOMER') { where.push('sr.customer_id = ?'); params.push(user.customerId); }

  const rows = await query(
    `SELECT sr.request_id, sr.request_date, sr.issue_type, sr.priority, sr.status,
            sc.center_code, c.full_name AS customer_name, s.serial_no, pm.model_name,
            (SELECT t.full_name FROM repair r JOIN technician t ON t.technician_id = r.technician_id
              WHERE r.request_id = sr.request_id ORDER BY r.repair_id DESC LIMIT 1) AS technician,
            fn_has_active_warranty(sr.serial_id, DATE(sr.request_date)) AS under_warranty,
            wc.status AS claim_status
     FROM service_request sr
     JOIN service_center sc ON sc.center_id = sr.center_id
     JOIN customer c        ON c.customer_id = sr.customer_id
     JOIN serial_unit s     ON s.serial_id = sr.serial_id
     JOIN product_model pm  ON pm.model_id = s.model_id
     LEFT JOIN warranty_claim wc ON wc.request_id = sr.request_id
     ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
     ORDER BY FIELD(sr.priority, 'URGENT','HIGH','MEDIUM','LOW'), sr.request_date DESC`,
    params
  );
  return NextResponse.json({ requests: rows });
}

// POST /api/service-requests : a customer raises a request for one of their units.
// Ownership and recall scope are checked by trigger trg_sr_bi.
export async function POST(request) {
  const auth = await requireRole(['CUSTOMER']);
  if (auth.error) return auth.error;
  const user = auth.user;

  const b = await request.json().catch(() => ({}));
  if (!b.serial_no || !b.center_id || !b.issue_type || !b.issue_description) {
    return NextResponse.json({ error: 'Unit, service center, issue type and description are required' }, { status: 400 });
  }
  try {
    const units = await query(
      'SELECT serial_id, fn_unit_under_recall(serial_id) AS recall_id FROM serial_unit WHERE serial_no = ?',
      [b.serial_no]
    );
    const unit = units[0];
    if (!unit) return NextResponse.json({ error: 'Unknown serial number' }, { status: 400 });
    if (b.issue_type === 'RECALL_FIX' && !unit.recall_id) {
      return NextResponse.json({ error: 'This unit is not under an active recall' }, { status: 400 });
    }
    const result = await query(
      `INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, recall_id, issue_description, priority)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [user.customerId, unit.serial_id, Number(b.center_id), b.issue_type,
       b.issue_type === 'RECALL_FIX' ? unit.recall_id : null,
       b.issue_description.trim(), b.priority || 'MEDIUM']
    );
    // add the new complaint to the vector store (does not block on failure)
    await syncRequestEmbedding(result.insertId);
    return NextResponse.json({ request_id: result.insertId }, { status: 201 });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
