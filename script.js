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

  /* ── Copula explorer ────────────────────────────────────
     Sharp Fréchet bounds on the harmed fraction of a binary outcome:
       π₋ ∈ [ max(0, p₀ − p₁),  min(p₀, 1 − p₁) ]
     Matches the three worked cases in the paper:
       p₀=.80 p₁=.70 → [.10,.30]   p₀=p₁=.98 → [0,.02]   p₀=p₁=.50 → [0,.50]
     ─────────────────────────────────────────────────────── */

  var explorer = document.getElementById("copula-explorer");

  if (explorer) {
    var p0El = document.getElementById("ctl-p0");
    var p1El = document.getElementById("ctl-p1");
    var outP0 = document.getElementById("out-p0");
    var outP1 = document.getElementById("out-p1");
    var outTau = document.getElementById("out-tau");
    var outPi = document.getElementById("out-pi");
    var band = document.getElementById("xt-band");
    var verdict = document.getElementById("out-verdict");
    var live = document.getElementById("out-live");
    var presets = explorer.querySelectorAll(".explorer-presets button");

    var fmt = function (x) {
      if (Math.abs(x) < 5e-3) return "0.00";
      return (x < 0 ? "−" : "+") + Math.abs(x).toFixed(2);
    };

    var render = function () {
      var p0 = Number(p0El.value) / 100;
      var p1 = Number(p1El.value) / 100;

      var tau = p1 - p0;
      var lo = Math.max(0, p0 - p1);
      var hi = Math.min(p0, 1 - p1);
      var width = hi - lo;

      outP0.textContent = p0.toFixed(2);
      outP1.textContent = p1.toFixed(2);
      outTau.textContent = fmt(tau);
      outPi.textContent = "[" + lo.toFixed(2) + ", " + hi.toFixed(2) + "]";

      band.style.left = (lo * 100).toFixed(2) + "%";
      band.style.width = Math.max(width * 100, 0.6).toFixed(2) + "%";

      /* Which regime the marginals put us in. For a binary outcome a common
         effect requires Δ ≡ δ a.s., which is only possible when p₀ = p₁ — so
         equality of the two rates, not a zero lower bound, is what admits
         homogeneity. Degeneracy is checked first: when both marginals sit at a
         ceiling or floor the Fréchet class collapses and the corners (0,1) and
         (1,0) fall here too, exactly as Lemma 1 has it.
         Tolerances are needed because 1 − 0.98 is 0.020000000000000018. */
      var same = Math.abs(p0 - p1) < 1e-9;
      var msg;

      if (width <= 0.02 + 1e-9) {
        msg =
          "Case 3 — the marginals are at or near degeneracy, so the Fréchet class has all but collapsed. " +
          "The harmed fraction is pinned to within " + (width * 100).toFixed(0) +
          " percentage points. Identification here is bought by the ceiling, not by any assumption " +
          "about dependence.";
      } else if (same) {
        msg =
          "Case 1 — heterogeneity is possible but not forced. The marginals are a location shift, so a common " +
          "effect sits inside the identified set; but so does a coupling that moves every unit, with up to " +
          (hi * 100).toFixed(0) + "% harmed. Both reproduce exactly what the experiment observes.";
      } else {
        msg =
          "Case 2 — heterogeneity is forced. These rates are not a location shift, so Var(Δ) > 0 under every " +
          "coupling: no common effect can reproduce them" +
          (lo > 0
            ? ". And the Fréchet floor goes further — at least " + (lo * 100).toFixed(0) +
              "% of units are made worse off" +
              (tau > 0 ? ", even though the average effect is positive." : ".")
            : ". The floor still permits zero losers, so dispersion is forced but harm is not — two distinct claims.");
      }

      verdict.textContent = msg;
      if (live) {
        live.textContent =
          "Harmed fraction between " + lo.toFixed(2) + " and " + hi.toFixed(2) + ". " + msg;
      }

      for (var i = 0; i < presets.length; i++) {
        var b = presets[i];
        b.classList.toggle(
          "is-on",
          Number(b.dataset.p0) === Number(p0El.value) && Number(b.dataset.p1) === Number(p1El.value)
        );
      }
    };

    p0El.addEventListener("input", render);
    p1El.addEventListener("input", render);

    for (var i = 0; i < presets.length; i++) {
      presets[i].addEventListener("click", function () {
        p0El.value = this.dataset.p0;
        p1El.value = this.dataset.p1;
        render();
      });
    }

    render();
  }

  /* ── Research field filter ──────────────────────────────── */

  var chips = document.querySelectorAll(".filters .chip");

  if (chips.length) {
    var groups = document.querySelectorAll("[data-group]");

    for (var c = 0; c < chips.length; c++) {
      chips[c].addEventListener("click", function () {
        var want = this.dataset.filter;

        for (var j = 0; j < chips.length; j++) {
          var on = chips[j] === this;
          chips[j].classList.toggle("is-on", on);
          chips[j].setAttribute("aria-pressed", String(on));
        }

        for (var k = 0; k < groups.length; k++) {
          groups[k].classList.toggle(
            "is-hidden",
            want !== "all" && groups[k].dataset.group !== want
          );
        }
      });
    }
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
