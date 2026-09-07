# On-Demand Doctor App — Project Spec

## What this app is

A telemedicine marketplace app for Kenya connecting three independent user types:
- **Patients** — request virtual consultations with doctors, and can also order medicine directly from chemists
- **Doctors** — accept consultation requests (matched by specialty), conduct video consultations, issue prescriptions
- **Chemists/Pharmacies** — manage medicine inventory, fulfill medicine orders, can answer general clinical questions from doctors

Core relationships (three independent actors, not a strict linear pipeline):
- Patient ↔ Doctor: video consultation → diagnosis → prescription
- Patient ↔ Chemist: search medicine → check stock/price → order (with prescription if required) → escrowed payment → pickup/delivery arranged directly between patient and chemist
- Doctor ↔ Chemist: async general clinical Q&A (phase 2, lower priority)

This is explicitly NOT a linear "doctor then chemist" flow — a patient can go directly to a chemist for OTC medicine, or with an existing prescription (app-issued or an uploaded photo of an external one).

## Tech stack (decided)

- **Frontend**: Flutter, built for web (`flutter create --platforms=web`), deployed as an installable PWA (manifest.json + service worker, `display: standalone`). No native app store builds planned — install via "Add to Home Screen" on iOS, browser install prompt on Android/desktop. Single Flutter codebase serves patient, doctor, and chemist interfaces — each with a distinct UI/dashboard appropriate to that role.
- **Backend**: Supabase (Postgres database + auto-generated REST API + built-in auth + file storage + realtime subscriptions + row-level security). Chosen specifically because the developer is solo, non-backend-experienced, and wants a WordPress-admin-like dashboard experience for managing data — Supabase's table editor fills that role.
- **Business logic requiring custom code**: Supabase Edge Functions for anything that isn't simple CRUD — payment/escrow state transitions, M-Pesa Daraja API integration, emergency-keyword detection logic.
- **Video calls**: not yet chosen/integrated — candidates are Agora or Daily.co (both have usable free tiers). To be added later; build the consultation flow with a clean interface/abstraction so the video SDK can be dropped in without reworking the rest of the flow.
- **Payments**: M-Pesa via Daraja API for the Kenyan market. To be integrated later — for now, build the `Order`/`Payment` schema and flow assuming M-Pesa, but the actual Daraja API calls will be wired up in a later work session.
- **Realtime matching**: use Supabase realtime subscriptions (not a custom WebSocket server) — e.g., a doctor's app subscribes to their incoming-offers table and gets notified instantly when a new consultation request arrives.

## Build sequencing (what to build now vs. later)

**Build now (core structure):**
- Supabase schema (all tables below)
- Auth flows for all three roles (see Auth section)
- Patient, doctor, and chemist dashboards/screens per the flow descriptions below
- Consultation request → matching → offer/accept logic (using Supabase realtime)
- Prescription issuing UI (structured drug search + free-text fallback)
- Chemist inventory management UI
- Medicine search + nearby chemist matching (by stock)
- Order creation flow and order status states (schema + UI, even before real payment is wired up — can start as a stubbed/mock payment step)
- Notifications system (in-app + push via PWA where supported; note iOS PWA push requires the app to be installed to home screen first)
- Emergency-detection keyword check on the intake form (hard-stop flow, not a warning)
- Doctor verification workflow (admin approval queue; doctor cannot go "available" until `license_verified = true`)

**Explicitly deferred to a later session:**
- M-Pesa Daraja API integration (real payment capture, escrow hold/release)
- Video call SDK integration (Agora or Daily.co)
- Chemist-doctor Q&A feature (phase 2)
- Refill/repeat prescription flow (phase 2)
- Multi-language support (Swahili) (phase 2)
- Doctor scheduling / non-on-demand appointments (phase 2)
- Admin analytics/reporting dashboards (phase 2)

**Not engineering — open business/legal items the developer must handle separately, not something to build around silently:**
- Kenya Digital Health Act / telemedicine certification and registration requirements
- Terms of Service, Privacy Policy, liability structure — needs real legal review
- Professional indemnity insurance for the platform
- Doctor license verification is manual (human checks the public KMPDC register) for v1 — no automated KMPDC integration yet

## Data model

### User (base table, shared across roles)
- id, phone, email, password_hash (handled by Supabase Auth), role (patient/doctor/chemist/admin), created_at, status (active/suspended)

### PatientProfile
- user_id, name, date_of_birth, location (lat/lng), allergies, current_medications, chronic_conditions

### DoctorProfile
- user_id, name, specialty(ies), license_number, license_verified (bool, default false), license_expiry, verification_documents (file refs), status (available/offered/busy/offline), rating_avg

### ChemistProfile
- user_id, business_name, location (lat/lng), registration_number, verified (bool, default false)

### Consultation
- id, patient_id, doctor_id (nullable until matched), specialty_requested, symptom_summary, status (requested/matched/in_progress/completed/cancelled/unmatched), started_at, ended_at, video_session_id

### IntakeForm
- consultation_id, symptoms, duration, severity, flagged_emergency (bool)

### Prescription
- id, consultation_id (nullable — null if uploaded/external), patient_id, doctor_id (nullable if external), issued_at, valid_until, source (app/external_upload), image_url (if uploaded)

### PrescriptionItem
- prescription_id, drug_id (nullable), free_text_name (nullable), dosage, quantity, instructions

### Drug (structured catalog)
- id, generic_name, brand_names, form, requires_prescription (bool), category
- Seed data: start with Kenya Essential Medicines List (KEML) subset (~200-500 common drugs), not an exhaustive database

### ChemistInventory
- chemist_id, drug_id, quantity, price, last_updated_at

### Order
- id, patient_id, chemist_id, prescription_id (nullable if all items OTC), status (placed/confirmed/ready/fulfilled/disputed/refunded), total_amount, escrow_status (held/released/refunded), fulfillment_type (pickup/delivery — informational only; actual logistics happen outside the app between patient and chemist)
- Application-level rule (not enforceable purely in DB across multiple items): checkout must be blocked unless every `requires_prescription` item in the order has a valid attached prescription

### OrderItem
- order_id, drug_id, quantity, unit_price

### Payment
- order_id or consultation_id, amount, provider (mpesa/card), status, escrow_release_at

### Review
- consultation_id or order_id, rating, comment, flagged_for_review (bool)

### ChemistDoctorQuery (phase 2)
- chemist_id, question, answered_by_doctor_id, answer, created_at

## Auth

- Use Supabase Auth. Phone/OTP login preferred for the Kenyan market (also support email as fallback).
- Role selected at registration (patient/doctor/chemist) — determines which profile table gets a row and which dashboard the user sees.
- Doctors and chemists start in a "pending verification" state and cannot access full functionality (doctor: cannot go "available"; chemist: cannot list inventory publicly) until an admin approves them.
- Use Supabase Row-Level Security to enforce: chemists can never read patient diagnosis/consultation data, patients can only read their own records, doctors can only read consultations assigned to them.

## Key flows to build

### Emergency detection
On intake form submission, before allowing the request to proceed to doctor matching: check symptom text against a static, doctor-reviewed red-flag keyword list (chest pain, difficulty breathing, severe bleeding, loss of consciousness, stroke signs, suicidal ideation, anaphylaxis signs, pregnancy complications with bleeding, etc.). If flagged: **hard stop** — do not allow matching for that request. Show a clear message directing to emergency services/nearest hospital, and log `flagged_emergency = true` for audit purposes. Always give a path to reach a human, not a dead end.

### Doctor matching
1. Patient submits intake form (passes emergency check) → Consultation created, `status = requested`
2. Query available, verified doctors matching `specialty_requested`
3. Rank by longest-idle-time (fair rotation) as the v1 default
4. Offer to top candidate with a short accept window (~20-30 seconds); flip their status to `offered` during this window so they're not double-offered
5. On decline/timeout, offer to next candidate
6. On accept: `status = matched`, both parties notified
7. If no doctors available in that specialty: fallback to general practitioners if appropriate, otherwise `status = unmatched` with a "notify me when available" option

### Prescription issuing
Doctor, during/after a consultation, searches the structured `Drug` table (autocomplete) or free-types a name if not found. Each `PrescriptionItem` records whether it came from the structured list or free text — this matters because free-text items can't be reliably matched against chemist inventory later.

### Medicine ordering (direct patient-to-chemist path)
1. Patient searches a drug by name
2. See nearby chemists with confirmed stock (`ChemistInventory.quantity > 0`) and price, sorted by distance
3. If `Drug.requires_prescription = true`, patient must attach a valid prescription — either an existing app-issued one, or upload a photo of an external one (chemist manually verifies uploaded photos)
4. Patient selects chemist, pays (escrow hold)
5. Chemist confirms order, prepares, marks ready
6. Pickup/delivery logistics are arranged directly between patient and chemist — the app does not manage delivery
7. Patient confirms receipt → escrow releases funds to chemist
8. Dispute/timeout path needed: if patient never confirms within a reasonable window, and if chemist never confirms an order, define auto-resolution behavior (flag for now, exact timeout policy TBD)

### Notifications
Needed for: doctor receiving a consultation offer, patient being matched, prescription ready, order status changes. Use push notifications via the PWA where supported (note: iOS requires the app to be installed to the home screen before push works at all — prompt users to install after their first successful action, not on landing). Because push reliability varies (especially iOS Safari), also consider SMS fallback for critical alerts given variable connectivity in the target market — flagged as a decision still to be made, not yet built.

## UI/Screens needed

**Patient**: onboarding/auth, home screen (two clear entry points: "See a Doctor" and "Order Medicine," plus consultation/order history), intake form, consultation waiting/matched screen, video call screen (once SDK integrated), prescription view/download, medicine search, chemist selection, order/payment flow, order status tracking, install-to-home-screen prompt (with iOS-specific walkthrough).

**Doctor**: onboarding/auth with license upload, pending-verification state screen, availability toggle + specialty selection, incoming offers queue, in-call panel (patient info/symptoms/notes/prescription builder), consultation history.

**Chemist**: onboarding/auth with registration upload, pending-verification state screen, inventory management (table-style, easy bulk editing), incoming orders queue, order status management.

## Notes on styling/UX

- Doctor and chemist interfaces should be optimized for desktop/web use (larger screens, table-dense layouts) even though it's the same Flutter/PWA codebase — these are professional, desk-based use cases.
- Patient interface should be optimized for mobile-first use, Uber/Duolingo-style simplicity — minimal decisions on the home screen, one clear primary action.
- Keep the video call area of the doctor's in-call screen as a distinct component/panel so a video SDK can be dropped in later without restructuring the surrounding UI (patient info, notes, prescription builder).

## Known open decisions (not yet resolved — flag rather than guess)

- Business model / commission structure (platform fee amount/mechanism)
- Doctor payout timing and method
- Dispute/timeout policy specifics for orders and escrow
- Whether in-consultation text chat is needed as a fallback alongside video
- Exact SMS-fallback-for-notifications decision
