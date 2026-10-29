import { NextResponse } from 'next/server';
import { query, callProcedure, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';
const STAFF = ['ADMIN', 'SERVICE_STAFF'];

// GET /api/sales : latest invoices
export async function GET() {
  const auth = await requireRole(STAFF);
  if (auth.error) return auth.error;

  const rows = await query(
    `SELECT p.purchase_id, p.invoice_no, p.purchase_date, p.channel, p.total_amount,
            c.full_name AS customer_name,
            GROUP_CONCAT(s.serial_no ORDER BY s.serial_no SEPARATOR ', ') AS units
     FROM purchase p
     JOIN customer c ON c.customer_id = p.customer_id
     LEFT JOIN purchase_item pi ON pi.purchase_id = p.purchase_id
     LEFT JOIN serial_unit s ON s.serial_id = pi.serial_id
     GROUP BY p.purchase_id
     ORDER BY p.purchase_date DESC, p.purchase_id DESC
     LIMIT 15`
  );
  return NextResponse.json({ sales: rows });
}

// POST /api/sales : register a sale and its warranty in one transaction (sp_register_sale)
export async function POST(request) {
  const auth = await requireRole(STAFF);
  if (auth.error) return auth.error;

  const b = await request.json().catch(() => ({}));
  const price = Number(b.price);
  if (!b.customer_id || !b.invoice_no || !b.serial_no || !b.plan_code || !b.channel || !(price > 0)) {
    return NextResponse.json({ error: 'Customer, invoice number, unit, plan, channel and a positive price are required' }, { status: 400 });
  }
  try {
    const out = await callProcedure(
      'sp_register_sale',
      [Number(b.customer_id), b.invoice_no.trim(), b.purchase_date || new Date().toISOString().slice(0, 10),
       b.channel, b.serial_no, price, b.plan_code],
      ['purchase_id']
    );
    return NextResponse.json({ purchase_id: out.purchase_id }, { status: 201 });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
