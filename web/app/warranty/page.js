'use client';
import { useState } from 'react';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import { api } from '@/lib/apiClient';

export default function WarrantyLookupPage() {
  const [serial, setSerial] = useState('');
  const [data, setData] = useState(null);
  const [error, setError] = useState('');

  async function lookup(e) {
    e.preventDefault();
    setError('');
    setData(null);
    try {
      setData(await api('/api/warranty?serial=' + encodeURIComponent(serial.trim())));
    } catch (err) {
      setError(err.message);
    }
  }

  const u = data?.unit;

  return (
    <>
      <h1>Warranty lookup</h1>
      <form className="row" onSubmit={lookup} style={{ margin: '16px 0' }}>
        <label>Serial number<input value={serial} onChange={(e) => setSerial(e.target.value)} placeholder="IP16-24L0011" required /></label>
        <button>Check</button>
      </form>
      {error && <p className="error">{error}</p>}

      {u && (
        <>
          <div className="stats">
            <div className="card stat"><div className="muted small">Product</div><div className="value">{u.brand} {u.model_name}</div></div>
            <div className="card stat"><div className="muted small">Owner</div><div className="value">{u.owner_name || 'In stock'}</div></div>
            <div className="card stat"><div className="muted small">Covered today</div><div className="value">{u.covered_today ? 'Yes' : 'No'}</div></div>
            <div className="card stat"><div className="muted small">Unit status</div><div className="value"><StatusBadge value={u.status} /></div></div>
          </div>
          {u.recall_code && (
            <p className="error">Under active recall {u.recall_code}: {u.recall_title}. Remedy: {u.recall_remedy.toLowerCase()}.</p>
          )}

          <h2>Warranties</h2>
          <DataTable
            rows={data.warranties}
            columns={[
              { key: 'plan_code', label: 'Plan' },
              { key: 'plan_type', label: 'Type' },
              { key: 'start_date', label: 'Start' },
              { key: 'end_date', label: 'End' },
              { key: 'live_status', label: 'Status', render: (r) => <StatusBadge value={r.live_status} /> },
              { key: 'days_left', label: 'Days left' }
            ]}
          />

          <h2>Service history</h2>
          <DataTable
            rows={data.history}
            empty="No service requests for this unit"
            columns={[
              { key: 'request_id', label: 'Request' },
              { key: 'request_date', label: 'Date' },
              { key: 'issue_type', label: 'Issue' },
              { key: 'status', label: 'Status', render: (r) => <StatusBadge value={r.status} /> }
            ]}
          />
        </>
      )}
    </>
  );
}
