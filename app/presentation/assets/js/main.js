(function() {
  function initFlash() {
    const flashBar = document.getElementById('flash-bar-container');
    if (!flashBar) return;

    // Use a flag to prevent multiple dismissal triggers
    let dismissed = false;

    function dismissFlash() {
      if (dismissed) return;
      dismissed = true;
      
      flashBar.classList.add('slide-out');
      flashBar.addEventListener('animationend', function() {
        flashBar.remove();
      }, { once: true });
    }

    // Auto-dismiss after ~3.5 seconds (adjustable)
    const AUTO_DISMISS_MS = 3500;
    const timer = setTimeout(dismissFlash, AUTO_DISMISS_MS);

    // Close button
    // Support both Bootstrap's .btn-close and our explicit .flash-close
    const closeBtn = flashBar.querySelector('.btn-close, .flash-close');
    if (closeBtn) {
      closeBtn.addEventListener('click', function(e) {
        e.preventDefault();
        clearTimeout(timer);
        dismissFlash();
      });
    }

    // Pause auto-dismiss while hovering so users can read/close
    flashBar.addEventListener('mouseenter', () => clearTimeout(timer));
    flashBar.addEventListener('focusin', () => clearTimeout(timer));
  }

  // Run on initial load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFlash);
  } else {
    initFlash();
  }
  
  // Intercept segmented-control filter links to show the click animation
  function initFilterNavigation() {
    const FILTER_CLICK_DELAY = 120; // ms
    document.querySelectorAll('.btn-filter').forEach(function(link) {
      link.addEventListener('click', function(e) {
        const href = link.getAttribute('href');
        // Only intercept normal navigation links (skip anchors and javascript:void)
        if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;
        e.preventDefault();
        // Add active class to show pressed/active visual feedback immediately
        link.classList.add('active');
        // Small delay to allow CSS animation to run, then navigate
        setTimeout(function() {
          window.location.href = href;
        }, FILTER_CLICK_DELAY);
      }, { passive: false });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFilterNavigation);
  } else {
    initFilterNavigation();
  }

  function initLazyMedia() {
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
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initLazyMedia);
  } else {
    initLazyMedia();
  }
})();
