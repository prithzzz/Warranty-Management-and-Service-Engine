'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import { api } from '@/lib/apiClient';

export default function ServiceQueuePage() {
  const [scope, setScope] = useState('open');
  const [rows, setRows] = useState([]);
  const [msg, setMsg] = useState(null);
  const [text, setText] = useState('');
  const [matches, setMatches] = useState(null);

  async function load(s = scope) {
    setRows((await api('/api/service-requests?scope=' + s)).requests);
  }
  useEffect(() => { load(scope); }, [scope]);

  async function assign(id) {
    setMsg(null);
    try {
      const res = await api(`/api/service-requests/${id}/assign`, { method: 'POST' });
      setMsg({ ok: true, text: `Request #${id} assigned to ${res.technician}` });
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  async function search(e) {
    e.preventDefault();
    setMatches(null);
    try {
      setMatches((await api('/api/similar?text=' + encodeURIComponent(text))).matches);
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  return (
    <>
      <div className="spread">
        <h1>Service queue</h1>
        <label>Show
          <select value={scope} onChange={(e) => setScope(e.target.value)}>
            <option value="open">Open requests</option>
            <option value="all">All requests</option>
          </select>
        </label>
      </div>
      {msg && <p className={msg.ok ? 'success' : 'error'}>{msg.text}</p>}
      <DataTable
        rows={rows}
        columns={[
          { key: 'request_id', label: '#', render: (r) => <Link href={`/service/${r.request_id}`}>{r.request_id}</Link> },
          { key: 'priority', label: 'Priority', render: (r) => <StatusBadge value={r.priority} /> },
          { key: 'status', label: 'Status', render: (r) => <StatusBadge value={r.status} /> },
          { key: 'center_code', label: 'Center' },
          { key: 'customer_name', label: 'Customer' },
          { key: 'model_name', label: 'Model' },
          { key: 'issue_type', label: 'Issue' },
          { key: 'under_warranty', label: 'Warranty', render: (r) => (r.under_warranty ? 'Yes' : 'No') },
          { key: 'technician', label: 'Technician' },
          { key: 'act', label: '', render: (r) => r.status === 'OPEN' && <button onClick={() => assign(r.request_id)}>Auto-assign</button> }
        ]}
      />

      <h2>Search past issues by meaning</h2>
      <form className="row" onSubmit={search}>
        <label style={{ flex: 1 }}>Describe the problem
          <input value={text} onChange={(e) => setText(e.target.value)} placeholder="phone switches off at 20 percent" />
        </label>
        <button>Find similar</button>
      </form>
      {matches && (
        <DataTable
          rows={matches}
          empty="No similar requests found"
          columns={[
            { key: 'request_id', label: '#', render: (r) => <Link href={`/service/${r.request_id}`}>{r.request_id}</Link> },
            { key: 'similarity', label: 'Match', render: (r) => Math.round(r.similarity * 100) + '%' },
            { key: 'model_name', label: 'Model' },
            { key: 'issue_text', label: 'Issue' },
            { key: 'resolution_text', label: 'Fix' }
          ]}
        />
      )}
    </>
  );
}
