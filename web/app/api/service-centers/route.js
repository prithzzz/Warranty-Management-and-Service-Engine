import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requireRole(null);   // any logged-in user
  if (auth.error) return auth.error;
  const centers = await query('SELECT center_id, center_code, center_name, city FROM service_center ORDER BY city, center_name');
  return NextResponse.json({ centers });
}
