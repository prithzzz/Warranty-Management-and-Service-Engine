'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';

const HOME_CARDS = {
  ADMIN: [
    ['/dashboard', 'Dashboard', 'Sales, warranty and recall overview'],
    ['/service', 'Service queue', 'Open requests across all centers'],
    ['/recalls', 'Recalls', 'Recall progress and owner notifications'],
    ['/claims', 'Claims', 'Approve, reject and settle warranty claims']
  ],
  SERVICE_STAFF: [
    ['/sales/new', 'Register a sale', 'Sell a unit with its warranty in one step'],
    ['/service', 'Service queue', 'Requests at your center, assign technicians'],
    ['/warranty', 'Warranty lookup', 'Check coverage by serial number'],
    ['/claims', 'Claims', 'Review warranty claims']
  ],
  TECHNICIAN: [
    ['/technician', 'My jobs', 'Start, add parts and complete repairs'],
    ['/parts', 'Parts', 'Spare part stock'],
    ['/warranty', 'Warranty lookup', 'Check coverage by serial number']
  ],
  CUSTOMER: [
    ['/my/products', 'My products', 'Your units, warranties and recall alerts'],
    ['/my/requests', 'Service requests', 'Raise a request and track it'],
    ['/warranty', 'Warranty lookup', 'Check coverage by serial number']
  ]
};

export default function Home() {
  const [user, setUser] = useState(null);

  useEffect(() => {
    fetch('/api/auth/me').then((r) => (r.ok ? r.json() : null)).then((d) => d && setUser(d.user));
  }, []);

  if (!user) return <p className="muted">Loading...</p>;

  return (
    <>
      <h1>Welcome, {user.username}</h1>
      <p className="muted">Signed in as {user.role.replace('_', ' ').toLowerCase()}</p>
      <div className="grid">
        {(HOME_CARDS[user.role] || []).map(([href, title, text]) => (
          <Link key={href} href={href} className="card card-link">
            <h3>{title}</h3>
            <p className="muted">{text}</p>
          </Link>
        ))}
      </div>
    </>
  );
}
