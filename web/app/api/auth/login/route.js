import { NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { query } from '@/lib/mysql';
import { createSessionToken, SESSION_COOKIE, sessionCookieOptions } from '@/lib/session';

export async function POST(request) {
  const { username, password } = await request.json().catch(() => ({}));
  if (!username || !password) {
    return NextResponse.json({ error: 'Username and password are required' }, { status: 400 });
  }

  const rows = await query(
    `SELECT user_id, username, password_hash, role, customer_id, technician_id, center_id, is_active
     FROM app_user WHERE username = ?`,
    [username.trim()]
  );
  const user = rows[0];

  // same message for unknown user and wrong password, so usernames cannot be guessed
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return NextResponse.json({ error: 'Invalid username or password' }, { status: 401 });
  }
  if (!user.is_active) {
    return NextResponse.json({ error: 'This account is disabled' }, { status: 403 });
  }

  const token = await createSessionToken(user);
  const response = NextResponse.json({
    user: { username: user.username, role: user.role }
  });
  response.cookies.set(SESSION_COOKIE, token, sessionCookieOptions);
  return response;
}
