/* @ds-bundle: {"format":4,"namespace":"Bipa","components":[{"name":"Button"},{"name":"Segmented"},{"name":"PriceTag"},{"name":"StockStepper"},{"name":"FilterChips"},{"name":"ProductCard"},{"name":"Carousel"},{"name":"SearchBar"},{"name":"ListPreview"},{"name":"ShoppingBar"},{"name":"SwipeRow"},{"name":"MarketChip"},{"name":"ScanNavBar"},{"name":"BipFeedback"},{"name":"Skeleton"},{"name":"ScanFrame"},{"name":"ScanTray"},{"name":"InsightCard"},{"name":"ShoppingList"}]} */
/*
 * Bipa: comportamento dos componentes, em JavaScript puro (sem React).
 * Cada componente expõe enhance(el), que liga animações e estados a um markup
 * pronto (veja os README de cada componente). Estilos em bundle.css.
 */
(function () {
  'use strict';

  var reducedMotion = function () {
    return typeof window.matchMedia === 'function' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  };

  /** Centavos para "7,99" (formato brasileiro, sem símbolo). */
  function formatCents(cents) {
    var abs = Math.abs(Math.round(cents));
    var reais = Math.floor(abs / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    var centavos = String(abs % 100).padStart(2, '0');
    return (cents < 0 ? '-' : '') + reais + ',' + centavos;
  }

  /** Troca o texto de um .bipa-roll com rolagem vertical (direção 'up' ou 'down'). */
  function roll(el, text, direction) {
    var dir = direction === 'down' ? 'down' : 'up';
    var current = el.lastElementChild;
    if (current && current.textContent === String(text)) return;
    var next = document.createElement('span');
    next.textContent = String(text);
    if (reducedMotion() || !current) {
      el.replaceChildren(next);
      return;
    }
    next.className = 'in-' + dir;
    current.className = 'out-' + dir;
    current.addEventListener('animationend', function () { current.remove(); }, { once: true });
    el.appendChild(next);
  }

  /** Conta de 0 até `cents` em `duration` ms, escrevendo em el.textContent. */
  function countUp(el, cents, duration) {
    var total = duration || 600;
    if (reducedMotion()) { el.textContent = formatCents(cents); return; }
    var start = null;
    function frame(now) {
      if (start === null) start = now;
      var t = Math.min(1, (now - start) / total);
      var eased = 1 - Math.pow(1 - t, 3);
      el.textContent = formatCents(cents * eased);
      if (t < 1) window.requestAnimationFrame(frame);
    }
    window.requestAnimationFrame(frame);
  }

  /** Anima o texto de el de `from` até `to` centavos (formato brasileiro). */
  function tweenCents(el, from, to, duration) {
    var total = duration || 380;
    if (reducedMotion()) { el.textContent = formatCents(to); return; }
    var start = null;
    function frame(now) {
      if (start === null) start = now;
      var t = Math.min(1, (now - start) / total);
      var eased = 1 - Math.pow(1 - t, 3);
      el.textContent = formatCents(from + (to - from) * eased);
      if (t < 1) window.requestAnimationFrame(frame);
    }
    window.requestAnimationFrame(frame);
  }

  /** Reinicia uma animação CSS removendo e recolocando a classe. */
  function replayClass(el, className) {
    el.classList.remove(className);
    void el.offsetWidth;
    el.classList.add(className);
  }

  var Button = {
    /** Botão com estados: clique simula salvar (carregando → concluído → volta). */
    enhance: function (button, options) {
      var opts = options || {};
      var busy = false;
      button.addEventListener('click', function () {
        if (busy || button.disabled) return;
        busy = true;
        button.classList.add('is-loading');
        button.setAttribute('aria-busy', 'true');
        window.setTimeout(function () {
          button.classList.remove('is-loading');
          button.classList.add('is-done');
          button.removeAttribute('aria-busy');
          window.setTimeout(function () {
            button.classList.remove('is-done');
            busy = false;
          }, opts.doneFor || 1400);
        }, opts.loadFor || 700);
      });
    }
  };

  var PriceTag = {
    /** Entrada da etiqueta: salta, conta o preço e risca o preço antigo. */
    play: function (tag) {
      var value = tag.querySelector('[data-cents]');
      replayClass(tag, 'is-entering');
      if (value) countUp(value, Number(value.getAttribute('data-cents')), 600);
      var badge = tag.parentElement && tag.parentElement.querySelector('.bipa-badge');
      if (badge) replayClass(badge, 'is-entering');
    },
    enhance: function (tag) { PriceTag.play(tag); }
  };

  // Segurar − ou + repete: espera 400ms e depois soma a cada 110ms.
  function bindRepeat(button, onStep) {
    var delay = null;
    var repeat = null;
    var repeated = false;
    function stop() { window.clearTimeout(delay); window.clearInterval(repeat); }
    button.addEventListener('pointerdown', function () {
      repeated = false;
      delay = window.setTimeout(function () {
        repeat = window.setInterval(function () { repeated = true; onStep(); }, 110);
      }, 400);
    });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(function (type) { button.addEventListener(type, stop); });
    button.addEventListener('click', function () {
      if (repeated) { repeated = false; return; }
      onStep();
    });
  }

  /**
   * Controle −/+ (.bipa-stepper). O valor e o mínimo vêm de data-value e
   * data-min em `host`, que recebe is-low/is-out. Retorna { step(delta) }.
   */
  function enhanceControl(stepper, host, onRender) {
    var qty = stepper.querySelector('.bipa-stepper__qty');
    var minus = stepper.querySelector('[data-step="-1"]');
    var plus = stepper.querySelector('[data-step="1"]');
    var min = Number(host.getAttribute('data-min') || 0);
    var value = Number(host.getAttribute('data-value') || 0);

    function render(direction) {
      roll(qty, value, direction);
      minus.disabled = value <= 0;
      host.classList.toggle('is-low', min > 0 && value < min);
      host.classList.toggle('is-out', value <= 0);
      host.setAttribute('data-value', String(value));
      if (onRender) onRender(value, min);
      if (direction) {
        replayClass(stepper, 'is-bip');
        host.dispatchEvent(new CustomEvent('bipa:change', { detail: { value: value } }));
      }
    }

    function step(delta) {
      if (delta < 0 && value <= 0) return;
      value += delta;
      render(delta > 0 ? 'up' : 'down');
    }

    bindRepeat(minus, function () { step(-1); });
    bindRepeat(plus, function () { step(1); });
    render(null);
    return { step: step };
  }

  /**
   * Atualiza o medidor (.bipa-gauge): o anel enche até o "ter sempre" (data-min)
   * e o número fica no centro. O rótulo acessível diz o estado por extenso.
   */
  function renderGauge(gauge, value, min, unit) {
    var percent = min > 0 ? Math.min(100, (value / min) * 100) : 100;
    gauge.style.setProperty('--p', String(Math.round(percent)));
    gauge.querySelector('.bipa-gauge__value').textContent = String(value);
    var label = value <= 0 ? 'Acabou' : (min > 0 && value < min ? value + ' de ' + min + ' ' + unit : value + ' ' + unit);
    gauge.setAttribute('aria-label', label);
  }

  var StockStepper = {
    /**
     * Lista calma de estoque (.bipa-shelf) ou só o controle (.bipa-stepper com
     * data-value e data-min). Na lista, cada .bipa-shelf__item[data-value][data-min][data-unit]
     * mostra só a informação; tocar na linha abre o editor (um por vez) com −/+ e
     * "Pôr na lista". Deslizar (SwipeRow) dá baixa ou põe na lista.
     * Emite "bipa:change" { value } e "bipa:list" { onList } no item.
     */
    enhance: function (root) {
      if (!root.classList.contains('bipa-shelf')) {
        enhanceControl(root, root);
        return;
      }
      var items = root.querySelectorAll('.bipa-shelf__item');

      function setOpen(item, open) {
        item.classList.toggle('is-open', open);
        item.querySelector('.bipa-shelf__row').setAttribute('aria-expanded', String(open));
      }

      Array.prototype.forEach.call(items, function (item) {
        var row = item.querySelector('.bipa-shelf__row');
        var gauge = item.querySelector('.bipa-gauge');
        var listButton = item.querySelector('.bipa-shelf__list');
        var onListMark = item.querySelector('.bipa-thumb__badge');
        var unit = item.getAttribute('data-unit') || '';
        var control = enhanceControl(item.querySelector('.bipa-stepper'), item, function (value, min) {
          renderGauge(gauge, value, min, unit);
        });

        function setList(on) {
          if (listButton) listButton.setAttribute('aria-pressed', String(on));
          if (onListMark) onListMark.hidden = !on;
          item.dispatchEvent(new CustomEvent('bipa:list', { detail: { onList: on } }));
        }

        setOpen(item, item.classList.contains('is-open'));
        row.addEventListener('click', function () {
          if (item.hasAttribute('data-dragged')) return;
          var open = !item.classList.contains('is-open');
          Array.prototype.forEach.call(items, function (other) { if (other !== item) setOpen(other, false); });
          setOpen(item, open);
        });
        if (listButton) {
          listButton.addEventListener('click', function () {
            setList(listButton.getAttribute('aria-pressed') !== 'true');
          });
        }
        item.addEventListener('bipa:swipe', function (event) {
          if (event.detail.action === 'used') control.step(-1);
          else setList(true);
        });
      });
    }
  };

  var SwipeRow = {
    /**
     * Deslizar a linha (.bipa-shelf__row dentro de `wrapper`): para a esquerda
     * dispara "bipa:swipe" { action: 'used' }, para a direita { action: 'list' }.
     * Passa de 30% da largura para valer. Um arraste não conta como toque.
     */
    enhance: function (wrapper) {
      var row = wrapper.querySelector('.bipa-shelf__row');
      var startX = 0;
      var dx = 0;
      var dragging = false;
      row.addEventListener('pointerdown', function (event) {
        var button = event.target.closest('button');
        if (button && button !== row) return;
        dragging = true;
        startX = event.clientX;
        dx = 0;
        row.style.transition = 'none';
        row.setPointerCapture(event.pointerId);
      });
      row.addEventListener('pointermove', function (event) {
        if (!dragging) return;
        dx = event.clientX - startX;
        if (Math.abs(dx) < 6) return;
        wrapper.setAttribute('data-dragged', '');
        row.style.transform = 'translateX(' + dx + 'px)';
        wrapper.classList.toggle('is-left', dx < 0);
        wrapper.classList.toggle('is-right', dx > 0);
      });
      function end() {
        if (!dragging) return;
        dragging = false;
        row.style.transition = '';
        row.style.transform = '';
        var threshold = wrapper.getBoundingClientRect().width * 0.3;
        if (Math.abs(dx) > threshold) {
          wrapper.dispatchEvent(new CustomEvent('bipa:swipe', { detail: { action: dx < 0 ? 'used' : 'list' } }));
        }
        // O clique que vem depois do arraste é ignorado; limpa no próximo ciclo.
        window.setTimeout(function () { wrapper.removeAttribute('data-dragged'); }, 0);
        window.setTimeout(function () { wrapper.classList.remove('is-left', 'is-right'); }, 300);
      }
      row.addEventListener('pointerup', end);
      row.addEventListener('pointercancel', end);
    }
  };

  var FilterChips = {
    /**
     * Chips de filtro de uma escolha só (.bipa-filter > button[data-value]).
     * Emite "bipa:filter" { value }. Com data-target (seletor), esconde os itens
     * [data-place] dentro dele cujo local não bate (o valor "all" mostra tudo).
     * A variante .bipa-filter--tiles mostra os locais como categorias com arte.
     */
    enhance: function (group) {
      var buttons = group.querySelectorAll('button[data-value]');
      var target = group.getAttribute('data-target');
      function apply(value) {
        if (!target) return;
        Array.prototype.forEach.call(document.querySelectorAll(target + ' [data-place]'), function (item) {
          item.classList.toggle('is-filtered', value !== 'all' && item.getAttribute('data-place') !== value);
        });
      }
      Array.prototype.forEach.call(buttons, function (button) {
        button.addEventListener('click', function () {
          Array.prototype.forEach.call(buttons, function (other) { other.setAttribute('aria-pressed', String(other === button)); });
          var value = button.getAttribute('data-value');
          apply(value);
          group.dispatchEvent(new CustomEvent('bipa:filter', { detail: { value: value } }));
        });
      });
    }
  };

  var ProductCard = {
    /** Cartão de produto (.bipa-pcard): o "+" alterna "na lista" e emite "bipa:list" { onList }. */
    enhance: function (card) {
      var add = card.querySelector('.bipa-pcard__add');
      if (!add) return;
      add.addEventListener('click', function (event) {
        event.stopPropagation();
        var on = add.getAttribute('aria-pressed') !== 'true';
        add.setAttribute('aria-pressed', String(on));
        add.setAttribute('aria-label', on ? 'Tirar da lista' : 'Pôr na lista');
        card.dispatchEvent(new CustomEvent('bipa:list', { detail: { onList: on } }));
      });
    }
  };

  var Carousel = {
    /** Carrossel (.bipa-carousel): os pontos (.bipa-dots i) acompanham o cartão visível e levam até ele ao toque. */
    enhance: function (root) {
      var track = root.querySelector('.bipa-carousel__track');
      var dots = root.querySelectorAll('.bipa-dots i');
      function current() { return Math.round(track.scrollLeft / Math.max(1, track.clientWidth)); }
      function render() {
        var index = current();
        Array.prototype.forEach.call(dots, function (dot, i) { dot.setAttribute('aria-current', String(i === index)); });
      }
      track.addEventListener('scroll', function () { window.requestAnimationFrame(render); }, { passive: true });
      Array.prototype.forEach.call(dots, function (dot, i) {
        dot.addEventListener('click', function () {
          track.scrollTo({ left: i * track.clientWidth, behavior: reducedMotion() ? 'auto' : 'smooth' });
        });
      });
      render();
    }
  };

  var SearchBar = {
    /** Busca (.bipa-search): tocar na barra foca o campo; o botão de bipar emite "bipa:scan". */
    enhance: function (bar) {
      var input = bar.querySelector('input');
      var scan = bar.querySelector('.bipa-search__scan');
      bar.addEventListener('click', function (event) { if (!event.target.closest('button')) input.focus(); });
      if (scan) scan.addEventListener('click', function () { bar.dispatchEvent(new CustomEvent('bipa:scan')); });
    }
  };

  var ShoppingBar = {
    /** Barra da compra (.bipa-cartbar): atualiza o progresso e o total. update({ done, total, cents }). */
    enhance: function (bar) {
      var strong = bar.querySelector('.bipa-cartbar__text strong');
      var fill = bar.querySelector('.bipa-cartbar__progress');
      return {
        update: function (state) {
          if (strong) strong.textContent = state.done + ' de ' + state.total + ' itens';
          if (fill) fill.style.setProperty('--p', String(Math.round((state.done / Math.max(1, state.total)) * 100)));
          var money = bar.querySelector('[data-cents]');
          if (money && state.cents != null) {
            tweenCents(money, Number(money.getAttribute('data-cents')), state.cents);
            money.setAttribute('data-cents', String(state.cents));
          }
        }
      };
    }
  };

  var MarketChip = {
    /** Entrada em cascata de uma lista de chips. */
    enhance: function (container) {
      var chips = container.querySelectorAll('.bipa-chip');
      Array.prototype.forEach.call(chips, function (chip, index) {
        chip.style.animationDelay = (index * 60) + 'ms';
        chip.classList.add('bipa-enter');
      });
    }
  };

  var ScanNavBar = {
    /**
     * Indicador da aba ativa que desliza com mola; menu do bipar no toque longo
     * (.bipa-scan-menu); barra compacta ao rolar para baixo (options.scroller).
     * options: { scroller?: Element, scrim?: Element, longPressMs?: number }
     */
    enhance: function (nav, options) {
      var opts = options || {};
      var indicator = nav.querySelector('.bipa-nav__indicator');
      var dests = nav.querySelectorAll('.bipa-nav__dest');

      function moveTo(dest) {
        var icon = dest.querySelector('.bipa-nav__icon');
        var navBox = nav.getBoundingClientRect();
        var box = icon.getBoundingClientRect();
        indicator.style.width = box.width + 'px';
        indicator.style.transform = 'translateX(' + (box.left - navBox.left) + 'px)';
        Array.prototype.forEach.call(dests, function (d) {
          if (d === dest) d.setAttribute('aria-current', 'page');
          else d.removeAttribute('aria-current');
        });
      }

      Array.prototype.forEach.call(dests, function (dest) {
        dest.addEventListener('click', function () { moveTo(dest); });
      });
      var active = nav.querySelector('.bipa-nav__dest[aria-current="page"]') || dests[0];
      if (active && indicator) {
        indicator.style.transition = 'none';
        moveTo(active);
        void indicator.offsetWidth;
        indicator.style.transition = '';
      }

      var scan = nav.querySelector('.bipa-scan');
      var menu = nav.querySelector('.bipa-scan-menu');
      var scrim = opts.scrim || null;
      if (scan && menu) {
        var timer = null;
        var openedByPress = false;
        var setOpen = function (open) {
          scan.classList.toggle('is-open', open);
          menu.classList.toggle('is-open', open);
          if (scrim) scrim.classList.toggle('is-open', open);
          scan.setAttribute('aria-expanded', String(open));
          scan.setAttribute('aria-label', open ? 'Fechar menu' : 'Bipar (segure para mais opções)');
        };
        scan.addEventListener('pointerdown', function () {
          if (scan.classList.contains('is-open')) return;
          scan.classList.add('is-pressing');
          timer = window.setTimeout(function () {
            scan.classList.remove('is-pressing');
            openedByPress = true;
            setOpen(true);
          }, opts.longPressMs || 420);
        });
        var cancel = function () {
          window.clearTimeout(timer);
          scan.classList.remove('is-pressing');
        };
        scan.addEventListener('pointerup', cancel);
        scan.addEventListener('pointerleave', cancel);
        scan.addEventListener('pointercancel', cancel);
        scan.addEventListener('click', function () {
          if (openedByPress) { openedByPress = false; return; }
          if (scan.classList.contains('is-open')) setOpen(false);
          else nav.dispatchEvent(new CustomEvent('bipa:scan'));
        });
        Array.prototype.forEach.call(menu.querySelectorAll('.bipa-scan-menu__item'), function (item) {
          item.addEventListener('click', function () {
            setOpen(false);
            nav.dispatchEvent(new CustomEvent('bipa:scan', { detail: { action: item.getAttribute('data-action') } }));
          });
        });
        if (scrim) scrim.addEventListener('click', function () { setOpen(false); });
        setOpen(false);
      }

      var scroller = opts.scroller;
      if (scroller) {
        var last = scroller.scrollTop;
        scroller.addEventListener('scroll', function () {
          var y = scroller.scrollTop;
          if (y > last + 4 && y > 24) nav.classList.add('is-compact');
          else if (y < last - 4) nav.classList.remove('is-compact');
          last = y;
        }, { passive: true });
      }
    }
  };

  var BipFeedback = {
    /** Toca o "Bipou!": círculo, check desenhado, onda e aviso. */
    play: function (el) { replayClass(el, 'is-playing'); },
    enhance: function (el) { BipFeedback.play(el); }
  };

  var Skeleton = {
    /** O brilho é só CSS; enhance existe por consistência. */
    enhance: function () {}
  };

  var ScanFrame = {
    /**
     * Visor da câmera: procura (laser e cantos respirando), trava no código
     * (moldura encolhe e fica verde), clarão de captura e, 150ms depois, o
     * evento "bipa:captured". Com options.loop, repete a demonstração.
     */
    enhance: function (viewfinder, options) {
      var opts = options || {};
      var frame = viewfinder.querySelector('.bipa-frame');
      var hint = viewfinder.querySelector('.bipa-viewfinder__hint');
      var idleText = hint ? hint.textContent : '';
      function search() {
        frame.classList.remove('is-locked');
        frame.classList.add('is-searching');
        viewfinder.classList.remove('is-captured');
        if (hint) hint.textContent = idleText;
      }
      function lock(code) {
        frame.classList.remove('is-searching');
        frame.classList.add('is-locked');
        replayClass(viewfinder, 'is-captured');
        if (hint) hint.textContent = code || 'Achei!';
        window.setTimeout(function () {
          viewfinder.dispatchEvent(new CustomEvent('bipa:captured', { detail: { code: code } }));
        }, 150);
      }
      search();
      if (opts.loop) {
        var cycle = function () {
          window.setTimeout(function () {
            lock(opts.code || '7891000100103');
            window.setTimeout(function () { search(); cycle(); }, 1800);
          }, 2200);
        };
        cycle();
      }
      return { search: search, lock: lock };
    }
  };

  var ScanTray = {
    /**
     * Bandeja do modo carrinho. add({ name, cents }) empilha um item no topo;
     * o total soma só os itens marcados como "levar".
     */
    enhance: function (tray) {
      var list = tray.querySelector('.bipa-tray__list');
      var count = tray.querySelector('.bipa-tray__count-value');
      var total = tray.querySelector('.bipa-tray__total-value');
      var current = 0;

      function sum() {
        var cents = 0;
        Array.prototype.forEach.call(list.children, function (row) {
          if (!row.classList.contains('is-skipped')) cents += Number(row.getAttribute('data-cents'));
        });
        return cents;
      }
      function refresh() {
        roll(count, list.children.length, 'up');
        var next = sum();
        tweenCents(total, current, next);
        current = next;
      }
      function bindToggle(row) {
        var toggle = row.querySelector('.bipa-toggle');
        toggle.addEventListener('click', function () {
          var on = toggle.getAttribute('aria-checked') !== 'true';
          toggle.setAttribute('aria-checked', String(on));
          row.classList.toggle('is-skipped', !on);
          refresh();
        });
      }
      Array.prototype.forEach.call(list.children, bindToggle);
      current = sum();
      total.textContent = formatCents(current);

      return {
        add: function (item) {
          var row = document.createElement('div');
          row.className = 'bipa-tray__item is-new';
          row.setAttribute('data-cents', String(item.cents));
          var name = document.createElement('span');
          name.className = 'bipa-tray__item-name';
          name.textContent = item.name;
          var price = document.createElement('span');
          price.className = 'bipa-tray__item-price';
          price.textContent = 'R$ ' + formatCents(item.cents);
          var toggle = document.createElement('button');
          toggle.type = 'button';
          toggle.className = 'bipa-toggle';
          toggle.setAttribute('role', 'switch');
          toggle.setAttribute('aria-checked', 'true');
          toggle.setAttribute('aria-label', 'Levar ' + item.name);
          row.append(name, price, toggle);
          list.prepend(row);
          bindToggle(row);
          refresh();
        }
      };
    }
  };

  var InsightCard = {
    /** Conta o número principal ([data-cents]) e os fatos ([data-count]); dispensa o cartão no X. */
    enhance: function (card) {
      var number = card.querySelector('[data-cents]');
      if (number) countUp(number, Number(number.getAttribute('data-cents')), 700);
      // Números inteiros dos fatos ([data-count]) contam junto com a régua.
      Array.prototype.forEach.call(card.querySelectorAll('[data-count]'), function (el) {
        var target = Number(el.getAttribute('data-count'));
        if (reducedMotion()) { el.textContent = String(target); return; }
        var start = null;
        function frame(now) {
          if (start === null) start = now;
          var t = Math.min(1, (now - start) / 600);
          el.textContent = String(Math.round(target * (1 - Math.pow(1 - t, 3))));
          if (t < 1) window.requestAnimationFrame(frame);
        }
        window.requestAnimationFrame(frame);
      });
      var info = card.querySelector('.bipa-insight__info');
      if (info) {
        info.addEventListener('click', function () {
          var on = !card.classList.contains('is-explained');
          card.classList.toggle('is-explained', on);
          info.setAttribute('aria-expanded', String(on));
        });
      }
      var dismiss = card.querySelector('.bipa-insight__dismiss');
      if (dismiss) {
        dismiss.addEventListener('click', function () {
          card.classList.add('is-dismissed');
          card.dispatchEvent(new CustomEvent('bipa:dismiss'));
        });
      }
    }
  };

  var ShoppingList = {
    /**
     * Adicionar rápido (.bipa-quick__tile alterna aria-pressed) e lista por
     * corredor: marcar um item risca, desce para o fim do corredor com
     * animação e atualiza o progresso (.bipa-progress).
     */
    enhance: function (root) {
      Array.prototype.forEach.call(root.querySelectorAll('.bipa-quick__tile'), function (tile) {
        tile.addEventListener('click', function () {
          var on = tile.getAttribute('aria-pressed') !== 'true';
          tile.setAttribute('aria-pressed', String(on));
        });
      });

      var items = root.querySelectorAll('.bipa-list__item');
      var fill = root.querySelector('.bipa-progress__fill');
      var done = root.querySelector('.bipa-progress__done');

      function progress() {
        var all = root.querySelectorAll('.bipa-list__item').length;
        var checked = root.querySelectorAll('.bipa-list__item.is-done').length;
        if (fill) fill.style.transform = 'scaleX(' + (all ? checked / all : 0) + ')';
        if (done) roll(done, checked, 'up');
      }

      function flipMove(item) {
        var group = item.parentElement;
        var siblings = Array.prototype.slice.call(group.querySelectorAll('.bipa-list__item'));
        var before = new Map(siblings.map(function (el) { return [el, el.getBoundingClientRect().top]; }));
        var firstDone = group.querySelector('.bipa-list__item.is-done:not([data-moving])');
        item.setAttribute('data-moving', '');
        if (item.classList.contains('is-done')) group.appendChild(item);
        else if (firstDone && firstDone !== item) group.insertBefore(item, firstDone);
        item.removeAttribute('data-moving');
        if (reducedMotion()) return;
        siblings.forEach(function (el) {
          var delta = before.get(el) - el.getBoundingClientRect().top;
          if (!delta) return;
          el.style.transition = 'none';
          el.style.transform = 'translateY(' + delta + 'px)';
          void el.offsetWidth;
          el.style.transition = '';
          el.style.transform = '';
        });
      }

      Array.prototype.forEach.call(items, function (item) {
        item.addEventListener('click', function () {
          item.classList.toggle('is-done');
          item.setAttribute('aria-pressed', String(item.classList.contains('is-done')));
          progress();
          window.setTimeout(function () { flipMove(item); }, 260);
        });
      });
      progress();
    }
  };

  var Segmented = {
    /** Seletor segmentado: o indicador desliza até o botão escolhido. Emite "bipa:select". */
    enhance: function (group) {
      var indicator = group.querySelector('.bipa-segmented__indicator');
      var buttons = group.querySelectorAll('button');
      function select(button, animate) {
        var box = group.getBoundingClientRect();
        var b = button.getBoundingClientRect();
        if (!animate) indicator.style.transition = 'none';
        indicator.style.width = b.width + 'px';
        indicator.style.transform = 'translateX(' + (b.left - box.left) + 'px)';
        if (!animate) { void indicator.offsetWidth; indicator.style.transition = ''; }
        Array.prototype.forEach.call(buttons, function (other) {
          other.setAttribute('aria-pressed', String(other === button));
        });
      }
      Array.prototype.forEach.call(buttons, function (button) {
        button.addEventListener('click', function () {
          select(button, true);
          group.dispatchEvent(new CustomEvent('bipa:select', { detail: { value: button.getAttribute('data-value') } }));
        });
      });
      select(group.querySelector('button[aria-pressed="true"]') || buttons[0], false);
    }
  };

  window.Bipa = {
    version: '4.0.0',
    formatCents: formatCents,
    roll: roll,
    countUp: countUp,
    tweenCents: tweenCents,
    Button: Button,
    Segmented: Segmented,
    PriceTag: PriceTag,
    StockStepper: StockStepper,
    FilterChips: FilterChips,
    ProductCard: ProductCard,
    Carousel: Carousel,
    SearchBar: SearchBar,
    ShoppingBar: ShoppingBar,
    SwipeRow: SwipeRow,
    MarketChip: MarketChip,
    ScanNavBar: ScanNavBar,
    BipFeedback: BipFeedback,
    Skeleton: Skeleton,
    ScanFrame: ScanFrame,
    ScanTray: ScanTray,
    InsightCard: InsightCard,
    ShoppingList: ShoppingList
  };
})();
