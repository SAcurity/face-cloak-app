(function(app, document) {
  app.registerInitializer('confirm-forms', function() {
    const dialog = document.getElementById('confirm-dialog');
    if (!dialog) return;

    const messageEl = document.getElementById('confirm-dialog-message');
    const submitButton = dialog.querySelector('[data-confirm-submit]');
    let pendingForm = null;

    function closeDialog() {
      dialog.hidden = true;
      pendingForm = null;
    }

    function openDialog(form) {
      pendingForm = form;
      if (messageEl) messageEl.textContent = form.getAttribute('data-confirm-message') || 'Are you sure?';
      dialog.hidden = false;
      if (submitButton) submitButton.focus();
    }

    document.querySelectorAll('form[data-confirm-message]').forEach(function(form) {
      form.addEventListener('submit', function(e) {
        if (form.getAttribute('data-confirmed') === 'true') {
          form.removeAttribute('data-confirmed');
          return;
        }

        e.preventDefault();
        openDialog(form);
      });
    });

    dialog.querySelectorAll('[data-confirm-cancel]').forEach(function(button) {
      button.addEventListener('click', closeDialog);
    });

    if (submitButton) {
      submitButton.addEventListener('click', function() {
        if (!pendingForm) return;

        const form = pendingForm;
        form.setAttribute('data-confirmed', 'true');
        closeDialog();
        if (typeof form.requestSubmit === 'function') form.requestSubmit();
        else form.submit();
      });
    }

    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && !dialog.hidden) closeDialog();
    });
  });

  app.registerInitializer('submit-loading', function() {
    document.querySelectorAll('form[data-loading-message]').forEach(function(form) {
      form.addEventListener('submit', function() {
        const overlay = document.getElementById('global-loading-overlay');
        if (!overlay) return;

        const textEl = overlay.querySelector('.loader .text');
        if (textEl) textEl.textContent = form.getAttribute('data-loading-message') || 'Loading...';
        overlay.classList.add('visible');
      });
    });
  });
})(window.FaceCloak, document);
