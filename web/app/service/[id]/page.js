'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import SimilarIssues from '@/components/SimilarIssues';
import { api, formatMoney } from '@/lib/apiClient';

export default function RequestDetailPage({ params }) {
  const id = params.id;
  const [data, setData] = useState(null);
  const [role, setRole] = useState(null);
  const [claimType, setClaimType] = useState('REPAIR');
  const [msg, setMsg] = useState(null);

  async function load() {
    try { setData(await api('/api/service-requests/' + id)); }
    catch (err) { setMsg({ ok: false, text: err.message }); }
  }
  useEffect(() => {
    load();
    api('/api/auth/me').then((d) => setRole(d.user.role));
  }, [id]);

  async function run(path, options, success) {
    setMsg(null);
    try {
      await api(path, options);
      setMsg({ ok: true, text: success });
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  if (!data) return msg ? <p className="error">{msg.text}</p> : <p className="muted">Loading...</p>;
  const r = data.request;
  const staff = role === 'ADMIN' || role === 'SERVICE_STAFF';

  return (
    <>
      <div className="spread">
        <h1>Request #{r.request_id}</h1>
        <span className="row"><StatusBadge value={r.priority} /><StatusBadge value={r.status} /></span>
      </div>
      <p className="muted">{r.brand} {r.model_name} ({r.serial_no}) · {r.customer_name} · {r.center_name} · raised {r.request_date}</p>
      <div className="card" style={{ margin: '14px 0' }}>
        <p><strong>{r.issue_type.replace(/_/g, ' ')}</strong>{r.recall_code ? ` (recall ${r.recall_code})` : ''}</p>
        <p>{r.issue_description}</p>
        <p className="small muted">Under warranty on request date: {r.under_warranty ? 'Yes' : 'No'}</p>
      </div>

      {msg && <p className={msg.ok ? 'success' : 'error'}>{msg.text}</p>}

      {staff && (
        <div className="row" style={{ margin: '12px 0' }}>
          {r.status === 'OPEN' && (
            <button onClick={() => run(`/api/service-requests/${id}/assign`, { method: 'POST' }, 'Technician assigned')}>Auto-assign technician</button>
          )}
          {!data.claim && !['CANCELLED', 'CLOSED'].includes(r.status) && (
            <>
              <select value={claimType} onChange={(e) => setClaimType(e.target.value)}>
                <option>REPAIR</option><option>REPLACEMENT</option><option>REFUND</option>
              </select>
              <button className="secondary" onClick={() => run(`/api/service-requests/${id}/claim`, { method: 'POST', body: { claim_type: claimType } }, 'Warranty claim filed')}>
                File warranty claim
              </button>
            </>
          )}
          {r.status === 'COMPLETED' && (
            <button className="secondary" onClick={() => run(`/api/service-requests/${id}`, { method: 'PATCH', body: { action: 'close' } }, 'Request closed')}>Close request</button>
          )}
          {r.status === 'OPEN' && (
            <button className="secondary" onClick={() => run(`/api/service-requests/${id}`, { method: 'PATCH', body: { action: 'cancel' } }, 'Request cancelled')}>Cancel</button>
          )}
        </div>
      )}

      <h2>Repairs</h2>
      <DataTable
        rows={data.repairs}
        empty="No technician assigned yet"
        columns={[
          { key: 'technician', label: 'Technician' },
          { key: 'status', label: 'Status', render: (x) => <StatusBadge value={x.status} /> },
          { key: 'assigned_at', label: 'Assigned' },
          { key: 'completed_at', label: 'Completed' },
          { key: 'parts_used', label: 'Parts' },
          { key: 'total_cost', label: 'Cost', render: (x) => formatMoney(x.total_cost) },
          { key: 'resolution_notes', label: 'Notes' }
        ]}
      />

      <h2>Warranty claim</h2>
      {data.claim ? (
        <div className="card">
          <p>{data.claim.claim_type} claim on plan {data.claim.plan_code} · <StatusBadge value={data.claim.status} /></p>
          {data.claim.approved_amount != null && <p className="muted">Amount: {formatMoney(data.claim.approved_amount)}</p>}
          {data.claim.remarks && <p className="muted">{data.claim.remarks}</p>}
        </div>
      ) : <p className="muted">No claim filed</p>}

      <h2>Similar past issues</h2>
      <SimilarIssues requestId={id} />

      <h2>Status history</h2>
      <DataTable
        rows={data.log}
        columns={[
          { key: 'changed_at', label: 'When' },
          { key: 'old_status', label: 'From' },
          { key: 'new_status', label: 'To' },
          { key: 'changed_by', label: 'By' }
        ]}
      />
    </>
  );
}
