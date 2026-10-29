import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/catalog : in-stock units (with recall flag) and warranty plans for the sale form
export async function GET() {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;

  const units = await query(
    `SELECT s.serial_no, s.manufacture_date, p.brand, pm.model_name, p.category, pm.mrp,
            rc.recall_code AS active_recall
     FROM serial_unit s
     JOIN product_model pm ON pm.model_id = s.model_id
     JOIN product p ON p.product_id = pm.product_id
     LEFT JOIN recall_campaign rc ON rc.recall_id = fn_unit_under_recall(s.serial_id)
     WHERE s.status = 'IN_STOCK'
     ORDER BY p.brand, pm.model_name, s.serial_no`
  );
  const plans = await query(
    `SELECT plan_code, plan_name, plan_type, duration_months, price
     FROM warranty_plan ORDER BY plan_type, duration_months`
  );
  return NextResponse.json({ units, plans });
}
