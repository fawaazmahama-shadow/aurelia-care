// Light / dark switch. The choice is remembered in this browser.
(function(){
  let t = null; try { t = localStorage.getItem('ac-theme'); } catch (e) {}
  if (t !== 'light' && t !== 'dark') t = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  const root = document.documentElement; root.setAttribute('data-theme', t);
  if (document.querySelector('.theme-toggle')) return;
  document.body.insertAdjacentHTML('beforeend',
    '<button class="theme-toggle" type="button" id="themeBtn" aria-label="Switch between light and dark mode" title="Switch light / dark">' +
    '<svg class="ic-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"/></svg>' +
    '<svg class="ic-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.6 1.6M17.1 17.1l1.6 1.6M5.3 18.7l1.6-1.6M17.1 6.9l1.6-1.6"/></svg></button>');
  document.getElementById('themeBtn').onclick = () => {
    const next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', next); try { localStorage.setItem('ac-theme', next); } catch (e) {}
  };
})();

// Full-screen looping video background, shown on every page.
(function(){
  if (document.querySelector('.bg')) return;
  document.body.insertAdjacentHTML('afterbegin',
    '<div class="bg" aria-hidden="true"><video id="bgv" autoplay muted loop playsinline preload="auto" poster="poster.jpg">' +
    '<source src="hospital.mp4" type="video/mp4"><source src="hospital.webm" type="video/webm"></video></div><div class="bg-scrim"></div>');
  const v = document.getElementById('bgv'); v.muted = true;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches){ v.removeAttribute('autoplay'); v.pause(); return; }
  const go = () => { const p = v.play(); if (p && p.catch) p.catch(() => {}); };
  go();
  ['click','touchstart','keydown'].forEach(ev => addEventListener(ev, () => { if (v.paused) go(); }, { once:true, passive:true }));
  document.addEventListener('visibilitychange', () => { if (!document.hidden && v.paused) go(); });
})();

const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const err = e => alert(e.message || 'Something went wrong.');
const STAFF = ['admin','doctor','nurse','receptionist'];
const ROLES = ['admin','doctor','nurse','receptionist','pending'];
const money = n => 'GH₵ ' + Number(n || 0).toLocaleString(undefined, { minimumFractionDigits:2, maximumFractionDigits:2 });
const configured = typeof SUPABASE_URL !== 'undefined' && !SUPABASE_URL.startsWith('YOUR_');
const sb = configured ? supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;

function needSetup(){
  [...document.body.children].forEach(n => { if (!n.classList.contains('bg') && !n.classList.contains('bg-scrim') && !n.classList.contains('theme-toggle') && n.tagName !== 'SCRIPT') n.remove(); });
  document.body.insertAdjacentHTML('beforeend', '<div class="center"><div class="box" style="max-width:520px"><h1>Connect Supabase</h1><p>Open <code>config.js</code> and set SUPABASE_URL and SUPABASE_ANON_KEY at the top. Both are in your Supabase project under Project Settings, API.</p></div></div>');
}

async function getMe(){
  const { data:{ session } } = await sb.auth.getSession();
  if (!session) return { session:null, me:null };
  const { data } = await sb.from('profiles').select('*').eq('id', session.user.id).single();
  return { session, me:data };
}

// Every protected page calls this first. It redirects when the visitor shouldn't be here,
// and otherwise draws the sidebar and returns the signed-in profile.
async function guard(active, opts = {}){
  if (!configured){ needSetup(); return null; }
  const { session, me } = await getMe();
  if (!session){ location.replace('login.html'); return null; }
  if (!me){ alert('Could not load your profile. Check that schema.sql ran.'); await sb.auth.signOut(); location.replace('login.html'); return null; }
  if (!STAFF.includes(me.role)){ location.replace('pending.html'); return null; }
  if ((opts.admin && me.role !== 'admin') || (opts.roles && !opts.roles.includes(me.role))){ location.replace('dashboard.html'); return null; }
  const links = [['dashboard','Dashboard'],['patients','Patients'],['appointments','Appointments']];
  links.push(['admissions','Admissions']);
  if (['admin','doctor','nurse'].includes(me.role)) links.push(['lab','Lab tests'], ['prescriptions','Prescriptions'], ['pharmacy','Pharmacy']);
  if (['admin','receptionist'].includes(me.role)) links.push(['requests','Booking requests'], ['billing','Billing'], ['claims','Insurance claims']);
  if (me.role === 'admin') links.push(['reports','Reports'], ['audit','Audit log'], ['users','Users and roles']);
  links.push(['profile','My account'], ['index','Hospital website']);
  $('app').innerHTML = `<div class="shell"><aside><h1>Aurelia Care</h1>
    ${links.map(([k,t]) => `<a class="nav${k === active ? ' on' : ''}" href="${k}.html">${t}</a>`).join('')}
    <div class="who"><b>${esc(me.full_name || me.email)}</b>${esc(me.role)}<br><button class="ghost" id="out" style="margin-top:8px;padding:5px 12px">Sign out</button></div></aside>
    <main id="view"></main></div>`;
  $('out').onclick = async () => { await sb.auth.signOut(); location.replace('login.html'); };
  return me;
}

function downloadCSV(name, rows){
  const cell = v => { v = v == null ? '' : String(v); if (/^[=+\-@]/.test(v)) v = "'" + v; return '"' + v.replace(/"/g, '""') + '"'; };
  const keys = rows.length ? Object.keys(rows[0]) : [];
  const csv = [keys.map(cell).join(',')].concat(rows.map(r => keys.map(k => cell(r[k])).join(','))).join('\n');
  const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([csv], { type:'text/csv' })); a.download = name; a.click();
}

// ---------- Public website: top bar and footer shared by every public page ----------
function publicChrome(active){
  const H = (typeof HOSPITAL !== 'undefined') ? HOSPITAL : { name:'Aurelia Care', phone:'', emergencyPhone:'', email:'', address:'', hours:'' };
  const tel = p => String(p || '').replace(/[^+\d]/g, '');
  const links = [['index','Home'],['services','Services'],['contact','Contact']];
  document.getElementById('pubnav').outerHTML =
    `<nav class="pubnav" id="pubnav" aria-label="Main"><a class="logo" href="index.html">${esc(H.name)}</a>
      <button class="menu-btn" id="menuBtn" type="button" aria-label="Open menu" aria-expanded="false"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg></button>
      <div class="links">${links.map(([k,t]) => `<a href="${k}.html"${k === active ? ' class="on" aria-current="page"' : ''}>${t}</a>`).join('')}
        <a href="login.html" id="staffLink">Staff login</a><a class="btn" href="book.html">Book appointment</a></div></nav>`;
  document.getElementById('menuBtn').onclick = e => { const n = document.getElementById('pubnav'); const o = n.classList.toggle('open'); e.currentTarget.setAttribute('aria-expanded', o); };
  const foot = document.getElementById('pubfoot');
  if (foot) foot.outerHTML =
    `<footer class="foot"><div><h4>${esc(H.name)}</h4><p>Calm, coordinated care for patients and families in Accra.</p></div>
      <div><h4>Visit us</h4><p>${esc(H.address)}</p><p>${esc(H.hours)}</p></div>
      <div><h4>Get in touch</h4><p><a href="tel:${esc(tel(H.phone))}">${esc(H.phone)}</a></p><p><a href="mailto:${esc(H.email)}">${esc(H.email)}</a></p></div>
      <div class="foot-bottom"><span>&copy; ${new Date().getFullYear()} ${esc(H.name)}</span><a href="login.html">Staff login</a></div></footer>`;
  document.querySelectorAll('[data-h]').forEach(el => {
    const k = el.dataset.h, v = H[k] || '';
    el.textContent = v; if (el.tagName === 'A') el.href = (k === 'email' ? 'mailto:' : 'tel:') + (k === 'email' ? v : tel(v));
  });
  // Staff who are already signed in see a shortcut to the dashboard instead.
  if (configured) sb.auth.getSession().then(({ data:{ session } }) => {
    if (session){ const a = document.getElementById('staffLink'); if (a){ a.textContent = 'Open dashboard'; a.href = 'dashboard.html'; } }
  }).catch(() => {});
}
