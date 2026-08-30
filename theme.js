/* Theme toggle.
   The stored value is applied by a small inline snippet in each page's <head>
   so the correct theme paints on first frame; this file only wires the button.
   No stored value means "follow the operating system", which is the default. */
(function () {
  "use strict";

  var KEY = "bbst-theme";
  var root = document.documentElement;

  function systemPrefersDark() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  function currentTheme() {
    var set = root.getAttribute("data-theme");
    if (set === "light" || set === "dark") return set;
    return systemPrefersDark() ? "dark" : "light";
  }

  function describe(theme) {
    return theme === "dark"
      ? "Switch to the light theme"
      : "Switch to the dark theme";
  }

  function apply(theme) {
    root.setAttribute("data-theme", theme);
    try {
      localStorage.setItem(KEY, theme);
    } catch (err) {
      /* Private browsing or blocked site data: the theme still applies for
         this page view, it just will not be remembered. Nothing to recover. */
    }
  }

  var button = document.querySelector(".theme-toggle");
  if (!button) return;

  button.setAttribute("aria-label", describe(currentTheme()));

  button.addEventListener("click", function () {
    var next = currentTheme() === "dark" ? "light" : "dark";
    apply(next);
    button.setAttribute("aria-label", describe(next));
  });

  /* Follow the OS while the reader has not made an explicit choice. */
  if (window.matchMedia) {
    var media = window.matchMedia("(prefers-color-scheme: dark)");
    var onChange = function () {
      var stored = null;
      try {
        stored = localStorage.getItem(KEY);
      } catch (err) {
        stored = null;
      }
      if (!stored) button.setAttribute("aria-label", describe(currentTheme()));
    };
    if (media.addEventListener) media.addEventListener("change", onChange);
    else if (media.addListener) media.addListener(onChange);
  }
})();
