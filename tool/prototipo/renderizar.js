// Gera as imagens do protótipo (docs/design/prototipo/telas/*.png) a partir
// do HTML em docs/design/prototipo/fonte/, em 390 px de largura e escala 2.
//
// Uso, na raiz do repositório (precisa do Playwright com o Chromium):
//   node tool/prototipo/renderizar.js                 # todas as telas
//   node tool/prototipo/renderizar.js Lista.dc.html   # só as indicadas
//
// O tamanho de cada tela vem de fonte/canvas.json (o mesmo do protótipo
// publicado). As fontes do Google e o support.js do canvas ficam de fora:
// a captura usa as fontes instaladas no sistema.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', '..', 'docs', 'design', 'prototipo');
const source = path.join(root, 'fonte');
const out = path.join(root, 'telas');
const boards = JSON.parse(fs.readFileSync(path.join(source, 'canvas.json'))).boards;
const wanted = process.argv.slice(2);
const names = wanted.length ? wanted : Object.keys(boards);

(async () => {
  const browser = await chromium.launch();
  for (const name of names) {
    const board = boards[name];
    if (!board) {
      console.log(`${name}: não está em canvas.json`);
      continue;
    }
    const page = await browser.newPage({
      viewport: { width: board.w, height: board.h },
      deviceScaleFactor: 2,
      reducedMotion: 'reduce',
    });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.route(/fonts\.googleapis|fonts\.gstatic|support\.js/, (r) => r.abort());
    await page.goto('file://' + path.join(source, name));
    await page.waitForTimeout(2200);
    await page.screenshot({ path: path.join(out, name.replace('.dc.html', '.png')) });
    console.log(name, errors.length ? 'ERROS: ' + errors.join(' | ') : 'ok');
    await page.close();
  }
  await browser.close();
})();
