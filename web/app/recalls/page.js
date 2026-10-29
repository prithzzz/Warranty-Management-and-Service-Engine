'use client';
import { useEffect, useState } from 'react';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import { api } from '@/lib/apiClient';

export default function RecallsPage() {
  const [recalls, setRecalls] = useState([]);
  const [selected, setSelected] = useState(null);
  const [role, setRole] = useState(null);
  const [msg, setMsg] = useState(null);

  async function load() {
    setRecalls((await api('/api/recalls')).recalls);
  }
  useEffect(() => {
    load();
    api('/api/auth/me').then((d) => setRole(d.user.role));
  }, []);

  async function open(id) {
    setMsg(null);
    setSelected(await api('/api/recalls/' + id));
  }

  async function notify(id) {
    setMsg(null);
    try {
      const res = await api(`/api/recalls/${id}/notify`, { method: 'POST' });
      setMsg({ ok: true, text: `${res.created} new owner notification(s) queued` });
      await load();
      await open(id);
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  return (
    <>
      <h1>Recall campaigns</h1>
      <DataTable
        rows={recalls}
        columns={[
          { key: 'recall_code', label: 'Code' },
          { key: 'title', label: 'Title' },
          { key: 'severity', label: 'Severity', render: (r) => <StatusBadge value={r.severity} /> },
          { key: 'status', label: 'Status', render: (r) => <StatusBadge value={r.status} /> },
          { key: 'owners_notified', label: 'Notified' },
          { key: 'pct_resolved', label: 'Resolved %', render: (r) => (r.pct_resolved ?? 0) + '%' },
          { key: 'actions', label: '', render: (r) => (
            <span className="row">
              <button className="secondary" onClick={() => open(r.recall_id)}>Units</button>
              {role === 'ADMIN' && r.status !== 'CLOSED' && <button onClick={() => notify(r.recall_id)}>Notify owners</button>}
            </span>
          ) }
        ]}
      />
      {msg && <p className={msg.ok ? 'success' : 'error'} style={{ marginTop: 12 }}>{msg.text}</p>}

      {selected && (
        <>
          <h2>{selected.recall.recall_code}: affected units</h2>
          <p className="muted">{selected.recall.reason}</p>
          <DataTable
            rows={selected.units}
            columns={[
              { key: 'serial_no', label: 'Serial number' },
              { key: 'model_name', label: 'Model' },
              { key: 'manufacture_date', label: 'Made on' },
              { key: 'unit_status', label: 'Unit', render: (r) => <StatusBadge value={r.unit_status} /> },
              { key: 'owner_name', label: 'Owner' },
              { key: 'owner_email', label: 'Email' },
              { key: 'notification_status', label: 'Notice', render: (r) => <StatusBadge value={r.notification_status} /> }
            ]}
          />
        </>
      )}
    </>
  );
}
