import { NextResponse } from 'next/server';
import { query, dbErrorMessage } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';
const STAFF = ['ADMIN', 'SERVICE_STAFF'];

// GET /api/customers?q=text  : search customers with their purchase summary
export async function GET(request) {
  const auth = await requireRole(STAFF);
  if (auth.error) return auth.error;

  const q = (new URL(request.url).searchParams.get('q') || '').trim();
  const like = `%${q}%`;
  const rows = await query(
    `SELECT c.customer_id, c.full_name, c.email, c.phone, c.city, c.preferred_channel, c.registered_on,
            COUNT(DISTINCT p.purchase_id) AS purchases,
            COALESCE(SUM(p.total_amount), 0) AS lifetime_spend
     FROM customer c
     LEFT JOIN purchase p ON p.customer_id = c.customer_id
     WHERE ? = '' OR c.full_name LIKE ? OR c.email LIKE ? OR c.phone LIKE ?
     GROUP BY c.customer_id
     ORDER BY c.full_name`,
    [q, like, like, like]
  );
  return NextResponse.json({ customers: rows });
}

// POST /api/customers : add a customer (format rules are enforced by CHECK constraints)
export async function POST(request) {
  const auth = await requireRole(STAFF);
  if (auth.error) return auth.error;

  const b = await request.json().catch(() => ({}));
  if (!b.full_name || !b.email || !b.phone || !b.city) {
    return NextResponse.json({ error: 'Name, email, phone and city are required' }, { status: 400 });
  }
  try {
    const result = await query(
      `INSERT INTO customer (full_name, email, phone, address, city, preferred_channel)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [b.full_name.trim(), b.email.trim().toLowerCase(), b.phone.trim(), b.address || null,
       b.city.trim(), b.preferred_channel || 'EMAIL']
    );
    return NextResponse.json({ customer_id: result.insertId }, { status: 201 });
  } catch (err) {
    return NextResponse.json({ error: dbErrorMessage(err) }, { status: 400 });
  }
}
