// Gera as pranchas das propostas de ícone (docs/design/icone/*/prancha.png)
// e a comparação lado a lado (docs/design/icone/comparacao.png) a partir dos
// SVGs de cada proposta: fundo.svg, frente.svg e mono.svg, na grade de 108 dp
// do ícone adaptativo do Android.
//
// Uso, na raiz do repositório (precisa do Playwright com o Chromium, como
// tool/prototipo/renderizar.js):
//   node tool/icone/renderizar.js
//
// As pranchas saem em escala 1, para que "48 px" seja 48 px de verdade.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', '..', 'docs', 'design', 'icone');

// Ordem e nome de cada proposta (a pasta é o identificador).
const proposals = [
  { dir: '1-etiqueta', name: '1 · Etiqueta', line: 'A etiqueta de gôndola com o furo e um "b" escuro, sobre fundo ink' },
  { dir: '2-bipe', name: '2 · Bipe', line: 'O símbolo atual: barras de código e o laser coral, sobre o amarelo' },
  { dir: '3-casa', name: '3 · Casa-etiqueta', line: 'A etiqueta pendurada de pé vira casa; as barras são as janelas' },
  { dir: '4-etiqueta-inteira', name: '4 · Etiqueta inteira', line: 'O ícone todo é a etiqueta: o furo e as barras do símbolo, sem o laser' },
];

// Máscaras, na grade de 108 (a área visível é o quadrado de 18 a 90).
const masks = {
  círculo: '<circle cx="54" cy="54" r="36"/>',
  squircle: `<path d="${squircle(54, 54, 36, 4)}"/>`,
  'quadrado arredondado': '<rect x="18" y="18" width="72" height="72" rx="14"/>',
};

// Cores aproximadas de um tema do Material You (papel de parede azul).
const themed = {
  claro: { bg: '#D8E2FF', fg: '#1A2D4F' },
  escuro: { bg: '#2B3040', fg: '#D8E2FF' },
};
const walls = { claro: '#EEF0F3', escuro: '#111318' };

function squircle(cx, cy, r, n) {
  const pts = [];
  for (let i = 0; i < 360; i += 3) {
    const t = (i * Math.PI) / 180;
    const c = Math.cos(t);
    const s = Math.sin(t);
    const x = cx + r * Math.sign(c) * Math.pow(Math.abs(c), 2 / n);
    const y = cy + r * Math.sign(s) * Math.pow(Math.abs(s), 2 / n);
    pts.push(`${x.toFixed(2)} ${y.toFixed(2)}`);
  }
  return 'M' + pts.join('L') + 'Z';
}

function inner(file) {
  const svg = fs.readFileSync(file, 'utf8');
  return svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
}

function load(dir) {
  const p = path.join(root, dir);
  return {
    fundo: inner(path.join(p, 'fundo.svg')),
    frente: inner(path.join(p, 'frente.svg')),
    mono: inner(path.join(p, 'mono.svg')),
  };
}

let uid = 0;
function icon(layers, mask, size, theme) {
  const id = 'm' + uid++;
  const content = theme
    ? `<rect width="108" height="108" fill="${theme.bg}"/>` + layers.mono.replace(/#000"/g, theme.fg + '"')
    : layers.fundo + layers.frente;
  return `<svg width="${size}" height="${size}" viewBox="18 18 72 72"><defs><clipPath id="${id}">${masks[mask]}</clipPath></defs><g clip-path="url(#${id})">${content}</g></svg>`;
}

// Camada inteira (108 dp) sobre xadrez, com a área visível (72) e a zona segura (66).
function layer(content, size) {
  return `<svg class="checker" width="${size}" height="${size}" viewBox="0 0 108 108">${content}
    <rect x="18" y="18" width="72" height="72" fill="none" stroke="#2F80ED" stroke-width="0.6" stroke-dasharray="2 2"/>
    <circle cx="54" cy="54" r="33" fill="none" stroke="#E8573A" stroke-width="0.6" stroke-dasharray="2 2"/></svg>`;
}

const css = `
  * { box-sizing: border-box; margin: 0; }
  body { font-family: Figtree, 'Segoe UI', sans-serif; color: #1C1B1F; background: #FFFFFF; padding: 32px; width: 1320px; }
  h1 { font: 800 28px/34px Manrope, 'Segoe UI', sans-serif; }
  .sub { color: #5F5E66; font-size: 15px; margin: 4px 0 24px; }
  h2 { font: 700 13px/16px Figtree, 'Segoe UI', sans-serif; text-transform: uppercase; letter-spacing: .06em; color: #5F5E66; margin: 0 0 12px; }
  .row { display: flex; gap: 24px; align-items: flex-end; flex-wrap: wrap; }
  .cell { display: flex; flex-direction: column; align-items: center; gap: 8px; }
  .cap { font-size: 12px; line-height: 16px; color: inherit; opacity: .7; text-align: center; }
  .panel { border-radius: 20px; padding: 24px; margin-bottom: 20px; }
  .claro { background: ${walls.claro}; color: #1C1B1F; }
  .escuro { background: ${walls.escuro}; color: #F3F3F5; }
  .sep { width: 1px; align-self: stretch; background: currentColor; opacity: .15; }
  .checker { background: repeating-conic-gradient(#E6E6E6 0 25%, #FFFFFF 0 50%) 0 0 / 12px 12px; border-radius: 8px; }
  .legend { font-size: 12px; color: #5F5E66; margin-top: 8px; }
  .legend b { font-weight: 700; }
`;

function sheet(p) {
  const L = load(p.dir);
  const surface = (mode) => {
    const big = Object.keys(masks).map((m) => `<div class="cell">${icon(L, m, 192)}<div class="cap">${m} · 192</div></div>`).join('');
    const small = Object.keys(masks).map((m) => `<div class="cell">${icon(L, m, 48)}<div class="cap">48</div></div>`).join('');
    const mono = `<div class="cell">${icon(L, 'círculo', 192, themed[mode])}<div class="cap">temático · 192</div></div>
      <div class="cell">${icon(L, 'círculo', 48, themed[mode])}<div class="cap">48</div></div>`;
    return `<div class="panel ${mode}"><h2 style="color:inherit;opacity:.7">Fundo ${mode}</h2>
      <div class="row">${big}<div class="sep"></div>${small}<div class="sep"></div>${mono}</div></div>`;
  };
  return `<!doctype html><meta charset="utf-8"><style>${css}</style>
    <h1>${p.name}</h1><p class="sub">${p.line}</p>
    <div class="panel" style="background:#F5F5F3"><h2>Camadas (108 dp)</h2>
      <div class="row">
        <div class="cell">${layer(L.fundo, 192)}<div class="cap">fundo</div></div>
        <div class="cell">${layer(L.frente, 192)}<div class="cap">primeiro plano</div></div>
        <div class="cell">${layer(L.mono, 192)}<div class="cap">monocromático</div></div>
      </div>
      <p class="legend"><b style="color:#2F80ED">Azul</b>: área visível (72 dp). <b style="color:#E8573A">Coral</b>: zona segura (66 dp), que nenhuma máscara corta.</p>
    </div>
    ${surface('claro')}${surface('escuro')}`;
}

function comparison() {
  const all = proposals.map((p) => ({ p, L: load(p.dir) }));
  const row = (mode, theme) => `<div class="panel ${mode}"><h2 style="color:inherit;opacity:.7">${theme ? 'Temático, fundo ' + mode : 'Fundo ' + mode}</h2>
    <div class="row" style="gap:48px">${all.map(({ p, L }) => `<div class="cell">
      <div class="row" style="gap:16px">${icon(L, 'círculo', 48, theme)}${icon(L, 'squircle', 48, theme)}${icon(L, 'quadrado arredondado', 48, theme)}</div>
      <div class="cap">${p.name}</div></div>`).join('')}</div></div>`;
  return `<!doctype html><meta charset="utf-8"><style>${css}</style>
    <h1>Ícone do Bipa: as quatro propostas em 48 px</h1><p class="sub">Círculo, squircle e quadrado arredondado, no tamanho da tela inicial</p>
    ${row('claro')}${row('escuro')}${row('claro', themed.claro)}${row('escuro', themed.escuro)}`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1320, height: 800 }, deviceScaleFactor: 1 });
  const shots = proposals.map((p) => [sheet(p), path.join(root, p.dir, 'prancha.png')]);
  shots.push([comparison(), path.join(root, 'comparacao.png')]);
  for (const [html, out] of shots) {
    await page.setContent(html);
    await page.screenshot({ path: out, fullPage: true });
    console.log(path.relative(process.cwd(), out));
  }
  await browser.close();
})();
