import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/recalls : every recall with notification progress
export async function GET() {
  const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
  if (auth.error) return auth.error;

  const rows = await query(
    `SELECT rc.recall_id, rc.recall_code, rc.title, rc.severity, rc.remedy, rc.status, rc.announced_on,
            COUNT(n.notification_id)               AS owners_notified,
            COALESCE(SUM(n.status = 'RESOLVED'), 0) AS resolved,
            ROUND(100 * SUM(n.status = 'RESOLVED') / NULLIF(COUNT(n.notification_id), 0), 1) AS pct_resolved
     FROM recall_campaign rc
     LEFT JOIN recall_notification n ON n.recall_id = rc.recall_id
     GROUP BY rc.recall_id
     ORDER BY rc.announced_on DESC`
  );
  return NextResponse.json({ recalls: rows });
}
