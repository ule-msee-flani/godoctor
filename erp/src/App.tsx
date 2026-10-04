import type { ReactNode } from 'react';
import { AuthProvider, useAuth } from './lib/auth';
import { useRoute, type Route } from './lib/router';
import { DialogProvider, Empty, NoticeProvider, Spinner } from './components/ui';
import { Layout } from './components/Layout';
import { LoginPage, NoAccessPage } from './pages/Login';
import { DashboardPage } from './pages/Dashboard';
import { PatientPage, PatientsPage } from './pages/Patients';
import {
  DoctorPage, DoctorsPage, LicencesPage, PharmaciesPage, PharmacyPage, VerificationPage,
} from './pages/Providers';
import {
  ConsultationPage, ConsultationsPage, OrderPage, OrdersPage, PrescriptionsPage,
} from './pages/Care';
import { FinancePage, PaymentsPage, PayoutsPage } from './pages/Finance';
import { AnnouncementsPage, ReviewsPage, TicketPage, TicketsPage } from './pages/Support';
import {
  ActivityPage, ChangesPage, ProfilePage, RolesPage, SettingsPage, StaffPage,
} from './pages/Company';

export function App() {
  return (
    <AuthProvider>
      <NoticeProvider>
        <DialogProvider>
          <Gate />
        </DialogProvider>
      </NoticeProvider>
    </AuthProvider>
  );
}

function Gate() {
  const { session, me, loading, noAccess } = useAuth();
  const route = useRoute();
  if (loading) {
    return (
      <div className="boot">
        <img src="./icon.png" alt="" width={56} height={56} />
        <Spinner text="Opening GoDoctor HQ…" />
      </div>
    );
  }
  if (!session) return <LoginPage />;
  if (noAccess || !me) return <NoAccessPage />;
  return (
    <Layout path={route.path}>
      <Page route={route} />
    </Layout>
  );
}

/** Each page with the permission it needs. Record pages are keyed by id so
 *  moving from one record to another starts fresh. */
function Page({ route }: { route: Route }) {
  const { can } = useAuth();
  const [a = '', b, c] = route.path;
  const need = (perm: string, page: ReactNode) =>
    can(perm) ? page : <Empty title="You don’t have access to this page">Ask an administrator if you need it.</Empty>;

  switch (a) {
    case '':
      return need('dashboard.view', <DashboardPage />);
    case 'patients':
      return need('patients.view', b ? <PatientPage key={b} id={b} /> : <PatientsPage route={route} />);
    case 'doctors':
      return need('providers.view', b ? <DoctorPage key={b} id={b} /> : <DoctorsPage route={route} />);
    case 'pharmacies':
      return need('providers.view', b ? <PharmacyPage key={b} id={b} /> : <PharmaciesPage route={route} />);
    case 'verification':
      return need('providers.verify', <VerificationPage />);
    case 'licences':
      return need('providers.view', <LicencesPage />);
    case 'consultations':
      return need('consultations.view', b ? <ConsultationPage key={b} id={b} /> : <ConsultationsPage route={route} />);
    case 'orders':
      return need('orders.view', b ? <OrderPage key={b} id={b} /> : <OrdersPage route={route} />);
    case 'prescriptions':
      return need('prescriptions.view', <PrescriptionsPage />);
    case 'finance':
      if (b === 'payments') return need('finance.view', <PaymentsPage route={route} />);
      if (b === 'payouts') return need('finance.view', <PayoutsPage route={route} />);
      return need('finance.view', <FinancePage />);
    case 'support':
      return need('support.view', b ? <TicketPage key={b} id={b} /> : <TicketsPage route={route} />);
    case 'reviews':
      return need('reviews.moderate', <ReviewsPage />);
    case 'announcements':
      return need('broadcast.send', <AnnouncementsPage />);
    case 'staff':
      if (b === 'roles') return need('staff.view', <RolesPage />);
      return need('staff.view', <StaffPage route={route} />);
    case 'activity':
      if (b === 'changes') return need('audit.view', <ChangesPage />);
      return need('audit.view', <ActivityPage route={route} />);
    case 'settings':
      return need('settings.manage', <SettingsPage />);
    case 'profile':
      return <ProfilePage />;
    default:
      return <Empty title="Page not found">{c ?? ''}</Empty>;
  }
}
