import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/dashboard : sales, warranty and recall figures for admin and staff
export async function GET() {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;

  const [totals] = await query(
    `SELECT (SELECT COUNT(*) FROM customer)                                        AS customers,
            (SELECT COUNT(*) FROM purchase_item)                                   AS units_sold,
            (SELECT COALESCE(SUM(total_amount), 0) FROM purchase)                  AS revenue,
            (SELECT COUNT(*) FROM v_warranty_overview WHERE live_status IN ('ACTIVE','EXPIRING_SOON')) AS active_warranties,
            (SELECT COUNT(*) FROM v_warranty_overview WHERE live_status = 'EXPIRING_SOON') AS expiring_soon,
            (SELECT COUNT(*) FROM recall_campaign WHERE status <> 'CLOSED')        AS open_recalls`
  );
  const byBrand = await query(
    `SELECT pr.brand, COUNT(*) AS units, SUM(pi.unit_price) AS revenue
     FROM purchase_item pi
     JOIN serial_unit s ON s.serial_id = pi.serial_id
     JOIN product_model pm ON pm.model_id = s.model_id
     JOIN product pr ON pr.product_id = pm.product_id
     GROUP BY pr.brand
     HAVING revenue > 0
     ORDER BY revenue DESC`
  );
  const monthly = await query(
    `WITH monthly AS (
       SELECT DATE_FORMAT(purchase_date, '%Y-%m') AS month, SUM(total_amount) AS revenue
       FROM purchase GROUP BY month
     )
     SELECT month, revenue, SUM(revenue) OVER (ORDER BY month) AS cumulative
     FROM monthly ORDER BY month DESC LIMIT 12`
  );
  const expiring = await query(
    `SELECT customer_name, serial_no, model_name, plan_code, end_date, days_left
     FROM v_warranty_overview
     WHERE live_status IN ('ACTIVE','EXPIRING_SOON') AND days_left <= 120
     ORDER BY days_left`
  );
  return NextResponse.json({ totals, byBrand, monthly: monthly.reverse(), expiring });
}
