(function(app, window, document) {
  app.registerInitializer('flash', function() {
    const flashBar = document.getElementById('flash-bar-container');
    if (!flashBar) return;

    let dismissed = false;

    function dismissFlash() {
      if (dismissed) return;
      dismissed = true;

      flashBar.classList.add('slide-out');
      flashBar.addEventListener('animationend', function() {
        flashBar.remove();
      }, { once: true });
    }

    const timer = window.setTimeout(dismissFlash, 3500);
    const closeBtn = flashBar.querySelector('.btn-close, .flash-close');
    if (closeBtn) {
      closeBtn.addEventListener('click', function(e) {
        e.preventDefault();
        window.clearTimeout(timer);
        dismissFlash();
      });
    }

    flashBar.addEventListener('mouseenter', function() { window.clearTimeout(timer); });
    flashBar.addEventListener('focusin', function() { window.clearTimeout(timer); });
  });

  app.registerInitializer('filter-navigation', function() {
    document.querySelectorAll('.btn-filter').forEach(function(link) {
      link.addEventListener('click', function(e) {
        const href = link.getAttribute('href');
        if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;

        e.preventDefault();
        link.classList.add('active');
        window.setTimeout(function() {
          window.location.href = href;
        }, 120);
      }, { passive: false });
    });
  });

  app.registerInitializer('lazy-media', function() {
    document.querySelectorAll('img.lazy-media').forEach(function(image) {
      function markLoaded() {
        image.classList.add('is-loaded');
      }

      if (image.complete) {
        markLoaded();
        return;
      }

      image.addEventListener('load', markLoaded, { once: true });
      image.addEventListener('error', markLoaded, { once: true });
    });
  });

  app.registerInitializer('page-back', function() {
    const previousPageKey = 'facecloak.previousPage';
    const currentPath = window.location.pathname + window.location.search;
    const imageDetailPattern = /^\/images\/[^/]+\/(?:raw|protected)$/;
    const isImageDetail = imageDetailPattern.test(window.location.pathname);
    const previousPage = window.sessionStorage.getItem(previousPageKey);
    const validPreviousPage = previousPage && previousPage !== currentPath ? previousPage : '/';

    document.querySelectorAll('[data-page-back="true"]').forEach(function(link) {
      link.setAttribute('href', validPreviousPage);
    });

    if (!isImageDetail) window.sessionStorage.setItem(previousPageKey, currentPath);
  });

  app.registerInitializer('copy-buttons', function() {
    function fallbackCopy(text) {
      const textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.setAttribute('readonly', 'readonly');
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      textarea.remove();
      return Promise.resolve();
    }

    document.querySelectorAll('[data-copy-target]').forEach(function(button) {
      const target = document.querySelector(button.getAttribute('data-copy-target'));
      if (!target) return;

      const icon = button.querySelector('i');
      const originalLabel = button.dataset.copyLabel || button.getAttribute('aria-label') || 'Copy API key';
      const copiedLabel = button.dataset.copiedLabel || 'Copied';
      button.addEventListener('click', function() {
        const text = target.textContent.trim();
        const copy = window.navigator.clipboard ?
          window.navigator.clipboard.writeText(text) :
          fallbackCopy(text);

        copy.then(function() {
          button.classList.add('is-copied');
          button.setAttribute('aria-label', copiedLabel);
          if (icon) icon.className = 'fas fa-check';
          window.setTimeout(function() {
            button.classList.remove('is-copied');
            button.setAttribute('aria-label', originalLabel);
            if (icon) icon.className = 'far fa-copy';
          }, 1400);
        });
      });
    });
  });

  app.registerInitializer('notifications', function() {
    document.querySelectorAll('.notification-menu').forEach(function(menu) {
      const trigger = menu.querySelector('[data-notification-trigger]');
      const panel = menu.querySelector('[data-notification-panel]');
      if (!trigger || !panel) return;

      trigger.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();

        const shouldOpen = !menu.classList.contains('open');
        document.querySelectorAll('.notification-menu.open').forEach(function(openMenu) {
          if (openMenu !== menu) openMenu.classList.remove('open');
        });

        menu.classList.toggle('open', shouldOpen);
        trigger.setAttribute('aria-expanded', shouldOpen ? 'true' : 'false');
      });

      panel.addEventListener('click', function(e) {
        e.stopPropagation();
      });
    });

    document.addEventListener('click', function() {
      document.querySelectorAll('.notification-menu.open').forEach(function(menu) {
        menu.classList.remove('open');
        const trigger = menu.querySelector('[data-notification-trigger]');
        if (trigger) trigger.setAttribute('aria-expanded', 'false');
      });
    });
  });
})(window.FaceCloak, window, document);
