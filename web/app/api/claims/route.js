import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/claims : warranty claims (staff see their own center)
export async function GET() {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;
  const user = auth.user;
  const staff = user.role === 'SERVICE_STAFF';

  const rows = await query(
    `SELECT wc.claim_id, wc.request_id, wc.claim_type, wc.status, wc.claim_date, wc.approved_amount, wc.remarks,
            wp.plan_code, wp.plan_type, c.full_name AS customer_name, s.serial_no, pm.model_name, sc.center_code,
            (SELECT GROUP_CONCAT(n.serial_no ORDER BY n.serial_no SEPARATOR ', ')
               FROM serial_unit n
              WHERE n.model_id = s.model_id AND n.status = 'IN_STOCK'
                AND fn_unit_under_recall(n.serial_id) IS NULL) AS replacement_options
     FROM warranty_claim wc
     JOIN warranty w        ON w.warranty_id = wc.warranty_id
     JOIN warranty_plan wp  ON wp.plan_id = w.plan_id
     JOIN service_request sr ON sr.request_id = wc.request_id
     JOIN service_center sc ON sc.center_id = sr.center_id
     JOIN customer c        ON c.customer_id = sr.customer_id
     JOIN serial_unit s     ON s.serial_id = sr.serial_id
     JOIN product_model pm  ON pm.model_id = s.model_id
     ${staff ? 'WHERE sr.center_id = ?' : ''}
     ORDER BY FIELD(wc.status, 'SUBMITTED','APPROVED','SETTLED','REJECTED'), wc.claim_date DESC`,
    staff ? [user.centerId] : []
  );
  return NextResponse.json({ claims: rows });
}
