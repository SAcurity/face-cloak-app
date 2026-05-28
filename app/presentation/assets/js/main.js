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

  function initPageBack() {
    const previousPageKey = 'facecloak.previousPage';
    const currentPath = window.location.pathname + window.location.search;
    const imageDetailPattern = /^\/images\/[^/]+\/(?:raw|protected)$/;
    const isImageDetail = imageDetailPattern.test(window.location.pathname);
    const backLinks = document.querySelectorAll('[data-page-back="true"]');
    const previousPage = window.sessionStorage.getItem(previousPageKey);
    const validPreviousPage = previousPage && previousPage !== currentPath ? previousPage : '/';

    backLinks.forEach(function(link) {
      link.setAttribute('href', validPreviousPage);
    });

    if (!isImageDetail) {
      window.sessionStorage.setItem(previousPageKey, currentPath);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPageBack);
  } else {
    initPageBack();
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

  function initFaceAssignment() {
    const boxes = Array.from(document.querySelectorAll('.face-box[data-face-target]'));
    const panels = Array.from(document.querySelectorAll('[data-face-panel]'));
    const selectedFaceNumber = document.getElementById('selected-face-number');
    const usernameOptions = document.querySelector('[data-username-options]');
    const currentUsername = normalizedUsername(usernameOptions && usernameOptions.getAttribute('data-current-username'));
    const currentAccountId = usernameOptions && usernameOptions.getAttribute('data-current-account-id');
    const accountStatuses = parseAccountStatuses();
    const selectedFaceKey = 'facecloak.selectedFace:' + window.location.pathname;
    let usernamesLoaded = false;

    function normalizedUsername(value) {
      return (value || '').trim().replace(/^@+/, '').toLowerCase();
    }

    function parseAccountStatuses() {
      if (!usernameOptions) return {};
      try {
        return JSON.parse(usernameOptions.getAttribute('data-account-statuses') || '{}');
      } catch (e) {
        return {};
      }
    }

    function accountStatus(account) {
      return accountStatuses[String(account.id)] || accountStatuses['username:' + normalizedUsername(account.handle)];
    }

    function populateAccounts(accounts) {
      if (!usernameOptions || !Array.isArray(accounts)) return;

      const existing = new Set(
        Array.from(usernameOptions.querySelectorAll('option')).map(function(option) {
          return option.getAttribute('data-account-id');
        })
      );

      accounts.forEach(function(account) {
        if (!account || !account.id || normalizedUsername(account.username) === currentUsername) return;
        if (String(account.id) === String(currentAccountId) || existing.has(String(account.id))) return;
        const option = document.createElement('option');
        option.value = account.handle || ('@' + account.username);
        option.setAttribute('data-account-id', account.id);
        option.setAttribute('data-account-status', accountStatus({ id: account.id, handle: option.value }) || '');
        usernameOptions.appendChild(option);
        existing.add(String(account.id));
      });
    }

    function accountOptions() {
      if (!usernameOptions) return [];
      return Array.from(usernameOptions.querySelectorAll('option'))
        .map(function(option) {
          return {
            id: option.getAttribute('data-account-id'),
            handle: option.value,
            status: option.getAttribute('data-account-status') || ''
          };
        })
        .filter(function(account) {
          return account.id && normalizedUsername(account.handle) !== currentUsername;
        });
    }

    function renderSuggestions(input) {
      const pill = input.closest('.assign-pill');
      const menu = pill && pill.querySelector('[data-username-menu]');
      if (!menu) return;

      if (input.readOnly || pill.classList.contains('is-assigned')) {
        menu.classList.remove('visible');
        menu.innerHTML = '';
        return;
      }

      const rawQuery = input.value.trim();
      if (!rawQuery.startsWith('@')) {
        menu.classList.remove('visible');
        menu.innerHTML = '';
        return;
      }

      const query = rawQuery.replace(/^@+/, '').toLowerCase();
      const explicitSearch = query.length > 0;
      const matches = accountOptions()
        .filter(function(account) {
          if (!account.handle.toLowerCase().replace(/^@+/, '').startsWith(query)) return false;
          return explicitSearch || !account.status;
        })
        .slice(0, 8);

      menu.innerHTML = '';
      matches.forEach(function(account) {
        const option = document.createElement('button');
        option.type = 'button';
        option.className = 'username-suggestion-option' + (account.status ? ' disabled' : '');
        option.disabled = Boolean(account.status);
        option.setAttribute('data-account-id', account.id);
        const label = document.createElement('span');
        label.className = 'username-suggestion-handle';
        label.textContent = account.handle;
        option.appendChild(label);
        if (account.status) {
          const status = document.createElement('span');
          status.className = 'username-suggestion-status';
          status.textContent = account.status;
          option.appendChild(status);
        }
        option.addEventListener('mousedown', function(e) {
          e.preventDefault();
          if (account.status) return;
          chooseSuggestion(input, menu, option);
        });
        menu.appendChild(option);
      });

      menu.classList.toggle('visible', matches.length > 0);
    }

    function suggestionOptions(menu) {
      if (!menu) return [];
      return Array.from(menu.querySelectorAll('.username-suggestion-option'));
    }

    function activeSuggestion(menu) {
      return enabledSuggestionOptions(menu).find(function(option) {
        return option.classList.contains('active');
      });
    }

    function enabledSuggestionOptions(menu) {
      return suggestionOptions(menu).filter(function(option) {
        return !option.disabled;
      });
    }

    function setActiveSuggestion(menu, index) {
      const options = enabledSuggestionOptions(menu);
      suggestionOptions(menu).forEach(function(option) {
        option.classList.remove('active');
      });
      options.forEach(function(option, optionIndex) {
        option.classList.toggle('active', optionIndex === index);
      });
      if (options[index]) options[index].scrollIntoView({ block: 'nearest' });
    }

    function chooseSuggestion(input, menu, option) {
      const form = input.closest('.face-assign-form');
      const hiddenInput = form && form.querySelector('[data-assigned-user-id-value]');
      if (option.disabled) return;
      input.value = option.querySelector('.username-suggestion-handle').textContent;
      if (hiddenInput) hiddenInput.value = option.getAttribute('data-account-id') || '';
      if (form) clearAssignmentError(form);
      menu.classList.remove('visible');
      input.focus();
    }

    function assignmentErrorElement(form) {
      let error = form.querySelector('[data-assignment-error]');
      if (error) return error;

      const field = form.closest('.face-field');
      const row = field && field.querySelector('.assign-control-row');
      error = document.createElement('div');
      error.className = 'auth-field-message assign-field-message';
      error.setAttribute('data-assignment-error', 'true');
      error.setAttribute('aria-live', 'polite');
      if (row && row.parentNode) row.insertAdjacentElement('afterend', error);
      return error;
    }

    function setAssignmentError(form, message) {
      const input = form.querySelector('[data-username-suggest]');
      const pill = form.querySelector('.assign-pill');
      const error = assignmentErrorElement(form);
      if (pill) pill.classList.add('assign-pill-error');
      if (input) {
        input.classList.add('auth-input-error');
        input.setAttribute('aria-invalid', 'true');
      }
      if (error) error.textContent = message;
    }

    function clearAssignmentError(form) {
      const input = form.querySelector('[data-username-suggest]');
      const pill = form.querySelector('.assign-pill');
      const error = form.closest('.face-field') && form.closest('.face-field').querySelector('[data-assignment-error]');
      if (pill) pill.classList.remove('assign-pill-error');
      if (input) {
        input.classList.remove('auth-input-error');
        input.removeAttribute('aria-invalid');
        input.setCustomValidity('');
      }
      if (error) error.textContent = '';
    }

    function loadUsernames() {
      if (!usernameOptions || usernamesLoaded) return;
      usernamesLoaded = true;

      const sourceUrl = usernameOptions.getAttribute('data-source-url');
      if (!sourceUrl) return;

      window.fetch(sourceUrl, { headers: { Accept: 'application/json' } })
        .then(function(response) {
          if (!response.ok) return { accounts: [] };
          return response.json();
        })
        .then(function(body) {
          populateAccounts(body.accounts || []);
          document.querySelectorAll('[data-username-suggest]').forEach(renderSuggestions);
        })
        .catch(function() {});
    }

    document.querySelectorAll('[data-username-suggest]').forEach(function(input) {
      input.addEventListener('focus', function() {
        if (input.value.trim().startsWith('@')) loadUsernames();
        renderSuggestions(input);
      });

      input.addEventListener('input', function() {
        if (input.value.trim().startsWith('@')) loadUsernames();
        renderSuggestions(input);
      });

      input.addEventListener('keydown', function(e) {
        const pill = input.closest('.assign-pill');
        const menu = pill && pill.querySelector('[data-username-menu]');
        const options = enabledSuggestionOptions(menu);
        if (!menu || !menu.classList.contains('visible') || !options.length) return;

        const currentIndex = options.indexOf(activeSuggestion(menu));
        if (e.key === 'ArrowDown') {
          e.preventDefault();
          setActiveSuggestion(menu, currentIndex < options.length - 1 ? currentIndex + 1 : 0);
        } else if (e.key === 'ArrowUp') {
          e.preventDefault();
          setActiveSuggestion(menu, currentIndex > 0 ? currentIndex - 1 : options.length - 1);
        } else if (e.key === 'Enter') {
          const option = activeSuggestion(menu) || options[0];
          e.preventDefault();
          chooseSuggestion(input, menu, option);
        } else if (e.key === 'Escape') {
          menu.classList.remove('visible');
        }
      });

      input.addEventListener('blur', function() {
        const pill = input.closest('.assign-pill');
        const menu = pill && pill.querySelector('[data-username-menu]');
        window.setTimeout(function() {
          if (menu) menu.classList.remove('visible');
        }, 120);
      });
    });

    document.querySelectorAll('.assign-self-form').forEach(function(form) {
      form.addEventListener('submit', function() {
        storeActiveFace();
        document.querySelectorAll('.face-self-submit').forEach(function(button) {
          button.disabled = true;
        });
      });
    });

    document.querySelectorAll('.face-assign-form').forEach(function(form) {
      const input = form.querySelector('[data-username-suggest]');
      const hiddenInput = form.querySelector('[data-assigned-user-id-value]');
      if (!input) return;

      function declinedUsernames() {
        return (input.getAttribute('data-declined-usernames') || '')
          .split(',')
          .map(normalizedUsername)
          .filter(Boolean);
      }

      input.addEventListener('input', function() {
        clearAssignmentError(form);
        if (hiddenInput) hiddenInput.value = '';
      });

      form.addEventListener('submit', function(e) {
        storeActiveFace();
        const username = normalizedUsername(input.value);
        const selfUsername = normalizedUsername(input.getAttribute('data-current-username')) || currentUsername;
        if (username && username === selfUsername) {
          setAssignmentError(form, 'Use Myself to assign your own face.');
          e.preventDefault();
          return;
        }

        if (username && declinedUsernames().includes(username)) {
          setAssignmentError(form, input.value + ' declined this assignment.');
          e.preventDefault();
          return;
        }

        if (!hiddenInput || !hiddenInput.value) {
          setAssignmentError(form, username ? 'Choose a valid account from the list.' : 'Enter a username.');
          e.preventDefault();
        }
      });
    });

    document.querySelectorAll('.cloak-choice-form, .decline-assignment-form').forEach(function(form) {
      form.addEventListener('submit', storeActiveFace);
    });

    if (!boxes.length || !panels.length) return;

    function storeActiveFace() {
      const activeBox = boxes.find(function(box) {
        return box.classList.contains('active');
      });
      if (activeBox) window.sessionStorage.setItem(selectedFaceKey, activeBox.getAttribute('data-face-target'));
    }

    function activateFace(targetId) {
      boxes.forEach(function(box) {
        const isActive = box.getAttribute('data-face-target') === targetId;
        box.classList.toggle('active', isActive);
        box.setAttribute('aria-pressed', isActive ? 'true' : 'false');
      });

      panels.forEach(function(panel) {
        panel.classList.toggle('active', panel.id === targetId);
      });

      const activePanel = document.getElementById(targetId);
      if (selectedFaceNumber && activePanel) {
        selectedFaceNumber.textContent = activePanel.getAttribute('data-face-number') || '';
      }

      if (activePanel) window.sessionStorage.setItem(selectedFaceKey, targetId);
    }

    boxes.forEach(function(box) {
      box.setAttribute('aria-pressed', box.classList.contains('active') ? 'true' : 'false');
      box.addEventListener('click', function() {
        activateFace(box.getAttribute('data-face-target'));
      });
    });

    const storedTargetId = window.sessionStorage.getItem(selectedFaceKey);
    const storedBox = storedTargetId && boxes.find(function(box) {
      return box.getAttribute('data-face-target') === storedTargetId;
    });
    const activeBox = storedBox || boxes.find(function(box) {
      return box.classList.contains('active');
    });
    if (activeBox) activateFace(activeBox.getAttribute('data-face-target'));
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFaceAssignment);
  } else {
    initFaceAssignment();
  }

})();
