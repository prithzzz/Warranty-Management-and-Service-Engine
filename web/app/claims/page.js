'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import DataTable from '@/components/DataTable';
import StatusBadge from '@/components/StatusBadge';
import { api, formatMoney } from '@/lib/apiClient';

export default function ClaimsPage() {
  const [claims, setClaims] = useState([]);
  const [msg, setMsg] = useState(null);

  async function load() { setClaims((await api('/api/claims')).claims); }
  useEffect(() => { load(); }, []);

  async function act(id, body, success) {
    setMsg(null);
    try {
      await api('/api/claims/' + id, { method: 'POST', body });
      setMsg({ ok: true, text: success });
      load();
    } catch (err) {
      setMsg({ ok: false, text: err.message });
    }
  }

  function actions(c) {
    if (c.status === 'SUBMITTED') {
      return (
        <span className="row">
          <button onClick={() => act(c.claim_id, { action: 'approve' }, `Claim #${c.claim_id} approved`)}>Approve</button>
          <button className="secondary" onClick={() => {
            const remarks = window.prompt('Reason for rejecting this claim');
            if (remarks) act(c.claim_id, { action: 'reject', remarks }, `Claim #${c.claim_id} rejected`);
          }}>Reject</button>
        </span>
      );
    }
    if (c.status === 'APPROVED' && c.claim_type === 'REPLACEMENT') {
      return (
        <button onClick={() => {
          const serial = window.prompt(`Replacement unit serial number.\nIn stock: ${c.replacement_options || 'none'}`);
          if (serial) act(c.claim_id, { action: 'replace', new_serial_no: serial }, `Unit replaced for claim #${c.claim_id}`);
        }}>Process replacement</button>
      );
    }
    if (c.status === 'APPROVED') return <span className="small muted">Settles when the repair completes</span>;
    return null;
  }

  return (
    <>
      <h1>Warranty claims</h1>
      {msg && <p className={msg.ok ? 'success' : 'error'}>{msg.text}</p>}
      <DataTable
        rows={claims}
        columns={[
          { key: 'claim_id', label: 'Claim' },
          { key: 'request_id', label: 'Request', render: (c) => <Link href={`/service/${c.request_id}`}>#{c.request_id}</Link> },
          { key: 'customer_name', label: 'Customer' },
          { key: 'model_name', label: 'Model' },
          { key: 'plan_code', label: 'Plan' },
          { key: 'claim_type', label: 'Type' },
          { key: 'status', label: 'Status', render: (c) => <StatusBadge value={c.status} /> },
          { key: 'approved_amount', label: 'Amount', render: (c) => formatMoney(c.approved_amount) },
          { key: 'act', label: '', render: actions }
        ]}
      />
    </>
  );
}
