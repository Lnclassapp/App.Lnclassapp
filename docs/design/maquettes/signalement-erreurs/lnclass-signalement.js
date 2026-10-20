/*
 * Lnclass — Signalement d'erreurs (mode relecture enseignant)
 * Module autonome, sans dépendance. À inclure sur n'importe quelle fiche :
 *   <script src="lnclass-signalement.js"
 *           data-email="contact@lnclass.com"
 *           data-fiche="La propriété de Thalès (Maths 3e)"
 *           data-zone="main"></script>
 * Options (attributs data-*) :
 *   data-email    adresse qui reçoit les signalements
 *   data-fiche    nom de la fiche, repris dans le rapport
 *   data-zone     sélecteur CSS de la zone relisible (défaut : body)
 *   data-endpoint URL facultative : si fournie, le rapport est envoyé en POST JSON
 *                 (sinon ouverture de la messagerie + copie dans le presse-papiers)
 * API : window.LnclassSignalement.open() / .close() / .getReport()
 */
(function () {
  'use strict';
  var script = document.currentScript || {};
  var ds = script.dataset || {};
  var CFG = {
    email: ds.email || 'contact@lnclass.com',
    fiche: ds.fiche || document.title || 'Fiche',
    zone: ds.zone || 'body',
    endpoint: ds.endpoint || ''
  };
  var RED = '#c0392b', INK = '#23263a', MUTED = '#6a6d80', PAPER = '#fffdf8', LINE = '#cfd6ea';
  var state = { on: false, marks: [], note: '', name: '' };
  var ranges = {};
  var hasHL = !!(window.CSS && CSS.highlights && typeof Highlight !== 'undefined');

  var css = document.createElement('style');
  css.textContent =
    '::highlight(lnc-err){background-color:#fbe7a1;color:#8a2a1c;text-decoration:underline wavy ' + RED + '}' +
    '.lnc-mark{background:#fbe7a1;color:#8a2a1c;text-decoration:underline wavy ' + RED + '}' +
    '#lnc-root,#lnc-root *{box-sizing:border-box}' +
    '#lnc-root{position:fixed;right:20px;bottom:20px;z-index:2147483000;font:14.5px/1.45 Georgia,serif;color:' + INK + '}' +
    '#lnc-root button,#lnc-root input,#lnc-root textarea{font:inherit}' +
    '#lnc-fab{display:flex;align-items:center;gap:8px;min-height:48px;padding:0 18px 0 14px;border-radius:24px;border:none;background:' + RED + ';color:#fff;font-size:16px;cursor:pointer;box-shadow:0 6px 18px rgba(120,30,20,.35)}' +
    '#lnc-fab i{width:22px;height:22px;border-radius:50%;border:2px solid #fff;display:flex;align-items:center;justify-content:center;font-style:normal;font-weight:700;font-size:13px}' +
    '#lnc-panel{width:350px;max-width:calc(100vw - 24px);max-height:78vh;overflow-y:auto;overflow-x:hidden;background:' + PAPER + ';border:2px solid ' + RED + ';border-radius:10px;box-shadow:0 10px 30px rgba(40,30,70,.25);padding:14px 16px;display:flex;flex-direction:column;gap:10px}' +
    '#lnc-panel .row{display:flex;justify-content:space-between;align-items:baseline;gap:8px}' +
    '#lnc-panel .ttl{font-size:20px;font-weight:700;color:' + RED + '}' +
    '#lnc-panel .x{border:none;background:none;color:' + MUTED + ';cursor:pointer;font-size:14px;padding:4px}' +
    '#lnc-panel .muted{color:' + MUTED + ';font-size:13.5px;margin:0}' +
    '#lnc-panel .item{display:flex;flex-direction:column;gap:4px;padding:8px 10px;border:1.5px solid #e2d9c4;border-radius:6px;background:#fff}' +
    '#lnc-panel .item b{color:#8a2a1c}' +
    '#lnc-panel .where{font-size:12.5px;color:' + MUTED + '}' +
    '#lnc-panel input,#lnc-panel textarea{width:100%;min-width:0;font-size:13.5px;padding:6px 8px;border:1px solid ' + LINE + ';border-radius:4px;background:#fff;outline:none}' +
    '#lnc-panel textarea{min-height:56px;resize:vertical}' +
    '#lnc-send{min-height:46px;border:none;border-radius:8px;background:' + RED + ';color:#fff;font-size:16px;cursor:pointer}' +
    '#lnc-send[disabled]{opacity:.4;cursor:default}' +
    '#lnc-ok{color:#1e7a4a;font-weight:600;font-size:13.5px}' +
    '#lnc-clear{align-self:flex-start;border:none;background:none;padding:0;color:' + MUTED + ';text-decoration:underline;cursor:pointer;font-size:13px}' +
    '#lnc-banner{position:fixed;top:0;left:0;right:0;z-index:2147482999;background:' + RED + ';color:#fff;text-align:center;padding:8px 12px;font:15px Georgia,serif}' +
    '@media (max-width:640px){#lnc-root{right:12px;bottom:12px}#lnc-root.open{left:0;right:0;bottom:0}' +
    '#lnc-root.open #lnc-panel{width:100%;max-width:none;max-height:60vh;border-radius:18px 18px 0 0;border-width:2px 0 0;padding-bottom:24px}}';
  document.head.appendChild(css);

  var root = document.createElement('div');
  root.id = 'lnc-root';
  var banner = document.createElement('div');
  banner.id = 'lnc-banner';
  banner.textContent = 'Mode relecture · cliquez sur un mot ou sélectionnez une expression pour la cocher';

  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function inUI(t) { return t && t.closest && (t.closest('#lnc-root') || t.closest('#lnc-banner')); }
  function zoneEl() { return document.querySelector(CFG.zone) || document.body; }

  function paint() {
    if (hasHL) {
      try { CSS.highlights.set('lnc-err', new Highlight(...Object.values(ranges))); } catch (e) {}
    }
  }

  function report() {
    var L = ['Signalement d\'erreurs — ' + CFG.fiche, 'Page : ' + location.href, 'Date : ' + new Date().toLocaleString('fr-FR')];
    if (state.name) L.push('Enseignant : ' + state.name);
    L.push('', state.marks.length + ' élément(s) signalé(s) :', '');
    state.marks.forEach(function (m, i) {
      L.push((i + 1) + '. « ' + m.text + ' »' + (m.where ? ' — ' + m.where : ''));
      if (m.ctx && m.ctx !== m.text) L.push('   Contexte : ' + m.ctx);
      if (m.comment) L.push('   Correction proposée : ' + m.comment);
      L.push('');
    });
    if (state.note) L.push('Commentaire général : ' + state.note);
    return L.join('\n');
  }

  function render() {
    root.className = state.on ? 'open' : '';
    if (!state.on) {
      root.innerHTML = '<button id="lnc-fab" type="button"><i>!</i>Signaler une erreur</button>';
      root.querySelector('#lnc-fab').onclick = open;
      if (banner.parentNode) banner.remove();
      return;
    }
    if (!banner.parentNode) document.body.appendChild(banner);
    var n = state.marks.length;
    var h = '<div id="lnc-panel">' +
      '<div class="row"><span class="ttl">Mode relecture</span><button class="x" id="lnc-close" type="button">Quitter ×</button></div>' +
      '<p class="muted">Cliquez sur un mot ou sélectionnez une expression pour la cocher. Cliquez de nouveau dessus pour la retirer.</p>' +
      '<div style="font-weight:600">' + (n ? n + ' élément' + (n > 1 ? 's' : '') + ' coché' + (n > 1 ? 's' : '') : 'Aucun élément coché pour l\'instant') + '</div>';
    state.marks.forEach(function (m) {
      h += '<div class="item"><div class="row"><b>« ' + esc(m.text) + ' »</b><button class="x" type="button" data-rm="' + m.id + '" title="Retirer">×</button></div>' +
        (m.where ? '<span class="where">' + esc(m.where) + '</span>' : '') +
        '<input type="text" data-cm="' + m.id + '" placeholder="Correction proposée (facultatif)" value="' + esc(m.comment) + '"></div>';
    });
    h += '<textarea id="lnc-note" placeholder="Commentaire général (facultatif)">' + esc(state.note) + '</textarea>' +
      '<input id="lnc-name" type="text" placeholder="Votre nom et établissement (facultatif)" value="' + esc(state.name) + '">' +
      '<button id="lnc-send" type="button"' + (n ? '' : ' disabled') + '>Signaler à l\'équipe Lnclass</button>' +
      '<div id="lnc-ok" hidden></div>' +
      '<button id="lnc-clear" type="button">Tout effacer</button></div>';
    root.innerHTML = h;
    root.querySelector('#lnc-close').onclick = close;
    root.querySelector('#lnc-send').onclick = send;
    root.querySelector('#lnc-clear').onclick = function () { clearMarks(); render(); };
    root.querySelector('#lnc-note').oninput = function (e) { state.note = e.target.value; };
    root.querySelector('#lnc-name').oninput = function (e) { state.name = e.target.value; };
    root.querySelectorAll('[data-rm]').forEach(function (b) { b.onclick = function () { removeMark(b.getAttribute('data-rm')); }; });
    root.querySelectorAll('[data-cm]').forEach(function (inp) {
      inp.oninput = function () { var m = find(inp.getAttribute('data-cm')); if (m) m.comment = inp.value; };
    });
  }

  function find(id) { for (var i = 0; i < state.marks.length; i++) if (state.marks[i].id === id) return state.marks[i]; }

  function unwrap(id) {
    document.querySelectorAll('.lnc-mark[data-lnc="' + id + '"]').forEach(function (s) {
      var p = s.parentNode; while (s.firstChild) p.insertBefore(s.firstChild, s); p.removeChild(s); p.normalize();
    });
  }
  function removeMark(id) {
    delete ranges[id]; unwrap(id);
    state.marks = state.marks.filter(function (m) { return m.id !== id; });
    paint(); render();
  }
  function clearMarks() {
    Object.keys(ranges).forEach(unwrap); ranges = {}; state.marks = []; state.note = ''; paint();
  }

  function locate(el) {
    var parts = [];
    var page = el.closest('[data-screen-label]'); if (page) parts.push(page.getAttribute('data-screen-label'));
    var sec = el.closest('section,article'); var hd = sec && sec.querySelector('h1,h2,h3');
    if (!hd) { var all = zoneEl().querySelectorAll('h1,h2,h3'); for (var i = all.length - 1; i >= 0; i--) { if (all[i].compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING) { hd = all[i]; break; } } }
    if (hd) parts.push(hd.textContent.replace(/\s+/g, ' ').trim());
    return parts.join(' · ');
  }

  function markSelection() {
    var sel = window.getSelection(); if (!sel || !sel.rangeCount) return;
    var r0 = sel.getRangeAt(0);
    if (sel.isCollapsed) {
      var t = r0.startContainer.nodeType === 1 ? r0.startContainer : r0.startContainer.parentElement;
      var wrapped = t && t.closest && t.closest('.lnc-mark');
      if (wrapped) { removeMark(wrapped.getAttribute('data-lnc')); sel.removeAllRanges(); return; }
      for (var id in ranges) { try { if (ranges[id].isPointInRange(r0.startContainer, r0.startOffset)) { removeMark(id); sel.removeAllRanges(); return; } } catch (e) {} }
      if (!sel.modify) return;
      sel.modify('move', 'backward', 'word'); sel.modify('extend', 'forward', 'word');
      if (!sel.rangeCount) return;
    }
    var range = sel.getRangeAt(0).cloneRange();
    for (var k = 0; k < 6 && /\s$/.test(range.toString()) && range.endContainer.nodeType === 3 && range.endOffset > 0; k++) range.setEnd(range.endContainer, range.endOffset - 1);
    var text = range.toString().replace(/\s+/g, ' ').trim();
    sel.removeAllRanges();
    if (!text || text.length > 400) return;
    var n = range.commonAncestorContainer, el = n.nodeType === 1 ? n : n.parentElement;
    if (!el || !zoneEl().contains(el) || inUI(el)) return;
    var block = el.closest('p,li,td,h1,h2,h3,h4,label,blockquote') || el;
    var mark = {
      id: 'm' + Date.now() + Math.floor(Math.random() * 1e4), text: text,
      ctx: block.textContent.replace(/\s+/g, ' ').trim().slice(0, 220), where: locate(el), comment: ''
    };
    if (hasHL) { ranges[mark.id] = range; paint(); }
    else {
      try { var sp = document.createElement('span'); sp.className = 'lnc-mark'; sp.setAttribute('data-lnc', mark.id); range.surroundContents(sp); }
      catch (e) { /* sélection à cheval sur plusieurs éléments : notée sans surlignage */ }
    }
    state.marks.push(mark); render();
  }

  function onClick(e) { if (state.on && !inUI(e.target)) { e.preventDefault(); e.stopPropagation(); } }
  function onDown(e) { if (state.on && !inUI(e.target)) e.stopPropagation(); }
  function onUp(e) { if (!state.on || inUI(e.target) || (e.button !== undefined && e.button !== 0)) return; setTimeout(markSelection, 0); }

  function open() {
    state.on = true;
    document.addEventListener('click', onClick, true);
    document.addEventListener('pointerdown', onDown, true);
    document.addEventListener('mouseup', onUp);
    document.addEventListener('touchend', onUp);
    render();
  }
  function close() {
    state.on = false;
    document.removeEventListener('click', onClick, true);
    document.removeEventListener('pointerdown', onDown, true);
    document.removeEventListener('mouseup', onUp);
    document.removeEventListener('touchend', onUp);
    render();
  }

  function done(msg) { var ok = root.querySelector('#lnc-ok'); if (ok) { ok.hidden = false; ok.textContent = msg; } }
  function send() {
    var body = report();
    try { navigator.clipboard && navigator.clipboard.writeText(body); } catch (e) {}
    if (CFG.endpoint) {
      fetch(CFG.endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fiche: CFG.fiche, url: location.href, enseignant: state.name, commentaire: state.note,
          elements: state.marks.map(function (m) { return { texte: m.text, emplacement: m.where, contexte: m.ctx, correction: m.comment }; }), rapport: body }) })
        .then(function (r) { if (!r.ok) throw 0; done('Signalement envoyé à l\'équipe Lnclass. Merci !'); })
        .catch(function () { mail(body); });
    } else mail(body);
  }
  function mail(body) {
    location.href = 'mailto:' + CFG.email + '?subject=' + encodeURIComponent('Signalement d\'erreurs — ' + CFG.fiche) + '&body=' + encodeURIComponent(body);
    done('Votre messagerie s\'ouvre avec le rapport. Il est aussi copié dans le presse-papiers. Merci !');
  }

  function init() { document.body.appendChild(root); render(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
  window.LnclassSignalement = { open: open, close: close, getReport: report, config: CFG };
})();
