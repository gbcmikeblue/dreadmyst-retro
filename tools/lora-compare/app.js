'use strict';

/* ============================================================================
   LoRA 对比台 · 前端逻辑（纯 JS，无框架）

   它做的事：同一提示词 + 同一参数 + 同一 seed，逐个换 LoRA 出图，并排对比，
   人工评分后把结论落盘成 RESULTS.md —— 用于决定最终保留哪些 LoRA。

   后端是 ComfyUI（127.0.0.1:8188）。所有请求都走同源的 /comfy/*，
   由本目录的 serve.py 反代 —— 浏览器直连 8188 会被同源策略拦。
   ========================================================================== */

const COMFY = '/comfy';      // 后端：ComfyUI（Qwen-Image 2.1）
const F_PROMPTS = 'data/prompts.json';
const F_LORAS = 'data/loras.json';
const F_RESULTS = 'data/results.json';
const F_REPORT = 'RESULTS.md';
const NONE = '__none__';           // 「无 LoRA 基线」的哨兵值
const VERDICTS = ['', '保留', '待定', '淘汰'];

/* ------------------------------- 状态 ------------------------------- */
const S = {
  prompts: null,      // prompts.json 内容
  pristine: null,     // 开机时的副本，用于「复位」
  meta: {},           // loras.json 的 loras 字段（按名字索引）
  disk: [],           // ComfyUI 上真实存在的 LoRA 文件名（无扩展名）
  ckpts: [],          // { title, model_name }
  samplers: [],
  records: [],        // 对比记录
  tplId: null,
  sel: new Set([NONE]),
  busy: false,
  poll: null,
  saveTimer: null,
  // 以下三项是纯 UI 状态，存 localStorage（不进 results.json，免得污染决策数据）
  weights: {},        // LoRA -> 单独权重（没有该键 = 继承全局权重）
  recent: [],         // 最近生成过的 LoRA（用于排序）
  filter: { q: '', base: 'all', group: 'all', sort: 'group' },
};

const LS_KEY = 'loraCompare.ui.v1';

function loadUiState() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return;
    const o = JSON.parse(raw);
    if (o && typeof o === 'object') {
      S.weights = o.weights || {};
      S.recent = Array.isArray(o.recent) ? o.recent : [];
      S.filter = Object.assign(S.filter, o.filter || {});
    }
  } catch (_) { /* 忽略坏数据 */ }
}

function saveUiState() {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify({ weights: S.weights, recent: S.recent, filter: S.filter }));
  } catch (_) { /* 忽略 */ }
}

/* ------------------------------- 小工具 ------------------------------- */
const $ = (s, r = document) => r.querySelector(s);

function h(tag, attrs, ...kids) {
  const n = document.createElement(tag);
  if (attrs) for (const k in attrs) {
    if (k === 'class') n.className = attrs[k];
    else if (k === 'text') n.textContent = attrs[k];
    else if (k === 'html') n.innerHTML = attrs[k];
    else if (k.startsWith('on')) n.addEventListener(k.slice(2), attrs[k]);
    else if (attrs[k] === true) n.setAttribute(k, '');
    else if (attrs[k] !== false && attrs[k] != null) n.setAttribute(k, attrs[k]);
  }
  for (const kid of kids.flat()) {
    if (kid == null || kid === false) continue;
    n.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return n;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function req(url, opts = {}, timeout = 0) {
  const ctl = new AbortController();
  const timer = timeout ? setTimeout(() => ctl.abort(), timeout) : null;
  try {
    const res = await fetch(url, Object.assign({ cache: 'no-store', signal: ctl.signal }, opts));
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch (_) { /* 非 JSON */ }
    if (!res.ok) {
      const detail = (data && (data.error || data.detail || data.message)) || text.slice(0, 300) || res.statusText;
      throw new Error(`HTTP ${res.status} · ${detail}`);
    }
    return data === null ? text : data;
  } finally {
    if (timer) clearTimeout(timer);
  }
}
const get = (u, ms) => req(u, {}, ms);
const post = (u, body, ms) => req(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }, ms);
const del = (u, body) => req(u, { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

const saveText = (path, content) => post('/api/save', { path, content }, 30000);
const saveImage = (name, data) => post('/api/image', { name, data }, 120000);

/* ------------------------------- 复制到剪贴板 -------------------------------
   127.0.0.1 属于安全上下文，navigator.clipboard 可用；其余情况退回 execCommand。 */
async function copyText(text, btn) {
  const t = String(text == null ? '' : text);
  if (!t) return false;
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(t);
    } else {
      const ta = document.createElement('textarea');
      ta.value = t;
      ta.style.position = 'fixed';
      ta.style.top = '-1000px';
      document.body.append(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
    }
    if (btn) {
      const old = btn.textContent;
      btn.textContent = '已复制 ✓';
      btn.classList.add('copied');
      setTimeout(() => { btn.textContent = old; btn.classList.remove('copied'); }, 1500);
    }
    return true;
  } catch (e) {
    banner('warn', '复制失败（浏览器拒绝）：' + e.message + ' —— 可以手动选中复制。');
    return false;
  }
}

/** 生成一个「复制」按钮；getText 惰性求值，保证复制的是当时的内容 */
function copyBtn(getText, label) {
  const b = h('button', { type: 'button', class: 'mini', text: label || '复制' });
  b.addEventListener('click', (e) => {
    e.preventDefault();
    e.stopPropagation();
    copyText(getText(), b);
  });
  return b;
}

/* ------------------------------- LoRA 权重 ------------------------------- */
function hasOwnWeight(key) {
  return typeof S.weights[key] === 'number' && isFinite(S.weights[key]);
}
/** 该 LoRA 本批要用多少权重：单独设过就用它，否则跟随全局滑块 */
function weightOf(key) {
  if (key === NONE) return null;
  return hasOwnWeight(key) ? S.weights[key] : Number($('#lw').value);
}

/* ------------------------------- 横幅 / 状态灯 ------------------------------- */
function banner(kind, msg) {
  const b = $('#banner');
  if (!kind) { b.hidden = true; b.textContent = ''; return; }
  b.hidden = false;
  b.className = 'banner ' + kind;
  b.textContent = msg;
}
function pill(id, on) {
  const p = $('#' + id);
  p.classList.toggle('on', !!on);
  p.classList.toggle('off', !on);
}
const setStatus = (t) => { $('#gen-status').textContent = t || ''; };
const setBar = (v) => { $('#bar-fill').style.width = Math.round(Math.max(0, Math.min(1, v)) * 100) + '%'; };

/* ------------------------------- 工具函数 ------------------------------- */
const plain = (t) => String(t || '').replace(/\s*\[[0-9a-f]{7,}\]\s*$/i, '').trim();
// 只有 Qwen 一条线了（SD 系已整体弃用）；非 Qwen 底模一律标 other，用于文件名与筛选兜底
const baseOf = (t) => (/qwen/i.test(String(t || '')) ? 'Qwen-Image' : 'other');
const stamp = () => new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const slug = (s) => String(s || '').replace(/[^A-Za-z0-9_.-]/g, '_').slice(0, 60);

function currentTpl() {
  return (S.prompts.templates || []).find((t) => t.id === S.tplId) || null;
}
function metaOf(key) { return S.meta[key] || {}; }
function ckptBase() { return baseOf($('#ckpt').value); }
/** LoRA 是否可用在当前 checkpoint 上（base 必须一致） */
function compatible(key) {
  if (key === NONE) return true;
  return metaOf(key).base === ckptBase();
}

/* ============================================================================
   启动
   ========================================================================== */
async function boot() {
  loadUiState();               // 单条权重 / 最近使用 / 筛选条件（存 localStorage）
  if (location.protocol === 'file:') {
    banner('err', '不能直接双击 index.html 打开：这样既调不到本地服务（它负责反代 ComfyUI），也无法把结果写回磁盘。请双击 start.bat，用 http://127.0.0.1:7788/ 访问。');
    return;
  }
  try {
    await get('/api/ping', 6000);
    pill('pill-server', true);
  } catch (e) {
    banner('err', '本地服务没有响应：' + e.message + '（请双击 start.bat 启动）');
    return;
  }

  try {
    S.prompts = await get(F_PROMPTS);
    S.pristine = JSON.parse(JSON.stringify(S.prompts));
    const lm = await get(F_LORAS);
    S.meta = lm.loras || {};
  } catch (e) {
    banner('err', '读取 data/prompts.json 或 data/loras.json 失败：' + e.message);
    return;
  }

  // 对比记录是**本地文件**（已被 .gitignore 排除）：第一次用、或换了机器时它不存在是正常的，
  // 所以这里单独兜底 —— 缺了就当作空记录，第一次「保存记录」时会自动生成。
  try {
    const rs = await get(F_RESULTS);
    S.records = rs.records || [];
  } catch (_) {
    S.records = [];
  }

  renderTemplates();
  renderResults();
  renderSummary();
  renderReqs();
  await refreshComfy();
  $('#lora-search').value = S.filter.q || '';
  $('#lora-base-filter').value = S.filter.base || 'all';
  $('#lora-sort').value = S.filter.sort || 'group';
  renderLoRA();
  await refreshImages();
  bind();
  bindPages();                 // 页面 A/B 路由 + 项目总览（卡片在 renderProjects 里渲染）
  updatePreview();
  renderInspector();
}

/* ------------------------------- 读 ComfyUI -------------------------------
   可用模型 / 编码器 / VAE / LoRA / 采样器统一从 /object_info 的节点输入定义里取
   （不依赖任何自定义接口）。 */
async function refreshComfy() {
  let oi = null;
  try {
    oi = await get(COMFY + '/object_info', 90000);
    pill('pill-comfy', true);
  } catch (e) {
    S.disk = []; S.ckpts = []; S.samplers = [];
    pill('pill-comfy', false);
    banner('warn', '读不到 ComfyUI（127.0.0.1:8188）：' + e.message + '　→ 先启动它：双击 D:\\AI\\启动ComfyUI.bat');
    renderCkptCards();
    return;
  }
  const list = (node, field) => {
    try {
      const v = oi[node].input.required[field];
      return Array.isArray(v[0]) ? v[0].slice() : [];
    } catch (_) { return []; }
  };
  S.ckpts = list('UNETLoader', 'unet_name').map((n) => ({ title: n, model_name: n }));
  S.disk = list('LoraLoader', 'lora_name');
  S.aux = { clip: list('CLIPLoader', 'clip_name'), vae: list('VAELoader', 'vae_name') };
  // T-22：/object_info 按字母序把 int8_convrot 排在前，但本机已定 nvfp4（backlog T-19：热态打平、
  // 体积小 2.84 GiB）→ 把 nvfp4 提到首位，下面提交图与面包屑用的 `S.aux.clip[0]` 就自动指向它。
  // 找不到 nvfp4 时保持原顺序（退回 int8，不会炸）。
  S.aux.clip.sort((a, b) => Number(String(b).includes('nvfp4')) - Number(String(a).includes('nvfp4')));
  S.samplers = list('KSampler', 'sampler_name');
  const sched = list('KSampler', 'scheduler');
  S.scheduler = sched.includes('simple') ? 'simple' : (sched[0] || 'simple');
  $('#pill-model').textContent = S.ckpts.length ? baseOf(S.ckpts[0].title) : '—';

  const sel = $('#ckpt');
  sel.textContent = '';
  if (!S.ckpts.length) {
    sel.append(h('option', { value: '', text: '（ComfyUI 里没有可用 unet，请确认模型已放到 models-comfy/diffusion_models）' }));
  } else {
    for (const c of S.ckpts) sel.append(h('option', { value: c.title, text: `${c.title}  ·  ${baseOf(c.title)}` }));
  }

  const sp = $('#sampler');
  sp.textContent = '';
  for (const s of S.samplers) sp.append(h('option', { value: s, text: s }));
  if (S.samplers.includes('euler')) sp.value = 'euler';

  renderCkptCards();
  applyDefaults(false);
}

/* ------------------------------- 模板 ------------------------------- */
function renderTemplates() {
  const sel = $('#tpl-select');
  sel.textContent = '';
  for (const t of S.prompts.templates) sel.append(h('option', { value: t.id, text: `${t.id} · ${t.name}` }));
  S.tplId = (S.prompts.templates[0] || {}).id || null;
  if (S.tplId) sel.value = S.tplId;
  loadTplToEditor();
}

function loadTplToEditor() {
  const t = currentTpl();
  if (!t) return;
  $('#pos').value = t.positive || '';
  $('#neg').value = t.negative || '';
  $('#tpl-req').value = t.要求 || '';
  const img2img = t.阶段 === 'img2img';
  $('#tpl-stage').textContent = img2img ? '图生图（img2img）' : '文生图（txt2img）';
  $('#denoise-field').hidden = !img2img;
  $('#denoise').value = t.denoise != null ? t.denoise : 0.7;
  $('#denoise-out').textContent = Number($('#denoise').value).toFixed(2);
  renderBlocksPick();
  const sug = S.prompts.global.checkpointDefaults[t.base建议] || {};
  $('#tpl-meta').textContent = [t.用途, t.出图尺寸 && '尺寸 ' + t.出图尺寸, sug.label && ('建议 base ' + sug.label)].filter(Boolean).join(' · ');
  renderHistory();
  markDirty(false);
  if ($('#preview')) updatePreview();
  renderDetailSummary();       // 工作台顶部摘要跟着模板变
}

function markDirty(d) {
  $('#prompt-state').textContent = d ? '● 有未保存的修改' : '';
  $('#prompt-state').style.color = d ? 'var(--warn)' : '';
}

function renderHistory() {
  const t = currentTpl();
  const hist = (t && t.history) || [];
  $('#hist-count').textContent = hist.length;
  const ul = $('#prompt-history');
  ul.textContent = '';
  if (!hist.length) {
    ul.append(h('li', { text: '（还没有修改记录）' }));
    return;
  }
  hist.slice().reverse().forEach((v, i) => {
    ul.append(h('li', {},
      h('div', { class: 'when', text: `${v.at || '?'} · ${v.note || '无备注'}` }),
      h('div', { text: (v.positive || '').split('\n')[0].slice(0, 60) + '…' }),
      h('button', {
        class: 'mini', text: '回退到此版本',
        onclick: () => {
          $('#pos').value = v.positive || '';
          $('#neg').value = v.negative || '';
          $('#tpl-req').value = v.要求 || '';
          if (v.套用要求) {
            for (const cb of $$('#blocks-pick input[type="checkbox"]')) cb.checked = v.套用要求.includes(cb.value);
          }
          if (v.denoise != null) { $('#denoise').value = v.denoise; $('#denoise-out').textContent = Number(v.denoise).toFixed(2); }
          markDirty(true);
          updatePreview();
          banner('info', '已把该历史版本填回编辑器，点「保存本模板」才会真正生效。');
        },
      })));
  });
}

/* ------------------------------- 参数 ------------------------------- */
function applyDefaults(resetSeed) {
  const t = currentTpl();
  const live = (S.prompts.global.checkpointDefaults[baseOf($('#ckpt').value)]) || {};
  const sug = (t && S.prompts.global.checkpointDefaults[t.base建议]) || {};
  // ⚠️ 以**实际在跑的底模**的默认值为准：模板建议与实际底模不一致时听底模的 ——
  // steps/cfg 配错在 Qwen 上直接出废图（挂 Turbo LoRA 时 cfg>1 会崩）。
  const def = Object.keys(live).length ? live : sug;
  // 模板级覆盖：模板自己声明了 `默认尺寸` 就听模板的（例：A4 一图流需要 1536² 才画得清 4 格）。
  // 放在底模默认值之后 → 换底模不会把 A4 的尺寸冲掉。
  const tplSize = (t && t.默认尺寸) || {};
  $('#w').value = tplSize.width || def.width || sug.width || 512;
  $('#h').value = tplSize.height || def.height || sug.height || 512;
  $('#steps').value = def.steps || sug.steps || 25;
  $('#cfg').value = def.cfg || sug.cfg || 7;
  if (resetSeed !== false && !$('#seed').value) $('#seed').value = -1;
  renderDetailSummary();
}

function readParams() {
  return {
    ckpt: $('#ckpt').value,
    w: Number($('#w').value) || 512,
    h: Number($('#h').value) || 512,
    steps: Number($('#steps').value) || 25,
    cfg: Number($('#cfg').value) || 7,
    sampler: $('#sampler').value,
    seed: Number($('#seed').value),
    weight: Number($('#lw').value),
  };
}

/* ------------------------------- LoRA 列表 / 选择器 ------------------------------- */
function loraKeys() {
  const keys = [], seen = new Set();
  for (const n of S.disk) if (!seen.has(n)) { seen.add(n); keys.push(n); }
  for (const n of Object.keys(S.meta)) if (!seen.has(n)) { seen.add(n); keys.push(n); }
  return keys;
}

/** 分组只认 loras.json 里登记的「分组」字段（SD 时代那套按 sd15_/sdxl_ 前缀推断的规则已删除） */
function groupOf(key) {
  return metaOf(key).分组 || '其他';
}

/** 该 LoRA 现在能不能选：在磁盘上 + base 兼容（或显式允许跨 base） */
function loraEnabled(key) {
  return S.disk.includes(key) && (compatible(key) || $('#force-base').checked);
}

/** 已选 tray：本批到底要测哪些、各自权重多少 */
function renderTray() {
  const ul = $('#lora-tray');
  ul.textContent = '';
  const keys = Array.from(S.sel);
  if (!keys.length) { ul.append(h('li', { class: 'tray-item', text: '（未选）' })); return; }
  keys.sort((a, b) => (a === NONE ? -1 : b === NONE ? 1 : a.localeCompare(b)));
  for (const k of keys) {
    const own = hasOwnWeight(k);
    ul.append(h('li', { class: 'tray-item' + (k === NONE ? ' base' : '') },
      k === NONE ? '（基线）' : k,
      k !== NONE ? h('span', {
        class: 'w', text: (own ? '★' : '') + weightOf(k).toFixed(2),
        title: own ? '单独权重（不跟随全局）' : '跟随全局权重',
      }) : null,
      h('button', {
        type: 'button', class: 'x', text: '✕', title: '从本批移除',
        onclick: () => { S.sel.delete(k); renderLoRA(); updatePreview(); renderInspector(); },
      })));
  }
}

function updateLoraCount() {
  const n = Array.from(S.sel).filter((k) => k === NONE || loraEnabled(k)).length;
  $('#lora-count').textContent = `已选 ${n} 项（含基线）`;
}

function baselineRow() {
  const cb = h('input', { type: 'checkbox', value: NONE });
  cb.checked = S.sel.has(NONE);
  cb.addEventListener('change', () => {
    if (cb.checked) S.sel.add(NONE); else S.sel.delete(NONE);
    renderTray(); updateLoraCount(); updatePreview(); renderInspector();
  });
  return h('li', { class: 'lora-item' },
    h('label', {}, cb,
      h('div', { class: 'grow' },
        h('div', { class: 'lora-name' }, '（无 LoRA 基线）', h('span', { class: 'tag ok', text: '对照组' })),
        h('div', { class: 'lora-sub', text: '不加任何 LoRA。没有它就判断不出「加 LoRA 到底有没有变好」' }))));
}

function loraRow(key) {
  const m = metaOf(key);
  const ok = loraEnabled(key);
  const cb = h('input', { type: 'checkbox', value: key });
  cb.checked = S.sel.has(key);
  cb.disabled = !ok;
  cb.addEventListener('change', () => {
    if (cb.checked) S.sel.add(key); else S.sel.delete(key);
    renderTray(); updateLoraCount(); updatePreview(); renderInspector();
  });

  const tags = [{ text: m.base || 'base 未知', k: m.base ? '' : 'warn' }];
  if (!S.disk.includes(key)) tags.push({ text: m.状态 || '未部署', k: 'bad' });
  if (m.署名) tags.push({ text: '须署名', k: 'warn' });
  if (S.disk.includes(key) && !compatible(key)) tags.push({ text: 'base 不兼容', k: 'bad' });

  const nameEl = h('span', { title: '点一下复制名字' }, key);
  nameEl.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); copyText(key, null); });
  const triggerEl = m.触发词 ? h('div', { class: 'lora-sub', title: '点一下复制触发词', text: '触发词 ' + m.触发词 }) : null;
  if (triggerEl) triggerEl.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); copyText(m.触发词, null); });

  const wrap = h('div', { class: 'perw' + (hasOwnWeight(key) ? ' on' : ''), title: '单独权重（默认跟随全局；改了会标黄）' });
  const wIn = h('input', { type: 'number', min: '0', max: '1.5', step: '0.05', value: weightOf(key).toFixed(2) });
  wIn.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); });
  wIn.addEventListener('input', () => {
    const v = Number(wIn.value);
    if (isFinite(v) && v >= 0) S.weights[key] = v; else delete S.weights[key];
    wrap.classList.toggle('on', hasOwnWeight(key));
    saveUiState();
    renderTray(); updatePreview(); renderInspector();
  });
  const reset = h('button', { type: 'button', class: 'reset', text: '↺', title: '恢复跟随全局权重' });
  reset.addEventListener('click', (e) => {
    e.preventDefault(); e.stopPropagation();
    delete S.weights[key];
    wIn.value = weightOf(key).toFixed(2);
    wrap.classList.remove('on');
    saveUiState();
    renderTray(); updatePreview(); renderInspector();
  });
  wrap.append(wIn, reset);

  return h('li', { class: 'lora-item' + (ok ? '' : ' bad') },
    h('label', {}, cb,
      h('div', { class: 'grow' },
        h('div', { class: 'lora-name' }, nameEl, ...tags.map((t) => h('span', { class: 'tag ' + (t.k || ''), text: t.text }))),
        h('div', { class: 'lora-sub', text: m.用途 || '(loras.json 里没有元数据)' }),
        triggerEl),
      wrap));
}

function renderLoRA() {
  const all = loraKeys();

  // 分组下拉（选项跟着数据变）
  const gf = $('#lora-group-filter');
  const groups = [...new Set(all.map(groupOf))].sort();
  const keepG = gf.value || 'all';
  gf.textContent = '';
  gf.append(h('option', { value: 'all', text: '分组: 全部' }));
  for (const g of groups) gf.append(h('option', { value: g, text: '分组: ' + g }));
  gf.value = groups.includes(keepG) ? keepG : 'all';

  // 过滤
  const f = S.filter;
  f.group = gf.value;
  let list = all.slice();
  if (f.q) {
    const q = f.q.toLowerCase();
    list = list.filter((k) => {
      const m = metaOf(k);
      return (k + ' ' + (m.用途 || '') + ' ' + (m.触发词 || '')).toLowerCase().includes(q);
    });
  }
  if (f.base === 'ok') list = list.filter(loraEnabled);
  else if (f.base !== 'all') list = list.filter((k) => metaOf(k).base === f.base);
  if (f.group !== 'all') list = list.filter((k) => groupOf(k) === f.group);

  // 排序
  const cmpName = (a, b) => a.localeCompare(b);
  if (f.sort === 'name') list.sort(cmpName);
  else if (f.sort === 'base') list.sort((a, b) => String(metaOf(a).base).localeCompare(String(metaOf(b).base)) || cmpName(a, b));
  else if (f.sort === 'recent') list.sort((a, b) => (S.recent.indexOf(b) - S.recent.indexOf(a)) || cmpName(a, b));
  else list.sort((a, b) => groupOf(a).localeCompare(groupOf(b)) || cmpName(a, b));

  // 已经是「不能选」的从本批剔掉
  for (const k of Array.from(S.sel)) if (k !== NONE && !loraEnabled(k)) S.sel.delete(k);

  // 渲染
  const ul = $('#lora-list');
  ul.textContent = '';
  ul.append(baselineRow());
  let last = null;
  for (const key of list) {
    const g = groupOf(key);
    if (f.sort === 'group' && g !== last) { ul.append(h('li', { class: 'lora-group', text: g })); last = g; }
    ul.append(loraRow(key));
  }
  if (!list.length) ul.append(h('li', { class: 'lora-group', text: '（没有符合筛选条件的 LoRA）' }));

  $('#picker-count').textContent = `筛选出 ${list.length} / 共 ${all.length}`;
  $('#lora-sort').value = f.sort;
  renderTray();
  updateLoraCount();
  renderDetailSummary();       // 勾选/取消 LoRA 后，工作台顶部摘要同步
}

/* ------------------------------- Checkpoint 卡片 ------------------------------- */
function renderCkptCards() {
  const box = $('#ckpt-cards');
  box.textContent = '';
  const cur = $('#ckpt').value;
  if (!S.ckpts.length) {
    box.append(h('div', { class: 'hint', text: '（读不到 unet —— ComfyUI 没启动，或 D:\\AI\\models-comfy\\diffusion_models 是空的）' }));
    $('#ckpt-note').textContent = '';
    return;
  }
  for (const c of S.ckpts) {
    const card = h('div', { class: 'ckpt-card' + (c.title === cur ? ' sel' : ''), title: c.title },
      h('span', { class: 'dot' }),
      h('span', { class: 'nm', text: plain(c.title) }),
      h('span', { class: 'tag', text: baseOf(c.title) }));
    card.addEventListener('click', () => {
      $('#ckpt').value = c.title;
      $('#ckpt').dispatchEvent(new Event('change'));
      renderCkptCards();
    });
    box.append(card);
  }
  $('#ckpt-note').textContent = cur ? '当前：' + baseOf(cur) : '';
}

function selectableKeys() {
  return Array.from(S.sel).filter((k) => k === NONE || (S.disk.includes(k) && (compatible(k) || $('#force-base').checked)));
}

/* ------------------------------- 提示词拼装 -------------------------------
   三层：全局「要求块」（按类型自动分正向/负向）+ 模板（勾选用哪些块 + 自己的要求/正负向）。
   拼装顺序见 prompts.json 的 global.组装顺序；界面上有实时预览。            */
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

/** 全局要求块：key -> { 名称, 类型, 用途, 文本 } */
function blockDefs() {
  return (S.prompts && S.prompts.global && S.prompts.global['要求块']) || {};
}

/** 编辑器里的当前模板 —— 生成用编辑器内容（WYSIWYG），不必先保存 */
function editorTpl() {
  const t = currentTpl() || {};
  const boxes = $$('#blocks-pick input[type="checkbox"]');
  const use = boxes.length
    ? boxes.filter((cb) => cb.checked).map((cb) => cb.value)
    : (t.套用要求 || []);
  return {
    id: t.id,
    name: t.name,
    阶段: t.阶段 || 'txt2img',
    套用要求: use,
    要求: $('#tpl-req').value,
    positive: $('#pos').value,
    negative: $('#neg').value,
    denoise: Number($('#denoise').value),
  };
}

function joinPrompt(parts) {
  // 分段 → 去重（不区分大小写、保留首次出现顺序）→ 重新拼接。
  // 要求与模板之间很容易撞词（watermark、text、centered…），去重能省 prompt 预算。
  const seen = new Set();
  const out = [];
  for (const p of parts) {
    if (!p) continue;
    for (const piece of String(p).split(/[,，]+/)) {
      const w = piece.trim().replace(/\s+/g, ' ');
      if (!w) continue;
      const k = w.toLowerCase();
      if (seen.has(k)) continue;
      seen.add(k);
      out.push(w);
    }
  }
  return out.join(', ');
}

/** 取模板勾选的要求块里，属于 type（正向/负向）的文本 */
function blocksOf(tpl, type) {
  const defs = blockDefs();
  return (tpl.套用要求 || [])
    .map((k) => defs[k])
    .filter((b) => b && b.类型 === type)
    .map((b) => b.文本);
}

function positiveFor(key, tpl) {
  const parts = [];
  if (key !== NONE) {
    const m = metaOf(key);
    parts.push(`<lora:${key}:${weightOf(key).toFixed(2)}>`);
    if ($('#inject-trigger').checked && m.触发词) parts.push(m.触发词);
  }
  parts.push(...blocksOf(tpl, '正向'), tpl.要求, tpl.positive);
  return joinPrompt(parts);
}

function negativeFor(tpl) {
  return joinPrompt([...blocksOf(tpl, '负向'), tpl.negative]);
}

/* 要求面板：读取 / 保存 / 历史 / 预览 */
function reqValuesFromForm() {
  const blocks = {};
  for (const key of Object.keys(blockDefs())) {
    const el = $('#blk-' + key);
    if (el) blocks[key] = el.value.trim();
  }
  return {
    要求块: blocks,
    其他规范: $('#g-rules').value.split('\n').map((s) => s.trim()).filter(Boolean),
  };
}

/** 支持两种形状：{要求块:{key:"文本"}} 或 {要求块:{key:{...,文本}}} */
function fillReqForm(g) {
  const blocks = (g && g['要求块']) || {};
  for (const key of Object.keys(blockDefs())) {
    const el = $('#blk-' + key);
    if (!el) continue;
    const v = blocks[key];
    el.value = typeof v === 'string' ? v : ((v && v.文本) || '');
  }
  $('#g-rules').value = ((g && g['其他规范']) || []).join('\n');
}

/** 【模板】页签里的「套用哪些要求块」勾选 */
function renderBlocksPick() {
  const box = $('#blocks-pick');
  if (!box) return;
  const use = (currentTpl() || {}).套用要求 || [];
  box.textContent = '';
  for (const [key, b] of Object.entries(blockDefs())) {
    const cb = h('input', { type: 'checkbox', value: key });
    cb.checked = use.includes(key);
    cb.addEventListener('change', () => { markDirty(true); updatePreview(); });
    box.append(h('label', { class: 'check' },
      cb,
      h('span', { class: 'tag ' + (b.类型 === '负向' ? 'bad' : 'ok'), text: b.类型 }),
      (b.名称 || key)));
  }
}

function renderReqs() {
  const box = $('#blocks-edit');
  box.textContent = '';
  for (const [key, b] of Object.entries(blockDefs())) {
    const id = 'blk-' + key;
    box.append(h('label', { class: 'field' },
      h('span', {},
        h('b', { text: b.名称 || key }),
        h('span', { class: 'tag ' + (b.类型 === '负向' ? 'bad' : 'ok'), text: b.类型 }),
        b.用途 ? ' ' + b.用途 : ''),
      h('textarea', { id, rows: 3, spellcheck: 'false' })));
    $('#' + id).addEventListener('input', () => {
      $('#req-state').textContent = '● 有未保存的修改';
      updatePreview();
    });
  }
  fillReqForm(S.prompts.global || {});
  renderReqHistory();
  renderBlocksPick();
  $('#req-state').textContent = '';
  updatePreview();
}

function renderReqHistory() {
  const hist = (S.prompts.global && S.prompts.global.history) || [];
  $('#req-hist-count').textContent = hist.length;
  const ul = $('#req-history');
  ul.textContent = '';
  if (!hist.length) {
    ul.append(h('li', { text: '（还没有修改记录）' }));
    return;
  }
  hist.slice().reverse().forEach((v) => {
    ul.append(h('li', {},
      h('div', { class: 'when', text: `${v.at || '?'} · ${v.note || '无备注'}` }),
      h('div', { text: '要求块：' + Object.keys(((v.snapshot || {})['要求块']) || {}).join(', ').slice(0, 70) }),
      h('button', {
        class: 'mini', text: '回退到此版本',
        onclick: () => {
          fillReqForm(v.snapshot || {});
          $('#req-state').textContent = '已填入历史版本，点「保存要求」才生效';
          updatePreview();
        },
      })));
  });
}

async function saveReqs() {
  const g = S.prompts.global;
  const form = reqValuesFromForm();
  const oldBlocks = g['要求块'] || {};
  const newBlocks = {};
  for (const key of Object.keys(form.要求块)) {
    const old = oldBlocks[key] || {};
    newBlocks[key] = {
      名称: old.名称 || key,
      类型: old.类型 || '正向',
      用途: old.用途 || '',
      文本: form.要求块[key],
    };
  }
  const changed =
    JSON.stringify(newBlocks) !== JSON.stringify(oldBlocks) ||
    JSON.stringify(form['其他规范']) !== JSON.stringify(g['其他规范'] || []);
  if (!changed) { banner('info', '要求没有变化，无需保存。'); return; }

  g.history = g.history || [];
  g.history.push({
    at: new Date().toISOString().replace('T', ' ').slice(0, 19),
    note: '人工编辑要求',
    snapshot: { 要求块: JSON.parse(JSON.stringify(oldBlocks)), 其他规范: JSON.parse(JSON.stringify(g['其他规范'] || [])) },
  });
  g['要求块'] = newBlocks;
  g['其他规范'] = form['其他规范'];
  S.prompts.updated = new Date().toISOString().slice(0, 10);
  try {
    await saveText(F_PROMPTS, JSON.stringify(S.prompts, null, 2));
    S.pristine = JSON.parse(JSON.stringify(S.prompts));
    renderReqHistory();
    renderBlocksPick();
    $('#req-state').textContent = '已保存';
    updatePreview();
    banner('info', '要求已保存到 data/prompts.json（旧版压入历史，可回退）。');
  } catch (e) {
    banner('err', '要求保存失败：' + e.message);
  }
}

function switchPane(name) {
  for (const b of $$('.tab')) b.classList.toggle('active', b.dataset.pane === name);
  $('#pane-tpl').hidden = name !== 'tpl';
  $('#pane-req').hidden = name !== 'req';
}

/** 实时预览：改任何一处（模板 / 要求 / 权重 / 触发词 / 勾选）都会立刻反映 */
function updatePreview() {
  const box = $('#preview');
  if (!box || !S.prompts) return;
  const tpl = editorTpl();
  const targets = Array.from(S.sel);
  const key = targets.length ? targets[0] : NONE;
  const add = (k, v) => {
    box.append(h('b', { text: k + '：' }));
    box.append(document.createTextNode((v || '（空）') + '\n\n'));
  };
  box.textContent = '';
  const defs = blockDefs();
  const usedNames = (tpl.套用要求 || []).map((k) => (defs[k] && defs[k].名称) || k);
  add('模板', `${tpl.id || '?'} · ${tpl.name || '?'}`);
  add('阶段', tpl.阶段 === 'img2img'
    ? `图生图（denoise ${Number(tpl.denoise).toFixed(2)}，底图：${$('#init-img').value || '⚠️ 未选！'}）`
    : '文生图');
  add('套用的要求块', usedNames.length ? usedNames.join(' + ') : '（无）');
  add('预览用的对比对象', key === NONE ? '（无 LoRA 基线）' : key);
  add('正向提示词', positiveFor(key, tpl));
  add('负向提示词', negativeFor(tpl));
  if (targets.length > 1) {
    box.append(h('span', { class: 'hint', text: `已选 ${targets.length} 项：其余只是把 <lora:…> 与触发词换掉，其它完全相同。` }));
  }
  renderInspector();          // 预览与检查面板永远同步
}

/* ------------------------------- 提示词检查 -------------------------------
   把最终提示词按逗号切成 chip，并标注每个词来自哪个块 —— 排查"怪词从哪来"的关键。
   这里**故意不去重**（拼装时才去重），所以能看见重复与冲突。                 */
function promptParts(key, tpl, type) {
  const parts = [];
  const push = (text, src, kind) => {
    for (const piece of String(text || '').split(/[,，]+/)) {
      const w = piece.trim().replace(/\s+/g, ' ');
      if (w) parts.push({ tag: w, src, kind });
    }
  };
  const defs = blockDefs();
  if (type === '正向') {
    if (key !== NONE) {
      const m = metaOf(key);
      push(`<lora:${key}:${weightOf(key).toFixed(2)}>`, 'LoRA', 'lora');
      if ($('#inject-trigger').checked && m.触发词) push(m.触发词, '触发词', 'trigger');
    }
    for (const k of (tpl.套用要求 || [])) {
      const b = defs[k];
      if (b && b.类型 === '正向') push(b.文本, b.名称 || k, 'block');
    }
    push(tpl.要求, '模板·要求', 'tplreq');
    push(tpl.positive, '模板·正向', 'tplpos');
  } else {
    for (const k of (tpl.套用要求 || [])) {
      const b = defs[k];
      if (b && b.类型 === '负向') push(b.文本, b.名称 || k, 'blockneg');
    }
    push(tpl.negative, '模板·负向', 'tplneg');
  }
  return parts;
}

const CONFLICT_PAIRS = [
  ['top-down', 'three-quarter', '视角冲突：既要正俯视又要 3/4 视角'],
  ["top-down", "bird's eye", '视角冲突：两个词都在描述俯视'],
  ['front view', 'high-angle', '视角冲突：正面平视与高角度俯视'],
  ['pixel art', 'painted', '风格冲突：像素风与手绘'],
  ['pixel art', 'painterly', '风格冲突：像素风与厚涂'],
  ['close-up', 'full body', '取景冲突：特写与全身'],
];
const NEG_ONLY_WORDS = ['pixel art', 'watermark', 'blurry', 'signature', 'deformed', 'ugly'];

function findConflicts(posChips, negChips) {
  const out = [];
  const posText = posChips.map((c) => c.tag.toLowerCase()).join(' | ');
  for (const [a, b, msg] of CONFLICT_PAIRS) {
    if (posText.includes(a) && posText.includes(b)) out.push(`${msg}（正向里同时有 \`${a}\` 与 \`${b}\`）`);
  }
  const posSet = new Set(posChips.map((c) => c.tag.toLowerCase()));
  for (const c of negChips) {
    if (posSet.has(c.tag.toLowerCase())) out.push(`\`${c.tag}\` 同时出现在正向和负向 —— 负向会被正向压掉，建议二选一`);
  }
  for (const w of NEG_ONLY_WORDS) {
    if (posText.includes(w)) out.push(`正向里出现了本该在负向的词 \`${w}\``);
  }
  const seen = {};
  for (const c of posChips) {
    const t = c.tag.toLowerCase();
    seen[t] = (seen[t] || 0) + 1;
  }
  for (const [t, n] of Object.entries(seen)) {
    if (n > 1) out.push(`正向里 \`${t}\` 出现了 ${n} 次 —— 拼装时会自动去重，但建议从来源块里删掉一处`);
  }
  return [...new Set(out)].slice(0, 12);
}

function renderChips(boxId, parts) {
  const box = $('#' + boxId);
  box.textContent = '';
  if (!parts.length) { box.append(h('span', { class: 'hint', text: '（空）' })); return; }
  const counts = {};
  for (const p of parts) counts[p.tag.toLowerCase()] = (counts[p.tag.toLowerCase()] || 0) + 1;
  for (const p of parts) {
    const dup = counts[p.tag.toLowerCase()] > 1;
    const chip = h('span', {
      class: 'chip s-' + p.kind,
      title: `来源：${p.src}${dup ? '（重复出现）' : ''}\n点一下复制这一个词`,
    }, h('span', { class: 'src', text: p.src.slice(0, 4) }), p.tag);
    chip.addEventListener('click', () => copyText(p.tag, null));
    box.append(chip);
  }
}

function renderInspector() {
  if (!S.prompts) return;
  const tpl = editorTpl();
  const targets = Array.from(S.sel);
  const key = targets.length ? targets[0] : NONE;
  const pos = promptParts(key, tpl, '正向');
  const neg = promptParts(key, tpl, '负向');
  renderChips('inspect-pos', pos);
  renderChips('inspect-neg', neg);
  const words = pos.reduce((n, p) => n + p.tag.split(/\s+/).length, 0);
  $('#inspect-stat').textContent = `正向 ${pos.length} 段 / ${words} 词 · 负向 ${neg.length} 段 · ${key === NONE ? '基线' : key}`;

  const box = $('#inspect-conflict');
  const list = findConflicts(pos, neg);
  box.textContent = '';
  if (!list.length) { box.hidden = true; return; }
  box.hidden = false;
  box.append(h('div', { text: `⚠️ 发现 ${list.length} 处值得看一眼的地方（不一定错）：` }));
  const ul = h('ul', {});
  for (const t of list) ul.append(h('li', { text: t }));
  box.append(ul);
}

/** 复制整段时用的文本 —— 与真实发出去的一致（含自动去重） */
function finalPromptText(kind) {
  const tpl = editorTpl();
  const targets = Array.from(S.sel);
  const key = targets.length ? targets[0] : NONE;
  return kind === 'neg' ? negativeFor(tpl) : positiveFor(key, tpl);
}

async function switchCheckpoint(title) {
  // ComfyUI 不需要「切换模型」：模型在每次提交的图里指定 —— 这里只更新状态灯。
  $('#pill-model').textContent = title ? baseOf(title) : '—';
}

function startPoll() {
  stopPoll();
  S.poll = setInterval(async () => {
    try {
      const q = await get(COMFY + '/queue', 6000);
      const run = (q.queue_running || []).length;
      const pend = (q.queue_pending || []).length;
      setStatus(`ComfyUI：运行中 ${run} · 排队 ${pend}`);
    } catch (_) { /* 忽略 */ }
  }, 1000);
}
function stopPoll() { if (S.poll) { clearInterval(S.poll); S.poll = null; } }

/* ------------------------------- ComfyUI 提交 / 等待 / 取图 -------------------------------
   图结构对照 ComfyUI 官方模板 image_qwen_image.json 的子图「Text to Image (Qwen-Image)」：
     UNETLoader → ModelSamplingAuraFlow(shift 3.1) → [LoraLoaderModelOnly] → KSampler
     CLIPLoader(type=qwen_image) → CLIPTextEncode ×2 ；EmptySD3LatentImage → VAEDecode → SaveImage
   要点：cfg 默认 1（官方口径）；若挂了 Turbo LoRA 必须 cfg=1，否则画面会崩。 */
function comfyGraph({ key, prompt, negText, cfg, seed }) {
  const g = {
    1: { class_type: 'UNETLoader', inputs: { unet_name: plain(cfg.ckpt), weight_dtype: 'default' } },
    2: { class_type: 'ModelSamplingAuraFlow', inputs: { model: ['1', 0], shift: 3.1 } },
    4: { class_type: 'CLIPLoader', inputs: { clip_name: (S.aux && S.aux.clip[0]) || '', type: 'qwen_image' } },
    5: { class_type: 'CLIPTextEncode', inputs: { clip: ['4', 0], text: prompt } },
    6: { class_type: 'CLIPTextEncode', inputs: { clip: ['4', 0], text: negText } },
    7: { class_type: 'EmptySD3LatentImage', inputs: { width: cfg.w, height: cfg.h, batch_size: 1 } },
    9: { class_type: 'VAELoader', inputs: { vae_name: (S.aux && S.aux.vae[0]) || '' } },
    10: { class_type: 'VAEDecode', inputs: { samples: ['8', 0], vae: ['9', 0] } },
    11: { class_type: 'SaveImage', inputs: { images: ['10', 0], filename_prefix: 'lora-compare' } },
  };
  const useLora = key !== NONE && S.disk.includes(key);
  if (useLora) {
    // 用节点挂 LoRA（不靠提示词里的 <lora:...> 语法，避免名字写错直接报错）
    g[3] = { class_type: 'LoraLoaderModelOnly',
             inputs: { model: ['2', 0], lora_name: key, strength_model: weightOf(key) } };
  }
  g[8] = { class_type: 'KSampler',
           inputs: { model: useLora ? ['3', 0] : ['2', 0], positive: ['5', 0], negative: ['6', 0],
                     latent_image: ['7', 0], seed: seed, steps: cfg.steps, cfg: cfg.cfg,
                     sampler_name: cfg.sampler, scheduler: S.scheduler || 'simple', denoise: 1.0 } };
  return g;
}

/** 轮询 /history 直到出图；把 ComfyUI 的执行错误抛出来（否则只会看到"超时"） */
async function waitComfy(pid, timeoutMs = 1800000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    await sleep(2500);
    let h = null;
    try { h = await get(COMFY + '/history/' + pid, 20000); } catch (_) { continue; }
    const e = h && h[pid];
    if (!e) continue;
    const st = ((e.status || {}).status_str) || '';
    if (st === 'error') {
      const msg = JSON.stringify((e.status && e.status.messages) || {}).slice(0, 600);
      throw new Error('ComfyUI 执行失败：' + msg);
    }
    const outs = [];
    for (const nid of Object.keys(e.outputs || {})) {
      for (const im of (e.outputs[nid].images || [])) outs.push(im);
    }
    if (outs.length) return outs;
  }
  throw new Error('ComfyUI 超过 ' + Math.round(timeoutMs / 1000) + ' 秒未完成');
}

/** 经 /comfy/view 取图 → 裸 base64（给 /api/image 落盘用） */
async function fetchComfyImage(im) {
  const q = '?filename=' + encodeURIComponent(im.filename)
    + '&subfolder=' + encodeURIComponent(im.subfolder || '')
    + '&type=' + encodeURIComponent(im.type || 'output');
  const res = await fetch(COMFY + '/view' + q, { cache: 'no-store' });
  if (!res.ok) throw new Error('取图失败 HTTP ' + res.status);
  const blob = await res.blob();
  return await new Promise((resolve, reject) => {
    const fr = new FileReader();
    fr.onload = () => resolve(String(fr.result).split(',')[1] || '');
    fr.onerror = () => reject(new Error('读图失败'));
    fr.readAsDataURL(blob);
  });
}

/* ------------------------------- 图生图辅助 ------------------------------- */
/** 从本机服务读一张图，转成裸 base64（图生图底图 / 上传给 ComfyUI 都用这个格式） */
async function loadImageB64(url) {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error('HTTP ' + res.status + ' ' + url);
  const blob = await res.blob();
  return await new Promise((resolve, reject) => {
    const fr = new FileReader();
    fr.onload = () => resolve(String(fr.result).split(',')[1]);
    fr.onerror = reject;
    fr.readAsDataURL(blob);
  });
}

/** 读图片像素尺寸（图生图要让 w/h 跟随底图） */
function imageSize(url) {
  return new Promise((resolve) => {
    const im = new Image();
    im.onload = () => resolve([im.naturalWidth, im.naturalHeight]);
    im.onerror = () => resolve(null);
    im.src = url;
  });
}

/** 选/换底图：自动把宽高设成底图的尺寸 */
async function setInitImage(name) {
  const sel = $('#init-img');
  if (name && !Array.from(sel.options).some((o) => o.value === name)) {
    sel.append(h('option', { value: name, text: name }));
  }
  sel.value = name || '';
  if (name) {
    const size = await imageSize('images/' + name);
    if (size) { $('#w').value = size[0]; $('#h').value = size[1]; }
    const t = currentTpl();
    if (t && t.阶段 !== 'img2img') {
      banner('info', `已把 ${name} 设为底图（宽高已跟随 ${size ? size[0] + '×' + size[1] : '底图'}）。要跑图生图，请把模板切到 A2「视角转换」。`);
    }
  }
  updatePreview();
}

async function refreshImages() {
  try {
    const r = await get('/api/list?dir=images');
    const sel = $('#init-img');
    const cur = sel.value;
    sel.textContent = '';
    sel.append(h('option', { value: '', text: '（未选）' }));
    for (const f of r.files) {
      sel.append(h('option', { value: f.name, text: `${f.name}  (${Math.round(f.bytes / 1024)}KB)` }));
    }
    if (cur) sel.value = cur;
  } catch (_) { /* 忽略 */ }
}

async function uploadInit(ev) {
  const file = ev.target.files && ev.target.files[0];
  if (!file) return;
  try {
    const b64 = await new Promise((resolve, reject) => {
      const fr = new FileReader();
      fr.onload = () => resolve(String(fr.result).split(',')[1]);
      fr.onerror = reject;
      fr.readAsDataURL(file);
    });
    const name = 'uploaded__' + stamp() + '__' + slug(file.name.replace(/\.[^.]+$/, '')) + '.png';
    await saveImage(name, b64);
    await refreshImages();
    await setInitImage(name);
    banner('info', '已上传并设为底图：' + name);
  } catch (e) {
    banner('err', '上传底图失败：' + e.message);
  } finally {
    ev.target.value = '';
  }
}

async function generate() {
  if (S.busy) return;
  const tpl = currentTpl();
  if (!tpl) return;

  const targets = selectableKeys();
  if (!targets.length) { banner('warn', '至少要勾选一个对比对象。'); return; }

  const cfg = readParams();
  if (!cfg.ckpt) { banner('err', '没读到模型列表：先启动 ComfyUI，再点「重读 LoRA 列表」。'); return; }

  let seed = Number.isFinite(cfg.seed) && cfg.seed >= 0 ? cfg.seed : Math.floor(Math.random() * 2147483647);
  $('#seed').value = seed;   // 锁进界面：本批共用同一个 seed 家族，保证"只换了 LoRA"

  const ed0 = editorTpl();
  const img2img = false;   // ⚠️ Qwen 的图生图还没接进这个工具 → 一律按文生图走（模板 A2 只能测「同提示词不加底图」）
  const repeat = Math.max(1, Math.min(6, Number($('#repeat').value) || 1));
  let initName = '', initB64 = null;
  if (img2img) {
    initName = $('#init-img').value;
    if (!initName) {
      banner('err', '这是图生图模板，但没选底图：先在参数区选一张（或点结果卡片上的「设为底图」）。');
      return;
    }
    try {
      initB64 = await loadImageB64('images/' + initName);
    } catch (e) {
      banner('err', '读不到底图：' + e.message);
      return;
    }
  }
  const total = targets.length * repeat;

  S.busy = true;
  $('#btn-gen').disabled = true;
  banner('info', `开始 ${total} 张（${targets.length} 项 × 每项 ${repeat} 张）· ${img2img ? '图生图 denoise ' + ed0.denoise.toFixed(2) + ' · 底图 ' + initName : '文生图'} · checkpoint = ${plain(cfg.ckpt)} · seed ${seed}${repeat > 1 ? '…' + (seed + repeat - 1) : ''} · ${cfg.w}x${cfg.h} · steps ${cfg.steps} · CFG ${cfg.cfg}`);
  setBar(0);

  const created = [];
  let done = 0;
  try {
    await switchCheckpoint(cfg.ckpt);
    for (const key of targets) {
      for (let r = 0; r < repeat; r++) {
        done++;
        const label = (key === NONE ? '（基线）' : key) + (repeat > 1 ? ` #${r + 1}` : '');
        setStatus(`第 ${done}/${total} 张 · ${label}`);
        const ed = editorTpl();                  // WYSIWYG：用编辑器里的当前内容
        const prompt = positiveFor(key, ed);
        const negText = negativeFor(ed);
        const thisSeed = seed + r;
        if (img2img) banner('warn', 'Qwen 的图生图还没接进来：本次按文生图处理（模板 A2 暂不可用）。');
        startPoll();
        let pid;
        try {
          const graph = comfyGraph({ key, prompt, negText, cfg, seed: thisSeed });
          pid = (await post(COMFY + '/prompt', { prompt: graph }, 120000)).prompt_id;
        } finally { stopPoll(); }
        if (!pid) throw new Error(label + '：ComfyUI 没返回 prompt_id');

        const outs = await waitComfy(pid);
        if (!outs.length) throw new Error(label + '：ComfyUI 没产出图片');
        const b64 = await fetchComfyImage(outs[0]);
        if (!b64) throw new Error(label + '：取不到图片数据');

        const fname = `${stamp()}__${tpl.id}__${slug(baseOf(cfg.ckpt))}__${key === NONE ? 'base' : slug(key)}__s${thisSeed}${img2img ? '__i2i' + String(ed.denoise).replace('.', '') : ''}.png`;
        await saveImage(fname, b64);

        const rec = {
          id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
          at: new Date().toISOString().replace('T', ' ').slice(0, 19),
          template: tpl.id,
          template_name: tpl.name,
          阶段: img2img ? 'img2img' : 'txt2img',
          denoise: img2img ? ed.denoise : null,
          底图: img2img ? ('images/' + initName) : null,
          base: baseOf(cfg.ckpt),
          checkpoint: plain(cfg.ckpt),
          width: cfg.w, height: cfg.h,
          steps: cfg.steps, cfg: cfg.cfg, sampler: cfg.sampler, seed: thisSeed,
          lora: key === NONE ? null : key,
          weight: key === NONE ? null : weightOf(key),
          own_weight: key === NONE ? false : hasOwnWeight(key),
          trigger: key === NONE ? '' : (($('#inject-trigger').checked && metaOf(key).触发词) || ''),
          final_prompt: prompt,
          negative_prompt: negText,
          image: 'images/' + fname,
          rating: null, verdict: '', notes: '',
        };
        S.records.push(rec);
        created.push(rec);
        if (key !== NONE && !S.recent.includes(key)) {
          S.recent.unshift(key);              // 「最近使用」排序用
          S.recent = S.recent.slice(0, 30);
          saveUiState();
        }
        renderResults(); renderSummary();
        await persist();
        setBar(done / total);
      }
    }
    banner('info', `完成 ${created.length} 张。给每张打分 / 选结论后，点右上角「导出 RESULTS.md」。`);
    setStatus('');
  } catch (e) {
    banner('err', '生成中断：' + e.message);
    setStatus('');
  } finally {
    S.busy = false;
    $('#btn-gen').disabled = false;
    stopPoll();
  }
}

/* ------------------------------- 结果卡片 ------------------------------- */
function renderResults() {
  const box = $('#results');
  box.textContent = '';
  $('#rec-count').textContent = S.records.length ? `共 ${S.records.length} 条` : '';

  if (!S.records.length) {
    box.append(h('div', { class: 'empty', text: '还没有记录。选好模板与 LoRA，点「开始生成」。' }));
    return;
  }

  for (const r of S.records.slice().reverse()) {
    const isBase = !r.lora;
    const card = h('article', { class: 'card' + (r.verdict === '保留' ? ' kept' : r.verdict === '淘汰' ? ' drop' : '') });

    const img = h('img', { class: 'thumb', src: r.image, alt: r.lora || 'baseline', loading: 'lazy' });
    img.addEventListener('click', () => openLightbox(r));

    const stars = h('div', { class: 'stars', title: '点击打分（点第 1 颗可清零）' });
    const paint = (v) => {
      stars.textContent = '';
      for (let i = 1; i <= 5; i++) {
        const s = h('span', { class: i <= (v || 0) ? 'on' : '', text: '★' });
        s.addEventListener('click', () => {
          r.rating = (r.rating === i) ? null : i;   // 再点一次同一颗 = 清零
          renderResults(); renderSummary(); scheduleSave();
        });
        stars.append(s);
      }
    };
    paint(r.rating);

    const ver = h('select', { title: '结论' });
    for (const v of VERDICTS) ver.append(h('option', { value: v, text: v || '（未评）' }));
    ver.value = r.verdict || '';
    ver.addEventListener('change', () => {
      r.verdict = ver.value;
      renderResults(); renderSummary(); scheduleSave();
    });

    const notes = h('input', { type: 'text', placeholder: '备注（例如：铠甲细节糊 / 触发词太强）', value: r.notes || '' });
    notes.addEventListener('input', () => { r.notes = notes.value; scheduleSave(); });

    card.append(img, h('div', { class: 'card-body' },
      h('div', { class: 'card-head' },
        h('span', { class: 'lora-name', text: isBase ? '（基线·无 LoRA）' : r.lora }),
        h('span', { class: 'tag', text: r.base }),
        r.weight != null ? h('span', { class: 'tag', text: 'w ' + Number(r.weight).toFixed(2) }) : null,
        r.own_weight ? h('span', { class: 'warn-badge', text: '单独权重' }) : null,
        r.阶段 === 'img2img' ? h('span', { class: 'tag warn', text: 'i2i ' + Number(r.denoise || 0).toFixed(2) }) : null),
      h('div', { class: 'card-sub', text: `${r.template} · ${r.width}×${r.height} · steps ${r.steps} · CFG ${r.cfg} · seed ${r.seed}` }),
      stars, ver, notes,
      h('details', {}, h('summary', { text: '最终提示词' }),
        h('pre', { text: r.final_prompt + '\n\n[负向]\n' + (r.negative_prompt || '') })),
      (r.crops && r.crops.length) ? h('div', { class: 'crop-row' },
        h('span', { class: 'crop-cap', text: '已裁 sprite（' + r.crops.length + '）：' }),
        ...r.crops.map((c) => h('a', {
          class: 'crop-thumb', href: c.url, target: '_blank',
          title: c.url + '（' + Math.round((c.bytes || 0) / 1024) + ' KB）',
        }, h('img', { src: c.url, alt: c.name })))) : null,
      h('div', { class: 'acts' },
        copyBtn(() => r.final_prompt, '复制正向'),
        copyBtn(() => r.negative_prompt || '', '复制负向'),
        copyBtn(() => `steps ${r.steps} · CFG ${r.cfg} · ${r.sampler} · seed ${r.seed} · ${r.width}x${r.height}` +
          (r.阶段 === 'img2img' ? ` · denoise ${Number(r.denoise || 0).toFixed(2)}` : ''), '复制参数'),
        h('button', {
          class: 'del', text: '设为底图 →',
          onclick: () => setInitImage(String(r.image || '').split('images/').pop()),
        }),
        h('button', {
          class: 'del', text: '裁 sprite →',
          title: '把这张 2×2 设定图裁成 4 张单视角 sprite（front / iso / side / back）',
          onclick: () => cropRecord(r),
        }),
        h('button', {
          class: 'del danger', text: '删除',
          onclick: async () => {
            S.records = S.records.filter((x) => x.id !== r.id);
            try { await del('/api/delete', { path: r.image }); } catch (_) {}
            renderResults(); renderSummary(); await persist();
          },
        }))));
    box.append(card);
  }
}

/* 裁切：A4 的 2×2 设定图 → 4 张单视角 sprite（弹窗选名称与尺寸 → /api/crop → crop_sheet.py） */
let cropTarget = null;

/** 打开裁切弹窗（尺寸记住上次用的值，默认 128 = 项目规范） */
function cropRecord(r) {
  if (!r || !r.image) { banner('err', '这条记录没有图片路径'); return; }
  cropTarget = r;
  const guess = String(r.template || 'sheet').toLowerCase() + '_s' + (r.seed == null ? 'x' : r.seed);
  $('#crop-name').value = r.crop_name || guess;
  $('#crop-size').value = r.crop_size || S.cropSize || 128;
  $('#crop-src').textContent = `${r.image}（${r.width}×${r.height}）`;
  $('#crop-hint').textContent = '';
  $('#crop-dlg').hidden = false;
  $('#crop-name').focus();
  $('#crop-name').select();
}

/** 执行裁切（弹窗「开始裁切」或回车触发） */
async function doCrop() {
  const r = cropTarget;
  if (!r) return;
  const name = ($('#crop-name').value || '').trim();
  const size = Math.round(Number($('#crop-size').value) || 128);
  if (size < 32 || size > 1024) { $('#crop-hint').textContent = '边长要在 32 ~ 1024 之间'; return; }
  $('#crop-dlg').hidden = true;
  S.cropSize = size;
  banner('info', `正在裁切…（2×2 四格 → ${size}² sprite）`);
  try {
    const res = await post('/api/crop', { path: r.image, name: name || 'sheet', size, mode: 'auto' }, 300000);
    r.crops = res.files || [];
    r.crop_dir = res.dir;
    r.crop_name = name;
    r.crop_size = size;
    renderResults();
    await persist();
    if (!r.crops.length) banner('err', '裁切完成但没产出文件：\n' + (res.log || '（无日志）'));
    else banner('info', `已裁出 ${r.crops.length} 张 → ${res.dir}（${size}²，点缩略图看大图）`);
  } catch (e) {
    banner('err', '裁切失败：' + e.message);
  }
}

function openLightbox(r) {
  $('#lightbox-img').src = r.image;
  $('#lightbox-cap').textContent = `${r.lora || '（基线）'} · ${r.base} · ${r.width}×${r.height} · seed ${r.seed} · 权重 ${r.weight == null ? '-' : Number(r.weight).toFixed(2)}`;
  $('#lightbox').hidden = false;
}

/* ------------------------------- 汇总 ------------------------------- */
function aggregate() {
  const byKey = new Map();
  for (const r of S.records) {
    const k = r.lora || NONE;
    if (!byKey.has(k)) byKey.set(k, { key: k, base: r.base, count: 0, sum: 0, rated: 0, verdict: '', verdicts: {} });
    const g = byKey.get(k);
    g.count++;
    g.base = r.base;
    if (typeof r.rating === 'number') { g.sum += r.rating; g.rated++; }
    if (r.verdict) { g.verdicts[r.verdict] = (g.verdicts[r.verdict] || 0) + 1; g.verdict = r.verdict; }
  }
  return Array.from(byKey.values()).sort((a, b) => b.count - a.count);
}

function renderSummary() {
  const box = $('#summary');
  box.textContent = '';
  const groups = aggregate();
  if (!groups.length) {
    box.append(h('div', { class: 'empty', text: '还没有数据。先跑一轮生成。' }));
    return;
  }

  const tbl = h('table', {});
  tbl.append(h('thead', {}, h('tr', {},
    h('th', { text: 'LoRA' }), h('th', { text: 'base' }), h('th', { text: '用途' }),
    h('th', { text: '样本' }), h('th', { text: '均分' }), h('th', { text: '结论' }), h('th', { text: '署名' }))));

  const tbody = h('tbody', {});
  for (const g of groups) {
    const m = g.key === NONE ? {} : metaOf(g.key);
    const avg = g.rated ? (g.sum / g.rated).toFixed(1) : '—';
    const cls = g.verdict === '保留' ? 'verdict-keep' : g.verdict === '淘汰' ? 'verdict-drop' : g.verdict === '待定' ? 'verdict-maybe' : '';
    tbody.append(h('tr', {},
      h('td', { class: 'mono', text: g.key === NONE ? '（基线）' : g.key }),
      h('td', { text: g.base }),
      h('td', { text: g.key === NONE ? '对照组' : (m.用途 || '—') }),
      h('td', { text: g.count }),
      h('td', { text: avg }),
      h('td', { class: cls, text: g.verdict || '（未评）' }),
      h('td', { text: m.署名 ? '⚠️ 必需' : '否' })));
  }
  tbl.append(tbody);
  box.append(tbl);

  const keep = groups.filter((g) => g.verdict === '保留').map((g) => g.key === NONE ? '（基线）' : g.key);
  const drop = groups.filter((g) => g.verdict === '淘汰').map((g) => g.key);
  box.append(h('p', { class: 'hint', style: 'margin-top:10px' },
    `建议保留：${keep.join('、') || '—'}　|　建议淘汰：${drop.join('、') || '—'}（点「导出 RESULTS.md」写成文档）`));
}

/* ------------------------------- 落盘 ------------------------------- */
function scheduleSave() {
  if (S.saveTimer) clearTimeout(S.saveTimer);
  S.saveTimer = setTimeout(() => persist().catch(() => {}), 700);
}

async function persist() {
  const payload = {
    note: '对比记录。每条 record = 一次生成。评分(rating 0~5) / 结论(verdict: 保留|待定|淘汰|空) / 备注(notes) 由人工在界面上填写，导出 RESULTS.md 时按 LoRA 汇总，用于决定最终保留哪些 LoRA。',
    updated: new Date().toISOString().slice(0, 10),
    records: S.records,
  };
  await saveText(F_RESULTS, JSON.stringify(payload, null, 2));
}

/* ------------------------------- 导出 RESULTS.md ------------------------------- */
function buildMarkdown() {
  const groups = aggregate();
  const now = new Date().toISOString().replace('T', ' ').slice(0, 19);
  const L = [];

  L.push('# LoRA 对比结论（自动生成）');
  L.push('');
  L.push(`> 由 \`tools/lora-compare\` 生成于 **${now}** · 共 ${S.records.length} 条记录。`);
  L.push('> 用途：**决定最终保留哪些 LoRA**。图片在同目录 `images/`（未入库，仅本机可见）。');
  L.push('> 口径：同一提示词 + 同一 seed + 同一参数，**只换 LoRA**；「（基线）」= 不加 LoRA 的对照组。');
  L.push('');
  L.push('---');
  L.push('');

  // ---- 1. 汇总 ----
  L.push('## 一、结论汇总');
  L.push('');
  if (!groups.length) {
    L.push('_（还没有记录）_');
  } else {
    L.push('| LoRA | base | 用途 | 样本 | 均分 | 结论 | 署名义务 |');
    L.push('| --- | --- | --- | --- | --- | --- | --- |');
    for (const g of groups) {
      const m = g.key === NONE ? {} : metaOf(g.key);
      const avg = g.rated ? (g.sum / g.rated).toFixed(1) : '—';
      L.push(`| ${g.key === NONE ? '**（基线·无 LoRA）**' : '`' + g.key + '`'} | ${g.base} | ${g.key === NONE ? '对照组' : (m.用途 || '—')} | ${g.count} | ${avg} | ${g.verdict || '未评'} | ${m.署名 ? '⚠️ 必须署名' : '否'} |`);
    }
    const keep = groups.filter((g) => g.verdict === '保留').map((g) => g.key === NONE ? '（基线）' : g.key);
    const drop = groups.filter((g) => g.verdict === '淘汰').map((g) => g.key);
    const pend = groups.filter((g) => !g.verdict || g.verdict === '待定').map((g) => g.key);
    L.push('');
    L.push(`- **建议保留**：${keep.length ? keep.map((k) => '`' + k + '`').join('、') : '—'}`);
    L.push(`- **建议淘汰**：${drop.length ? drop.map((k) => '`' + k + '`').join('、') : '—'}`);
    L.push(`- **待定（样本不足或结论未定）**：${pend.length ? pend.map((k) => '`' + k + '`').join('、') : '—'}`);
  }
  L.push('');
  L.push('---');
  L.push('');

  // ---- 2. 逐组对比 ----
  L.push('## 二、逐组对比');
  L.push('');
  const byGroup = new Map();
  for (const r of S.records) {
    const gk = [r.template, r.base, r.width + 'x' + r.height, 'steps' + r.steps, 'cfg' + r.cfg, r.sampler, 'seed' + r.seed].join('|');
    if (!byGroup.has(gk)) byGroup.set(gk, []);
    byGroup.get(gk).push(r);
  }
  let gi = 0;
  for (const [gk, recs] of byGroup) {
    gi++;
    const p = recs[0];
    L.push(`### 组 ${gi} · 模板 ${p.template} ${p.template_name || ''} · ${p.base} · ${p.width}×${p.height} · steps ${p.steps} · CFG ${p.cfg} · ${p.sampler} · seed ${p.seed}`);
    L.push('');
    L.push('| 对比项 | 权重 | 最终提示词 | 评分 | 结论 | 备注 | 图 |');
    L.push('| --- | --- | --- | --- | --- | --- | --- |');
    for (const r of recs) {
      const stars = typeof r.rating === 'number' ? '★'.repeat(r.rating) + '☆'.repeat(5 - r.rating) : '—';
      const prompt = '`' + String(r.final_prompt).replace(/\|/g, '\\|').replace(/\n/g, ' ').slice(0, 260) + '`';
      L.push(`| ${r.lora ? '`' + r.lora + '`' : '（基线）'} | ${r.weight == null ? '—' : Number(r.weight).toFixed(2)} | ${prompt} | ${stars} | ${r.verdict || '—'} | ${(r.notes || '').replace(/\|/g, '\\|') || '—'} | [图](${r.image}) |`);
    }
    L.push('');
    L.push(`**负向**：\`${String(p.negative_prompt || '').replace(/\n/g, ' ')}\``);
    L.push('');
  }

  // ---- 3. 当前提示词版本 ----
  L.push('---');
  L.push('');
  L.push('## 三、提示词版本（导出时的状态）');
  L.push('');
  for (const t of S.prompts.templates) {
    L.push(`### ${t.id} · ${t.name}（改动 ${(t.history || []).length} 次）`);
    L.push('');
    L.push('```');
    L.push(t.positive);
    L.push('```');
    L.push('');
  }
  return L.join('\n') + '\n';
}

async function exportReport() {
  try {
    const md = buildMarkdown();
    const res = await saveText(F_REPORT, md);
    banner('info', `已写入 ${res.path}（${res.bytes} 字节）。它是决定"最终保留哪些 LoRA"的依据。`);
  } catch (e) {
    banner('err', '导出失败：' + e.message);
  }
}

/* ============================================================================
   页面结构：页面 A（项目总览）/ 页面 B（工作台）

   页面 A 的条目 = prompts.json 的 templates（即"项目需要出的图"）。
   点卡片 = 选中该模板（等价于改 #tpl-select 并触发既有 change 绑定）→ 进入页面 B。
   页面 B 复用旧版全部面板（id 未变），因此生成 / 结果 / 汇总逻辑一行都不用改。
   ========================================================================== */

const PAGE_LIST = 'page-list';
const PAGE_DETAIL = 'page-detail';

/** 类别（按模板 id 首字母）—— 决定卡片左侧色条与标签 */
const CATEGORY = {
  A: { name: '角色', color: '#8fb0ff' },
  B: { name: '场景', color: '#4bc98d' },
  C: { name: '装备', color: '#e2b34a' },
  D: { name: 'Boss', color: '#e4737f' },
  E: { name: '技能', color: '#b39cff' },
  F: { name: 'UI', color: '#38d6e8' },
};

function categoryOf(tpl) {
  const c = CATEGORY[String((tpl && tpl.id) || '')[0].toUpperCase()];
  return c || { name: (tpl && tpl.id) || '其它', color: '#4f7dff' };
}

/** 单个项目的出图统计（从对比记录里算，纯派生值） */
function projectStats(id) {
  const rs = S.records.filter((r) => r.template === id);
  let best = null;
  for (const r of rs) {
    if (typeof r.rating === 'number' && (best === null || r.rating > best)) best = r.rating;
  }
  return {
    count: rs.length,
    best,
    last: rs.length ? rs[rs.length - 1].at : '',
    kept: rs.some((r) => r.verdict === '保留'),
  };
}

function showPage(name) {
  const detail = name === 'detail';
  const list = $('#page-list'), det = $('#page-detail');
  if (!list || !det) return;
  list.hidden = detail;
  det.hidden = !detail;
  for (const b of $$('#nav .nav-btn')) b.classList.toggle('active', b.dataset.page === (detail ? 'detail' : 'list'));
  if (!detail) renderProjects();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/** 选中某个生图项目 → 进工作台（其它逻辑全走既有绑定） */
function openProject(id) {
  const sel = $('#tpl-select');
  sel.value = id;
  sel.dispatchEvent(new Event('change'));   // → loadTplToEditor() + applyDefaults()
  showPage('detail');
}

function fact(k, v) {
  return h('div', {}, h('dt', { text: k }), h('dd', { text: v, title: String(v) }));
}

function projectCard(t, st) {
  const cat = categoryOf(t);
  const i2i = t.阶段 === 'img2img';
  const card = h('article', {
    class: 'proj-card' + (t.id === S.tplId ? ' is-active' : ''),
    style: '--cat:' + cat.color,
    title: '点卡片进入工作台',
  });
  card.append(
    h('div', { class: 'proj-head' },
      h('span', { class: 'proj-id', text: t.id }),
      h('span', { class: 'tag ' + (i2i ? 'warn' : 'ok'), text: i2i ? '图生图' : '文生图', style: 'margin-left:0' }),
      h('span', { class: 'tag', text: cat.name })),
    h('h3', { class: 'proj-title', text: t.name || t.id }),
    h('p', { class: 'proj-usage', text: t.用途 || '（没写用途）' }),
    h('dl', { class: 'proj-facts' },
      fact('建议底模', ((S.prompts.global.checkpointDefaults || {})[t.base建议] || {}).label || t.base建议 || '—'),
      fact('出图尺寸', t.出图尺寸 || '—'),
      fact('要求块', (t.套用要求 || []).join(' · ') || '—'),
      fact('模板提示词', t.positive || '—')));
  // ⚠️ 别把 null 直接塞进 append（会渲染成字符串 "null"）
  if (t.备注) card.append(h('p', { class: 'proj-note', text: '⚠️ ' + t.备注 }));
  card.append(
    h('div', { class: 'proj-foot' },
      h('span', { class: 'proj-stat', html: '已出 <b>' + st.count + '</b> 张' }),
      st.best != null ? h('span', { class: 'proj-stat', html: '最佳 <b>★' + st.best + '</b>' }) : null,
      st.kept ? h('span', { class: 'tag ok', text: '有保留' }) : null,
      st.last ? h('span', { class: 'proj-stat', text: '最近 ' + String(st.last).slice(5, 16) }) : null,
      h('button', {
        class: 'primary go', text: '进入工作台 →',
        onclick: (e) => { e.stopPropagation(); openProject(t.id); },
      })));

  card.addEventListener('click', () => openProject(t.id));
  return card;
}

/** 页面 A 渲染 */
function renderProjects() {
  if (!S.prompts) return;
  const box = $('#project-grid');
  if (!box) return;
  const tpls = S.prompts.templates || [];
  const q = (($('#proj-search') || {}).value || '').trim().toLowerCase();
  const mode = (($('#proj-filter') || {}).value) || 'all';

  let shots = 0;
  const rows = tpls.map((t) => {
    const st = projectStats(t.id);
    shots += st.count;
    return { t, st };
  });
  $('#proj-total').textContent = tpls.length;
  $('#proj-shots').textContent = shots;
  $('#proj-hint').textContent = shots ? '' : '· 还没有出过图';

  let list = rows;
  if (q) {
    list = list.filter(({ t }) => [t.id, t.name, t.用途, t.备注, (t.套用要求 || []).join(' ')]
      .join(' ').toLowerCase().includes(q));
  }
  if (mode === 'todo') list = list.filter(({ st }) => !st.count);
  else if (mode === 'done') list = list.filter(({ st }) => st.count > 0);
  else if (mode === 'keep') list = list.filter(({ st }) => st.kept);

  box.textContent = '';
  if (!list.length) {
    box.append(h('div', { class: 'empty', text: '（没有符合筛选条件的项目）' }));
    return;
  }
  for (const { t, st } of list) box.append(projectCard(t, st));
}

/** 页面 B 顶部摘要：当前用的是哪个模型 / 哪些 LoRA / 尺寸与阶段 */
function renderDetailSummary() {
  if (!S.prompts) return;
  const box = $('#detail-summary');
  if (!box) return;
  const t = currentTpl() || {};
  $('#detail-id').textContent = t.id || '—';
  $('#detail-name').textContent = t.name || '未选模板';
  const stage = $('#detail-stage');
  stage.textContent = t.阶段 === 'img2img' ? '图生图' : '文生图';
  stage.className = 'tag ' + (t.阶段 === 'img2img' ? 'warn' : 'ok');

  const picked = Array.from(S.sel).filter((k) => k !== NONE);
  const aux = S.aux || {};
  const bits = [
    '模型 ' + (plain($('#ckpt').value) || '—'),
    '文本编码器 ' + ((aux.clip || [])[0] || '—'),
    'VAE ' + ((aux.vae || [])[0] || '—'),
    ($('#w').value || '?') + '×' + ($('#h').value || '?'),
    '步数 ' + $('#steps').value + ' · CFG ' + $('#cfg').value,
    '本批对比 ' + (picked.length ? picked.join(' / ') : '仅基线'),
  ];
  box.textContent = categoryOf(t).name + '　|　' + bits.join('　|　');
}

function bindPages() {
  for (const b of $$('#nav .nav-btn')) b.addEventListener('click', () => showPage(b.dataset.page));
  $('#btn-back').addEventListener('click', () => showPage('list'));
  $('#proj-search').addEventListener('input', renderProjects);
  $('#proj-filter').addEventListener('change', renderProjects);
  showPage('list');
  renderDetailSummary();
}

/* ------------------------------- 事件绑定 ------------------------------- */
function bind() {
  $('#tpl-select').addEventListener('change', () => { S.tplId = $('#tpl-select').value; loadTplToEditor(); applyDefaults(false); });
  $('#pos').addEventListener('input', () => markDirty(true));
  $('#neg').addEventListener('input', () => markDirty(true));
  $('#btn-pos-reset').addEventListener('click', () => {
    const p = (S.pristine.templates || []).find((t) => t.id === S.tplId);
    if (!p) return;
    $('#pos').value = p.positive || '';
    $('#neg').value = p.negative || '';
    markDirty(true);
  });
  $('#btn-prompt-save').addEventListener('click', savePrompt);

  // 页签 + 要求面板
  for (const b of $$('.tab')) b.addEventListener('click', () => switchPane(b.dataset.pane));
  $('#tpl-req').addEventListener('input', () => { markDirty(true); updatePreview(); });
  $('#inject-trigger').addEventListener('change', updatePreview);
  $('#denoise').addEventListener('input', () => {
    $('#denoise-out').textContent = Number($('#denoise').value).toFixed(2);
    markDirty(true);
    updatePreview();
  });
  $('#repeat').addEventListener('input', () => { $('#repeat-out').textContent = $('#repeat').value; });
  $('#init-img').addEventListener('change', () => setInitImage($('#init-img').value));
  $('#btn-init-refresh').addEventListener('click', refreshImages);
  $('#init-upload').addEventListener('change', uploadInit);
  $('#g-rules').addEventListener('input', () => {
    $('#req-state').textContent = '● 有未保存的修改';
    updatePreview();
  });
  $('#btn-req-save').addEventListener('click', saveReqs);
  $('#btn-req-reset').addEventListener('click', () => {
    fillReqForm((S.pristine && S.pristine.global) || {});
    $('#req-state').textContent = '已复位到上次保存的内容';
    updatePreview();
  });
  $('#lw').addEventListener('input', () => { $('#lw-out').textContent = Number($('#lw').value).toFixed(2); updatePreview(); });
  $('#lw-out').textContent = Number($('#lw').value).toFixed(2);
  $('#ckpt').addEventListener('change', () => { applyDefaults(false); renderLoRA(); });
  $('#force-base').addEventListener('change', renderLoRA);
  $('#btn-all').addEventListener('click', () => {
    for (const cb of document.querySelectorAll('#lora-list input[type="checkbox"]')) {
      if (!cb.disabled) { cb.checked = true; S.sel.add(cb.value); }
    }
    updateLoraCount();
    updatePreview();
  });
  $('#btn-none').addEventListener('click', () => {
    S.sel.clear(); S.sel.add(NONE);
    for (const cb of document.querySelectorAll('#lora-list input[type="checkbox"]')) cb.checked = cb.value === NONE;
    updateLoraCount();
    updatePreview();
  });
  $('#btn-refresh').addEventListener('click', async () => { await refreshComfy(); renderLoRA(); banner(null); });

  // —— 模型选择器：搜索 / 筛选 / 排序 ——
  $('#lora-search').addEventListener('input', () => { S.filter.q = $('#lora-search').value; saveUiState(); renderLoRA(); });
  $('#lora-base-filter').addEventListener('change', () => { S.filter.base = $('#lora-base-filter').value; saveUiState(); renderLoRA(); });
  $('#lora-group-filter').addEventListener('change', () => { S.filter.group = $('#lora-group-filter').value; saveUiState(); renderLoRA(); });
  $('#lora-sort').addEventListener('change', () => { S.filter.sort = $('#lora-sort').value; saveUiState(); renderLoRA(); });

  // —— 复制按钮：HTML 里标了 data-copy="元素id" 的，复制那个元素的值 ——
  for (const b of $$('[data-copy]')) {
    b.addEventListener('click', (e) => {
      e.preventDefault();
      const el = $('#' + b.dataset.copy);
      if (el) copyText(el.value, b);
    });
  }
  $('#copy-preview-pos').addEventListener('click', (e) => copyText(finalPromptText('pos'), e.currentTarget));
  $('#copy-preview-neg').addEventListener('click', (e) => copyText(finalPromptText('neg'), e.currentTarget));
  $('#copy-inspect-pos').addEventListener('click', (e) => copyText(finalPromptText('pos'), e.currentTarget));
  $('#copy-inspect-neg').addEventListener('click', (e) => copyText(finalPromptText('neg'), e.currentTarget));
  $('#btn-gen').addEventListener('click', generate);
  $('#btn-save').addEventListener('click', async () => {
    try { await persist(); banner('info', '对比记录已写入 data/results.json。'); }
    catch (e) { banner('err', '保存失败：' + e.message); }
  });
  $('#btn-export').addEventListener('click', exportReport);
  $('#lightbox').addEventListener('click', () => { $('#lightbox').hidden = true; $('#lightbox-img').src = ''; });
  // 裁切弹窗：点「开始裁切」/ 回车 执行；点「取消」/ 点遮罩 / Esc 关闭
  $('#crop-go').addEventListener('click', doCrop);
  $('#crop-cancel').addEventListener('click', () => { $('#crop-dlg').hidden = true; });
  $('#crop-dlg').addEventListener('click', (e) => { if (e.target.id === 'crop-dlg') $('#crop-dlg').hidden = true; });
  $('#crop-dlg').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); doCrop(); }
    else if (e.key === 'Escape') $('#crop-dlg').hidden = true;
  });
}

async function savePrompt() {
  const t = currentTpl();
  if (!t) return;
  const ed = editorTpl();
  const next = {
    positive: ed.positive,
    要求: ed.要求,
    negative: ed.negative,
    套用要求: ed.套用要求,
    denoise: ed.denoise,
  };
  const changed = ['positive', 'negative', '要求', '套用要求', 'denoise'].some(
    (k) => JSON.stringify(next[k]) !== JSON.stringify(t[k]));
  if (!changed) { banner('info', '本模板没有变化，无需保存。'); return; }
  t.history = t.history || [];
  t.history.push({
    at: new Date().toISOString().replace('T', ' ').slice(0, 19),
    note: '人工编辑',
    positive: t.positive,
    negative: t.negative,
    要求: t.要求,
    套用要求: t.套用要求,
    denoise: t.denoise,
  });
  Object.assign(t, next);
  S.prompts.updated = new Date().toISOString().slice(0, 10);
  try {
    await saveText(F_PROMPTS, JSON.stringify(S.prompts, null, 2));
    S.pristine = JSON.parse(JSON.stringify(S.prompts));
    renderHistory();
    markDirty(false);
    updatePreview();
    banner('info', `模板 ${t.id} 已保存（旧版压入修改历史，可回退）。`);
  } catch (e) {
    banner('err', '提示词保存失败：' + e.message);
  }
}

boot();
