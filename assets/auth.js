/* NOOK — auth.js
 * Sistema real de cuentas de usuario con rol (reemplaza la contraseña compartida).
 * Compartido por las 6 herramientas + index.html + cocina/ + formatos/ + admin/.
 *
 * Requiere que la página también cargue, ANTES de este script:
 *   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
 *
 * Uso típico en una página de herramienta (protegida por rol):
 *   <script src="../assets/auth.js"></script>
 *   <script>NookAuth.guard({ allow: ['gerencia','chef'], home: '../' });</script>
 *
 * Uso en el panel de administración:
 *   <script src="../assets/auth.js"></script>
 *   <script>NookAuth.guardAdmin({ home: '../' }).then(() => { /* cargar tabla *\/ });</script>
 */
(function (global) {
  'use strict';

  const SUPA_URL = 'https://fcswffoilwqltkghlvff.supabase.co';
  const SUPA_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjc3dmZm9pbHdxbHRrZ2hsdmZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk2NjE5MzksImV4cCI6MjEwNTIzNzkzOX0.dMP-7fB3rwaYhYnMw4UQXFSiLNeKe963cnWl3w8fy1E';
  const MARIO_EMAIL = 'mario@delamorazumaran.com';

  let _client = null;
  function client() {
    if (!_client) {
      if (!global.supabase || !global.supabase.createClient) {
        throw new Error('supabase-js no cargó — falta el <script> del CDN antes de auth.js');
      }
      _client = global.supabase.createClient(SUPA_URL, SUPA_ANON);
    }
    return _client;
  }

  /* ---------- estilos (inyectados una sola vez) ---------- */
  function injectStyles() {
    if (document.getElementById('nook-auth-style')) return;
    const s = document.createElement('style');
    s.id = 'nook-auth-style';
    s.textContent = `
      body.nook-locked > *:not(#nook-auth-overlay){display:none !important;}
      body:not(.nook-locked) #nook-auth-overlay{display:none !important;}
      #nook-auth-overlay{position:fixed;inset:0;background:#2b4a5e;color:#faf7ee;display:flex;
        align-items:center;justify-content:center;z-index:9999;font-family:'Poppins',-apple-system,"Helvetica Neue",Arial,sans-serif;padding:20px;}
      #nook-auth-overlay *{box-sizing:border-box;}
      #nook-auth-overlay .box{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.15);
        border-radius:14px;padding:32px 30px;max-width:380px;width:100%;}
      #nook-auth-overlay h1{font-size:15px;letter-spacing:.06em;text-transform:uppercase;margin:0 0 4px;color:#faf7ee;}
      #nook-auth-overlay .sub{font-size:12px;color:rgba(250,247,238,.6);margin:0 0 18px;}
      #nook-auth-overlay input, #nook-auth-overlay select{width:100%;padding:10px 12px;border-radius:8px;
        border:1px solid rgba(255,255,255,.25);background:rgba(255,255,255,.08);color:#faf7ee;
        font-family:inherit;font-size:14px;margin-bottom:10px;}
      #nook-auth-overlay input::placeholder{color:rgba(250,247,238,.5);}
      #nook-auth-overlay button.na-btn{width:100%;padding:11px;border:none;border-radius:8px;
        background:#b8935a;color:#26221c;font-weight:700;font-family:inherit;font-size:14px;cursor:pointer;margin-top:4px;}
      #nook-auth-overlay button.na-btn:disabled{opacity:.6;cursor:default;}
      #nook-auth-overlay button.na-link{background:none;border:none;color:#b8935a;font-family:inherit;
        font-size:12.5px;cursor:pointer;text-decoration:underline;padding:0;margin-top:14px;}
      #nook-auth-overlay .na-err{color:#e8a3a3;font-size:12.5px;margin-top:10px;min-height:14px;}
      #nook-auth-overlay .na-ok{color:#9fd6a8;font-size:12.5px;margin-top:10px;}
      #nook-auth-overlay .na-msg{font-size:14px;line-height:1.5;color:#faf7ee;}
      #nook-auth-overlay a.na-home{color:#b8935a;font-weight:700;font-size:13px;}
      #nook-badge{position:fixed;bottom:14px;right:14px;z-index:500;background:#2b4a5e;color:#faf7ee;
        border-radius:999px;padding:8px 14px;font-family:'Poppins',-apple-system,sans-serif;font-size:11.5px;
        display:flex;align-items:center;gap:8px;box-shadow:0 4px 14px rgba(0,0,0,.2);}
      #nook-badge b{color:#e9c98f;}
      #nook-badge button{background:rgba(255,255,255,.15);border:none;color:#faf7ee;border-radius:6px;
        padding:4px 9px;font-size:11px;cursor:pointer;font-family:inherit;}
      #nook-badge a{background:#b8935a;color:#26221c;border-radius:6px;padding:4px 9px;font-size:11px;
        font-weight:700;text-decoration:none;font-family:inherit;white-space:nowrap;}
    `;
    document.head.appendChild(s);
  }

  function overlayEl() {
    let el = document.getElementById('nook-auth-overlay');
    if (!el) {
      el = document.createElement('div');
      el.id = 'nook-auth-overlay';
      document.body.appendChild(el);
    }
    return el;
  }
  function lock(html) {
    injectStyles();
    overlayEl().innerHTML = '<div class="box">' + html + '</div>';
    document.body.classList.add('nook-locked');
  }
  function unlock() {
    document.body.classList.remove('nook-locked');
  }

  /* ---------- perfil ---------- */
  async function getSessionAndProfile() {
    const { data: { session } } = await client().auth.getSession();
    if (!session) return { session: null, profile: null };
    const { data: profile, error } = await client()
      .from('profiles')
      .select('id,email,nombre,telefono,puesto,rol,aprobado,created_at')
      .eq('id', session.user.id)
      .single();
    if (error) return { session, profile: null };
    return { session, profile };
  }

  /* ---------- pantallas ---------- */
  function screenAuth(home, opts) {
    const mode = opts && opts._mode === 'signup' ? 'signup' : 'login';
    const err = (opts && opts._err) || '';
    const info = (opts && opts._info) || '';
    if (mode === 'login') {
      lock(`
        <h1>Acceso NOOK</h1>
        <p class="sub">Inicia sesión con tu cuenta.</p>
        <input type="email" id="na-email" placeholder="correo@ejemplo.com" autocomplete="username">
        <input type="password" id="na-pass" placeholder="Contraseña" autocomplete="current-password">
        <button class="na-btn" id="na-submit">Entrar</button>
        <button class="na-link" id="na-toggle">¿No tienes cuenta? Regístrate</button>
        ${err ? `<div class="na-err">${escapeHtml(err)}</div>` : ''}
        ${info ? `<div class="na-ok">${escapeHtml(info)}</div>` : ''}
      `);
      byId('na-submit').onclick = () => doLogin();
      byId('na-toggle').onclick = () => screenAuth(home, { _mode: 'signup' });
      byId('na-pass').addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });
    } else {
      lock(`
        <h1>Crear cuenta NOOK</h1>
        <p class="sub">Tu cuenta queda pendiente de aprobación de Mario hasta que te asigne un rol.</p>
        <input type="text" id="na-nombre" placeholder="Nombre completo">
        <input type="text" id="na-telefono" placeholder="Teléfono">
        <input type="text" id="na-puesto" placeholder="Puesto">
        <input type="email" id="na-email" placeholder="correo@ejemplo.com" autocomplete="username">
        <input type="password" id="na-pass" placeholder="Contraseña (mínimo 6 caracteres)" autocomplete="new-password">
        <button class="na-btn" id="na-submit">Registrarme</button>
        <button class="na-link" id="na-toggle">¿Ya tienes cuenta? Inicia sesión</button>
        ${err ? `<div class="na-err">${escapeHtml(err)}</div>` : ''}
        ${info ? `<div class="na-ok">${escapeHtml(info)}</div>` : ''}
      `);
      byId('na-submit').onclick = () => doSignup();
      byId('na-toggle').onclick = () => screenAuth(home, { _mode: 'login' });
    }
  }

  function screenPending(home, profile, session) {
    const soyMario = session && session.user && session.user.email &&
      session.user.email.toLowerCase() === MARIO_EMAIL;
    lock(`
      <h1>Cuenta pendiente</h1>
      <p class="na-msg">Tu cuenta (<b>${escapeHtml(profile.email)}</b>) está registrada pero pendiente de
      aprobación por Mario. Cuando te asigne un rol, tendrás acceso.</p>
      ${soyMario ? `<p class="na-msg" style="margin-top:14px;">Detectamos que iniciaste sesión con el correo de Mario —
        puedes entrar al <a class="na-home" href="${home}admin/">panel de administración</a> para aprobarte.</p>` : ''}
      <button class="na-btn" id="na-signout" style="margin-top:16px;">Cerrar sesión</button>
    `);
    byId('na-signout').onclick = () => signOut(home);
  }

  function screenDenied(home, profile, reason) {
    lock(`
      <h1>Acceso denegado</h1>
      <p class="na-msg">${escapeHtml(reason)}</p>
      <a class="na-home" href="${home}">&larr; Menú principal</a>
      <button class="na-btn" id="na-signout" style="margin-top:16px;">Cerrar sesión</button>
    `);
    byId('na-signout').onclick = () => signOut(home);
  }

  function screenError(home, msg) {
    lock(`
      <h1>Error</h1>
      <p class="na-msg">${escapeHtml(msg)}</p>
      <a class="na-home" href="${home}">&larr; Menú principal</a>
    `);
  }

  function badge(profile, home) {
    if (document.getElementById('nook-badge')) return;
    const esMario = (profile.email || '').toLowerCase() === MARIO_EMAIL;
    const el = document.createElement('div');
    el.id = 'nook-badge';
    el.innerHTML = `<span><b>${escapeHtml(profile.nombre || profile.email)}</b> · ${escapeHtml(profile.rol)}</span>
      ${esMario ? `<a id="nook-badge-config" href="${(home || './')}admin/">Configuración</a>` : ''}
      <button id="nook-badge-out">Salir</button>`;
    document.body.appendChild(el);
    document.getElementById('nook-badge-out').onclick = () => signOut(home || './');
  }

  function byId(id) { return document.getElementById(id); }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  /* ---------- estado del flujo activo (un guard por página) ---------- */
  let _home = './';
  let _allow = null;       // null => modo admin; array => modo sección
  let _adminMode = false;
  let _resolve = null;     // resuelve la Promise de guard()/guardAdmin() una sola vez, en un estado terminal

  function finish(value) {
    if (_resolve) { const r = _resolve; _resolve = null; r(value); }
  }

  /* ---------- acciones ---------- */
  async function doLogin() {
    const email = byId('na-email').value.trim();
    const pass = byId('na-pass').value;
    if (!email || !pass) { screenAuth(_home, { _mode: 'login', _err: 'Completa correo y contraseña.' }); return; }
    byId('na-submit').disabled = true; byId('na-submit').textContent = 'Entrando…';
    const { error } = await client().auth.signInWithPassword({ email, password: pass });
    if (error) { screenAuth(_home, { _mode: 'login', _err: traducirError(error.message) }); return; }
    await startFlow();
  }

  async function doSignup() {
    const nombre = byId('na-nombre').value.trim();
    const telefono = byId('na-telefono').value.trim();
    const puesto = byId('na-puesto').value.trim();
    const email = byId('na-email').value.trim();
    const pass = byId('na-pass').value;
    if (!email || !pass) { screenAuth(_home, { _mode: 'signup', _err: 'Completa correo y contraseña.' }); return; }
    if (pass.length < 6) { screenAuth(_home, { _mode: 'signup', _err: 'La contraseña debe tener al menos 6 caracteres.' }); return; }
    byId('na-submit').disabled = true; byId('na-submit').textContent = 'Creando…';
    const { data, error } = await client().auth.signUp({
      email, password: pass,
      options: { data: { nombre, telefono, puesto } }
    });
    if (error) { screenAuth(_home, { _mode: 'signup', _err: traducirError(error.message) }); return; }
    if (!data.session) {
      screenAuth(_home, { _mode: 'login', _info: 'Cuenta creada. Revisa tu correo para confirmarla y luego inicia sesión.' });
      return;
    }
    await startFlow();
  }

  async function signOut(home) {
    await client().auth.signOut();
    location.href = home || _home || './';
  }

  function traducirError(msg) {
    if (/invalid login credentials/i.test(msg)) return 'Correo o contraseña incorrectos.';
    if (/already registered|already exists/i.test(msg)) return 'Ese correo ya tiene una cuenta — inicia sesión.';
    if (/rate limit/i.test(msg)) return 'Demasiados intentos, espera un momento.';
    return msg;
  }

  /* ---------- flujo único: se re-ejecuta tras cada login/signup exitoso ---------- */
  async function startFlow() {
    let session, profile;
    try {
      ({ session, profile } = await getSessionAndProfile());
    } catch (e) {
      screenError(_home, 'No se pudo verificar la sesión: ' + e.message);
      finish(null);
      return;
    }
    if (!session) {
      screenAuth(_home, { _mode: 'login' });
      return; // no resuelve todavía — esperamos a que el usuario inicie sesión o se registre
    }

    if (_adminMode) {
      const email = (session.user.email || '').toLowerCase();
      if (email !== MARIO_EMAIL) {
        screenDenied(_home, null, 'Este panel es solo para mario@delamorazumaran.com. La seguridad real la aplica la función admin_set_profile en el servidor — esta pantalla es solo para no mostrar controles que de todos modos serían rechazados.');
        finish(null);
        return;
      }
      unlock();
      finish(session);
      return;
    }

    if (!profile) { screenError(_home, 'No se encontró tu perfil. Avisa a Mario.'); finish(null); return; }
    if (!profile.aprobado || profile.rol === 'pendiente') { screenPending(_home, profile, session); finish(null); return; }
    if (_allow && _allow.indexOf(profile.rol) === -1) {
      screenDenied(_home, profile, `Tu rol (${profile.rol}) no tiene acceso a esta sección.`);
      finish(null);
      return;
    }
    unlock();
    badge(profile, _home);
    finish(profile);
  }

  /* ---------- API pública ---------- */
  function guard(opts) {
    opts = opts || {};
    _home = opts.home || './';
    _allow = opts.allow || ['gerencia', 'chef'];
    _adminMode = false;
    injectStyles();
    overlayEl();
    return new Promise((resolve) => { _resolve = resolve; startFlow(); });
  }

  function guardAdmin(opts) {
    opts = opts || {};
    _home = opts.home || './';
    _allow = null;
    _adminMode = true;
    injectStyles();
    overlayEl();
    return new Promise((resolve) => { _resolve = resolve; startFlow(); });
  }

  global.NookAuth = {
    MARIO_EMAIL,
    client,
    guard,
    guardAdmin,
    signOut,
    getSessionAndProfile
  };
})(window);
