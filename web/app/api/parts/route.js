import { NextResponse } from 'next/server';
import { query, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/parts : inventory with reorder flag
export async function GET() {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF', 'TECHNICIAN']);
  if (auth.error) return auth.error;
  const parts = await query(
    `SELECT part_code, part_name, part_category, unit_price, stock_qty, reorder_level,
            stock_qty <= reorder_level AS needs_reorder,
            (SELECT COALESCE(SUM(rp.quantity), 0) FROM repair_part rp WHERE rp.part_id = sp.part_id) AS units_used
     FROM spare_part sp
     ORDER BY needs_reorder DESC, part_category, part_name`
  );
  return NextResponse.json({ parts });
}

// POST /api/parts { part_code, quantity } : record a delivery (admin only)
export async function POST(request) {
  const auth = await requireRole(['ADMIN']);
  if (auth.error) return auth.error;
  const b = await request.json().catch(() => ({}));
  const qty = Number(b.quantity);
  if (!b.part_code || !Number.isInteger(qty) || qty <= 0) {
    return NextResponse.json({ error: 'Choose a part and a whole quantity above 0' }, { status: 400 });
  }
  try {
    const result = await query('UPDATE spare_part SET stock_qty = stock_qty + ? WHERE part_code = ?', [qty, b.part_code]);
    if (result.affectedRows === 0) return NextResponse.json({ error: 'Unknown part' }, { status: 400 });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
