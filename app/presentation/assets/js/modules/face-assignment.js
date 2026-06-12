(function(app, window, document) {
  app.registerInitializer('face-assignment', function() {
    applyFaceBoxGeometry();

    const boxes = Array.from(document.querySelectorAll('.face-box[data-face-target]'));
    const panels = Array.from(document.querySelectorAll('[data-face-panel]'));
    const logPanels = Array.from(document.querySelectorAll('[data-face-log-panel]'));
    const selectedFaceNumber = document.getElementById('selected-face-number');
    const usernameOptions = document.querySelector('[data-username-options]');
    const currentUsername = normalizedUsername(usernameOptions && usernameOptions.getAttribute('data-current-username'));
    const currentAccountId = usernameOptions && usernameOptions.getAttribute('data-current-account-id');
    const accountStatuses = parseAccountStatuses();
    const selectedFaceKey = 'facecloak.selectedFace:' + window.location.pathname;
    let usernamesLoaded = false;
    let usernamesLoading = false;
    let accountsCache = [];

    function applyFaceBoxGeometry() {
      const img = document.querySelector('.image-detail-image');
      const overlay = document.querySelector('.face-overlay');
      if (img && overlay) {
        // The stage is sized to the rendered image. Keep the overlay on that
        // same origin so percentage face coordinates do not drift vertically.
        overlay.style.position = 'absolute';
        overlay.style.left = '0';
        overlay.style.top = '0';
        overlay.style.width = img.offsetWidth + 'px';
        overlay.style.height = img.offsetHeight + 'px';
      }

      if (img && img.offsetHeight > 0) {
        document.querySelectorAll('.image-assignment-layout .face-assignment-sidebar').forEach(function(sidebar) {
          sidebar.style.height = img.offsetHeight + 'px';
        });
      }

      document.querySelectorAll('.face-box[data-box-left]').forEach(function(box) {
        box.style.left = box.getAttribute('data-box-left') + '%';
        box.style.top = box.getAttribute('data-box-top') + '%';
        box.style.width = box.getAttribute('data-box-width') + '%';
        box.style.height = box.getAttribute('data-box-height') + '%';
      });
    }

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
      if (!Array.isArray(accounts)) return;
      // store into a local cache for cases where the datalist is not present
      accountsCache = accounts.filter(function(account) { return account && account.id; });

      if (!usernameOptions) return;

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
      if (usernameOptions) {
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

      // fallback to cached accounts if datalist not present
      return accountsCache
        .map(function(account) {
          return {
            id: account.id,
            handle: account.handle || ('@' + account.username),
            status: account.status || ''
          };
        })
        .filter(function(account) { return account.id && normalizedUsername(account.handle) !== currentUsername; });
    }

    function positionSuggestionMenu(input, menu) {
      const rect = input.closest('.assign-pill').getBoundingClientRect();
      menu.style.left = rect.left + 10 + 'px';
      menu.style.top = rect.bottom + 6 + 'px';
      menu.style.width = Math.max(180, rect.width - 20) + 'px';
    }

    function showSuggestionMessage(input, menu, message) {
      menu.innerHTML = '';
      const option = document.createElement('div');
      option.className = 'username-suggestion-option is-empty';
      option.textContent = message;
      menu.appendChild(option);
      positionSuggestionMenu(input, menu);
      menu.classList.add('visible');
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

      if (!usernamesLoaded && usernamesLoading) {
        showSuggestionMessage(input, menu, 'Loading accounts...');
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
      if (!matches.length) {
        showSuggestionMessage(input, menu, usernamesLoaded ? 'No matching accounts' : 'Type to search accounts');
        return;
      }

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

      positionSuggestionMenu(input, menu);
      menu.classList.toggle('visible', matches.length > 0);
    }

    function suggestionOptions(menu) {
      if (!menu) return [];
      return Array.from(menu.querySelectorAll('.username-suggestion-option'));
    }

    function enabledSuggestionOptions(menu) {
      return suggestionOptions(menu).filter(function(option) {
        return !option.disabled;
      });
    }

    function exactAccountMatch(input) {
      const username = normalizedUsername(input.value);
      if (!username) return null;

      return accountOptions().find(function(account) {
        return !account.status && normalizedUsername(account.handle) === username;
      });
    }

    function syncExactAccount(input) {
      const form = input.closest('.face-assign-form');
      const hiddenInput = form && form.querySelector('[data-assigned-user-id-value]');
      if (!hiddenInput || input.readOnly) return;

      const match = exactAccountMatch(input);
      hiddenInput.value = match ? match.id : '';
      if (match && form) clearAssignmentError(form);
    }

    function activeSuggestion(menu) {
      return enabledSuggestionOptions(menu).find(function(option) {
        return option.classList.contains('active');
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
      const field = form.closest('.face-field');
      const error = field && field.querySelector('[data-assignment-error]');

      if (pill) pill.classList.remove('assign-pill-error');
      if (input) {
        input.classList.remove('auth-input-error');
        input.removeAttribute('aria-invalid');
        input.setCustomValidity('');
      }
      if (error) error.textContent = '';
    }

    function loadUsernames() {
      if (!usernameOptions || usernamesLoaded || usernamesLoading) return;
      usernamesLoading = true;
      var sourceUrl = usernameOptions.getAttribute('data-source-url');
      if (!sourceUrl) sourceUrl = '/account/usernames';

      window.fetch(sourceUrl, { headers: { Accept: 'application/json' } })
        .then(function(response) {
          if (!response.ok) return { accounts: [] };
          return response.json();
        })
        .then(function(body) {
          populateAccounts(body.accounts || []);
          usernamesLoaded = true;
          document.querySelectorAll('[data-username-suggest]').forEach(function(input) {
            syncExactAccount(input);
            renderSuggestions(input);
          });
        })
        .catch(function() {
          usernamesLoaded = false;
        })
        .finally(function() {
          usernamesLoading = false;
          document.querySelectorAll('[data-username-suggest]').forEach(renderSuggestions);
        });
    }

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

      logPanels.forEach(function(panel) {
        panel.classList.toggle('active', panel.getAttribute('data-face-log-panel') === targetId);
      });

      const activePanel = document.getElementById(targetId);
      if (selectedFaceNumber && activePanel) {
        selectedFaceNumber.textContent = activePanel.getAttribute('data-face-number') || '';
      }

      if (activePanel) window.sessionStorage.setItem(selectedFaceKey, targetId);
    }

    document.querySelectorAll('[data-username-suggest]').forEach(function(input) {
      input.addEventListener('focus', function() {
        if (input.value.trim().startsWith('@')) loadUsernames();
        renderSuggestions(input);
      });

      input.addEventListener('input', function() {
        if (input.value.trim().startsWith('@')) loadUsernames();
        syncExactAccount(input);
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

    window.addEventListener('scroll', function() {
      document.querySelectorAll('[data-username-suggest]').forEach(function(input) {
        const pill = input.closest('.assign-pill');
        const menu = pill && pill.querySelector('[data-username-menu]');
        if (menu && menu.classList.contains('visible')) positionSuggestionMenu(input, menu);
      });
    }, true);

    document.querySelectorAll('[data-self-choice-toggle]').forEach(function(button) {
      button.addEventListener('click', function() {
        const faceId = button.getAttribute('data-self-choice-toggle');
        const choicePanel = Array.from(document.querySelectorAll('[data-self-choice-panel]')).find(function(panel) {
          return panel.getAttribute('data-self-choice-panel') === faceId;
        });
        const facePanel = button.closest('.face-side-panel');

        if (choicePanel) choicePanel.classList.remove('is-hidden');
        if (facePanel && facePanel.id) window.sessionStorage.setItem(selectedFaceKey, facePanel.id);
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

      form.addEventListener('submit', function(e) {
        const username = normalizedUsername(input.value);
        syncExactAccount(input);
        clearAssignmentError(form);

        if (String(hiddenInput && hiddenInput.value) === String(currentAccountId)) {
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

    document.querySelectorAll('.cloak-choice-form, .decline-assignment-form, .face-unassign-form').forEach(function(form) {
      form.addEventListener('submit', storeActiveFace);
    });

    document.querySelectorAll('[data-face-sidebar-tab]').forEach(function(button) {
      button.addEventListener('click', function() {
        const mode = button.getAttribute('data-face-sidebar-tab');
        const sidebar = button.closest('.face-assignment-sidebar');
        if (!sidebar) return;

        sidebar.classList.toggle('show-logs', mode === 'logs');
        sidebar.querySelectorAll('[data-face-sidebar-tab]').forEach(function(tab) {
          const isActive = tab.getAttribute('data-face-sidebar-tab') === mode;
          tab.classList.toggle('active', isActive);
          tab.setAttribute('aria-pressed', isActive ? 'true' : 'false');
        });
      });
    });

    if (!boxes.length || !panels.length) return;

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

    // Recompute overlay/box geometry when the image loads or the window resizes.
    const detailImage = document.querySelector('.image-detail-image');
    if (detailImage) {
      detailImage.addEventListener('load', applyFaceBoxGeometry);
    }
    window.addEventListener('resize', function() { window.requestAnimationFrame(applyFaceBoxGeometry); });
  });

  app.registerInitializer('identity-confirmation', function() {
    document.querySelectorAll('[data-confirm-identity]').forEach(function(button) {
      button.addEventListener('click', function() {
        const faceId = button.getAttribute('data-confirm-identity');
        const check = document.querySelector('[data-identity-check="' + faceId + '"]');
        const cloakSection = document.querySelector('[data-cloak-section="' + faceId + '"]');

        if (check) check.classList.add('is-confirmed');
        if (cloakSection) cloakSection.classList.remove('is-hidden');
      });
    });
  });
})(window.FaceCloak, window, document);
