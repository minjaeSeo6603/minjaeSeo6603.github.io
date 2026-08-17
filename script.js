/* Minjae Seo — site behavior: contents toggle, scroll-spy, section reveal. */

(function () {
  "use strict";

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ── Contents toggle (mobile) ───────────────────────────── */

  var toggle = document.querySelector(".rail-toggle");
  var nav = document.getElementById("rail-nav");

  if (toggle && nav) {
    toggle.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
    });

    nav.addEventListener("click", function (event) {
      if (event.target.closest("a")) {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  /* ── Scroll-spy: mark the section currently being read ──── */

  var navLinks = Array.prototype.slice.call(document.querySelectorAll(".rail-nav a"));
  var sections = navLinks
    .map(function (link) {
      return document.querySelector(link.getAttribute("href"));
    })
    .filter(Boolean);

  if (sections.length && "IntersectionObserver" in window) {
    var visible = new Set();

    var spy = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            visible.add(entry.target.id);
          } else {
            visible.delete(entry.target.id);
          }
        });

        var current = null;
        for (var i = 0; i < sections.length; i++) {
          if (visible.has(sections[i].id)) {
            current = sections[i].id;
            break;
          }
        }

        navLinks.forEach(function (link) {
          link.classList.toggle("is-current", link.getAttribute("href") === "#" + current);
        });
      },
      { rootMargin: "-10% 0px -70% 0px", threshold: 0 }
    );

    sections.forEach(function (section) {
      spy.observe(section);
    });
  }

  /* ── Reveal sections on first scroll into view ──────────── */

  if (reduceMotion || !("IntersectionObserver" in window)) {
    return;
  }

  var targets = Array.prototype.slice.call(
    document.querySelectorAll(".section, .paper, .work, .position, .proposal")
  );

  targets.forEach(function (element) {
    element.classList.add("reveal-target");
  });

  var reveal = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          reveal.unobserve(entry.target);
        }
      });
    },
    { rootMargin: "0px 0px -8% 0px", threshold: 0.04 }
  );

  targets.forEach(function (element) {
    reveal.observe(element);
  });
})();
