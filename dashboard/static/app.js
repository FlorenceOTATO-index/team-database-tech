/* FARS 2024 dashboard front end.
   Every chart fetches /api/chart/<id>?<filters>; the server runs that chart's
   SQL against MySQL and returns rows + the exact SQL + timing. No chart data is
   hard-coded here: this file only draws what the database returns. */
'use strict';

// ------------------------------------------------------------------ helpers
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => Number(n || 0).toLocaleString('en-US');
const pct = (a, b) => (b ? (100 * a) / b : 0);
const p1 = (x) => (Math.round(x * 10) / 10).toFixed(1);
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const MON = MONTHS.map((m) => m.slice(0, 3));
const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const C = {
  blue: '#3987e5', orange: '#d95926', aqua: '#199e70', gray: '#3a4150', amber: '#e9a23b', amberHi: '#ffd58a',
  ink: '#eef0f3', ink2: '#b4bac6', muted: '#8a93a5', grid: '#262c38', axis: '#3a4150', surface: '#121720', empty: '#171c26',
};
const RAMP = ['#2a2118', '#4a3415', '#7a5114', '#a96d17', '#d98e24', '#f5b84f']; // one hue, dark -> bright
const rampColor = (v, lo, hi) => {
  if (!v) return C.empty;
  if (hi <= lo) return RAMP[3];
  return RAMP[Math.min(5, Math.floor(((v - lo) / (hi - lo)) * 6))];
};
const rampLegend = (lo, hi, unit) =>
  `<span class="ramp"><span>${esc(lo)}</span>${RAMP.map((c) => `<i style="background:${c}"></i>`).join('')}<span>${esc(hi)}${unit ? ' ' + esc(unit) : ''}</span></span>`;
const tip = (...lines) => esc(lines.filter((l) => l !== '' && l != null).join('\n'));

const FIPS = { 1: 'AL', 2: 'AK', 4: 'AZ', 5: 'AR', 6: 'CA', 8: 'CO', 9: 'CT', 10: 'DE', 11: 'DC', 12: 'FL', 13: 'GA', 15: 'HI', 16: 'ID', 17: 'IL', 18: 'IN', 19: 'IA', 20: 'KS', 21: 'KY', 22: 'LA', 23: 'ME', 24: 'MD', 25: 'MA', 26: 'MI', 27: 'MN', 28: 'MS', 29: 'MO', 30: 'MT', 31: 'NE', 32: 'NV', 33: 'NH', 34: 'NJ', 35: 'NM', 36: 'NY', 37: 'NC', 38: 'ND', 39: 'OH', 40: 'OK', 41: 'OR', 42: 'PA', 44: 'RI', 45: 'SC', 46: 'SD', 47: 'TN', 48: 'TX', 49: 'UT', 50: 'VT', 51: 'VA', 53: 'WA', 54: 'WV', 55: 'WI', 56: 'WY' };
const TILE_GRID = ['AK . . . . . . . . . ME', '. . . . . . . . . VT NH', 'WA ID MT ND MN IL WI MI NY RI MA', 'OR NV WY SD IA IN OH PA NJ CT .', 'CA UT CO NE MO KY WV VA MD DE .', '. AZ NM KS AR TN NC SC DC . .', '. . . OK LA MS AL GA . . .', 'HI . . TX . . . . FL . .'];
const TILE_POS = {};
TILE_GRID.forEach((row, r) => row.split(' ').forEach((ab, c) => { if (ab !== '.') TILE_POS[ab] = [c + 1, r + 1]; }));

// ------------------------------------------------------------------ state
const state = { state: '', area: '', m1: 1, m2: 12, page: 'overview', highlight: 'drinking' };
let META = { states: [] };
let generation = 0;
const stateName = (code) => (META.states.find((s) => String(s.code) === String(code)) || {}).name || '';

function qs() {
  const p = new URLSearchParams();
  if (state.state) p.set('state', state.state);
  if (state.area) p.set('area', state.area);
  p.set('m1', state.m1);
  p.set('m2', state.m2);
  return p.toString();
}

async function getJSON(url) {
  const r = await fetch(url);
  let d;
  try { d = await r.json(); } catch { throw new Error(`${r.status} ${r.statusText}`); }
  if (!r.ok || d.error) { const e = new Error(d.error || r.statusText); e.data = d; throw e; }
  return d;
}

// ------------------------------------------------------------------ SQL highlighting
const KW = new Set('SELECT FROM WHERE JOIN LEFT ON AND OR NOT IN AS GROUP BY ORDER LIMIT WITH CASE WHEN THEN ELSE END SUM COUNT AVG MAX MIN ROUND EXISTS DISTINCT UNION ALL INTERSECT EXCEPT OVER PARTITION ROW_NUMBER RANK DENSE_RANK LAG ROLLUP GROUPING BETWEEN IS NULL DESC ASC HAVING CAST SIGNED CHAR IF COALESCE FLOOR CEIL SUBSTRING EXPLAIN ANALYZE IGNORE INDEX USE CREATE VIEW REPLACE TABLE ELT MAKEDATE INTERVAL MONTH DAY DATE_FORMAT'.split(' '));
function highlightSQL(sql) {
  return String(sql).replace(/(--[^\n]*|#[^\n]*|'(?:[^']|'')*'|`[^`]*`|\b\d+(?:\.\d+)?\b|\b[A-Za-z_][A-Za-z_0-9]*\b|[\s\S])/g, (t) => {
    if (t.startsWith('--') || (t.startsWith('#') && t.length > 1)) return `<span class="c">${esc(t)}</span>`;
    if (t.startsWith("'")) return `<span class="s">${esc(t)}</span>`;
    if (/^\d/.test(t)) return `<span class="n">${t}</span>`;
    if (KW.has(t.toUpperCase()) && t === t.toUpperCase()) return `<span class="k">${t}</span>`;
    return esc(t);
  });
}

// ------------------------------------------------------------------ tooltip
const tipEl = $('#tip');
document.addEventListener('mousemove', (e) => {
  const t = e.target.closest && e.target.closest('[data-tip]');
  if (!t || !t.dataset.tip) { tipEl.hidden = true; return; }
  tipEl.textContent = t.dataset.tip;
  tipEl.hidden = false;
  const r = tipEl.getBoundingClientRect();
  let x = e.clientX + 14, y = e.clientY + 14;
  if (x + r.width > innerWidth - 8) x = e.clientX - r.width - 14;
  if (y + r.height > innerHeight - 8) y = e.clientY - r.height - 14;
  tipEl.style.left = x + 'px';
  tipEl.style.top = y + 'px';
});
document.addEventListener('scroll', () => { tipEl.hidden = true; }, { passive: true });

// ------------------------------------------------------------------ SVG helpers
const svgOpen = (w, h, label) => `<svg viewBox="0 0 ${w} ${h}" width="100%" role="img" aria-label="${esc(label)}" style="display:block">`;

function lineChart({ series, xLabels, yMax, label, valueFmt = (v) => p1(v) + '%' }) {
  const W = 620, H = 290, L = 62, R = 120, T = 22, B = 40;
  const pw = W - L - R, ph = H - T - B;
  const x = (i) => L + (xLabels.length === 1 ? pw / 2 : (i * pw) / (xLabels.length - 1));
  const y = (v) => T + ph - (v / yMax) * ph;
  let s = svgOpen(W, H, label);
  for (let g = 0; g <= 4; g++) {
    const v = (yMax * g) / 4, yy = y(v);
    s += `<line x1="${L}" x2="${W - R}" y1="${yy}" y2="${yy}" stroke="${g ? C.grid : C.axis}"/>`;
    s += `<text x="${L - 10}" y="${yy + 4}" fill="${C.muted}" font-size="11" text-anchor="end">${Math.round(v)}%</text>`;
  }
  xLabels.forEach((t, i) => { s += `<text x="${x(i)}" y="${H - 14}" fill="${C.muted}" font-size="11" text-anchor="middle">${esc(t)}</text>`; });
  series.forEach((sr) => {
    const pts = sr.values.map((v, i) => (v == null ? null : [x(i), y(v), v, i])).filter(Boolean);
    if (!pts.length) return;
    s += `<path d="${pts.map((p, k) => (k ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join('')}" fill="none" stroke="${sr.color}" stroke-width="2" stroke-linejoin="round"/>`;
    pts.forEach((p) => {
      s += `<circle cx="${p[0]}" cy="${p[1]}" r="12" fill="transparent" data-tip="${tip(sr.name + ' · ' + xLabels[p[3]], valueFmt(p[2]) + (sr.tips ? '\n' + sr.tips[p[3]] : ''))}"/>`;
      s += `<circle cx="${p[0]}" cy="${p[1]}" r="5" fill="${sr.color}" stroke="${C.surface}" stroke-width="2" pointer-events="none"/>`;
    });
    const last = pts[pts.length - 1], first = pts[0];
    s += `<text x="${last[0] + 12}" y="${last[1] + 4}" fill="${C.ink}" font-size="12.5">${esc(sr.name)} ${valueFmt(last[2])}</text>`;
    s += `<text x="${first[0] + 10}" y="${first[1] - 10}" fill="${C.ink2}" font-size="12" text-anchor="start">${valueFmt(first[2])}</text>`;
  });
  return s + '</svg>';
}

function hbars(items, { max, onClickAttr } = {}) {
  const m = max || Math.max(1, ...items.map((i) => i.value));
  return `<div class="hbars">${items.map((it) => `
    <div class="hbar${it.selected ? ' selected' : ''}${it.click ? ' clickable' : ''}" data-tip="${it.tip || ''}" ${it.click ? `data-state="${it.click}" role="button" tabindex="0"` : ''}>
      <div class="row"><span>${esc(it.label)}</span><span>${esc(it.display)}</span></div>
      <div class="track"><div class="fill" style="width:${Math.max(0.5, (100 * it.value) / m)}%;background:${it.color || C.blue}"></div></div>
    </div>`).join('')}</div>`;
}

function pairBars(a, b) {
  const m = Math.max(a.value, b.value, 1) * 1.05;
  return `<div class="pairs">
      ${[a, b].map((p) => `<div class="pair"><span class="num">${p1(p.value)}%</span><div class="col" data-tip="${p.tip}" style="height:${(85 * p.value) / m}%;background:${p.color}"></div></div>`).join('')}
    </div>
    <div class="pair-labels"><span>${esc(a.label)}</span><span>${esc(b.label)}</span></div>`;
}

// ------------------------------------------------------------------ map
function albers(lat0, lon0, pa, pb) {
  const r = Math.PI / 180;
  const n = (Math.sin(pa * r) + Math.sin(pb * r)) / 2;
  const Cc = Math.cos(pa * r) ** 2 + 2 * n * Math.sin(pa * r);
  const rho0 = Math.sqrt(Cc - 2 * n * Math.sin(lat0 * r)) / n;
  return (lat, lon) => {
    const rho = Math.sqrt(Cc - 2 * n * Math.sin(lat * r)) / n;
    const th = n * (lon - lon0) * r;
    return [rho * Math.sin(th), rho0 - rho * Math.cos(th)];
  };
}
function edgeBounds(proj, lat1, lat2, lon1, lon2) {
  const xs = [], ys = [];
  for (let lon = lon1; lon <= lon2; lon += 0.5) for (const lat of [lat1, lat2]) { const p = proj(lat, lon); xs.push(p[0]); ys.push(p[1]); }
  for (let lat = lat1; lat <= lat2; lat += 0.5) for (const lon of [lon1, lon2]) { const p = proj(lat, lon); xs.push(p[0]); ys.push(p[1]); }
  return [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
}
const MAP_LAYERS = {
  drinking: { idx: 2, label: 'Drinking driver', phrase: 'involved a drinking driver' },
  dark: { idx: 3, label: 'After dark', phrase: 'happened after dark' },
  nonmotorist: { idx: 4, label: 'Pedestrian or cyclist killed', phrase: 'killed a pedestrian or cyclist' },
};
function drawMap(canvas, rows) {
  const wrap = canvas.parentElement;
  const W = wrap.clientWidth;
  if (!W) return;
  const H = Math.round(W * 0.6);
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
  canvas.style.width = W + 'px'; canvas.style.height = H + 'px';
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const hi = MAP_LAYERS[state.highlight].idx;
  const groups = [];
  if (state.state) {
    const lats = rows.map((r) => r[0]), lons = rows.map((r) => r[1]);
    const lat0 = lats.reduce((a, b) => a + b, 0) / (lats.length || 1), lon0 = lons.reduce((a, b) => a + b, 0) / (lons.length || 1);
    groups.push({ rows, proj: albers(lat0, lon0, lat0 - 4, lat0 + 4), box: [24, 24, W - 24, H - 24], bounds: null });
  } else {
    const l48 = albers(37.5, -96, 29.5, 45.5), ak = albers(58, -154, 55, 65), hiP = albers(20.5, -157, 8, 18);
    const isAK = (r) => r[0] > 50.5 && r[1] < -129, isHI = (r) => r[0] < 23 && r[1] < -150;
    groups.push({ rows: rows.filter((r) => !isAK(r) && !isHI(r) && r[0] >= 24 && r[0] <= 50 && r[1] >= -125.5 && r[1] <= -66), proj: l48, box: [16, 16, W - 16, H - 16], bounds: edgeBounds(l48, 24.5, 49.4, -124.8, -66.9) });
    groups.push({ rows: rows.filter(isAK), proj: ak, box: [W * 0.02, H * 0.72, W * 0.2, H * 0.98], bounds: edgeBounds(ak, 51.2, 71.5, -179, -129.9), label: 'Alaska' });
    groups.push({ rows: rows.filter(isHI), proj: hiP, box: [W * 0.215, H * 0.83, W * 0.33, H * 0.98], bounds: edgeBounds(hiP, 18.9, 22.3, -160.3, -154.8), label: 'Hawaii' });
  }
  const base = [], top = [];
  for (const g of groups) {
    const xy = g.rows.map((r) => g.proj(r[0], r[1]));
    let b = g.bounds;
    if (!b) {
      if (!xy.length) continue;
      b = [Math.min(...xy.map((p) => p[0])), Math.min(...xy.map((p) => p[1])), Math.max(...xy.map((p) => p[0])), Math.max(...xy.map((p) => p[1]))];
      const padX = (b[2] - b[0]) * 0.04 || 0.01, padY = (b[3] - b[1]) * 0.04 || 0.01;
      b = [b[0] - padX, b[1] - padY, b[2] + padX, b[3] + padY];
    }
    const [x0, y0, x1, y1] = g.box;
    const s = Math.min((x1 - x0) / (b[2] - b[0]), (y1 - y0) / (b[3] - b[1]));
    const ox = x0 + ((x1 - x0) - s * (b[2] - b[0])) / 2, oy = y0 + ((y1 - y0) - s * (b[3] - b[1])) / 2;
    if (g.label) {
      ctx.strokeStyle = 'rgba(255,255,255,0.08)'; ctx.lineWidth = 1;
      ctx.strokeRect(x0 + 0.5, y0 + 0.5, x1 - x0, y1 - y0);
      ctx.fillStyle = C.muted; ctx.font = '11px Inter, sans-serif'; ctx.fillText(g.label, x0 + 6, y0 + 14);
    }
    g.rows.forEach((r, i) => {
      const px = ox + (xy[i][0] - b[0]) * s, py = oy + (b[3] - xy[i][1]) * s;
      (r[hi] ? top : base).push(px, py);
    });
  }
  const size = state.state ? 2.6 : 1.7;
  ctx.globalCompositeOperation = 'lighter';
  const sparse = (base.length + top.length) / 2 < 6000;
  ctx.fillStyle = `rgba(233,162,59,${sparse ? 0.75 : top.length ? 0.28 : 0.4})`;
  for (let i = 0; i < base.length; i += 2) ctx.fillRect(base[i] - size / 2, base[i + 1] - size / 2, size, size);
  ctx.globalCompositeOperation = 'source-over';
  ctx.fillStyle = sparse ? 'rgba(142,197,255,0.95)' : 'rgba(142,197,255,0.7)';
  const s2 = sparse ? size + 0.6 : size;
  for (let i = 0; i < top.length; i += 2) ctx.fillRect(top[i] - s2 / 2, top[i + 1] - s2 / 2, s2, s2);
}

// ------------------------------------------------------------------ chart definitions
// Each: id (matches /api/chart/<id>), title, span, render(body, d) -> optional insight HTML.
const CHARTS = {
  overview: [
    { id: 'map', title: 'A dot for every crash', span: '', hero: true,
      controls: () => `<div class="seg" role="group" aria-label="Highlight on map">${Object.entries(MAP_LAYERS).map(([k, v]) =>
        `<button type="button" data-layer="${k}" aria-pressed="${state.highlight === k}">${esc(v.label)}</button>`).join('')}</div>`,
      render(body, d) {
        body.innerHTML = `<div class="map-wrap"><canvas aria-label="Map with one dot per fatal crash"></canvas></div>
          <div class="legend"><span><span class="sw dot" style="background:${C.amber}"></span>Fatal crash</span>
          <span><span class="sw dot" style="background:#8ec5ff"></span>${esc(MAP_LAYERS[state.highlight].label)}</span>
          <span style="color:${C.muted}">${fmt(d.rows.length)} crashes with coordinates</span></div>`;
        const canvas = $('canvas', body);
        const redraw = () => drawMap(canvas, d.rows);
        redraw();
        if (this._ro) this._ro.disconnect();
        this._ro = new ResizeObserver(redraw);
        this._ro.observe(canvas.parentElement);
        this._redraw = redraw;
        const n = d.rows.length, k = d.rows.filter((r) => r[MAP_LAYERS[state.highlight].idx]).length;
        return `No basemap: crash locations alone draw the cities and interstates. <b>${p1(pct(k, n))}%</b> of these crashes ${MAP_LAYERS[state.highlight].phrase} (blue dots).`;
      } },
    { id: 'calendar', title: 'Which days of 2024 were deadliest?', span: 'span-6',
      render(body, d) {
        const rows = d.rows; // MONTH, DAY, DAY_WEEK, deaths
        const inRange = (m) => m >= state.m1 && m <= state.m2;
        const vals = rows.filter((r) => inRange(r[0])).map((r) => r[3]).filter((v) => v > 0);
        const lo = Math.min(...vals), hi = Math.max(...vals);
        const offset = rows[0][2] - 1;
        const cell = 13, step = 16, L = 30, T = 20;
        const HOL = { '1-1': 'New Year’s Day', '5-27': 'Memorial Day', '7-4': 'Independence Day', '9-2': 'Labor Day', '10-31': 'Halloween', '11-28': 'Thanksgiving', '12-25': 'Christmas Day', '12-31': 'New Year’s Eve' };
        const wk = {}; rows.forEach((r) => { if (inRange(r[0])) (wk[r[2]] = wk[r[2]] || []).push(r[3]); });
        const wkAvg = {}; Object.keys(wk).forEach((k) => { wkAvg[k] = wk[k].reduce((a, b) => a + b, 0) / wk[k].length; });
        let s = svgOpen(L + 53 * step, T + 7 * step, 'Calendar heatmap of deaths per day in 2024');
        ['Mon', 'Wed', 'Fri'].forEach((t, i) => { s += `<text x="${L - 6}" y="${T + (1 + 2 * i) * step + 10}" fill="${C.muted}" font-size="10" text-anchor="end">${t}</text>`; });
        const hol = [];
        let best = null;
        rows.forEach((r, i) => {
          const col = Math.floor((i + offset) / 7), row = (i + offset) % 7;
          const dt = new Date(2024, r[0] - 1, r[1]);
          if (r[1] === 1) s += `<text x="${L + col * step}" y="${T - 7}" fill="${C.muted}" font-size="10">${MON[r[0] - 1]}</text>`;
          const h = HOL[r[0] + '-' + r[1]];
          const active = inRange(r[0]);
          const diff = active && wkAvg[r[2]] ? pct(r[3] - wkAvg[r[2]], wkAvg[r[2]]) : null;
          if (h && active && diff != null) hol.push({ h, diff, deaths: r[3], dw: r[2] });
          if (active && (!best || r[3] > best.v)) best = { v: r[3], dt };
          const label = dt.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
          s += `<rect x="${L + col * step}" y="${T + row * step}" width="${cell}" height="${cell}" rx="2.5" fill="${active ? rampColor(r[3], lo, hi) : C.empty}"
            ${h && active ? `stroke="${C.ink}" stroke-width="1.6"` : ''} data-tip="${tip(label + (h ? ' · ' + h : ''), fmt(r[3]) + ' deaths', diff != null ? (diff >= 0 ? '+' : '') + p1(diff) + '% vs an average ' + DAYS[r[2] - 1] : '')}"/>`;
        });
        s += '</svg>';
        hol.sort((a, b) => b.diff - a.diff);
        body.innerHTML = `<div class="scroll-x"><div style="min-width:760px">${s}</div></div>
          <div class="legend" style="justify-content:space-between">
            <div class="holidays">${hol.slice(0, 6).map((x) => `<span>${esc(x.h)} <b class="${x.diff < 10 ? 'low' : ''}">${x.diff >= 0 ? '+' : ''}${Math.round(x.diff)}%</b></span>`).join('')}</div>
            ${rampLegend(lo, hi, 'deaths')}
          </div>`;
        if (!best) return '';
        const top = hol[0];
        return `Deadliest day: <b>${best.dt.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</b> (${fmt(best.v)} deaths).` +
          (top ? ` ${esc(top.h)} ran <b>${top.diff >= 0 ? '+' : ''}${p1(top.diff)}%</b> above an average ${DAYS[top.dw - 1]}. Outlined squares are holidays.` : '');
      } },
    { id: 'heat', title: 'When do fatal crashes happen?', span: 'span-4',
      render(body, d) {
        const grid = Array.from({ length: 7 }, () => Array(24).fill(0));
        d.rows.forEach(([dw, h, n]) => { grid[dw - 1][h] = n; });
        const flat = grid.flat().filter((v) => v > 0);
        const lo = Math.min(...flat), hi = Math.max(...flat);
        const W = 780, L = 42, T = 18, cw = (W - L) / 24, chh = 38;
        let s = svgOpen(W, T + 7 * (chh + 3), 'Heatmap of fatal crashes by weekday and hour');
        for (let h = 0; h < 24; h += 3) s += `<text x="${L + h * cw + 2}" y="12" fill="${C.muted}" font-size="10.5">${h === 0 ? '12a' : h === 12 ? '12p' : (h % 12) + (h < 12 ? 'a' : 'p')}</text>`;
        let peak = { v: -1 }, low = { v: Infinity };
        grid.forEach((row, dw) => {
          s += `<text x="0" y="${T + dw * (chh + 3) + chh / 2 + 4}" fill="${C.muted}" font-size="11">${DAYS[dw].slice(0, 3)}</text>`;
          row.forEach((v, h) => {
            if (v > peak.v) peak = { v, dw, h };
            if (v < low.v) low = { v, dw, h };
            const hr = (h % 12 || 12) + (h < 12 ? ' am' : ' pm');
            s += `<rect x="${L + h * cw}" y="${T + dw * (chh + 3)}" width="${cw - 3}" height="${chh}" rx="4" fill="${rampColor(v, lo, hi)}" data-tip="${tip(DAYS[dw] + ' ' + hr, fmt(v) + ' fatal crashes')}"/>`;
          });
        });
        body.innerHTML = `<div class="scroll-x"><div style="min-width:620px">${s}</div></div><div class="legend">${rampLegend(lo, hi, 'crashes per hour slot')}</div>`;
        const hn = (h) => (h % 12 || 12) + (h < 12 ? ' am' : ' pm');
        return `Busiest hour of the week: <b>${DAYS[peak.dw]} ${hn(peak.h)}</b> (${fmt(peak.v)} crashes). Quietest: ${DAYS[low.dw]} ${hn(low.h)}.`;
      } },
    { id: 'vehstates', title: 'Most vehicles in fatal crashes', span: 'span-2',
      render(body, d) {
        const items = d.rows.map(([code, name, n]) => ({ label: name, value: n, display: fmt(n), selected: String(code) === String(state.state),
          color: String(code) === String(state.state) ? C.orange : C.blue, click: code, tip: tip(name, fmt(n) + ' vehicles', 'Click to filter the dashboard') }));
        body.innerHTML = hbars(items) + `<p class="note">Raw counts follow population and miles driven, not road danger. Click a state to filter.</p>`;
        const [a, b, c] = d.rows;
        return a ? `<b>${esc(a[1])}</b> leads with ${fmt(a[2])} vehicles, then ${esc(b ? b[1] : '')}${c ? ' and ' + esc(c[1]) : ''}.` : '';
      } },
    { id: 'monthly', title: 'Deaths by month', span: 'span-6',
      render(body, d) {
        const byM = {}; d.rows.forEach(([m, c, dd]) => { byM[m] = { c, d: dd }; });
        const vals = d.rows.map((r) => r[2]);
        const max = Math.max(...vals, 1), min = Math.min(...vals);
        const W = 1000, H = 220, L = 44, B = 26, T = 22, bw = (W - L) / 12;
        const yMax = Math.ceil(max / 1000) * 1000;
        let s = svgOpen(W, H, 'Bar chart of deaths by month') + `<text x="0" y="10" fill="${C.muted}" font-size="11">Deaths</text>`;
        for (let g = 0; g <= 4; g++) { const v = (yMax * g) / 4, y = T + (H - T - B) * (1 - v / yMax); s += `<line x1="${L}" x2="${W}" y1="${y}" y2="${y}" stroke="${g ? C.grid : C.axis}"/><text x="${L - 8}" y="${y + 4}" fill="${C.muted}" font-size="11" text-anchor="end">${fmt(v)}</text>`; }
        for (let m = 1; m <= 12; m++) {
          const v = byM[m] ? byM[m].d : 0, h = ((H - T - B) * v) / yMax, x = L + (m - 1) * bw + bw * 0.18;
          const isMax = v === max && v > 0, isMin = v === min && v > 0 && d.rows.length > 1;
          s += `<rect x="${x}" y="${H - B - h}" width="${bw * 0.64}" height="${Math.max(h, 0)}" rx="4" fill="${isMax ? C.amber : C.blue}" data-tip="${tip(MONTHS[m - 1], fmt(v) + ' deaths', byM[m] ? fmt(byM[m].c) + ' crashes' : '')}"/>`;
          if (isMax || isMin) s += `<text x="${x + bw * 0.32}" y="${H - B - h - 7}" fill="${C.ink}" font-size="12" text-anchor="middle">${fmt(v)}</text>`;
          s += `<text x="${x + bw * 0.32}" y="${H - 8}" fill="${C.muted}" font-size="11" text-anchor="middle">${MON[m - 1]}</text>`;
        }
        body.innerHTML = s + '</svg>';
        const mx = d.rows.find((r) => r[2] === max), mn = d.rows.find((r) => r[2] === min);
        return mx ? `Deaths peak in <b>${MONTHS[mx[0] - 1]}</b> (${fmt(max)}) and are lowest in ${MONTHS[mn[0] - 1]} (${fmt(min)}).` : '';
      } },
  ],
  behavior: [
    { id: 'tilemap', title: 'Where do fatal crashes involve a drinking driver?', span: 'span-4',
      render(body, d) {
        const rows = d.rows.map(([code, n, k]) => ({ code, ab: FIPS[code], n, k, p: pct(k, n) })).filter((r) => r.ab);
        const solid = rows.filter((r) => r.n >= 30);
        const ps = (solid.length ? solid : rows).map((r) => r.p);
        const lo = Math.min(...ps), hi = Math.max(...ps);
        body.innerHTML = `<div class="tiles">${rows.map((r) => {
          const [c, rr] = TILE_POS[r.ab];
          const col = rampColor(Math.max(r.p, lo + 0.0001), lo, hi);
          const light = col === RAMP[4] || col === RAMP[5];
          return `<button type="button" class="tile${String(r.code) === String(state.state) ? ' sel' : ''}" data-state="${r.code}" style="grid-column:${c};grid-row:${rr};background:${col};color:${light ? '#0b0b0b' : C.ink}"
            data-tip="${tip(stateName(r.code) || r.ab, p1(r.p) + '% of ' + fmt(r.n) + ' fatal crashes', fmt(r.k) + ' with a drinking driver', r.n < 30 ? 'Small sample' : '', 'Click to filter')}"><b>${r.ab}</b><small>${Math.round(r.p)}%</small></button>`;
        }).join('')}</div><div class="legend">${rampLegend(Math.round(lo) + '%', Math.round(hi) + '%', 'of crashes')}<span style="color:${C.muted}">Click a state to filter every chart</span></div>`;
        const sorted = [...(solid.length ? solid : rows)].sort((a, b) => b.p - a.p);
        if (!sorted.length) return '';
        const tot = rows.reduce((a, r) => [a[0] + r.k, a[1] + r.n], [0, 0]);
        return `<b>${p1(pct(tot[0], tot[1]))}%</b> of fatal crashes involved a police-reported drinking driver. Highest: <b>${esc(stateName(sorted[0].code))}</b> (${p1(sorted[0].p)}%); lowest: ${esc(stateName(sorted[sorted.length - 1].code))} (${p1(sorted[sorted.length - 1].p)}%).`;
      } },
    { id: 'wrongway', title: 'The wrong-way clock', span: 'span-2',
      render(body, d) {
        const byH = Array.from({ length: 24 }, () => [0, 0]);
        d.rows.forEach(([h, n, k]) => { byH[h] = [k, n - k]; });
        const maxT = Math.max(1, ...byH.map((x) => x[0] + x[1]));
        const cx = 180, cy = 180, r0 = 40, rM = 140;
        const rad = (v) => r0 + (v / maxT) * (rM - r0);
        const pt = (r, a) => { const t = (a * Math.PI) / 180; return (cx + r * Math.cos(t)).toFixed(1) + ' ' + (cy + r * Math.sin(t)).toFixed(1); };
        const sector = (ra, rb, a1, a2) => `M${pt(rb, a1)}A${rb} ${rb} 0 0 1 ${pt(rb, a2)}L${pt(ra, a2)}A${ra} ${ra} 0 0 0 ${pt(ra, a1)}Z`;
        const total = byH.reduce((a, x) => a + x[0] + x[1], 0);
        let s = svgOpen(360, 360, 'Radial chart of wrong-way crashes by hour of day');
        [0.5, 1].forEach((f) => { s += `<circle cx="${cx}" cy="${cy}" r="${rad(maxT * f)}" fill="none" stroke="${C.grid}"/>`; });
        byH.forEach(([k, o], h) => {
          const a1 = -90 + h * 15 + 1.2, a2 = -90 + (h + 1) * 15 - 1.2, rd = rad(k), rt = rad(k + o);
          const hr = (h % 12 || 12) + (h < 12 ? ' am' : ' pm');
          const t = tip(hr, fmt(k + o) + ' wrong-way crashes', fmt(k) + ' with a drinking wrong-way driver (' + Math.round(pct(k, k + o)) + '%)');
          if (k) s += `<path d="${sector(r0, rd, a1, a2)}" fill="${C.orange}" stroke="${C.surface}" stroke-width="1" data-tip="${t}"/>`;
          if (o) s += `<path d="${sector(rd, rt, a1, a2)}" fill="${C.blue}" stroke="${C.surface}" stroke-width="1" data-tip="${t}"/>`;
        });
        s += `<text x="180" y="13" fill="${C.muted}" font-size="11.5" text-anchor="middle">midnight</text><text x="354" y="184" fill="${C.muted}" font-size="11.5" text-anchor="end">6 am</text>
          <text x="180" y="356" fill="${C.muted}" font-size="11.5" text-anchor="middle">noon</text><text x="6" y="184" fill="${C.muted}" font-size="11.5">6 pm</text>
          <text x="180" y="184" fill="${C.ink}" font-size="22" font-weight="700" text-anchor="middle" font-family="Space Grotesk, sans-serif">${fmt(total)}</text>
          <text x="180" y="201" fill="${C.muted}" font-size="11" text-anchor="middle">crashes</text></svg>`;
        body.innerHTML = `<div style="max-width:380px;margin:0 auto">${s}</div><div class="legend" style="justify-content:center">
          <span><span class="sw" style="background:${C.orange}"></span>Wrong-way driver drinking</span><span><span class="sw" style="background:${C.blue}"></span>Not reported drinking</span></div>`;
        const night = byH.slice(0, 5).reduce((a, x) => [a[0] + x[0], a[1] + x[0] + x[1]], [0, 0]);
        const all = byH.reduce((a, x) => [a[0] + x[0], a[1] + x[0] + x[1]], [0, 0]);
        return night[1] ? `Between midnight and 5 am, <b>${Math.round(pct(night[0], night[1]))}%</b> of wrong-way crashes had a drinking wrong-way driver (all hours: ${Math.round(pct(all[0], all[1]))}%).` : 'No wrong-way crashes match these filters.';
      } },
    { id: 'dwi', title: 'Repeat offenders', span: 'span-2',
      render(body, d) {
        body.innerHTML = `<div class="bigbars">${d.rows.map(([g, n, drink, tested, bac]) => {
          const p = pct(bac, tested);
          return `<div class="bigbar" data-tip="${tip(g, fmt(tested) + ' tested drivers', fmt(bac) + ' at BAC 0.08+', p1(pct(drink, n)) + '% police-reported drinking')}">
            <div class="top"><span>${esc(g)}</span><span class="num">${tested >= 5 ? p1(p) + '%' : '–'}</span></div>
            <div class="track"><div class="fill" style="width:${tested >= 5 ? p : 0}%;background:${g.startsWith('No') ? C.blue : C.orange}"></div></div>
            <div class="sub">${fmt(tested)} tested of ${fmt(n)} drivers${tested < 5 ? ' · too few tested' : ''}</div></div>`;
        }).join('')}</div><p class="note">Share of BAC-tested drivers at 0.08 or higher.</p>`;
        const none = d.rows.find((r) => r[0].startsWith('No')), one = d.rows.find((r) => r[0].startsWith('1'));
        if (!none || !one || !none[3] || !one[3]) return '';
        return `Tested drivers with a prior DWI were legally drunk <b>${(pct(one[4], one[3]) / pct(none[4], none[3])).toFixed(1)}×</b> as often as drivers with none.`;
      } },
    { id: 'alcdrug', title: 'Alcohol, drugs, or both?', span: 'span-4',
      render(body, d) {
        const colors = [C.aqua, C.orange, C.blue, C.gray];
        const total = d.rows.reduce((a, r) => a + r[1], 0);
        if (!total) { body.innerHTML = '<div class="empty">No drivers tested for both match these filters.</div>'; return ''; }
        body.innerHTML = `<div class="stack" role="img" aria-label="${esc(d.rows.map((r) => r[0] + ' ' + p1(pct(r[1], total)) + '%').join(', '))}">${d.rows.map((r, i) => {
          const p = pct(r[1], total);
          return `<div style="width:${p}%;background:${colors[i]}" data-tip="${tip(r[0], fmt(r[1]) + ' drivers', p1(p) + '% of tested drivers')}">${p >= 7 ? Math.round(p) + '%' : ''}</div>`;
        }).join('')}</div>
        <div class="legend">${d.rows.map((r, i) => `<span><span class="sw" style="background:${colors[i]}"></span>${esc(r[0])} · ${fmt(r[1])}</span>`).join('')}</div>
        <p class="note">Built with INTERSECT and EXCEPT. ${fmt(total)} drivers were tested for both. A positive drug test shows presence, not impairment.</p>`;
        return `<b>${p1(pct(d.rows[0][1], total))}%</b> of drivers tested for both were over the legal limit and drug-positive at the same time.`;
      } },
    { id: 'combos', title: 'Drinking and speeding after dark', span: 'span-4',
      render(body, d) {
        const order = ['Drinking + speeding', 'Drinking only', 'Speeding only', 'Neither'];
        const get = (light, rf) => (d.rows.find((r) => r[0] === light && r[1] === rf) || [0, 0, 0, 0])[3];
        const max = Math.max(1, ...d.rows.filter((r) => r[1] !== 'All crashes').map((r) => r[3])) * 1.1;
        body.innerHTML = `<div class="legend" style="margin:0 0 14px"><span><span class="sw" style="background:${C.orange}"></span>Daylight</span><span><span class="sw" style="background:${C.blue}"></span>Dark</span></div>
          <div class="hbars">${order.map((rf) => {
            const a = get('Daylight', rf), b = get('Dark', rf);
            return `<div style="display:grid;grid-template-columns:170px minmax(0,1fr);gap:14px;align-items:center"><span>${rf}</span><div style="display:grid;gap:4px">
              ${[[a, C.orange, 'Daylight'], [b, C.blue, 'Dark']].map(([v, col, nm]) => `<div style="display:flex;align-items:center;gap:8px"><div class="fill" style="height:13px;width:${(100 * v) / max}%;background:${col};border-radius:0 4px 4px 0" data-tip="${tip(rf + ' · ' + nm, p1(v) + '% of ' + nm.toLowerCase() + ' crashes')}"></div><span style="font-size:12px;color:${C.ink2}">${p1(v)}%</span></div>`).join('')}
            </div></div>`;
          }).join('')}</div><p class="note">From the saved view <code>v_crash_facts</code>, with WITH ROLLUP subtotals. Dawn, dusk and unknown light are excluded.</p>`;
        const a = get('Daylight', order[0]), b = get('Dark', order[0]);
        return `After dark, <b>${p1(b)}%</b> of fatal crashes involve both drinking and speeding, versus ${p1(a)}% in daylight${a ? ` (${(b / a).toFixed(1)}×)` : ''}.`;
      } },
    { id: 'speeding', title: 'Speeding alone', span: 'span-2',
      render(body, d) {
        const one = d.rows.find((r) => r[0] === 'One vehicle') || ['One vehicle', 0, 0], multi = d.rows.find((r) => r[0] !== 'One vehicle') || ['Multiple vehicles', 0, 0];
        const a = pct(one[2], one[1]), b = pct(multi[2], multi[1]);
        body.innerHTML = pairBars({ label: 'One vehicle', value: a, color: C.orange, tip: tip('One-vehicle crashes', fmt(one[2]) + ' of ' + fmt(one[1]) + ' vehicles speeding') },
                                  { label: 'Multiple vehicles', value: b, color: C.blue, tip: tip('Multi-vehicle crashes', fmt(multi[2]) + ' of ' + fmt(multi[1]) + ' vehicles speeding') }) +
          '<p class="note">Share of vehicles (with known speeding status) that were speed-related, by crash type.</p>';
        return b ? `Vehicles in one-vehicle crashes were speeding <b>${(a / b).toFixed(1)}×</b> as often (${p1(a)}% vs ${p1(b)}%).` : '';
      } },
  ],
  survival: [
    { id: 'seatbelt', title: 'Out of every 100 car occupants…', span: 'span-3',
      render(body, d) {
        const g = (name) => d.rows.find((r) => r[0] === name) || [name, 0, 0, 0];
        const b = g('Belted'), u = g('Unbelted');
        const pb = pct(b[2], b[1]), pu = pct(u[2], u[1]);
        const grid = (p, col) => `<div class="unit-grid">${Array.from({ length: 100 }, (_, i) => `<i style="background:${i < Math.round(p) ? col : '#2a3140'}"></i>`).join('')}</div>`;
        body.innerHTML = `<div class="units">
          <div class="unit" data-tip="${tip('Wearing a seat belt', fmt(b[2]) + ' of ' + fmt(b[1]) + ' died (' + p1(pb) + '%)', p1(pct(b[3], b[1])) + '% ejected')}">${grid(pb, C.blue)}<div><div class="num">${Math.round(pb)} died</div><div class="sub">wearing a seat belt · ${p1(pct(b[3], b[1]))}% ejected</div></div></div>
          <div class="unit" data-tip="${tip('No restraint', fmt(u[2]) + ' of ' + fmt(u[1]) + ' died (' + p1(pu) + '%)', p1(pct(u[3], u[1])) + '% ejected')}">${grid(pu, C.orange)}<div><div class="num">${Math.round(pu)} died</div><div class="sub">no restraint · ${p1(pct(u[3], u[1]))}% ejected</div></div></div>
        </div><div class="legend" style="justify-content:center"><span><span class="sw dot" style="background:${C.blue}"></span>Died, belted</span><span><span class="sw dot" style="background:${C.orange}"></span>Died, unbelted</span><span><span class="sw dot" style="background:#2a3140"></span>Survived</span></div>`;
        return pb ? `Unbelted occupants were <b>${(pu / pb).toFixed(1)}×</b> as likely to die (${p1(pu)}% vs ${p1(pb)}%), and ${p1(pct(u[3], u[1]))}% were thrown from the vehicle.` : '';
      } },
    { id: 'vehage', title: 'Newer cars, more survivors', span: 'span-3',
      render(body, d) {
        const labels = ['2004 or older', '2005–09', '2010–14', '2015–19', '2020–25'];
        const byB = {}; d.rows.forEach((r) => { byB[r[0]] = r; });
        const val = (i, k, n) => { const r = byB[i + 1]; return r && r[n] >= 10 ? pct(r[k], r[n]) : null; };
        const belted = labels.map((_, i) => val(i, 3, 2)), unbelted = labels.map((_, i) => val(i, 5, 4));
        const top = Math.max(40, ...belted.filter((v) => v != null), ...unbelted.filter((v) => v != null));
        body.innerHTML = lineChart({ label: 'Share of occupants killed by vehicle model year, belted vs unbelted', xLabels: labels, yMax: Math.ceil(top / 20) * 20,
          series: [{ name: 'No belt', color: C.orange, values: unbelted, tips: labels.map((_, i) => byB[i + 1] ? fmt(byB[i + 1][4]) + ' unbelted occupants' : '') },
                   { name: 'Belted', color: C.blue, values: belted, tips: labels.map((_, i) => byB[i + 1] ? fmt(byB[i + 1][2]) + ' belted occupants' : '') }] }) +
          `<div class="legend"><span><span class="sw dot" style="background:${C.orange}"></span>No restraint</span><span><span class="sw dot" style="background:${C.blue}"></span>Seat belt</span>
           <span style="color:${C.muted}">Share of car occupants killed, by the vehicle’s model year</span></div>`;
        const f = belted.find((v) => v != null), l = [...belted].reverse().find((v) => v != null);
        return f != null ? `Even wearing a belt, the death rate falls from <b>${p1(f)}%</b> in 2004-or-older vehicles to <b>${p1(l)}%</b> in the newest ones.` : '';
      } },
    { id: 'timing', title: 'Rural victims die at the scene', span: 'span-4',
      render(body, d) {
        const names = ['At the scene', 'On the way to hospital', 'Within 1 hour at hospital', '1–23 hours later', '1+ days later'];
        const cols = [C.orange, '#86b6ef', '#5598e7', '#2a78d6', '#1c5cab'];
        const areas = { 1: 'Rural', 2: 'Urban' };
        const byA = {}; d.rows.forEach(([a, b, n, p]) => { (byA[a] = byA[a] || {})[b] = { n, p }; });
        body.innerHTML = Object.keys(byA).map((a) => `<div class="stack-row"><span>${areas[a]}</span><div class="stack">${[1, 2, 3, 4, 5].map((b) => {
          const v = byA[a][b] || { n: 0, p: 0 };
          return `<div style="width:${v.p}%;background:${cols[b - 1]}" data-tip="${tip(areas[a] + ' · ' + names[b - 1], fmt(v.n) + ' deaths (' + p1(v.p) + '%)')}">${v.p >= 8 ? Math.round(v.p) + '%' : ''}</div>`;
        }).join('')}</div></div>`).join('') + `<div class="legend" style="padding-left:84px">${names.map((n, i) => `<span><span class="sw" style="background:${cols[i]}"></span>${n}</span>`).join('')}</div>`;
        const r = byA[1] && byA[1][1], u = byA[2] && byA[2][1];
        const alive = (a) => byA[a] ? [3, 4, 5].reduce((s, b) => s + (byA[a][b] ? byA[a][b].p : 0), 0) : 0;
        if (r && u) return `<b>${p1(r.p)}%</b> of rural victims died at the scene vs ${p1(u.p)}% of urban victims. ${p1(alive(2))}% of urban victims reached a hospital alive, vs ${p1(alive(1))}% rural.`;
        return r ? `${p1(r.p)}% of these rural victims died at the scene.` : u ? `${p1(u.p)}% of these urban victims died at the scene.` : '';
      } },
    { id: 'ems', title: 'Waiting for EMS', span: 'span-2',
      render(body, d) {
        const areas = { 1: 'Rural', 2: 'Urban' };
        const max = Math.max(15, ...d.rows.map((r) => r[2])) * 1.1;
        body.innerHTML = `<div class="bigbars">${d.rows.map(([a, n, avg, med]) => `<div class="bigbar" data-tip="${tip(areas[a], 'Median ' + med + ' min · average ' + avg + ' min', fmt(n) + ' crashes with valid times')}">
          <div class="top"><span>${areas[a]}</span><span class="num">${Math.round(med)} min</span></div>
          <div class="track"><div class="fill" style="width:${(100 * med) / max}%;background:${C.blue}"></div></div>
          <div class="sub">average ${avg} min · ${fmt(n)} crashes</div></div>`).join('')}</div><p class="note">Median minutes from EMS notification to arrival (MySQL has no MEDIAN(), so it uses ROW_NUMBER()).</p>`;
        const r = d.rows.find((x) => x[0] === 1), u = d.rows.find((x) => x[0] === 2);
        return r && u ? `EMS takes <b>${Math.round(r[3] - u[3])} minutes longer</b> to reach rural crashes (median ${Math.round(r[3])} vs ${Math.round(u[3])}).` : '';
      } },
    { id: 'nonmotor', title: 'Walking at night', span: 'span-3',
      render(body, d) {
        const items = d.rows.map(([t, n, k]) => ({ label: t, value: pct(k, n), display: p1(pct(k, n)) + '%', tip: tip(t, fmt(k) + ' of ' + fmt(n) + ' people were pedestrians or cyclists') }));
        body.innerHTML = hbars(items, { max: Math.max(1, ...items.map((i) => i.value)) * 1.1 }) + `<p class="note">Share of everyone in a fatal crash who was not in a vehicle.</p>`;
        const s = [...items].sort((a, b) => b.value - a.value);
        return s.length > 1 ? `Pedestrians and cyclists are <b>${p1(s[0].value)}%</b> of people in ${esc(s[0].label.split(' (')[0].toLowerCase())} crashes vs ${p1(s[s.length - 1].value)}% in the ${esc(s[s.length - 1].label.split(' (')[0].toLowerCase())}.` : '';
      } },
    { id: 'bodies', title: 'What hits pedestrians and cyclists', span: 'span-3',
      render(body, d) {
        const short = (s) => s.replace(/\s*\(.*$/, '').replace(/,.*$/, '');
        const items = d.rows.map(([b, n]) => ({ label: short(b), value: n, display: fmt(n), tip: tip(b, fmt(n) + ' vehicles') }));
        body.innerHTML = hbars(items) + `<p class="note">Vehicles in crashes where someone outside a vehicle was involved.</p>`;
        return items.length ? `Everyday vehicles lead, not big rigs: <b>${esc(items[0].label)}</b>${items[1] ? ', then ' + esc(items[1].label) : ''}${items[2] ? ' and ' + esc(items[2].label) : ''}.` : '';
      } },
    { id: 'weather', title: 'Deadlier weather', span: 'span-3',
      render(body, d) {
        const overall = d.rows.length ? d.rows[0][4] : 1;
        const vals = d.rows.map((r) => r[3]).concat(overall);
        const lo = Math.floor((Math.min(...vals) - 0.02) * 50) / 50, hi = Math.ceil((Math.max(...vals) + 0.02) * 50) / 50;
        const x = (v) => (100 * (v - lo)) / (hi - lo);
        body.innerHTML = `<div style="display:grid;gap:12px">${d.rows.map(([w, n, dd, dpc]) => `
          <div style="display:grid;grid-template-columns:150px minmax(0,1fr) 46px;gap:10px;align-items:center" data-tip="${tip(w, dpc + ' deaths per crash', fmt(n) + ' crashes · ' + fmt(dd) + ' deaths', n < 100 ? 'Small sample' : '')}">
            <span style="font-size:13px">${esc(w)}</span>
            <div style="position:relative;height:16px"><div style="position:absolute;left:0;right:0;top:7px;height:2px;background:${C.grid}"></div>
              <div style="position:absolute;top:0;bottom:0;left:${x(overall)}%;width:1px;background:${C.muted}"></div>
              <div style="position:absolute;top:2px;left:${x(dpc)}%;width:12px;height:12px;margin-left:-6px;border-radius:50%;background:${dpc > overall ? C.orange : C.muted};box-shadow:0 0 0 2px ${C.surface}"></div></div>
            <span style="font-size:13px;color:${C.ink2};text-align:right">${Number(dpc).toFixed(2)}</span></div>`).join('')}</div>
          <div style="display:grid;grid-template-columns:150px minmax(0,1fr) 46px;gap:10px;margin-top:6px;font-size:11px;color:${C.muted}"><span></span>
            <span style="position:relative;height:14px">${[lo, (lo + hi) / 2, hi].map((t, i) => `<span style="position:absolute;left:${x(t)}%;transform:translateX(${i === 0 ? '0' : i === 2 ? '-100%' : '-50%'})">${t.toFixed(2)}</span>`).join('')}</span><span></span></div>
          <div class="legend"><span><span class="sw dot" style="background:${C.orange}"></span>Above average</span><span><span class="sw dot" style="background:${C.muted}"></span>At or below average</span>
            <span style="color:${C.muted}">Deaths per crash · thin line = average of all weather (${Number(overall).toFixed(3)})</span></div>`;
        const above = d.rows.filter((r) => r[3] > overall && r[1] >= 50);
        return above.length ? `<b>${esc(above[0][0])}</b> crashes kill ${Number(above[0][3]).toFixed(2)} people per crash vs ${Number(overall).toFixed(2)} on average.` : 'No common weather type is above average under these filters.';
      } },
    { id: 'rollover', title: 'Rolling over', span: 'span-3',
      render(body, d) {
        const one = d.rows.find((r) => r[0] === 'One vehicle') || ['One vehicle', 0, 0], multi = d.rows.find((r) => r[0] !== 'One vehicle') || ['Multiple vehicles', 0, 0];
        const a = pct(one[2], one[1]), b = pct(multi[2], multi[1]);
        body.innerHTML = pairBars({ label: 'One vehicle', value: a, color: C.orange, tip: tip('One-vehicle crashes', fmt(one[2]) + ' of ' + fmt(one[1]) + ' vehicles rolled over') },
                                  { label: 'Multiple vehicles', value: b, color: C.blue, tip: tip('Multi-vehicle crashes', fmt(multi[2]) + ' of ' + fmt(multi[1]) + ' vehicles rolled over') }) +
          '<p class="note">Share of vehicles that rolled over, by crash type.</p>';
        return b ? `Vehicles in one-vehicle crashes rolled over <b>${(a / b).toFixed(1)}×</b> as often (${p1(a)}% vs ${p1(b)}%).` : '';
      } },
  ],
};
const ALL_CHARTS = Object.values(CHARTS).flat();

const PAGES = {
  overview: { eyebrow: 'NHTSA FARS · 2024', title: 'Every fatal crash in America, 2024', lede: 'FARS records every crash on a U.S. public road where someone died within 30 days. Each chart below runs a live query against our 53-table MySQL database. Change a filter and every chart re-queries.' },
  behavior: { eyebrow: '02 · Behavior', title: 'Impairment & risky driving', lede: 'Who was drinking, who had done it before, and when the most dangerous drivers are on the road.' },
  survival: { eyebrow: '03 · Survival', title: 'Who survives a fatal crash?', lede: 'Everyone counted here was in a crash that killed someone. What separated the people who walked away from the people who didn’t?' },
};

// ------------------------------------------------------------------ cards
const CODE_ICON = '<svg aria-hidden="true" width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M5.5 4 2 8l3.5 4M10.5 4 14 8l-3.5 4"/></svg>';
function cardShell(def) {
  return `<article class="card ${def.span}" id="card-${def.id}" aria-busy="true">
    <header class="card-head">
      <div><h3>${esc(def.title)}</h3><p class="insight" id="ins-${def.id}">&nbsp;</p></div>
      <div class="chips">${def.controls ? def.controls() : ''}
        <button type="button" class="sql-btn" data-sql="${def.id}" aria-haspopup="dialog" aria-label="Show the SQL behind “${esc(def.title)}” and who wrote it">
          ${CODE_ICON}<span>SQL</span><span class="who" id="who-${def.id}"></span></button>
      </div>
    </header>
    <div class="card-body" id="body-${def.id}"><div class="spinner"></div></div>
    <footer class="card-foot"><span class="meta" id="meta-${def.id}">Running query…</span></footer>
  </article>`;
}

async function loadChart(def, gen) {
  const card = $('#card-' + def.id);
  if (!card) return;
  const body = $('#body-' + def.id);
  card.classList.add('loading');
  card.setAttribute('aria-busy', 'true');
  if (!$('.spinner', body)) body.insertAdjacentHTML('beforeend', '<div class="spinner"></div>');
  try {
    const d = await getJSON(`/api/chart/${def.id}?${qs()}`);
    if (gen !== generation) return;
    def.data = d;
    let insight = '';
    if (!d.rows.length) body.innerHTML = '<div class="empty">No crashes match these filters.</div>';
    else insight = def.render(body, d) || '';
    $('#ins-' + def.id).innerHTML = insight || '&nbsp;';
    $('#who-' + def.id).textContent = '· ' + d.member;
    $('#meta-' + def.id).innerHTML = `Live query · <code>${esc(d.sources.map((s) => s.name).join(' + '))}</code> · ${fmt(d.rows.length)} row${d.rows.length === 1 ? '' : 's'} · ${d.ms} ms`;
  } catch (e) {
    if (gen !== generation) return;
    body.innerHTML = `<div class="err">Query failed: ${esc(e.message)}</div>`;
    def.data = Object.assign({ rows: [], columns: [], sources: [], note: '' }, e.data || {}, { error: e.message });
    $('#meta-' + def.id).textContent = 'Error';
  } finally {
    if (gen === generation) { card.classList.remove('loading'); card.setAttribute('aria-busy', 'false'); $('.spinner', body)?.remove(); }
  }
}

function renderChartPage(page) {
  const meta = PAGES[page];
  const defs = CHARTS[page];
  let html = `<div class="page-head"><div><div class="eyebrow">${esc(meta.eyebrow)}</div><h1>${esc(meta.title)}</h1><p>${esc(meta.lede)}</p></div></div>`;
  if (page === 'overview') {
    const [mapDef, ...rest] = defs;
    html += `<div class="hero">${cardShell(mapDef)}<div class="kpis" id="kpis" aria-live="polite">${'<div class="kpi"><div class="label">&nbsp;</div><div class="value">–</div></div>'.repeat(4)}</div></div>`;
    html += `<div class="section-title"><span>01</span><h2>When crashes happen</h2></div><div class="grid">${rest.map(cardShell).join('')}</div>`;
  } else {
    html += `<div class="grid">${defs.map(cardShell).join('')}</div>`;
  }
  $('#main').innerHTML = html;
  refreshCharts();
}

const KPI_DEF = { id: 'kpis', title: 'Headline numbers' };
async function loadKpis(gen) {
  const el = $('#kpis');
  if (!el) return;
  try {
    const d = await getJSON(`/api/chart/kpis?${qs()}`);
    if (gen !== generation) return;
    KPI_DEF.data = d;
    const [crashes, deaths, people, drink, nonmotor] = d.rows[0];
    const k = (label, value, sub, cls = '', bar = null) => `<div class="kpi"><div class="label">${label}</div><div class="value ${cls}">${value}</div><div class="sub">${sub}</div>${bar != null ? `<div class="bar"><i style="width:${bar}%"></i></div>` : ''}</div>`;
    el.innerHTML = k('Fatal crashes', fmt(crashes), 'one row each in <code>accident</code>') +
      k('People killed', fmt(deaths), crashes ? `${(deaths / crashes).toFixed(2)} per crash · ${fmt(people)} people involved` : '') +
      k('Involved a drinking driver', p1(pct(drink, crashes)) + '%', `${fmt(drink)} crashes`, 'accent', pct(drink, crashes)) +
      k('Killed a pedestrian or cyclist', p1(pct(nonmotor, crashes)) + '%', `${fmt(nonmotor)} crashes`, '', pct(nonmotor, crashes)) +
      `<button type="button" class="sql-btn" data-sql="kpis" aria-haspopup="dialog" aria-label="Show the SQL behind the headline numbers and who wrote it" style="justify-self:start">${CODE_ICON}<span>SQL</span><span class="who">· ${esc(d.member)}</span></button>`;
  } catch (e) {
    el.innerHTML = `<div class="kpi err">KPIs failed: ${esc(e.message)}</div>`;
  }
}

function refreshCharts() {
  const gen = ++generation;
  if (state.page === 'overview') loadKpis(gen);
  (CHARTS[state.page] || []).forEach((def) => loadChart(def, gen));
  updateSummary();
}

// ------------------------------------------------------------------ filters
function updateSummary() {
  const parts = [];
  if (state.state) parts.push(`<b>${esc(stateName(state.state))}</b>`);
  if (state.area) parts.push(`<b>${state.area === '1' ? 'rural' : 'urban'}</b> roads`);
  if (state.m1 !== 1 || state.m2 !== 12) parts.push(`<b>${MON[state.m1 - 1]}${state.m1 !== state.m2 ? '–' + MON[state.m2 - 1] : ''}</b>`);
  $('#filter-summary').innerHTML = parts.length ? 'Showing ' + parts.join(' · ') : 'Showing all 50 states + DC, all of 2024';
}
function syncControls() {
  $('#f-state').value = state.state;
  $('#f-m1').value = state.m1;
  $('#f-m2').value = state.m2;
  $$('#f-area button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.v === state.area)));
}
function setFilter(patch) {
  Object.assign(state, patch);
  if (state.m1 > state.m2) [state.m1, state.m2] = [state.m2, state.m1];
  syncControls();
  if (CHARTS[state.page]) refreshCharts();
}
function initFilters() {
  $('#f-m1').innerHTML = MONTHS.map((m, i) => `<option value="${i + 1}">${m}</option>`).join('');
  $('#f-m2').innerHTML = $('#f-m1').innerHTML;
  $('#f-state').addEventListener('change', (e) => setFilter({ state: e.target.value }));
  $('#f-m1').addEventListener('change', (e) => setFilter({ m1: +e.target.value }));
  $('#f-m2').addEventListener('change', (e) => setFilter({ m2: +e.target.value }));
  $('#f-area').addEventListener('click', (e) => { const b = e.target.closest('button'); if (b) setFilter({ area: b.dataset.v }); });
  $('#f-reset').addEventListener('click', () => setFilter({ state: '', area: '', m1: 1, m2: 12 }));
  syncControls();
}

// ------------------------------------------------------------------ SQL panel (who wrote it + saved file + SQL as run + rows)
const sourceCache = {};
function filterText() {
  const parts = [];
  if (state.state) parts.push(stateName(state.state));
  if (state.area) parts.push(state.area === '1' ? 'rural' : 'urban');
  if (state.m1 !== 1 || state.m2 !== 12) parts.push(MON[state.m1 - 1] + '–' + MON[state.m2 - 1]);
  return parts.length ? parts.join(' · ') : 'no filters';
}
function rowsTable(cols, rows) {
  if (!rows.length) return '<div class="empty">No rows.</div>';
  const isNum = cols.map((_, i) => rows.every((r) => r[i] == null || typeof r[i] === 'number'));
  return `<div class="result-wrap"><table class="result-table"><thead><tr>${cols.map((c) => `<th scope="col">${esc(c)}</th>`).join('')}</tr></thead><tbody>${rows.slice(0, 200).map((r) =>
    `<tr>${r.map((v, i) => `<td class="${isNum[i] ? 'num' : ''}">${v == null ? '<span style="color:#8a93a5">NULL</span>' : esc(isNum[i] && Number.isInteger(v) && Math.abs(v) >= 1000 ? fmt(v) : v)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>
    <p class="note">${fmt(rows.length)} rows${rows.length > 200 ? ' (first 200 shown)' : ''}</p>`;
}
async function openSqlPanel(def) {
  const d = def.data;
  const dlg = $('#sql-dialog');
  if (!d) return;
  const authors = [];
  d.sources.forEach((s) => { if (s.author && !authors.some((a) => a.who === s.author)) authors.push({ who: s.author, file: s.name }); });
  const byline = authors.length > 1 ? authors.map((a) => `<b>${esc(a.who)}</b> (${esc(a.file)})`).join(' and ') : `<b>${esc(authors[0] ? authors[0].who : d.member)}</b>`;
  const tabs = d.sources.map((s, i) => ({ key: 'src' + i, label: s.name, sub: 'saved query · ' + s.author }))
    .concat([{ key: 'run', label: 'As run in this chart', sub: filterText() }, { key: 'rows', label: 'Result rows', sub: fmt(d.rows.length) + ' rows · ' + (d.ms ?? '–') + ' ms' }]);
  dlg.innerHTML = `<div class="drawer">
    <header class="drawer-head">
      <div><div class="eyebrow">SQL behind this chart</div><h2 id="sql-dialog-title">${esc(def.title)}</h2>
        <p class="byline">Query written by ${byline}</p></div>
      <button type="button" class="icon-btn" data-close aria-label="Close">
        <svg aria-hidden="true" width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 4l10 10M14 4 4 14"/></svg></button>
    </header>
    ${d.note ? `<p class="drawer-note">${esc(d.note)}</p>` : ''}
    <div class="drawer-tabs" role="tablist" aria-label="SQL views">${tabs.map((t, i) =>
      `<button type="button" role="tab" id="tab-${t.key}" aria-selected="${i === 0}" aria-controls="panel-sql" data-tab="${t.key}"><span>${esc(t.label)}</span><small>${esc(t.sub)}</small></button>`).join('')}</div>
    <div class="drawer-panel" id="panel-sql" role="tabpanel" aria-live="polite"></div>
  </div>`;
  const panel = $('#panel-sql', dlg);
  const show = async (key) => {
    $$('[data-tab]', dlg).forEach((b) => b.setAttribute('aria-selected', String(b.dataset.tab === key)));
    if (key === 'run') {
      const ft = filterText();
      panel.innerHTML = `<pre class="sql">${highlightSQL(d.sql || '')}</pre>${d.error ? `<p class="err" style="min-height:0">${esc(d.error)}</p>` : ''}
        <p class="note">The saved query as this chart runs it. ${ft === 'no filters' ? 'No filters are set, so this is the national, full-year version.' : 'Current filters: ' + esc(ft) + '.'} Filter values are sent to MySQL as parameters, not pasted into the SQL.</p>`;
      return;
    }
    if (key === 'rows') { panel.innerHTML = rowsTable(d.columns, d.rows); return; }
    const src = d.sources[+key.slice(3)];
    panel.innerHTML = '<div style="position:relative;min-height:120px"><div class="spinner"></div></div>';
    try {
      const s = sourceCache[src.path] || (sourceCache[src.path] = await getJSON('/api/source?path=' + encodeURIComponent(src.path)));
      panel.innerHTML = `<p class="note" style="margin:0 0 10px"><code>${esc(s.path)}</code> · written by <b style="color:#eef0f3">${esc(s.author)}</b> · exactly as saved in the repo</p><pre class="sql">${highlightSQL(s.text.trim())}</pre>`;
    } catch (e) { panel.innerHTML = `<div class="err">${esc(e.message)}</div>`; }
  };
  dlg.setAttribute('aria-labelledby', 'sql-dialog-title');
  dlg.onclick = (e) => {
    if (e.target === dlg || e.target.closest('[data-close]')) dlg.close();
    const t = e.target.closest('[data-tab]');
    if (t) show(t.dataset.tab);
  };
  dlg.showModal();
  show(tabs[0].key);
}

document.addEventListener('click', (e) => {
  const sqlBtn = e.target.closest('[data-sql]');
  if (sqlBtn) {
    const def = ALL_CHARTS.concat(KPI_DEF).find((c) => c.id === sqlBtn.dataset.sql);
    if (def) openSqlPanel(def);
    return;
  }
  const layer = e.target.closest('[data-layer]');
  if (layer) {
    state.highlight = layer.dataset.layer;
    $$('[data-layer]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.layer === state.highlight)));
    const def = CHARTS.overview[0];
    if (def.data) $('#ins-map').innerHTML = def.render($('#body-map'), def.data);
    return;
  }
  const st = e.target.closest('[data-state]');
  if (st) { setFilter({ state: String(st.dataset.state) === String(state.state) ? '' : String(st.dataset.state) }); window.scrollTo({ top: 0, behavior: 'smooth' }); }
});
document.addEventListener('keydown', (e) => {
  const st = e.target.closest && e.target.closest('.hbar[data-state]');
  if (st && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); st.click(); }
});

// ------------------------------------------------------------------ portfolio page
let PORT = null;
async function renderPortfolio() {
  $('#main').innerHTML = `<div class="page-head"><div><div class="eyebrow">04 · SQL portfolio</div><h1>Query Portfolio</h1>
    <p>Every saved query in <code>sql/queries/</code>, run live. Each one follows question → SQL → result → insight.</p></div></div>
    <div class="member-tiles" id="member-tiles"></div><div class="portfolio"><nav class="qlist" id="qlist" aria-label="Saved queries"></nav><section class="qdetail" id="qdetail"></section></div>`;
  if (!PORT) PORT = await getJSON('/api/queries');
  const groups = PORT.members.concat(PORT.queries.some((q) => q.member === 'Unassigned') ? ['Unassigned'] : []);
  $('#member-tiles').innerHTML = PORT.members.map((m) => {
    const qs_ = PORT.queries.filter((q) => q.member === m);
    const b = qs_.filter((q) => q.level === 'basic').length, a = qs_.filter((q) => q.level === 'advanced').length;
    return `<div class="member-tile"><div class="name">${esc(m)}</div><div class="counts"><b>${qs_.length}</b>queries · ${b} basic · ${a} advanced</div></div>`;
  }).join('');
  const qid = (f) => (f.match(/^(q\d+|\d+)/) || [])[0]?.replace(/^(\d)/, 'q$1') || (f.match(/saida_q(\d)/) ? 's' + f.match(/saida_q(\d)/)[1] : f.slice(0, 4));
  $('#qlist').innerHTML = groups.map((m) => `<div class="qgroup">${esc(m)}</div>` + PORT.queries.filter((q) => q.member === m).map((q) =>
    `<button type="button" class="qitem" data-q="${esc(q.file)}"><span class="qid">${esc(qid(q.file))}</span><span><span class="qq">${esc(q.question)}</span><br><span class="lvl ${q.level === 'advanced' ? 'adv' : ''}">${esc(q.level)}</span></span></button>`).join('')).join('');
  $('#qlist').addEventListener('click', (e) => { const b = e.target.closest('[data-q]'); if (b) showQuery(b.dataset.q); });
  const want = decodeURIComponent((location.hash.split('/')[1] || ''));
  showQuery(PORT.queries.find((q) => q.file === want) ? want : PORT.queries[0].file);
}
function resultTable(r) {
  if (r.columns.length === 1 && /^EXPLAIN$/i.test(r.columns[0])) return `<pre class="explain">${esc(r.rows.map((x) => x[0]).join('\n\n'))}</pre>`;
  const isNum = r.columns.map((_, i) => r.rows.every((row) => row[i] == null || typeof row[i] === 'number'));
  return `<div class="result-wrap"><table class="result-table"><thead><tr>${r.columns.map((c) => `<th scope="col">${esc(c)}</th>`).join('')}</tr></thead><tbody>${r.rows.slice(0, 50).map((row) =>
    `<tr>${row.map((v, i) => `<td class="${isNum[i] ? 'num' : ''}">${v == null ? '<span style="color:#8a93a5">NULL</span>' : esc(isNum[i] && Number.isInteger(v) && Math.abs(v) >= 1000 ? fmt(v) : v)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>
    <p class="note">${fmt(r.total_rows)} row${r.total_rows === 1 ? '' : 's'}${r.total_rows > 50 ? ' (first 50 shown)' : ''} · ${r.ms} ms</p>`;
}
async function showQuery(file) {
  const q = PORT.queries.find((x) => x.file === file);
  history.replaceState(null, '', '#portfolio/' + encodeURIComponent(file));
  $$('.qitem').forEach((b) => b.setAttribute('aria-current', String(b.dataset.q === file)));
  const el = $('#qdetail');
  el.innerHTML = `<div class="card"><div class="qmeta"><span class="chip">${esc(q.member)}</span><span class="chip">${esc(q.level || 'query')}</span><span class="chip">${esc(file)}</span></div>
      <h2>${esc(q.question)}</h2><p class="insight">${esc(q.technique)}</p></div>
    <div class="card"><p class="step-label">Result (running live)</p><div id="qresult" style="position:relative;min-height:120px"><div class="spinner"></div></div></div>
    ${q.insight ? `<div class="insight-box"><div class="eyebrow">Insight</div>${esc(q.insight)}</div>` : ''}
    <div class="card"><p class="step-label">SQL · ${esc(file)}</p><pre class="sql" style="max-height:520px">…</pre></div>`;
  try {
    const d = await getJSON('/api/queries/' + encodeURIComponent(file));
    if (!$('#qresult')) return;
    $('pre.sql', el).innerHTML = highlightSQL(d.source.trim());
    $('#qresult').innerHTML = (d.results.map(resultTable).join('<div style="height:14px"></div>') || '<div class="empty">No result set.</div>') +
      (d.error ? `<div class="err" style="min-height:0;margin-top:12px">MySQL error: ${esc(d.error)}${/idx_/.test(d.error) ? ' (run sql/schema/indexes.sql first)' : ''}</div>` : '');
  } catch (e) {
    $('#qresult').innerHTML = `<div class="err">${esc(e.message)}</div>`;
  }
}

// ------------------------------------------------------------------ database page
async function renderDatabase() {
  $('#main').innerHTML = `<div class="page-head"><div><div class="eyebrow">05 · Database</div><h1>Schema &amp; import status</h1>
    <p>The FARS 2024 files normalized to 3NF and loaded into MySQL. Every number on this page is read live from <code>information_schema</code> and <code>COUNT(*)</code>.</p></div></div>
    <div class="stats" id="db-stats">${'<div class="kpi"><div class="label">&nbsp;</div><div class="value">–</div></div>'.repeat(4)}</div>
    <div class="grid" style="margin-top:20px">
      <article class="card span-4"><div class="card-head"><div><h3>Final EER diagram</h3><p class="insight">Crash → unit (vehicle / parked vehicle subtypes) → person, with child tables for multi-valued facts and lookup tables from 3NF.</p></div><a class="chip" href="/eer.png" target="_blank" rel="noopener">Open full size</a></div>
        <div class="card-body"><a href="/eer.png" target="_blank" rel="noopener"><img class="eer" src="/eer.png" alt="Entity-relationship diagram of the 53-table FARS schema with primary and foreign keys"></a></div></article>
      <article class="card span-2"><div class="card-head"><div><h3>Dataset recap</h3></div></div><div class="card-body">
        <dl class="recap">
          <dt>Source</dt><dd>NHTSA Fatality Analysis Reporting System, 2024 national + auxiliary files</dd>
          <dt>Coverage</dt><dd>Every crash on a U.S. public road (50 states + DC) with a death within 30 days</dd>
          <dt>Raw data</dt><dd>39 CSV files · 2,033,633 rows · 1,125 columns</dd>
          <dt>Since the midpoint</dt><dd>2 indexes (indexes.sql), 1 view (v_crash_facts), new queries q13–q22, this dashboard</dd>
        </dl>
        <p class="step-label" style="margin-top:22px">Load pipeline</p>
        <ol class="pipeline">
          <li><div><b>Clean</b><br><span>src/etl/clean_raw.py trims values, moves label columns to lookups, keeps every row</span></div></li>
          <li><div><b>Stage</b><br><span>LOAD DATA LOCAL INFILE into text-only fars_stage tables</span></div></li>
          <li><div><b>Load</b><br><span>INSERT … SELECT into typed tables, strict mode, foreign keys on, parents first</span></div></li>
          <li><div><b>Verify</b><br><span>12_load_verify.sql: row counts and 29 integrity checks</span></div></li>
          <li><div><b>Tune</b><br><span>indexes.sql and views.sql for the queries and this app</span></div></li>
        </ol></div></article>
    </div>
    <article class="card" style="margin-top:20px"><div class="card-head"><div><h3>Tables, keys and row counts</h3><p class="insight" id="db-note">Loading…</p></div><input class="search" id="db-search" type="search" placeholder="Filter tables…" aria-label="Filter tables"></div>
      <div class="card-body"><div class="result-wrap" style="max-height:560px" id="db-table"><div class="spinner"></div></div></div></article>`;
  try {
    const d = await getJSON('/api/schema');
    const k = (label, value, sub) => `<div class="kpi"><div class="label">${label}</div><div class="value">${value}</div><div class="sub">${sub}</div></div>`;
    $('#db-stats').innerHTML = k('Tables', fmt(d.table_count), 'base tables in <code>fars</code>') + k('Primary keys', fmt(d.pk_count), 'every table has one') +
      k('Foreign keys', fmt(d.fk_count), 'enforced by InnoDB') + k('Rows loaded', fmt(d.total_rows), 'live COUNT(*) per table');
    $('#db-note').textContent = `${d.table_count} tables · ${fmt(d.total_rows)} rows. PK = primary key; FK = foreign key → referenced table.`;
    const draw = (filter) => {
      const rows = d.tables.filter((t) => !filter || t.table.includes(filter.toLowerCase()));
      $('#db-table').innerHTML = `<table class="result-table"><thead><tr><th scope="col">Table</th><th scope="col" style="text-align:right">Rows</th><th scope="col" style="text-align:right">Columns</th><th scope="col">Primary key</th><th scope="col">Foreign keys</th></tr></thead><tbody>${rows.map((t) =>
        `<tr><td style="color:#eef0f3;font-family:var(--mono)">${esc(t.table)}</td><td class="num">${fmt(t.rows)}</td><td class="num">${t.columns}</td><td style="font-family:var(--mono);color:#f5b84f">${esc(t.pk)}</td><td style="font-family:var(--mono);font-size:12px">${t.fks.map(esc).join('<br>') || '<span style="color:#8a93a5">—</span>'}</td></tr>`).join('')}</tbody></table>`;
    };
    draw('');
    $('#db-search').addEventListener('input', (e) => draw(e.target.value.trim()));
  } catch (e) {
    $('#db-table').innerHTML = `<div class="err">${esc(e.message)}</div>`;
  }
}

// ------------------------------------------------------------------ routing
function route() {
  const page = (location.hash.replace('#', '').split('/')[0]) || 'overview';
  state.page = ['overview', 'behavior', 'survival', 'portfolio', 'database'].includes(page) ? page : 'overview';
  $$('.tabs a').forEach((a) => (a.dataset.page === state.page ? a.setAttribute('aria-current', 'page') : a.removeAttribute('aria-current')));
  $('#filters').hidden = !CHARTS[state.page];
  generation++;
  window.scrollTo(0, 0);
  if (CHARTS[state.page]) renderChartPage(state.page);
  else if (state.page === 'portfolio') renderPortfolio();
  else renderDatabase();
  document.title = `FARS 2024 · ${state.page[0].toUpperCase() + state.page.slice(1)}`;
}

async function init() {
  initFilters();
  try {
    META = await getJSON('/api/meta');
    $('#f-state').insertAdjacentHTML('beforeend', META.states.map((s) => `<option value="${s.code}">${esc(s.name)}</option>`).join(''));
    $('#conn').classList.add('ok');
    $('#conn-text').innerHTML = `Live · MySQL ${esc(META.version.split('-')[0])} · <code>${esc(META.database)}</code>`;
  } catch (e) {
    $('#conn').classList.add('bad');
    $('#conn-text').textContent = 'Database not reachable: check .env';
  }
  addEventListener('hashchange', () => { if (!location.hash.startsWith('#portfolio/') || state.page !== 'portfolio') route(); });
  route();
}
init();
