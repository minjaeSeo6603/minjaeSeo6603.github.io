(function () {
  const body = document.body;
  const menuToggle = document.querySelector('.menu-toggle');
  const nav = document.querySelector('.site-nav');
  const navLinks = Array.from(document.querySelectorAll('.site-nav a'));
  const revealTargets = Array.from(document.querySelectorAll('.reveal'));
  const filterButtons = Array.from(document.querySelectorAll('.filter-button'));
  const projectCards = Array.from(document.querySelectorAll('.project-card'));
  const metricValues = Array.from(document.querySelectorAll('.metric-value[data-value]'));
  const lastUpdated = document.getElementById('last-updated');
  const progressFill = document.getElementById('scroll-progress-fill');
  const cursorGlow = document.querySelector('.cursor-glow');
  const heroSection = document.getElementById('home');

  const supportsObserver = 'IntersectionObserver' in window;
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const hasFinePointer = window.matchMedia('(pointer: fine)').matches;

  if (lastUpdated) {
    const now = new Date();
    const formatted = now.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
    lastUpdated.textContent = `Updated ${formatted}`;
  }

  if (menuToggle && nav) {
    const closeMenu = function () {
      nav.classList.remove('is-open');
      menuToggle.setAttribute('aria-expanded', 'false');
    };

    menuToggle.addEventListener('click', function () {
      const isOpen = nav.classList.toggle('is-open');
      menuToggle.setAttribute('aria-expanded', String(isOpen));
    });

    document.addEventListener('click', function (event) {
      const clickedInside = nav.contains(event.target) || menuToggle.contains(event.target);
      if (!clickedInside) {
        closeMenu();
      }
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        closeMenu();
      }
    });

    navLinks.forEach(function (link) {
      link.addEventListener('click', closeMenu);
    });
  }

  if (revealTargets.length && supportsObserver) {
    const revealObserver = new IntersectionObserver(
      function (entries, obs) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            obs.unobserve(entry.target);
          }
        });
      },
      {
        threshold: 0.16,
        rootMargin: '0px 0px -30px 0px'
      }
    );

    revealTargets.forEach(function (el, index) {
      el.style.transitionDelay = `${Math.min(index * 35, 240)}ms`;
      revealObserver.observe(el);
    });
  } else {
    revealTargets.forEach(function (el) {
      el.classList.add('is-visible');
    });
  }

  if (filterButtons.length && projectCards.length) {
    filterButtons.forEach(function (button) {
      button.addEventListener('click', function () {
        const selected = button.dataset.filter;

        filterButtons.forEach(function (btn) {
          btn.classList.remove('is-active');
        });
        button.classList.add('is-active');

        projectCards.forEach(function (card) {
          const category = card.dataset.category || '';
          const shouldShow = selected === 'all' || category.includes(selected);
          card.classList.toggle('is-hidden', !shouldShow);
        });
      });
    });
  }

  const sectionIds = ['about', 'projects', 'workflow', 'contact'];
  const sections = sectionIds
    .map(function (id) {
      return document.getElementById(id);
    })
    .filter(Boolean);

  if (sections.length && navLinks.length && supportsObserver) {
    const setActive = function (activeId) {
      navLinks.forEach(function (link) {
        const href = link.getAttribute('href') || '';
        link.classList.toggle('is-active', href === `#${activeId}`);
      });
    };

    const sectionObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            setActive(entry.target.id);
          }
        });
      },
      {
        threshold: 0.35,
        rootMargin: '-20% 0px -45% 0px'
      }
    );

    sections.forEach(function (section) {
      sectionObserver.observe(section);
    });
  }

  if (progressFill) {
    const updateProgress = function () {
      const scrollTop = window.scrollY || window.pageYOffset;
      const maxScroll = Math.max(document.documentElement.scrollHeight - window.innerHeight, 1);
      const progress = Math.min(Math.max((scrollTop / maxScroll) * 100, 0), 100);
      progressFill.style.width = `${progress}%`;
    };

    window.addEventListener('scroll', updateProgress, { passive: true });
    window.addEventListener('resize', updateProgress);
    updateProgress();
  }

  if (cursorGlow && hasFinePointer && !prefersReducedMotion) {
    let currentX = window.innerWidth / 2;
    let currentY = window.innerHeight / 2;
    let targetX = currentX;
    let targetY = currentY;
    let ticking = false;

    const render = function () {
      currentX += (targetX - currentX) * 0.17;
      currentY += (targetY - currentY) * 0.17;
      cursorGlow.style.left = `${currentX}px`;
      cursorGlow.style.top = `${currentY}px`;

      if (Math.abs(targetX - currentX) < 0.1 && Math.abs(targetY - currentY) < 0.1) {
        ticking = false;
        return;
      }

      window.requestAnimationFrame(render);
    };

    document.addEventListener('mousemove', function (event) {
      targetX = event.clientX;
      targetY = event.clientY;
      if (!ticking) {
        ticking = true;
        window.requestAnimationFrame(render);
      }
    });

    document.addEventListener('mouseleave', function () {
      cursorGlow.style.opacity = '0';
    });

    document.addEventListener('mouseenter', function () {
      cursorGlow.style.opacity = '';
    });
  }

  if (metricValues.length) {
    const animateMetric = function (el) {
      if (el.dataset.counted === 'true') {
        return;
      }

      const finalValue = Number(el.dataset.value || '0');
      const suffix = el.dataset.suffix || '';
      const duration = prefersReducedMotion ? 0 : 1400;

      if (duration === 0) {
        el.textContent = `${finalValue}${suffix}`;
        el.dataset.counted = 'true';
        return;
      }

      const start = performance.now();

      const step = function (now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        const current = Math.floor(finalValue * eased);
        el.textContent = `${current}${suffix}`;

        if (progress < 1) {
          window.requestAnimationFrame(step);
        } else {
          el.textContent = `${finalValue}${suffix}`;
          el.dataset.counted = 'true';
        }
      };

      window.requestAnimationFrame(step);
    };

    if (supportsObserver && heroSection) {
      const metricObserver = new IntersectionObserver(
        function (entries, obs) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              metricValues.forEach(animateMetric);
              obs.disconnect();
            }
          });
        },
        {
          threshold: 0.34
        }
      );

      metricObserver.observe(heroSection);
    } else {
      metricValues.forEach(animateMetric);
    }
  }

  const interactiveCards = Array.from(document.querySelectorAll('.project-card, .document-card'));

  if (interactiveCards.length && hasFinePointer && !prefersReducedMotion) {
    interactiveCards.forEach(function (card) {
      const resetCard = function () {
        card.classList.remove('is-tilting');
        card.style.transform = '';
        card.style.removeProperty('--mx');
        card.style.removeProperty('--my');
      };

      card.addEventListener('mousemove', function (event) {
        const rect = card.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        const px = x / rect.width;
        const py = y / rect.height;

        const rotateX = (0.5 - py) * 7;
        const rotateY = (px - 0.5) * 9;

        card.classList.add('is-tilting');
        card.style.setProperty('--mx', `${px * 100}%`);
        card.style.setProperty('--my', `${py * 100}%`);
        card.style.transform = `perspective(900px) rotateX(${rotateX.toFixed(2)}deg) rotateY(${rotateY.toFixed(2)}deg) translateY(-4px)`;
      });

      card.addEventListener('mouseleave', resetCard);
      card.addEventListener('blur', resetCard, true);
    });
  }

  body.classList.add('is-ready');
})();
