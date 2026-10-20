# Aurelia Care: Hospital Management System

## Setup (about 15 minutes)
1. Create a project at supabase.com.
2. SQL Editor: run `schema.sql`, `schema_v2.sql`, `schema_v3.sql`, then `schema_v4.sql` (one at a time, in that order, each once).
3. Project Settings > API: copy the Project URL and anon public key into the top of `config.js`. Also put the hospital's real phone, email, address and hours in `config.js`.
4. Test locally: `python -m http.server 8000` and open http://localhost:8000/ (the public website; staff sign in at login.html)
5. Sign up in the app, then make yourself the first admin in the SQL Editor:
   `update public.profiles set role = 'admin' where email = 'you@example.com';`
6. Sign in again. Use "Users and roles" to approve everyone else.

## Files
Everything lives in one folder, with no subfolders.
```
config.js         the ONLY file to edit: Supabase keys and hospital contact details
app.js            shared code: sign-in guard, sidebar, public navigation, theme switch, video background
style.css         all styles
hospital.mp4, hospital.webm, poster.jpg    the looping background video
index.html, services.html, book.html, contact.html    the public website
login.html, dashboard.html, requests.html, ...        the staff management system
schema.sql, schema_v2.sql, schema_v3.sql, schema_v4.sql    database setup (run in Supabase only)
reset.sql         erases the Aurelia Care tables so you can start over
```

## How the website and the system fit together
- **Public website** (anyone can open): `index.html` (home), `services.html`, `book.html`, `contact.html`.
- **Booking:** a visitor fills in `book.html`. The request is saved as a "new" row and appears under **Booking requests** for the front desk and admins. Visitors can only add requests; they can never read anything.
- **Staff:** "Staff login" on the website leads to `login.html`, then `dashboard.html`. Signed-in staff see "Open dashboard" in the website menu and "Hospital website" in the sidebar.

## Pages
| Page | Who can open it |
|---|---|
| index, services, book, contact (public website) | everyone |
| login, forgot, reset, pending | everyone |
| dashboard, patients, patient (detail, visit notes), appointments, profile | all staff |
| lab (order tests, record results) | admin, doctor, nurse (only admin and doctor order) |
| pharmacy (stock) | admin, doctor, nurse view; admin, nurse change stock |
| requests (website booking requests) | admin, receptionist |
| billing (invoices, payments) | admin, receptionist |
| admissions (wards and beds) | all staff view; admin, doctor, nurse admit and discharge; admin adds wards |
| prescriptions | admin, doctor, nurse view; admin and doctor prescribe; admin and nurse dispense (stock drops automatically) |
| claims (insurance) | admin, receptionist |
| reports (charts, CSV export) | admin |
| audit (who changed what) | admin |
| users (assign roles) | admin |

Visit notes and lab results are hidden from receptionists. Permissions are enforced in the database (Row Level Security), not only in the pages.

## Go-live checklist
1. **Host the folder** on any static host (Netlify, Vercel, Cloudflare Pages, GitHub Pages). It must be served over HTTPS.
2. **Supabase > Authentication > URL Configuration:** set Site URL to your live address and add `https://your-site/reset.html` to Redirect URLs, or password reset links will fail.
3. **Email:** Supabase's built-in email sender is heavily rate limited. Add your own SMTP provider under Authentication settings before many staff sign up.
4. **Decide on email confirmation** (Authentication > Providers > Email). Keep it on for production.
5. **Create the admin** (step 5 above) and add a second admin so the owner is never locked out.
6. **Try every role** with a test account each before real use: doctor, nurse, receptionist.
7. **Backups:** Free Supabase projects have no automatic backups. Use a paid plan or schedule exports before storing real patient data.
8. **Privacy:** patient records are sensitive personal data. Check Ghana's Data Protection Act requirements (registration with the Data Protection Commission, consent, retention) with the owner.
