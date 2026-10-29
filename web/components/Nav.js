'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';

// Links each role sees in the top bar
const LINKS = {
  ADMIN: [
    ['/dashboard', 'Dashboard'], ['/customers', 'Customers'], ['/sales/new', 'New sale'],
    ['/warranty', 'Warranty lookup'], ['/recalls', 'Recalls'], ['/service', 'Service queue'],
    ['/claims', 'Claims'], ['/parts', 'Parts'], ['/technician', 'Technician jobs']
  ],
  SERVICE_STAFF: [
    ['/dashboard', 'Dashboard'], ['/customers', 'Customers'], ['/sales/new', 'New sale'],
    ['/warranty', 'Warranty lookup'], ['/recalls', 'Recalls'], ['/service', 'Service queue'],
    ['/claims', 'Claims'], ['/parts', 'Parts']
  ],
  TECHNICIAN: [['/technician', 'My jobs'], ['/warranty', 'Warranty lookup'], ['/parts', 'Parts']],
  CUSTOMER: [['/my/products', 'My products'], ['/my/requests', 'My service requests'], ['/warranty', 'Warranty lookup']]
};

export default function Nav() {
  const pathname = usePathname();
  const [user, setUser] = useState(null);

  useEffect(() => {
    if (pathname === '/login') { setUser(null); return; }
    fetch('/api/auth/me')
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => setUser(d ? d.user : null))
      .catch(() => setUser(null));
  }, [pathname]);

  async function logout() {
    await fetch('/api/auth/logout', { method: 'POST' });
    window.location.href = '/login';
  }

  if (pathname === '/login') return null;

  return (
    <header className="topbar">
      <Link href="/" className="brand">Warranty Engine</Link>
      <nav>
        {user && (LINKS[user.role] || []).map(([href, label]) => (
          <Link key={href} href={href} className={pathname.startsWith(href) ? 'active' : ''}>
            {label}
          </Link>
        ))}
      </nav>
      {user && (
        <div className="who">
          <span>{user.username} <small>({user.role.replace('_', ' ').toLowerCase()})</small></span>
          <button className="link-btn" onClick={logout}>Log out</button>
        </div>
      )}
    </header>
  );
}
