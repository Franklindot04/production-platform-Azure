/* Site script: mode toggle, drawer, on this page, anchors, search, copy buttons, tables. No dependencies. */
/* The exact Mermaid version that draws the diagrams. Change it here. */
const MERMAID_VERSION = "11.17.2";

(function () {
  "use strict";

  var root = document.documentElement;
  var STORE_KEY = "pp-mode";

  function qs(sel, ctx) { return (ctx || document).querySelector(sel); }
  function qsa(sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }

  /* Colour mode. The inline script in the head sets the saved value before the first paint. */
  function currentMode() {
    var m = root.getAttribute("data-theme");
    if (m === "light" || m === "dark") { return m; }
    var dark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    return dark ? "dark" : "light";
  }

  function initMode() {
    var btn = qs("#mode-toggle");
    if (!btn) { return; }
    function label() {
      var next = currentMode() === "dark" ? "light" : "dark";
      btn.setAttribute("aria-label", "Switch to " + next + " mode");
    }
    label();
    btn.addEventListener("click", function () {
      var next = currentMode() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem(STORE_KEY, next); } catch (e) { /* storage can throw */ }
      label();
      document.dispatchEvent(new CustomEvent("pp-mode"));
    });
  }

  /* Drawer under 1024px. Open: focus moves in, Escape, the scrim and a link close it, the
     page behind is inert and does not scroll, focus returns to the menu button. */
  function initMenu() {
    var btn = qs("#menu-button");
    var drawer = qs("#sidebar");
    var scrim = qs("#scrim");
    if (!btn || !drawer) { return; }
    var behind = ["#main", "#toc"].map(function (sel) { return qs(sel); }).filter(Boolean);
    function set(open, returnFocus) {
      root.classList.toggle("menu-open", open);
      btn.setAttribute("aria-expanded", open ? "true" : "false");
      behind.forEach(function (el) {
        if (open) { el.setAttribute("inert", ""); } else { el.removeAttribute("inert"); }
      });
      if (open) {
        var nav = qs(".site-nav", drawer);
        if (nav) { nav.scrollTop = 0; }
        var first = qs(".nav-chev, .nav-label", drawer);
        if (first) { first.focus({ preventScroll: true }); }
      } else if (returnFocus) {
        btn.focus();
      }
    }
    btn.addEventListener("click", function () { set(!root.classList.contains("menu-open"), true); });
    if (scrim) { scrim.addEventListener("click", function () { set(false, true); }); }
    drawer.addEventListener("click", function (e) {
      if (e.target.closest("a") && root.classList.contains("menu-open")) { set(false, false); }
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && root.classList.contains("menu-open")) { set(false, true); }
    });
    window.addEventListener("resize", function () {
      if (window.innerWidth >= 1024 && root.classList.contains("menu-open")) { set(false, false); }
    });
  }

  /* Sidebar groups. The chevron and a label without a landing page toggle the list. All groups
     are open without scripting. Folder groups start closed. The group with the current page is
     always open on load. The open state is saved in localStorage under one key. */
  function initNavGroups() {
    var KEY = "pp-nav";
    var saved = {};
    try { saved = JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { saved = {}; }
    qsa(".nav-group[data-group]").forEach(function (g) {
      var id = g.getAttribute("data-group");
      var title = g.getAttribute("data-title");
      var list = qs(".nav-list", g);
      var chev = qs(".nav-chev", g);
      if (!list) { return; }
      var toggles = qsa(".nav-chev, .nav-label-toggle", g);
      var open = Object.prototype.hasOwnProperty.call(saved, id) ? !!saved[id] : g.getAttribute("data-kind") !== "folder";
      if (g.getAttribute("data-has-current") === "true") { open = true; }
      function apply(state) {
        list.hidden = !state;
        toggles.forEach(function (t) { t.setAttribute("aria-expanded", state ? "true" : "false"); });
        if (chev) { chev.setAttribute("aria-label", (state ? "Collapse " : "Expand ") + title); }
        open = state;
      }
      apply(open);
      toggles.forEach(function (t) {
        t.addEventListener("click", function () {
          apply(!open);
          saved[id] = open;
          try { localStorage.setItem(KEY, JSON.stringify(saved)); } catch (e) { /* storage can throw */ }
        });
      });
    });
  }

  /* Marks the heading that is in view in the "On this page" list. */
  function watchHeadings(heads, links, count) {
    if (!("IntersectionObserver" in window)) { return; }
    var current = null;
    function mark(i) {
      if (current === i) { return; }
      current = i;
      links.forEach(function (a, n) {
        var on = (n % count) === i;
        a.classList.toggle("is-current", on);
        if (on) { a.setAttribute("aria-current", "true"); } else { a.removeAttribute("aria-current"); }
      });
    }
    var visible = {};
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { visible[en.target.id] = en.isIntersecting; });
      for (var i = 0; i < heads.length; i++) {
        if (visible[heads[i].id]) { mark(i); return; }
      }
    }, { rootMargin: "-72px 0px -65% 0px" });
    heads.forEach(function (h) { observer.observe(h); });
  }

  /* On this page, built from h2 and h3 that have an id. The right column shows it from 1280px.
     Below that a closed disclosure at the top of the content holds the same list.
     Anchor links on every heading with an id. */
  function tocList(tocHeads) {
    var ul = document.createElement("ul");
    tocHeads.forEach(function (h) {
      var li = document.createElement("li");
      if (h.tagName === "H3") { li.className = "toc-h3"; }
      var a = document.createElement("a");
      a.href = "#" + h.id;
      a.textContent = h.textContent;
      li.appendChild(a);
      ul.appendChild(li);
    });
    return ul;
  }

  function initHeadings() {
    var heads = qsa(".content h2[id], .content h3[id], .content h4[id]");
    var toc = qs("#toc");
    var tocHeads = heads.filter(function (h) { return h.tagName !== "H4"; });
    if (toc && tocHeads.length > 1) {
      var title = document.createElement("p");
      title.className = "toc-title";
      title.textContent = "On this page";
      var ul = tocList(tocHeads);
      toc.appendChild(title);
      toc.appendChild(ul);
      toc.hidden = false;
      var links = qsa("a", ul);
      var inline = null;
      var h1 = qs(".content .page-title");
      if (h1 && !document.body.classList.contains("layout-home")) {
        inline = document.createElement("details");
        inline.className = "toc-inline";
        var sum = document.createElement("summary");
        sum.textContent = "On this page";
        inline.appendChild(sum);
        var ul2 = tocList(tocHeads);
        /* A click on a link closes the list first, so the page scrolls with the list collapsed. */
        ul2.addEventListener("click", function (e) {
          if (e.target.closest("a")) { inline.open = false; }
        });
        inline.appendChild(ul2);
        h1.parentNode.insertBefore(inline, h1.nextSibling);
        links = links.concat(qsa("a", ul2));
      }
      watchHeadings(tocHeads, links, tocHeads.length);
    }
    heads.forEach(function (h) {
      var a = document.createElement("a");
      a.className = "anchor";
      a.href = "#" + h.id;
      a.textContent = "#";
      a.setAttribute("aria-label", "Link to this section");
      h.appendChild(a);
    });
  }

  /* Tables: scroll block, status chips. */
  function initTables() {
    qsa(".content table").forEach(function (table) {
      var wrap = document.createElement("div");
      wrap.className = "table-wrap";
      wrap.tabIndex = 0;
      wrap.setAttribute("role", "region");
      wrap.setAttribute("aria-label", "Table, scrolls sideways");
      table.parentNode.insertBefore(wrap, table);
      wrap.appendChild(table);

      var idx = -1;
      qsa("thead th", table).forEach(function (th, i) {
        if (th.textContent.trim().toLowerCase() === "status") { idx = i; }
      });
      if (idx < 0) { return; }
      qsa("tbody tr", table).forEach(function (tr) {
        var cell = tr.children[idx];
        if (!cell) { return; }
        var text = cell.textContent.trim();
        var cls = null;
        if (text.indexOf("exercised") === 0) { cls = "chip-ok"; }
        else if (text === "not exercised") { cls = "chip-muted"; }
        else if (text === "planned") { cls = "chip-caution"; }
        if (!cls) { return; }
        var chip = document.createElement("span");
        chip.className = "chip " + cls;
        while (cell.firstChild) { chip.appendChild(cell.firstChild); }
        cell.appendChild(chip);
      });
    });
  }

  /* Status chips on decision records and runbooks. Only the value is wrapped. */
  function chipFor(value) {
    if (value === "accepted" || value.indexOf("exercised") === 0) { return "chip-ok"; }
    if (value === "proposed" || value === "planned") { return "chip-caution"; }
    if (value === "not exercised" || value.indexOf("superseded") === 0) { return "chip-muted"; }
    return null;
  }

  function wrapValue(node, start, end, cls) {
    var text = node.nodeValue;
    var chip = document.createElement("span");
    chip.className = "chip " + cls;
    chip.textContent = text.slice(start, end);
    var after = document.createTextNode(text.slice(end));
    node.nodeValue = text.slice(0, start);
    node.parentNode.insertBefore(chip, node.nextSibling);
    node.parentNode.insertBefore(after, chip.nextSibling);
  }

  function initStatus() {
    var path = window.location.pathname;
    if (/\/adr\//.test(path)) {
      var items = qsa(".content li, .content p");
      for (var i = 0; i < items.length; i++) {
        var n = items[i].firstChild;
        if (n && n.nodeType === 3 && /^Status:\s*/.test(n.nodeValue)) {
          var m = n.nodeValue.match(/^Status:\s*/);
          var cls = chipFor(n.nodeValue.slice(m[0].length).trim());
          if (cls) { wrapValue(n, m[0].length, n.nodeValue.trimEnd().length, cls); }
          break;
        }
      }
    }
    if (/\/runbooks\//.test(path)) {
      var h = qsa(".content h2").filter(function (x) { return x.id === "status"; })[0];
      var p = h && h.nextElementSibling;
      var t = p && p.firstChild;
      if (t && t.nodeType === 3) {
        var v = t.nodeValue.match(/^(not exercised|exercised in [^.]*|planned)/);
        if (v && chipFor(v[1])) { wrapValue(t, 0, v[1].length, chipFor(v[1])); }
      }
    }
  }

  /* Live region for the copy buttons. */
  var announcer = null;
  function announce(text) {
    if (!announcer) {
      announcer = document.createElement("div");
      announcer.className = "visually-hidden";
      announcer.setAttribute("role", "status");
      announcer.setAttribute("aria-live", "polite");
      document.body.appendChild(announcer);
    }
    announcer.textContent = "";
    setTimeout(function () { announcer.textContent = text; }, 50);
  }

  /* Code blocks: a strip above the code holds the language and the copy button.
     Without the clipboard API there is no button. */
  function initCopy() {
    var canCopy = !!(navigator.clipboard && navigator.clipboard.writeText);
    qsa(".content pre").forEach(function (pre) {
      var host = pre.closest(".highlighter-rouge");
      if (!host) {
        host = document.createElement("div");
        pre.parentNode.insertBefore(host, pre);
        host.appendChild(pre);
      }
      host.classList.add("code-block");
      var lang = "";
      Array.prototype.forEach.call(host.classList, function (c) {
        if (c.indexOf("language-") === 0 && c !== "language-plaintext") { lang = c.slice(9); }
      });
      if (!lang && !canCopy) { return; }
      var bar = document.createElement("div");
      bar.className = "code-bar";
      var label = document.createElement("span");
      label.className = "code-lang";
      label.textContent = lang;
      bar.appendChild(label);
      if (canCopy) {
        var btn = document.createElement("button");
        btn.type = "button";
        btn.className = "copy";
        btn.textContent = "Copy";
        btn.setAttribute("aria-label", "Copy code");
        var timer = null;
        btn.addEventListener("click", function () {
          var text = pre.textContent.replace(/\n$/, "");
          try {
            navigator.clipboard.writeText(text).then(function () {
              btn.textContent = "Copied";
              announce("Copied to the clipboard");
              clearTimeout(timer);
              timer = setTimeout(function () { btn.textContent = "Copy"; }, 2000);
            }, function () { announce("Copy failed"); });
          } catch (e) { announce("Copy failed"); }
        });
        bar.appendChild(btn);
      }
      host.insertBefore(bar, host.firstChild);
    });
  }

  /* Home page: lists become rows. A link followed by ": text" gets one description element
     that holds every node after the link, so inline code stays inside the sentence. */
  function initHome() {
    if (!document.body.classList.contains("layout-home")) { return; }
    qsa(".content > ul").forEach(function (ul) {
      var items = qsa(":scope > li", ul);
      items.forEach(function (li) {
        var a = li.firstElementChild;
        var t = a && a.nextSibling;
        if (a && a.tagName === "A" && t && t.nodeType === 3 && /^:\s/.test(t.nodeValue)) {
          t.nodeValue = t.nodeValue.replace(/^:\s*/, "");
          var span = document.createElement("span");
          span.className = "desc";
          while (a.nextSibling) { span.appendChild(a.nextSibling); }
          li.appendChild(span);
          li.classList.add("has-desc");
        }
      });
      if (items.length > 4) { ul.classList.add("rows-many"); }
    });
    /* Decision records: the part before the first colon is muted, the title keeps the ink colour. */
    var h = qs("#decision-records");
    var list = h && h.nextElementSibling;
    if (list && list.tagName === "UL") {
      qsa(":scope > li > a", list).forEach(function (a) {
        if (a.children.length || !a.firstChild || a.firstChild.nodeType !== 3) { return; }
        var text = a.firstChild.nodeValue;
        var k = text.indexOf(":");
        if (k < 1) { return; }
        var num = document.createElement("span");
        num.className = "adr-num";
        num.textContent = text.slice(0, k + 1) + " ";
        var title = document.createElement("span");
        title.className = "adr-title";
        title.textContent = text.slice(k + 1).replace(/^\s+/, "");
        a.textContent = "";
        a.appendChild(num);
        a.appendChild(title);
      });
    }
  }

  /* Diagrams. A fenced mermaid block is drawn by the Mermaid library, which is loaded from a public
     content delivery network only on a page that has such a block. The inline view fits the width.
     A button opens the diagram at its natural size in a dialog. The code block stays in the page,
     inside a "Diagram source" disclosure. If anything fails the code block stays where it was. */
  function cssVar(name) { return getComputedStyle(root).getPropertyValue(name).trim(); }

  function mermaidVariables() {
    var page = cssVar("--page"), surface = cssVar("--surface"), ink = cssVar("--ink");
    var edge = cssVar("--muted"), panel = cssVar("--sidebar-bg"), font = cssVar("--font-text");
    return {
      background: page, mainBkg: surface, primaryColor: surface, primaryTextColor: ink,
      primaryBorderColor: edge, lineColor: edge, textColor: ink, nodeTextColor: ink,
      secondaryColor: panel, tertiaryColor: panel, clusterBkg: panel, clusterBorder: edge,
      edgeLabelBackground: page, titleColor: ink, fontFamily: font, fontSize: "15px"
    };
  }

  function initDiagrams() {
    var found = qsa(".content div.language-mermaid, .content pre > code.language-mermaid");
    var hosts = [];
    found.forEach(function (el) {
      var host = el.closest(".code-block") || el.closest(".highlighter-rouge") || el;
      if (hosts.indexOf(host) === -1 && !host.closest(".diagram")) { hosts.push(host); }
    });
    if (!hosts.length) { return; }
    var items = hosts.map(function (host, n) {
      var code = qs("code", host) || host;
      return { host: host, n: n + 1, source: (code.textContent || "").replace(/\s+$/, ""), view: null, failed: false };
    });
    var canDialog = typeof HTMLDialogElement === "function" && typeof HTMLDialogElement.prototype.showModal === "function";
    var lib = null;
    var counter = 0;
    var dialog = null, dialogBody = null, closeButton = null, opener = null;

    function configure() {
      lib.initialize({
        startOnLoad: false, securityLevel: "strict", theme: "base",
        themeVariables: mermaidVariables(), flowchart: { useMaxWidth: false, htmlLabels: false }
      });
    }

    function drawSvg(source) {
      var id = "pp-diagram-" + (++counter);
      return lib.render(id, source).then(function (out) { return out.svg; }, function (e) {
        var junk = document.getElementById("d" + id);
        if (junk && junk.parentNode) { junk.parentNode.removeChild(junk); }
        throw e;
      });
    }

    function fail(item) {
      if (item.failed || item.view) { return; }
      item.failed = true;
      var note = document.createElement("p");
      note.className = "diagram-error";
      note.textContent = "The diagram could not be drawn. The source is shown above.";
      item.host.parentNode.insertBefore(note, item.host.nextSibling);
    }

    /* The dialog: one element, built when it is first needed. */
    function buildDialog() {
      if (dialog) { return; }
      dialog = document.createElement("dialog");
      dialog.className = "diagram-dialog";
      dialog.setAttribute("aria-labelledby", "diagram-dialog-title");
      var head = document.createElement("div");
      head.className = "diagram-dialog-head";
      var title = document.createElement("h2");
      title.id = "diagram-dialog-title";
      title.textContent = "Diagram";
      closeButton = document.createElement("button");
      closeButton.type = "button";
      closeButton.className = "btn diagram-close";
      closeButton.textContent = "Close";
      head.appendChild(title);
      head.appendChild(closeButton);
      dialogBody = document.createElement("div");
      dialogBody.className = "diagram-full";
      dialogBody.tabIndex = 0;
      dialogBody.setAttribute("role", "region");
      dialogBody.setAttribute("aria-label", "Diagram, scrolls in both directions");
      dialog.appendChild(head);
      dialog.appendChild(dialogBody);
      document.body.appendChild(dialog);
      closeButton.addEventListener("click", function () { dialog.close(); });
      dialog.addEventListener("click", function (e) { if (e.target === dialog) { dialog.close(); } });
      dialog.addEventListener("close", function () {
        root.classList.remove("dialog-open");
        dialogBody.textContent = "";
        if (opener) { opener.focus(); opener = null; }
      });
    }

    function openFull(item, button) {
      if (dialog && dialog.open) { return; }
      configure();
      drawSvg(item.source).then(function (svg) {
        buildDialog();
        dialogBody.innerHTML = svg;
        var el = qs("svg", dialogBody);
        var box = el && el.viewBox && el.viewBox.baseVal;
        if (el && box && box.width) {
          el.setAttribute("width", String(box.width));
          el.setAttribute("height", String(box.height));
          el.style.width = box.width + "px";
          el.style.height = box.height + "px";
          el.style.maxWidth = "none";
        }
        opener = button;
        root.classList.add("dialog-open");
        dialog.showModal();
        closeButton.focus();
      }, function () { /* the inline diagram stays as it is */ });
    }

    function place(item, svg) {
      if (item.view) { item.view.innerHTML = svg; return; }
      var host = item.host;
      var figure = document.createElement("figure");
      figure.className = "diagram";
      var strip = document.createElement("div");
      strip.className = "diagram-strip";
      var label = document.createElement("span");
      label.className = "diagram-label";
      label.textContent = "Diagram";
      strip.appendChild(label);
      if (canDialog) {
        var button = document.createElement("button");
        button.type = "button";
        button.className = "copy view-full";
        button.textContent = "View full size";
        button.setAttribute("aria-label", "View full size, diagram " + item.n);
        button.addEventListener("click", function () { openFull(item, button); });
        strip.appendChild(button);
      }
      var view = document.createElement("div");
      view.className = "diagram-view";
      view.innerHTML = svg;
      figure.appendChild(strip);
      figure.appendChild(view);
      /* A caption is a paragraph right after the block that holds only emphasised text. */
      var next = host.nextElementSibling;
      if (next && next.tagName === "P" && next.children.length === 1 && next.firstElementChild.tagName === "EM" &&
          next.textContent.trim() === next.firstElementChild.textContent.trim()) {
        var cap = document.createElement("figcaption");
        cap.textContent = next.textContent.trim();
        figure.appendChild(cap);
        next.parentNode.removeChild(next);
      }
      var details = document.createElement("details");
      details.className = "diagram-source";
      var summary = document.createElement("summary");
      summary.textContent = "Diagram source";
      details.appendChild(summary);
      host.parentNode.insertBefore(figure, host);
      details.appendChild(host);
      figure.appendChild(details);
      item.view = view;
    }

    async function renderAll() {
      configure();
      for (var i = 0; i < items.length; i++) {
        try {
          place(items[i], await drawSvg(items[i].source));
        } catch (e) {
          fail(items[i]);
        }
      }
    }

    function modeChanged() {
      if (dialog && dialog.open) { dialog.close(); }
      renderAll();
    }

    (async function () {
      try {
        /* Labels are measured with the page font, so wait until the fonts are ready. */
        if (document.fonts && document.fonts.ready) { await document.fonts.ready; }
      } catch (e) { /* draw anyway */ }
      try {
        var mod = await import("https://cdn.jsdelivr.net/npm/mermaid@" + MERMAID_VERSION + "/dist/mermaid.esm.min.mjs");
        lib = mod.default || mod;
        await renderAll();
      } catch (e) {
        items.forEach(fail);
        return;
      }
      /* Draw again when the colour mode changes: the toggle, or the system setting without an override. */
      document.addEventListener("pp-mode", modeChanged);
      if (window.matchMedia) {
        var query = window.matchMedia("(prefers-color-scheme: dark)");
        var onSystem = function () {
          var m = root.getAttribute("data-theme");
          if (m !== "light" && m !== "dark") { modeChanged(); }
        };
        if (query.addEventListener) { query.addEventListener("change", onSystem); }
      }
    })();
  }

  /* Search over assets/search.json. Loaded on the first focus. */
  function initSearch() {
    var input = qs("#search-input");
    var list = qs("#search-results");
    if (!input || !list) { return; }
    var index = null;
    var loading = false;
    var results = [];
    var active = -1;

    function load() {
      if (index || loading) { return; }
      loading = true;
      fetch(input.getAttribute("data-index"))
        .then(function (r) { return r.json(); })
        .then(function (data) { index = data; loading = false; run(); })
        .catch(function () { loading = false; });
    }

    function close() {
      list.hidden = true;
      list.innerHTML = "";
      input.setAttribute("aria-expanded", "false");
      input.removeAttribute("aria-activedescendant");
      active = -1;
    }

    function setActive(n) {
      var items = qsa("li[role=option]", list);
      items.forEach(function (li, i) { li.setAttribute("aria-selected", i === n ? "true" : "false"); });
      active = n;
      if (n >= 0 && items[n]) {
        input.setAttribute("aria-activedescendant", items[n].id);
        items[n].scrollIntoView({ block: "nearest" });
      } else {
        input.removeAttribute("aria-activedescendant");
      }
    }

    function run() {
      var q = input.value.trim().toLowerCase();
      if (!q || !index) { close(); return; }
      var words = q.split(/\s+/);
      results = index.filter(function (p) {
        var hay = (p.title + " " + p.excerpt).toLowerCase();
        return words.every(function (w) { return hay.indexOf(w) !== -1; });
      });
      results.sort(function (a, b) {
        var ta = words.every(function (w) { return a.title.toLowerCase().indexOf(w) !== -1; });
        var tb = words.every(function (w) { return b.title.toLowerCase().indexOf(w) !== -1; });
        return (tb ? 1 : 0) - (ta ? 1 : 0);
      });
      results = results.slice(0, 8);
      list.innerHTML = "";
      if (!results.length) {
        var none = document.createElement("li");
        none.className = "empty";
        none.setAttribute("role", "presentation");
        none.textContent = "No pages match.";
        list.appendChild(none);
      }
      results.forEach(function (p, i) {
        var li = document.createElement("li");
        li.id = "search-result-" + i;
        li.setAttribute("role", "option");
        li.setAttribute("aria-selected", "false");
        var a = document.createElement("a");
        a.href = p.url;
        a.tabIndex = -1;
        a.textContent = p.title;
        var ex = document.createElement("span");
        ex.className = "result-excerpt";
        ex.textContent = p.excerpt.length > 90 ? p.excerpt.slice(0, 90) + "..." : p.excerpt;
        a.appendChild(ex);
        li.appendChild(a);
        list.appendChild(li);
      });
      list.hidden = false;
      input.setAttribute("aria-expanded", "true");
      active = -1;
    }

    input.addEventListener("focus", load);
    input.addEventListener("input", function () { load(); run(); });
    input.addEventListener("keydown", function (e) {
      if (e.key === "ArrowDown" && results.length) {
        e.preventDefault();
        setActive((active + 1) % results.length);
      } else if (e.key === "ArrowUp" && results.length) {
        e.preventDefault();
        setActive(active <= 0 ? results.length - 1 : active - 1);
      } else if (e.key === "Enter" && results.length) {
        e.preventDefault();
        window.location.href = results[active >= 0 ? active : 0].url;
      } else if (e.key === "Escape") {
        e.stopPropagation();
        if (!list.hidden) { close(); } else { input.blur(); }
      }
    });
    /* Under 720px the search field is a panel that the search button opens. */
    var header = qs(".site-header");
    var toggle = qs("#search-toggle");
    function panel(open, returnFocus) {
      header.classList.toggle("search-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
      if (open) { input.focus(); } else { close(); if (returnFocus) { toggle.focus(); } }
    }
    if (toggle && header) {
      toggle.addEventListener("click", function () { panel(!header.classList.contains("search-open"), true); });
      input.addEventListener("keydown", function (e) {
        if (e.key === "Escape" && header.classList.contains("search-open") && list.hidden) { panel(false, true); }
      });
    }
    document.addEventListener("click", function (e) {
      if (!e.target.closest(".search")) { close(); }
      if (header && header.classList.contains("search-open") && !e.target.closest(".search, #search-toggle")) { panel(false, false); }
    });
    document.addEventListener("keydown", function (e) {
      if (e.key !== "/" || e.ctrlKey || e.metaKey || e.altKey || window.innerWidth < 720) { return; }
      var el = document.activeElement;
      var tag = el ? el.tagName : "";
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || (el && el.isContentEditable)) { return; }
      e.preventDefault();
      input.focus();
    });
  }

  /* Footer: the latest release tag of the repository, read in the browser. The item stays hidden
     until a tag that passes the checks has loaded. The answer is kept for the browser tab. */
  function initVersion() {
    var item = qs(".footer-version");
    if (!item) { return; }
    var api = item.getAttribute("data-release-api");
    var repo = item.getAttribute("data-repo");
    var link = qs("a", item);
    if (!api || !repo || !link) { return; }
    var KEY = "pp-latest-release";
    var TAG = /^v?\d+\.\d+\.\d+[A-Za-z0-9.-]*$/;

    function valid(tag, url) {
      return typeof tag === "string" && typeof url === "string" && TAG.test(tag) && url.indexOf(repo + "/") === 0;
    }
    function show(tag, url) {
      link.textContent = tag;
      link.setAttribute("href", url);
      item.removeAttribute("hidden");
    }

    try {
      var saved = JSON.parse(sessionStorage.getItem(KEY));
      if (saved && valid(saved.tag, saved.url)) { show(saved.tag, saved.url); return; }
    } catch (e) { /* storage can throw */ }

    if (typeof fetch !== "function") { return; }
    fetch(api, { headers: { Accept: "application/vnd.github+json" } })
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (data) {
        if (!data || !valid(data.tag_name, data.html_url)) { return; }
        show(data.tag_name, data.html_url);
        try {
          sessionStorage.setItem(KEY, JSON.stringify({ tag: data.tag_name, url: data.html_url }));
        } catch (e) { /* storage can throw */ }
      })
      .catch(function () { /* the item stays hidden */ });
  }

  function init() {
    initMode();
    initMenu();
    initNavGroups();
    initHeadings();
    initTables();
    initStatus();
    initCopy();
    initDiagrams();
    initHome();
    initSearch();
    initVersion();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
