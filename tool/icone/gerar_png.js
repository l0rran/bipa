// Gera os PNGs legados do ícone do app (Android anterior ao 8, que não lê o
// ícone adaptativo): android/app/src/main/res/mipmap-*/ic_launcher.png
// (quadrado arredondado) e ic_launcher_round.png (círculo).
//
// O desenho é o da proposta escolhida, docs/design/icone/1-etiqueta (fundo.svg
// e frente.svg), recortado na área visível de 72 dp da grade de 108.
//
// Uso, na raiz do repositório (precisa do Playwright com o Chromium, como
// tool/icone/renderizar.js):
//   npm i --prefix <pasta-temporária> playwright
//   NODE_PATH=<pasta-temporária>/node_modules node tool/icone/gerar_png.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const raiz = path.join(__dirname, '..', '..');
const camadas = path.join(raiz, 'docs', 'design', 'icone', '1-etiqueta');
const res = path.join(raiz, 'android', 'app', 'src', 'main', 'res');

// Tamanho de 48 dp em cada densidade.
const densidades = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };

function interior(arquivo) {
  const svg = fs.readFileSync(path.join(camadas, arquivo), 'utf8');
  return svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
}

const desenho = interior('fundo.svg') + interior('frente.svg');

// Área visível (18 a 90). O raio do quadrado arredondado é o das máscaras das
// pranchas (14 em 72).
const formas = {
  ic_launcher: '<rect x="18" y="18" width="72" height="72" rx="14"/>',
  ic_launcher_round: '<circle cx="54" cy="54" r="36"/>',
};

function html(forma, tamanho) {
  return `<body style="margin:0;background:transparent"><svg width="${tamanho}" height="${tamanho}" viewBox="18 18 72 72"><defs><clipPath id="m">${forma}</clipPath></defs><g clip-path="url(#m)">${desenho}</g></svg></body>`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [densidade, tamanho] of Object.entries(densidades)) {
    await page.setViewportSize({ width: tamanho, height: tamanho });
    for (const [nome, forma] of Object.entries(formas)) {
      await page.setContent(html(forma, tamanho));
      const destino = path.join(res, `mipmap-${densidade}`, `${nome}.png`);
      await page.screenshot({ path: destino, omitBackground: true });
      console.log(destino);
    }
  }
  await browser.close();
})();
