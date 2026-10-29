import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/my/products : the logged-in customer's units, warranties and recall notices
export async function GET() {
  const auth = await requireRole(['CUSTOMER']);
  if (auth.error) return auth.error;
  const customerId = auth.user.customerId;

  const units = await query(
    `SELECT s.serial_no, p.brand, pm.model_name, p.category, s.status,
            fn_has_active_warranty(s.serial_id, CURRENT_DATE) AS covered_today,
            rc.recall_code, rc.title AS recall_title
     FROM serial_unit s
     JOIN product_model pm ON pm.model_id = s.model_id
     JOIN product p ON p.product_id = pm.product_id
     LEFT JOIN recall_campaign rc ON rc.recall_id = fn_unit_under_recall(s.serial_id)
     WHERE s.current_owner_id = ?
     ORDER BY s.status = 'SOLD' DESC, pm.model_name`,
    [customerId]
  );
  const warranties = await query(
    `SELECT serial_no, model_name, plan_code, plan_type, start_date, end_date, live_status, days_left
     FROM v_warranty_overview WHERE customer_id = ? ORDER BY end_date DESC`,
    [customerId]
  );
  const notices = await query(
    `SELECT rc.recall_code, rc.title, rc.remedy, s.serial_no, n.status, n.notified_at
     FROM recall_notification n
     JOIN recall_campaign rc ON rc.recall_id = n.recall_id
     JOIN serial_unit s ON s.serial_id = n.serial_id
     WHERE n.customer_id = ?
     ORDER BY n.notified_at DESC`,
    [customerId]
  );
  return NextResponse.json({ units, warranties, notices });
}
