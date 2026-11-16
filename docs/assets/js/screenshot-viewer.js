/* Screenshot viewer: click an image under assets/screenshots/ to see it enlarged. No dependencies. */
(function () {
  "use strict";

  var shots = Array.prototype.slice.call(document.querySelectorAll('img[src*="assets/screenshots/"]'));
  if (!shots.length) { return; }

  var root = document.documentElement;
  var overlay = null;
  var opener = null;
  var scrollY = 0;

  function open(img) {
    if (overlay) { return; }
    opener = img;
    scrollY = window.pageYOffset;

    overlay = document.createElement("div");
    overlay.className = "shot-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-label", img.getAttribute("alt") || "Screenshot");
    overlay.tabIndex = -1;

    var big = document.createElement("img");
    big.className = "shot-overlay-img";
    big.src = img.currentSrc || img.src;
    big.alt = img.getAttribute("alt") || "";
    overlay.appendChild(big);

    overlay.addEventListener("click", close);
    document.addEventListener("keydown", onKey, true);
    root.classList.add("shot-open");
    document.body.appendChild(overlay);
    overlay.focus();
  }

  function close() {
    if (!overlay) { return; }
    document.removeEventListener("keydown", onKey, true);
    overlay.parentNode.removeChild(overlay);
    overlay = null;
    root.classList.remove("shot-open");
    window.scrollTo(0, scrollY);
    if (opener) {
      try { opener.focus({ preventScroll: true }); } catch (e) { opener.focus(); }
      opener = null;
    }
  }

  function onKey(e) {
    if (e.key === "Escape" || e.key === "Esc") {
      e.preventDefault();
      e.stopPropagation();
      close();
    } else if (e.key === "Tab") {
      /* The overlay holds the only focusable element, so focus stays on it. */
      e.preventDefault();
    }
  }

  shots.forEach(function (img) {
    img.setAttribute("tabindex", "0");
    img.setAttribute("role", "button");
    img.setAttribute("aria-label", "Enlarge image: " + (img.getAttribute("alt") || ""));
    img.classList.add("shot");
    img.addEventListener("click", function () { open(img); });
    img.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " " || e.key === "Spacebar") {
        e.preventDefault();
        open(img);
      }
    });
  });
})();
