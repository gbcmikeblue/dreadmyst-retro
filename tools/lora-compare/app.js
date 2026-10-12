'use strict';

/* ============================================================================
   LoRA 对比台 · 前端逻辑（纯 JS，无框架）

   它做的事：同一提示词 + 同一参数 + 同一 seed，逐个换 LoRA 出图，并排对比，
   人工评分后把结论落盘成 RESULTS.md —— 用于决定最终保留哪些 LoRA。

   为什么所有请求都走同源的 /forge/*：Forge 启动时未开 CORS
   （cors_allow_origins 为空），浏览器直连 127.0.0.1:7860 会被拦。
   ========================================================================== */

const FORGE = '/forge';
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
  disk: [],           // Forge 上真实存在的 LoRA 文件名（无扩展名）
  ckpts: [],          // { title, model_name }
  samplers: [],
  records: [],        // 对比记录
  tplId: null,
  sel: new Set([NONE]),
  busy: false,
  poll: null,
  saveTimer: null,
};

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
const baseOf = (t) => (/xl/i.test(String(t)) ? 'SDXL' : 'SD 1.5');
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
  if (location.protocol === 'file:') {
    banner('err', '不能直接双击 index.html 打开：这样既无法调用 Forge API（CORS 被拦），也无法把结果写回磁盘。请双击 start.bat，用 http://127.0.0.1:7788/ 访问。');
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
    const rs = await get(F_RESULTS);
    S.records = rs.records || [];
  } catch (e) {
    banner('err', '读取 data/*.json 失败：' + e.message);
    return;
  }

  renderTemplates();
  renderResults();
  renderSummary();
  renderReqs();
  await refreshForge();
  renderLoRA();
  await refreshImages();
  bind();
  updatePreview();
}

/* ------------------------------- 读 Forge ------------------------------- */
async function refreshForge() {
  try {
    const loras = await get(FORGE + '/sdapi/v1/loras', 25000);
    S.disk = loras.map((x) => x.name);
    pill('pill-forge', true);
  } catch (e) {
    S.disk = [];
    pill('pill-forge', false);
    banner('warn', '读不到 Forge 的 LoRA 列表：' + e.message + '（Forge 没启动的话请先起 Forge，再点「重读 LoRA 列表」）');
  }
  try {
    S.ckpts = await get(FORGE + '/sdapi/v1/sd-models', 25000);
    const sm = await get(FORGE + '/sdapi/v1/samplers', 25000);
    S.samplers = sm.map((x) => x.name);
  } catch (_) {
    S.ckpts = [];
    S.samplers = ['DPM++ 2M'];
  }
  let cur = null;
  try {
    const o = await get(FORGE + '/sdapi/v1/options', 25000);
    cur = plain(o.sd_model_checkpoint);
    $('#pill-model').textContent = cur || '—';
  } catch (_) { /* 忽略 */ }

  const sel = $('#ckpt');
  sel.textContent = '';
  if (!S.ckpts.length) {
    sel.append(h('option', { value: '', text: '（读不到 checkpoint，请确认 Forge 已启动）' }));
  } else {
    for (const c of S.ckpts) sel.append(h('option', { value: c.title, text: `${c.title}  ·  ${baseOf(c.title)}` }));
    const match = S.ckpts.find((c) => plain(c.title) === cur);
    if (match) sel.value = match.title;
  }

  const sp = $('#sampler');
  sp.textContent = '';
  for (const s of S.samplers) sp.append(h('option', { value: s, text: s }));
  if (S.samplers.includes('DPM++ 2M')) sp.value = 'DPM++ 2M';

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
  const def = (S.prompts.global.checkpointDefaults[baseOf($('#ckpt').value)]) || {};
  const sug = (t && S.prompts.global.checkpointDefaults[t.base建议]) || def;
  $('#w').value = sug.width || def.width || 512;
  $('#h').value = sug.height || def.height || 512;
  $('#steps').value = sug.steps || def.steps || 25;
  $('#cfg').value = sug.cfg || def.cfg || 7;
  if (resetSeed !== false && !$('#seed').value) $('#seed').value = -1;
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

/* ------------------------------- LoRA 列表 ------------------------------- */
function renderLoRA() {
  const ul = $('#lora-list');
  ul.textContent = '';

  const keys = [];
  const seen = new Set();
  for (const name of S.disk) { if (!seen.has(name)) { seen.add(name); keys.push(name); } }
  for (const name of Object.keys(S.meta)) { if (!seen.has(name)) { seen.add(name); keys.push(name); } }
  keys.sort();

  const add = (key, label, sub, tags, enabled) => {
    const cb = h('input', { type: 'checkbox', value: key });
    cb.checked = S.sel.has(key);
    if (!enabled) cb.disabled = true;
    cb.addEventListener('change', () => {
      if (cb.checked) S.sel.add(key); else S.sel.delete(key);
      updateLoraCount();
      updatePreview();
    });
    const li = h('li', { class: 'lora-item' + (enabled ? '' : ' bad') },
      h('label', {}, cb, h('div', { class: 'grow' },
        h('div', { class: 'lora-name' }, label, ...tags.map((t) => h('span', { class: 'tag ' + (t.k || ''), text: t.text }))),
        h('div', { class: 'lora-sub', text: sub }))));
    ul.append(li);
  };

  add(NONE, '（无 LoRA 基线）', '对照组：不加任何 LoRA，用来判断"加 LoRA 到底有没有变好"',
    [{ text: '基线', k: 'ok' }], true);

  for (const key of keys) {
    const m = metaOf(key);
    const onDisk = S.disk.includes(key);
    const tags = [];
    if (m.base) tags.push({ text: m.base, k: '' });
    else tags.push({ text: 'base 未知', k: 'warn' });
    if (!onDisk) tags.push({ text: m.状态 || '未部署', k: 'bad' });
    if (m.署名) tags.push({ text: '须署名', k: 'warn' });
    const ok = onDisk && (compatible(key) || $('#force-base').checked);
    if (onDisk && !compatible(key)) tags.push({ text: '与当前 checkpoint 不兼容', k: 'bad' });
    const sub = [m.用途, m.触发词 && ('触发词 ' + m.触发词)].filter(Boolean).join(' · ') || '(loras.json 里没有元数据)';
    add(key, key, sub, tags, ok);
    if (!ok) S.sel.delete(key);
  }
  updateLoraCount();
}

function updateLoraCount() {
  const n = Array.from(S.sel).filter((k) => k === NONE || S.disk.includes(k)).length;
  $('#lora-count').textContent = `已选 ${n} 项（含基线）`;
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
    parts.push(`<lora:${key}:${Number($('#lw').value).toFixed(2)}>`);
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
}

async function switchCheckpoint(title) {
  const want = plain(title);
  let cur = null;
  try { cur = plain((await get(FORGE + '/sdapi/v1/options', 20000)).sd_model_checkpoint); } catch (_) {}
  if (cur === want) { $('#pill-model').textContent = want; return; }

  setStatus(`正在切换 checkpoint → ${want}（8GB 显存下要数十秒）…`);
  await post(FORGE + '/sdapi/v1/options', { sd_model_checkpoint: want }, 300000);
  for (let i = 0; i < 180; i++) {
    await sleep(1000);
    try {
      const o = await get(FORGE + '/sdapi/v1/options', 20000);
      if (plain(o.sd_model_checkpoint) === want) { $('#pill-model').textContent = want; return; }
    } catch (_) { /* 切换中会短暂失败，继续等 */ }
  }
  throw new Error('切换 checkpoint 超时（>' + 180 + 's）：' + want);
}

function startPoll() {
  stopPoll();
  S.poll = setInterval(async () => {
    try {
      const p = await get(FORGE + '/sdapi/v1/progress?skip_current_image=true', 6000);
      setBar(p.progress || 0);
      const st = p.state || {};
      if (st.sampling_step != null && st.sampling_steps) {
        setStatus(`采样 ${st.sampling_step}/${st.sampling_steps}`);
      }
    } catch (_) { /* 忽略 */ }
  }, 1000);
}
function stopPoll() { if (S.poll) { clearInterval(S.poll); S.poll = null; } }

/* ------------------------------- 图生图辅助 ------------------------------- */
/** 从本机服务读一张图，转成裸 base64（Forge 的 init_images 要这个格式） */
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
  if (!cfg.ckpt) { banner('err', '没读到 checkpoint，先把 Forge 起来再点「重读 LoRA 列表」。'); return; }

  let seed = Number.isFinite(cfg.seed) && cfg.seed >= 0 ? cfg.seed : Math.floor(Math.random() * 2147483647);
  $('#seed').value = seed;   // 锁进界面：本批共用同一个 seed 家族，保证"只换了 LoRA"

  const ed0 = editorTpl();
  const img2img = ed0.阶段 === 'img2img';
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
        const payload = {
          prompt,
          negative_prompt: negText,
          steps: cfg.steps, cfg_scale: cfg.cfg,
          width: cfg.w, height: cfg.h,
          sampler_name: cfg.sampler, seed: thisSeed,
          batch_size: 1, n_iter: 1, save_images: false, send_images: true,
          override_settings: { sd_model_checkpoint: plain(cfg.ckpt) },
        };
        if (img2img) {
          payload.init_images = [initB64];
          payload.denoising_strength = ed.denoise;
          payload.resize_mode = 0;               // 不放大：避免"先缩放再重绘"毁掉轮廓
          payload.mask_blur = 0;
        }
        startPoll();
        let res;
        try {
          res = await post(FORGE + (img2img ? '/sdapi/v1/img2img' : '/sdapi/v1/txt2img'), payload, 900000);
        } finally { stopPoll(); }

        const b64 = res && res.images && res.images[0];
        if (!b64) throw new Error(label + '：返回里没有图片');

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
          weight: key === NONE ? null : cfg.weight,
          trigger: key === NONE ? '' : (($('#inject-trigger').checked && metaOf(key).触发词) || ''),
          final_prompt: prompt,
          negative_prompt: negText,
          image: 'images/' + fname,
          rating: null, verdict: '', notes: '',
        };
        S.records.push(rec);
        created.push(rec);
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
        r.weight != null ? h('span', { class: 'tag', text: 'w ' + Number(r.weight).toFixed(2) }) : null),
      h('div', { class: 'card-sub', text: `${r.template} · ${r.width}×${r.height} · steps ${r.steps} · CFG ${r.cfg} · seed ${r.seed}` }),
      stars, ver, notes,
      h('details', {}, h('summary', { text: '最终提示词' }),
        h('pre', { text: r.final_prompt + '\n\n[负向]\n' + (r.negative_prompt || '') })),
      h('button', {
        class: 'del', text: '设为底图 →',
        onclick: () => setInitImage(String(r.image || '').split('images/').pop()),
      }),
      h('button', {
        class: 'del', text: '删除这条记录',
        onclick: async () => {
          S.records = S.records.filter((x) => x.id !== r.id);
          try { await del('/api/delete', { path: r.image }); } catch (_) {}
          renderResults(); renderSummary(); await persist();
        },
      })));
    box.append(card);
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
  $('#btn-refresh').addEventListener('click', async () => { await refreshForge(); renderLoRA(); banner(null); });
  $('#btn-gen').addEventListener('click', generate);
  $('#btn-save').addEventListener('click', async () => {
    try { await persist(); banner('info', '对比记录已写入 data/results.json。'); }
    catch (e) { banner('err', '保存失败：' + e.message); }
  });
  $('#btn-export').addEventListener('click', exportReport);
  $('#lightbox').addEventListener('click', () => { $('#lightbox').hidden = true; $('#lightbox-img').src = ''; });
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
