import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase, friendlyError } from './supabase';

export interface Me {
  id: string;
  email: string | null;
  full_name: string;
  job_title: string;
  department: string;
  role: string;
  role_name: string;
  permissions: string[];
}

interface AuthState {
  session: Session | null;
  me: Me | null;
  loading: boolean;
  /** Signed in, but not a staff member. */
  noAccess: boolean;
  can: (permission: string) => boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  reload: () => Promise<void>;
}

const Ctx = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [me, setMe] = useState<Me | null>(null);
  const [loading, setLoading] = useState(true);
  const [noAccess, setNoAccess] = useState(false);

  const loadMe = useCallback(async (s: Session | null) => {
    if (!s) {
      setMe(null);
      setNoAccess(false);
      setLoading(false);
      return;
    }
    const { data, error } = await supabase.rpc('erp_me');
    if (error || !data) {
      setMe(null);
      setNoAccess(true);
    } else {
      setMe(data as Me);
      setNoAccess(false);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      loadMe(data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      setSession(s);
      if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'USER_UPDATED') {
        setLoading(true);
        loadMe(s);
      }
    });
    return () => sub.subscription.unsubscribe();
  }, [loadMe]);

  const can = useCallback((p: string) => Boolean(me?.permissions.includes(p)), [me]);

  const signIn = useCallback(async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      throw new Error(
        /invalid/i.test(error.message)
          ? 'The email or password is not right.'
          : /banned/i.test(error.message)
            ? 'This account is suspended. Speak to your administrator.'
            : friendlyError(error.message),
      );
    }
  }, []);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  const reload = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    await loadMe(data.session);
  }, [loadMe]);

  return (
    <Ctx.Provider value={{ session, me, loading, noAccess, can, signIn, signOut, reload }}>
      {children}
    </Ctx.Provider>
  );
}

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}
