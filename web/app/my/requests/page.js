'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import { api } from '@/lib/apiClient';

const ISSUE_TYPES = ['HARDWARE', 'SOFTWARE', 'PHYSICAL_DAMAGE', 'BATTERY', 'DISPLAY', 'RECALL_FIX', 'OTHER'];

export default function MyRequestsPage() {
  const [requests, setRequests] = useState([]);
  const [units, setUnits] = useState([]);
  const [centers, setCenters] = useState([]);
  const [form, setForm] = useState({ serial_no: '', center_id: '', issue_type: 'HARDWARE', priority: 'MEDIUM', issue_description: '' });
  const [msg, setMsg] = useState(null);

  async function load() {
    const [r, p, c] = await Promise.all([
      api('/api/service-requests?scope=all'), api('/api/my/products'), api('/api/service-centers')
    ]);
    setRequests(r.requests);
    setUnits(p.units.filter((u) => u.status === 'SOLD'));
    setCenters(c.centers);
  }
  useEffect(() => { load(); }, []);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault();
    setMsg(null);
    try {
      const res = await api('/api/service-requests', { method: 'POST', body: form });
      setMsg({ ok: true, text: `Request #${res.request_id} raised. The service center will assign a technician.` });
      setForm({ ...form, issue_description: '' });
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  async function cancel(id) {
    try {
      await api('/api/service-requests/' + id, { method: 'PATCH', body: { action: 'cancel' } });
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  return (
    <>
      <h1>My service requests</h1>
      <DataTable
        rows={requests}
        empty="You have not raised any requests"
        columns={[
          { key: 'request_id', label: '#' },
          { key: 'request_date', label: 'Raised' },
          { key: 'model_name', label: 'Product' },
          { key: 'issue_type', label: 'Issue' },
          { key: 'status', label: 'Status', render: (r) => <StatusBadge value={r.status} /> },
          { key: 'technician', label: 'Technician' },
          { key: 'claim_status', label: 'Warranty claim', render: (r) => <StatusBadge value={r.claim_status} /> },
          { key: 'act', label: '', render: (r) => r.status === 'OPEN' && <button className="secondary" onClick={() => cancel(r.request_id)}>Cancel</button> }
        ]}
      />

      <h2>Raise a new request</h2>
      <form className="card stack" onSubmit={submit}>
        <label>Product
          <select value={form.serial_no} onChange={set('serial_no')} required>
            <option value="">Choose your product</option>
            {units.map((u) => (
              <option key={u.serial_no} value={u.serial_no}>
                {u.brand} {u.model_name} ({u.serial_no}){u.recall_code ? ` under recall ${u.recall_code}` : ''}
              </option>
            ))}
          </select>
        </label>
        <label>Service center
          <select value={form.center_id} onChange={set('center_id')} required>
            <option value="">Choose a center</option>
            {centers.map((c) => <option key={c.center_id} value={c.center_id}>{c.center_name}, {c.city}</option>)}
          </select>
        </label>
        <label>Issue type
          <select value={form.issue_type} onChange={set('issue_type')}>
            {ISSUE_TYPES.map((t) => <option key={t} value={t}>{t.replace(/_/g, ' ')}</option>)}
          </select>
        </label>
        <label>Priority
          <select value={form.priority} onChange={set('priority')}>
            <option>LOW</option><option>MEDIUM</option><option>HIGH</option><option>URGENT</option>
          </select>
        </label>
        <label>Describe the problem (at least 10 characters)
          <textarea value={form.issue_description} onChange={set('issue_description')} required />
        </label>
        {msg && <p className={msg.ok ? 'success' : 'error'}>{msg.text}</p>}
        <button>Submit request</button>
      </form>
    </>
  );
}
