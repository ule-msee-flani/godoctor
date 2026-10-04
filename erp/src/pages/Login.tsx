import { useState } from 'react';
import { Lock } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { configured } from '../lib/supabase';
import { Button } from '../components/ui';

export function LoginPage() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="login">
      <div className="login-card">
        <div className="login-brand">
          <img src="./icon.png" alt="" width={64} height={64} />
          <h1>GoDoctor HQ</h1>
          <p>Company console · staff only</p>
        </div>
        {!configured && (
          <div className="login-error">This console isn’t connected to the database yet.</div>
        )}
        {error && <div className="login-error" role="alert">{error}</div>}
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            setBusy(true);
            setError(null);
            try {
              await signIn(email.trim(), password);
            } catch (err) {
              setError((err as Error).message);
            } finally {
              setBusy(false);
            }
          }}
        >
          <label className="field">
            <span>Email address</span>
            <input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
          </label>
          <label className="field">
            <span>Password</span>
            <input
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>
          <Button type="submit" variant="primary" busy={busy} className="login-submit">
            Log in
          </Button>
        </form>
        <p className="login-foot">
          <Lock size={13} /> Forgot your password? Ask a GoDoctor administrator to reset it. Everything you do here is
          recorded in the activity log.
        </p>
      </div>
    </div>
  );
}

export function NoAccessPage() {
  const { session, signOut } = useAuth();
  return (
    <div className="login">
      <div className="login-card">
        <div className="login-brand">
          <img src="./icon.png" alt="" width={64} height={64} />
          <h1>No access</h1>
          <p>{session?.user.email}</p>
        </div>
        <p>
          This account isn’t a GoDoctor staff account, or it has been suspended. If you work at GoDoctor, ask an
          administrator to add you under <b>Staff</b>.
        </p>
        <Button variant="primary" className="login-submit" onClick={signOut}>Sign out</Button>
      </div>
    </div>
  );
}
