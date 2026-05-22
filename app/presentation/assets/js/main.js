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

  function initHistoryBack() {
    document.querySelectorAll('[data-history-back="true"]').forEach(function(link) {
      link.addEventListener('click', function(e) {
        if (window.history.length <= 1) return;

        e.preventDefault();
        window.history.back();
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initHistoryBack);
  } else {
    initHistoryBack();
  }

  function initPasswordToggles() {
    document.querySelectorAll('[data-toggle-password]').forEach(function(button) {
      const targetSelector = button.getAttribute('data-toggle-password');
      const input = document.querySelector(targetSelector);
      const icon = button.querySelector('i');

      if (!input || !icon) return;

      button.addEventListener('click', function() {
        const shouldShow = input.type === 'password';
        input.type = shouldShow ? 'text' : 'password';
        button.setAttribute('aria-label', shouldShow ? 'Hide password' : 'Show password');
        icon.classList.toggle('fa-eye', shouldShow);
        icon.classList.toggle('fa-eye-slash', !shouldShow);
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPasswordToggles);
  } else {
    initPasswordToggles();
  }

  function initUsernameAvailability() {
    const input = document.querySelector('[data-username-availability-url]');
    const message = document.getElementById('username-availability');
    if (!input || !message) return;

    const endpoint = input.getAttribute('data-username-availability-url');
    const serverError = document.querySelector('.server-username-error');
    let timerId = null;
    let requestId = 0;
    let currentState = null; // null | 'checking' | 'available' | 'taken' | 'error'
    let lastCheckPromise = null;
    const clearBtn = document.getElementById('username-clear');
    const spinner = document.getElementById('username-spinner');

    // initialize clear button visibility
    if (clearBtn) {
      if (!input.value || !input.value.trim()) clearBtn.classList.add('hidden');
      clearBtn.addEventListener('click', function(e) {
        e.preventDefault();
        // cancel inflight checks by bumping requestId
        requestId += 1;
        input.value = '';
        input.focus();
        // hide UI indicators
        setAvailability(null, '');
        if (spinner) spinner.classList.remove('visible');
        clearBtn.classList.add('hidden');
        currentState = null;
      });
    }

    function showGlobalLoading(text) {
      const overlay = document.getElementById('global-loading-overlay');
      if (!overlay) return;
      const textEl = overlay.querySelector('.loader .text');
      if (textEl) textEl.textContent = text || 'Loading...';
      overlay.classList.add('visible');
    }

    function hideGlobalLoading() {
      const overlay = document.getElementById('global-loading-overlay');
      if (!overlay) return;
      overlay.classList.remove('visible');
    }

    function normalizeUsername(value) {
      return value.trim().replace(/^@+/, '');
    }

    function setAvailability(state, text) {
      message.className = 'username-availability-message mt-2';
      // mark state on the input-group container so the visible outline/border can change
      const group = input.closest('.input-group');
      if (group) {
        group.classList.remove('is-available', 'is-taken', 'is-error');
      }

      if (!state) {
        message.textContent = '';
        input.classList.remove('auth-input-error');
        return;
      }

      message.classList.add(`is-${state}`);
      message.textContent = text;

      if (state === 'taken' || state === 'error') {
        input.classList.add('auth-input-error');
        if (group) group.classList.add('is-taken');
      } else if (state === 'available') {
        if (group) group.classList.add('is-available');
      }

      // ensure clear button is visible when there's content and a result
      if (clearBtn) {
        if (input.value && input.value.trim()) clearBtn.classList.remove('hidden');
      }
    }

    const DEBOUNCE_MS = 600;

    function performCheck(username) {
      if (!username) {
        setAvailability(null, '');
        return Promise.resolve({ ok: true, available: false });
      }

      requestId += 1;
      const thisRequest = requestId;
      currentState = 'checking';
      setAvailability('checking', 'Checking username...');

      if (spinner) spinner.classList.add('visible');

      const p = window.fetch(`${endpoint}/${encodeURIComponent(username)}`, {
        headers: { Accept: 'application/json' }
      })
        .then(function(response) {
          return response.json().then(function(body) {
            return { ok: response.ok, body: body };
          });
        })
        .then(function(result) {
          if (spinner) spinner.classList.remove('visible');
          if (thisRequest !== requestId) return { ok: false, stale: true };
          if (!result.ok) {
            currentState = 'error';
            setAvailability('error', result.body.message || 'Could not check username right now.');
            return { ok: false, available: false };
          }

          if (result.body.available) {
            currentState = 'available';
            setAvailability('available', 'Username is available.');
            return { ok: true, available: true };
          } else {
            currentState = 'taken';
            setAvailability('taken', 'Username is already taken.');
            return { ok: true, available: false };
          }
        })
        .catch(function() {
          if (spinner) spinner.classList.remove('visible');
          if (thisRequest !== requestId) return { ok: false, stale: true };
          currentState = 'error';
          setAvailability('error', 'Could not check username right now.');
          return { ok: false, available: false };
        });

      lastCheckPromise = p;
      return p;
    }

    // Clear availability message while typing; debounce a check when typing stops
    input.addEventListener('input', function() {
      if (serverError) serverError.hidden = true;
      window.clearTimeout(timerId);
      currentState = null;
      setAvailability(null, '');
      // toggle clear button visibility
      if (clearBtn) {
        if (input.value && input.value.trim()) clearBtn.classList.remove('hidden');
        else clearBtn.classList.add('hidden');
      }
      const username = normalizeUsername(input.value);
      if (!username) return;

      timerId = window.setTimeout(function() {
        performCheck(username);
      }, DEBOUNCE_MS);
    });

    // On blur: if a debounce timer is pending, run the check immediately
    input.addEventListener('blur', function() {
      window.clearTimeout(timerId);
      const username = normalizeUsername(input.value);
      if (!username) {
        setAvailability(null, '');
        return;
      }
      // If we already have a definitive state, don't refetch
      if (currentState === 'available' || currentState === 'taken') return;
      performCheck(username);
    });

    // On form submit: ensure username is available before allowing submission
    const form = document.getElementById('form-register-confirm');
    if (form) {
      form.addEventListener('submit', function(e) {
        // If available, allow submit
        if (currentState === 'available') return true;

        // Prevent submit and run/await a check
        e.preventDefault();
        const username = normalizeUsername(input.value);
        if (!username) {
          setAvailability('error', 'Enter your username');
          input.focus();
          return false;
        }

        // Show global loading while we validate availability before submit
        showGlobalLoading('Checking username...');

        const checkPromise = lastCheckPromise || performCheck(username);
        checkPromise.then(function(result) {
          if (result && result.available) {
            // proceed with submission (navigation will occur)
            form.submit();
            return;
          }
          // not available -> hide loader and focus
          hideGlobalLoading();
          input.focus();
        }).catch(function() {
          hideGlobalLoading();
          input.focus();
        });
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initUsernameAvailability);
  } else {
    initUsernameAvailability();
  }

})();
