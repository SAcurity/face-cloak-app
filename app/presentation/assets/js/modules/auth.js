(function(app, window, document) {
  app.registerInitializer('password-toggles', function() {
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
  });

  app.registerInitializer('username-availability', function() {
    const input = document.querySelector('[data-username-availability-url]');
    const message = document.getElementById('username-availability');
    if (!input || !message) return;

    const endpoint = input.getAttribute('data-username-availability-url');
    const originalUsername = normalizeUsername(input.getAttribute('data-current-username') || '');
    const serverError = document.querySelector('.server-username-error');
    const clearBtn = document.getElementById('username-clear');
    const spinner = document.getElementById('username-spinner');
    let timerId = null;
    let requestId = 0;
    let currentState = null;
    let lastCheckPromise = null;
    let lastCheckedUsername = null;

    function showGlobalLoading(text) {
      const overlay = document.getElementById('global-loading-overlay');
      if (!overlay) return;

      const textEl = overlay.querySelector('.loader .text');
      if (textEl) textEl.textContent = text || 'Loading...';
      overlay.classList.add('visible');
    }

    function hideGlobalLoading() {
      const overlay = document.getElementById('global-loading-overlay');
      if (overlay) overlay.classList.remove('visible');
    }

    function normalizeUsername(value) {
      return value.trim().replace(/^@+/, '');
    }

    function setAvailability(state, text) {
      message.className = 'username-availability-message mt-2';
      const group = input.closest('.input-group');
      if (group) group.classList.remove('is-available', 'is-taken', 'is-error');

      if (!state) {
        message.textContent = '';
        input.classList.remove('auth-input-error');
        return;
      }

      message.classList.add('is-' + state);
      message.textContent = text;

      if (state === 'taken' || state === 'error') {
        input.classList.add('auth-input-error');
        if (group) group.classList.add('is-taken');
      } else if (state === 'available' && group) {
        group.classList.add('is-available');
      }

      if (clearBtn && input.value && input.value.trim()) clearBtn.classList.remove('hidden');
    }

    function performCheck(username) {
      if (!username) {
        setAvailability(null, '');
        return Promise.resolve({ ok: true, available: false });
      }

      if (originalUsername && username === originalUsername) {
        requestId += 1;
        lastCheckedUsername = username;
        currentState = 'available';
        setAvailability('available', 'This is your current username.');
        lastCheckPromise = Promise.resolve({ ok: true, available: true, unchanged: true });
        return lastCheckPromise;
      }

      requestId += 1;
      const thisRequest = requestId;
      lastCheckedUsername = username;
      currentState = 'checking';
      setAvailability('checking', 'Checking username...');
      if (spinner) spinner.classList.add('visible');

      const request = window.fetch(endpoint + '/' + encodeURIComponent(username), {
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
          }

          currentState = 'taken';
          setAvailability('taken', 'Username is already taken.');
          return { ok: true, available: false };
        })
        .catch(function() {
          if (spinner) spinner.classList.remove('visible');
          if (thisRequest !== requestId) return { ok: false, stale: true };

          currentState = 'error';
          setAvailability('error', 'Could not check username right now.');
          return { ok: false, available: false };
        });

      lastCheckPromise = request;
      return request;
    }

    if (clearBtn) {
      if (!input.value || !input.value.trim()) clearBtn.classList.add('hidden');
      clearBtn.addEventListener('click', function(e) {
        e.preventDefault();
        requestId += 1;
        input.value = '';
        input.focus();
        setAvailability(null, '');
        if (spinner) spinner.classList.remove('visible');
        clearBtn.classList.add('hidden');
        currentState = null;
      });
    }

    input.addEventListener('input', function() {
      if (serverError) serverError.hidden = true;
      window.clearTimeout(timerId);
      currentState = null;
      setAvailability(null, '');

      if (clearBtn) {
        if (input.value && input.value.trim()) clearBtn.classList.remove('hidden');
        else clearBtn.classList.add('hidden');
      }

      const username = normalizeUsername(input.value);
      if (!username) return;

      timerId = window.setTimeout(function() {
        performCheck(username);
      }, 600);
    });

    input.addEventListener('blur', function() {
      window.clearTimeout(timerId);
      const username = normalizeUsername(input.value);
      if (!username) {
        setAvailability(null, '');
        return;
      }

      if (currentState === 'available' || currentState === 'taken') return;
      performCheck(username);
    });

    const form = input.closest('form') || document.getElementById('form-register-confirm');
    if (form) {
      form.addEventListener('submit', function(e) {
        if (currentState === 'available') return true;

        e.preventDefault();
        const username = normalizeUsername(input.value);
        if (!username) {
          setAvailability('error', 'Enter your username');
          input.focus();
          return false;
        }

        showGlobalLoading('Checking username...');
        const checkPromise = lastCheckedUsername === username && lastCheckPromise ? lastCheckPromise : performCheck(username);
        checkPromise.then(function(result) {
          if (result && result.available) {
            form.submit();
            return;
          }

          hideGlobalLoading();
          input.focus();
        }).catch(function() {
          hideGlobalLoading();
          input.focus();
        });
      });
    }
  });
})(window.FaceCloak, window, document);
