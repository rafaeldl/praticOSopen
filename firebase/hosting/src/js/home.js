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
