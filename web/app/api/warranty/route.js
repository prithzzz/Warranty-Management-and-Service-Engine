import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/warranty?serial=XXXX : unit details, warranties, recall status and service history
export async function GET(request) {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF', 'TECHNICIAN', 'CUSTOMER']);
  if (auth.error) return auth.error;
  const user = auth.user;

  const serial = (new URL(request.url).searchParams.get('serial') || '').trim();
  if (!serial) return NextResponse.json({ error: 'Enter a serial number' }, { status: 400 });

  const units = await query(
    `SELECT s.serial_id, s.serial_no, s.status, s.manufacture_date, s.current_owner_id,
            p.brand, pm.model_name, p.category, c.full_name AS owner_name,
            fn_has_active_warranty(s.serial_id, CURRENT_DATE) AS covered_today,
            rc.recall_code, rc.title AS recall_title, rc.remedy AS recall_remedy
     FROM serial_unit s
     JOIN product_model pm ON pm.model_id = s.model_id
     JOIN product p ON p.product_id = pm.product_id
     LEFT JOIN customer c ON c.customer_id = s.current_owner_id
     LEFT JOIN recall_campaign rc ON rc.recall_id = fn_unit_under_recall(s.serial_id)
     WHERE s.serial_no = ?`,
    [serial]
  );
  const unit = units[0];

  // customers may only look up their own units
  if (!unit || (user.role === 'CUSTOMER' && unit.current_owner_id !== user.customerId)) {
    return NextResponse.json({ error: 'No unit found with that serial number' }, { status: 404 });
  }

  const warranties = await query(
    `SELECT warranty_id, plan_code, plan_type, start_date, end_date, live_status, days_left
     FROM v_warranty_overview WHERE serial_no = ? ORDER BY start_date DESC`,
    [serial]
  );
  const history = await query(
    `SELECT request_id, DATE(request_date) AS request_date, issue_type, status
     FROM service_request WHERE serial_id = ? ORDER BY request_date DESC`,
    [unit.serial_id]
  );
  return NextResponse.json({ unit, warranties, history });
}
