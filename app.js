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

// Set these two values from Supabase: Project Settings > API
const SUPABASE_URL = 'https://utmbqgbunijtbvhaifsh.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_msX_J9dqNG72UvG6KnFJ3w_1OKQOe9_';

const $ = id => document.getElementById(id);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const err = e => alert(e.message || 'Something went wrong.');
const STAFF = ['admin','doctor','nurse','receptionist'];
const ROLES = ['admin','doctor','nurse','receptionist','pending'];
const money = n => 'GH₵ ' + Number(n || 0).toLocaleString(undefined, { minimumFractionDigits:2, maximumFractionDigits:2 });
const configured = !SUPABASE_URL.startsWith('YOUR_');
const sb = configured ? supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;

function needSetup(){
  [...document.body.children].forEach(n => { if (!n.classList.contains('bg') && !n.classList.contains('bg-scrim') && n.tagName !== 'SCRIPT') n.remove(); });
  document.body.insertAdjacentHTML('beforeend', '<div class="center"><div class="box" style="max-width:520px"><h1>Connect Supabase</h1><p>Open <code>app.js</code> and set SUPABASE_URL and SUPABASE_ANON_KEY at the top. Both are in your Supabase project under Project Settings, API.</p></div></div>');
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
  if ((opts.admin && me.role !== 'admin') || (opts.roles && !opts.roles.includes(me.role))){ location.replace('index.html'); return null; }
  const links = [['index','Dashboard'],['patients','Patients'],['appointments','Appointments']];
  links.push(['admissions','Admissions']);
  if (['admin','doctor','nurse'].includes(me.role)) links.push(['lab','Lab tests'], ['prescriptions','Prescriptions'], ['pharmacy','Pharmacy']);
  if (['admin','receptionist'].includes(me.role)) links.push(['billing','Billing'], ['claims','Insurance claims']);
  if (me.role === 'admin') links.push(['reports','Reports'], ['audit','Audit log'], ['users','Users and roles']);
  links.push(['profile','My account']);
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
