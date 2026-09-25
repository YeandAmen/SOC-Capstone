const $ = id => document.getElementById(id);
const colors = { 'T1110': '#65e7d1', 'T1136.001': '#eab45e', 'T1059.001': '#94a8ff', 'T1070.001': '#ff777c' };
let current = null;
let selectedHours = 24;

function node(tag, text, cls) {
  const element = document.createElement(tag);
  if (text !== undefined) element.textContent = text;
  if (cls) element.className = cls;
  return element;
}

function drawTrace() {
  const canvas = $('trace');
  const rect = canvas.getBoundingClientRect();
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.max(1, Math.round(rect.width * ratio));
  canvas.height = Math.max(1, Math.round(rect.height * ratio));
  const ctx = canvas.getContext('2d');
  ctx.scale(ratio, ratio);
  const width = rect.width, height = rect.height;
  ctx.clearRect(0, 0, width, height);
  ctx.strokeStyle = '#323b42'; ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i++) {
    const y = 16 + (height - 32) * i / 4;
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
  }
  const bins = current?.trace || Array.from({length: 60}, () => ({}));
  if (!current?.total) {
    ctx.beginPath(); ctx.moveTo(0, height - 20); ctx.lineTo(width, height - 20);
    ctx.strokeStyle = '#526068'; ctx.lineWidth = 1; ctx.stroke();
    return;
  }
  const max = Math.max(1, ...bins.map(bin => Object.values(bin).reduce((a,b) => a + b, 0)));
  for (const [technique, color] of Object.entries(colors)) {
    ctx.beginPath();
    bins.forEach((bin, i) => {
      const value = bin[technique] || 0;
      const x = i / 59 * width;
      const y = height - 20 - value / max * (height - 42);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.shadowColor = color; ctx.shadowBlur = 9; ctx.stroke(); ctx.shadowBlur = 0;
    bins.forEach((bin, i) => {
      if (!bin[technique]) return;
      const x = i / 59 * width;
      const y = height - 20 - bin[technique] / max * (height - 42);
      ctx.fillStyle = color; ctx.fillRect(x - 2, y - 2, 4, 4);
    });
  }
}

function render(data) {
  current = data;
  $('total-count').textContent = data.total.toLocaleString();
  $('metric-events').textContent = data.total.toLocaleString();
  $('metric-detections').textContent = data.detections.length;
  $('metric-hosts').textContent = data.hosts.length;
  $('last-update').textContent = `LAST SEARCH ${new Date(data.updated_at * 1000).toLocaleString()} · AUTO REFRESH 15s`;
  $('axis-start').textContent = `−${data.hours}h`;
  $('trace-caption').textContent = `${data.total} matching events · ${data.hours}h window`;
  $('event-count').textContent = `${data.events.length} SHOWN`;
  $('limit-note').textContent = data.limited ? 'Result limit reached for at least one source. Narrow the time window to inspect more events.' : '';
  const stats = $('technique-stats'); stats.replaceChildren();
  const maximum = Math.max(1, ...Object.values(data.counts));
  for (const [technique, color] of Object.entries(colors)) {
    const row = node('div', undefined, 'technique-row');
    const track = node('div', undefined, 'stat-track');
    const fill = node('div', undefined, 'stat-fill');
    fill.style.background = color;
    fill.style.width = `${(data.counts[technique] || 0) / maximum * 100}%`;
    track.append(fill);
    row.append(node('span', technique), track, node('strong', String(data.counts[technique] || 0)));
    stats.append(row);
  }
  const detections = $('detections'); detections.replaceChildren();
  if (!data.detections.length) detections.append(node('p', 'No detection rules matched in this window.', 'empty'));
  for (const item of data.detections) {
    const card = node('div', undefined, `detection ${item.severity}`);
    card.append(node('code', item.technique), node('strong', item.title), node('small', item.reason));
    detections.append(card);
  }
  const tbody = $('events'); tbody.replaceChildren();
  if (!data.events.length) {
    const row = node('tr'); const cell = node('td', 'No matching events in this window.', 'empty'); cell.colSpan = 5; row.append(cell); tbody.append(row);
  }
  for (const event of data.events) {
    const row = node('tr');
    for (const value of [new Date(event.time * 1000).toLocaleString(), event.technique, event.label, event.host, event.actor]) row.append(node('td', value));
    row.title = event.detail;
    tbody.append(row);
  }
  drawTrace();
}

async function refresh() {
  try {
    const response = await fetch(`/api/events?hours=${selectedHours}`, {cache:'no-store'});
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    render(data);
    $('status').className = 'status live'; $('status').innerHTML = '<i></i> LIVE';
  } catch (error) {
    $('status').className = 'status error'; $('status').innerHTML = '<i></i> DISCONNECTED';
    $('last-update').textContent = error.message;
  }
}

$('hours').addEventListener('change', event => { selectedHours = Number(event.target.value); refresh(); });
$('refresh').addEventListener('click', refresh);
function setView(view) {
  const stats = view === 'stats';
  $('statistics').hidden = !stats;
  document.querySelector('.trace-section').hidden = stats;
  document.querySelector('.events-section').hidden = stats;
  $('stats-tab').classList.toggle('active', stats);
  $('traces-tab').classList.toggle('active', !stats);
  $('stats-tab').setAttribute('aria-selected', String(stats));
  $('traces-tab').setAttribute('aria-selected', String(!stats));
  if (!stats) drawTrace();
}
$('stats-tab').addEventListener('click', () => setView('stats'));
$('traces-tab').addEventListener('click', () => setView('traces'));
window.addEventListener('resize', drawTrace);
refresh();
setInterval(refresh, 15000);
