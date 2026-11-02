(function () {
  var tabs = [].slice.call(document.querySelectorAll('[data-tabs] [role="tab"]'));

  function select(tab, focus) {
    tabs.forEach(function (t) {
      var on = t === tab;
      t.setAttribute('aria-selected', on ? 'true' : 'false');
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
    });
    if (focus) tab.focus();
  }

  tabs.forEach(function (t, i) {
    t.addEventListener('click', function () { select(t); });
    t.addEventListener('keydown', function (e) {
      var d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (!d) return;
      e.preventDefault();
      select(tabs[(i + d + tabs.length) % tabs.length], true);
    });
  });

  // Rows are plain scrollers, so touch swipes work natively. The script adds the slow
  // advance and mouse dragging; clones make the loop seamless and stay out of the tab order.
  var reels = document.querySelector('[data-reels]');
  var toggle = document.querySelector('[data-reels-toggle]');
  if (reels && toggle) {
    var LOOP_SECONDS = 90;
    var DRAG_THRESHOLD = 6;
    var TOUCH_RESUME_MS = 1500;
    var moving = false;
    var paused = false;
    var hovering = false;
    var drag = null;
    var skipClick = false;
    var lastFrame = 0;
    var rowsOf = [].slice.call(reels.querySelectorAll('[data-reel]')).map(function (el) {
      return { el: el, back: el.classList.contains('reel--back'), pos: 0, held: false, resumeAt: 0 };
    });

    var advancing = function (row) {
      return moving && !paused && !hovering && !row.held && Date.now() >= row.resumeAt;
    };

    // Half the width is one full pass, so jumping by it is invisible.
    var wrap = function (row) {
      if (!moving) return;
      var half = row.el.scrollWidth / 2;
      if (row.el.scrollLeft >= half) row.el.scrollLeft -= half;
      else if (row.el.scrollLeft <= 0) row.el.scrollLeft += half;
    };

    var tick = function (now) {
      if (!moving) return;
      var seconds = Math.min((now - lastFrame) / 1000, 0.1);
      lastFrame = now;
      rowsOf.forEach(function (row) {
        if (!advancing(row)) return;
        var half = row.el.scrollWidth / 2;
        row.pos += (row.back ? -1 : 1) * (half / LOOP_SECONDS) * seconds;
        if (row.pos >= half) row.pos -= half;
        if (row.pos <= 0) row.pos += half;
        row.el.scrollLeft = row.pos;
      });
      requestAnimationFrame(tick);
    };

    var setPaused = function (value) {
      paused = value;
      toggle.textContent = toggle.getAttribute(value ? 'data-resume' : 'data-pause');
    };

    var startReels = function () {
      rowsOf.forEach(function (row) {
        [].slice.call(row.el.children).forEach(function (item) {
          var copy = item.cloneNode(true);
          copy.setAttribute('aria-hidden', 'true');
          copy.setAttribute('data-copy', '');
          copy.querySelector('a').tabIndex = -1;
          row.el.appendChild(copy);
        });
      });
      reels.classList.add('is-moving');
      moving = true;
      rowsOf.forEach(function (row) {
        if (row.back && !row.el.scrollLeft) row.el.scrollLeft = row.el.scrollWidth / 2;
        row.pos = row.el.scrollLeft;
      });
      setPaused(false);
      lastFrame = performance.now();
      requestAnimationFrame(tick);
    };

    // A focused link must stay reachable, so keyboard users get the hand-scrolled rows.
    var stopReels = function () {
      moving = false;
      reels.classList.remove('is-moving');
      [].slice.call(reels.querySelectorAll('[data-copy]')).forEach(function (c) { c.remove(); });
      setPaused(true);
    };

    rowsOf.forEach(function (row) {
      row.el.addEventListener('scroll', function () {
        if (advancing(row)) return;
        wrap(row);
        row.pos = row.el.scrollLeft;
      }, { passive: true });

      row.el.addEventListener('pointerdown', function (e) {
        if (e.pointerType !== 'mouse' || e.button !== 0) return;
        row.held = true;
        drag = { row: row, startX: e.clientX, startLeft: row.el.scrollLeft, moved: false };
      });

      row.el.addEventListener('touchstart', function () { row.held = true; }, { passive: true });
      ['touchend', 'touchcancel'].forEach(function (type) {
        row.el.addEventListener(type, function () {
          row.held = false;
          row.resumeAt = Date.now() + TOUCH_RESUME_MS;
        }, { passive: true });
      });

      // Images and links would otherwise start the browser's own drag.
      row.el.addEventListener('dragstart', function (e) { e.preventDefault(); });

      // A drag ends with a click on whatever is under the mouse; that one must not navigate.
      row.el.addEventListener('click', function (e) {
        if (!skipClick) return;
        skipClick = false;
        e.preventDefault();
      }, true);
    });

    window.addEventListener('pointermove', function (e) {
      if (!drag) return;
      var dx = e.clientX - drag.startX;
      if (!drag.moved && Math.abs(dx) < DRAG_THRESHOLD) return;
      if (!drag.moved) {
        drag.moved = true;
        drag.row.el.classList.add('is-dragging');
      }
      var el = drag.row.el;
      var target = drag.startLeft - dx;
      el.scrollLeft = target;
      wrap(drag.row);
      // After a loop jump, keep following the mouse from the new position.
      drag.startLeft += el.scrollLeft - target;
      drag.row.pos = el.scrollLeft;
    });

    var endDrag = function () {
      if (!drag) return;
      drag.row.held = false;
      drag.row.el.classList.remove('is-dragging');
      skipClick = drag.moved;
      // Keep the flag only for the click of this release; a drag released off the row has none.
      setTimeout(function () { skipClick = false; }, 0);
      drag = null;
    };
    window.addEventListener('pointerup', endDrag);
    window.addEventListener('pointercancel', endDrag);

    reels.addEventListener('pointerenter', function (e) { if (e.pointerType === 'mouse') hovering = true; });
    reels.addEventListener('pointerleave', function (e) { if (e.pointerType === 'mouse') hovering = false; });

    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      reels.addEventListener('focusin', function (e) {
        if (moving && e.target.matches(':focus-visible')) stopReels();
      });

      toggle.addEventListener('click', function () {
        if (!moving) startReels();
        else setPaused(!paused);
      });

      toggle.hidden = false;
      startReels();
    }
  }

  // The card stays complete at rest; one pass plays on load, replays are manual.
  var demo = document.querySelector('[data-demo]');
  if (!demo || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var line = demo.querySelector('[data-demo-line]');
  var done = demo.querySelector('[data-demo-done]');
  var again = demo.querySelector('[data-demo-again]');
  var rows = [].slice.call(demo.querySelectorAll('[data-demo-row]'));
  var words = line.textContent.trim().split(' ').map(function (w) {
    var s = document.createElement('span');
    s.textContent = w;
    return s;
  });

  line.textContent = '';
  words.forEach(function (s, i) {
    if (i) line.appendChild(document.createTextNode(' '));
    line.appendChild(s);
  });

  var timers = [];
  function at(ms, fn) { timers.push(setTimeout(fn, ms)); }

  function showAll() {
    timers.forEach(clearTimeout);
    timers = [];
    words.forEach(function (s) { s.classList.remove('is-off'); });
    rows.forEach(function (r) { r.classList.remove('is-off'); });
    done.classList.remove('is-off');
    demo.classList.remove('is-speaking');
    again.hidden = false;
  }

  function play() {
    timers.forEach(clearTimeout);
    timers = [];
    again.hidden = true;
    words.forEach(function (s) { s.classList.add('is-off'); });
    rows.forEach(function (r) { r.classList.add('is-off'); });
    done.classList.add('is-off');
    demo.classList.add('is-speaking');
    words.forEach(function (s, i) { at(350 + i * 300, function () { s.classList.remove('is-off'); }); });
    var t = 350 + words.length * 300 + 250;
    at(t, function () { demo.classList.remove('is-speaking'); });
    rows.forEach(function (r, i) { at(t + 200 + i * 240, function () { r.classList.remove('is-off'); }); });
    at(t + 200 + rows.length * 240 + 150, showAll);
  }

  again.addEventListener('click', play);
  document.addEventListener('visibilitychange', function () { if (document.hidden) showAll(); });
  play();
})();
