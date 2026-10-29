import { NextResponse } from 'next/server';
import { query } from '@/lib/mysql';
import { requireRole } from '@/lib/auth';

export const dynamic = 'force-dynamic';

// GET /api/repairs : a technician's jobs (admin sees every open job)
export async function GET() {
  const auth = await requireRole(['TECHNICIAN', 'ADMIN']);
  if (auth.error) return auth.error;
  const user = auth.user;

  const mine = user.role === 'TECHNICIAN';
  const rows = await query(
    `SELECT r.repair_id, r.request_id, r.status, r.assigned_at, r.completed_at, r.labour_charge,
            t.full_name AS technician, sr.priority, sr.issue_type, sr.issue_description,
            s.serial_no, pm.model_name, fn_repair_cost(r.repair_id) AS total_cost,
            (SELECT GROUP_CONCAT(CONCAT(sp.part_name, ' x', rp.quantity) SEPARATOR ', ')
               FROM repair_part rp JOIN spare_part sp ON sp.part_id = rp.part_id
              WHERE rp.repair_id = r.repair_id) AS parts_used
     FROM repair r
     JOIN technician t      ON t.technician_id = r.technician_id
     JOIN service_request sr ON sr.request_id = r.request_id
     JOIN serial_unit s     ON s.serial_id = sr.serial_id
     JOIN product_model pm  ON pm.model_id = s.model_id
     WHERE ${mine ? 'r.technician_id = ?' : "r.status IN ('ASSIGNED','IN_PROGRESS')"}
     ORDER BY r.status IN ('ASSIGNED','IN_PROGRESS') DESC,
              FIELD(sr.priority, 'URGENT','HIGH','MEDIUM','LOW'), r.assigned_at DESC`,
    mine ? [user.technicianId] : []
  );
  return NextResponse.json({ repairs: rows });
}
