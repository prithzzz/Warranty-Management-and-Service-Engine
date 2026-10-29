// Server-side authorisation helpers for API routes.
import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { SESSION_COOKIE, readSessionToken } from './session';

export async function getSessionUser() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  return readSessionToken(token);
}

// Usage inside a route:
//   const auth = await requireRole(['ADMIN', 'SERVICE_STAFF']);
//   if (auth.error) return auth.error;
//   const user = auth.user;
export async function requireRole(roles) {
  const user = await getSessionUser();
  if (!user) {
    return { error: NextResponse.json({ error: 'Please log in' }, { status: 401 }) };
  }
  if (roles && !roles.includes(user.role)) {
    return { error: NextResponse.json({ error: 'You do not have access to this' }, { status: 403 }) };
  }
  return { user };
}
