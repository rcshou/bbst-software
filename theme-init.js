/* Apply the stored theme before first paint so the page never flashes.
   Loaded synchronously from each page's <head>, before any content, and kept
   in a file rather than inline so the Content-Security-Policy can forbid
   inline script. theme.js wires the toggle button after the page loads. */
(function () {
  try {
    var t = localStorage.getItem("bbst-theme");
    if (t === "light" || t === "dark") document.documentElement.setAttribute("data-theme", t);
  } catch (e) {
    /* Blocked site data: fall back to the operating system's theme. */
  }
})();
