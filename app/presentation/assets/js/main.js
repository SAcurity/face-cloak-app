(function(window, document) {
  const app = window.FaceCloak = window.FaceCloak || {};
  const initializers = [];
  let booted = false;

  function runInitializer(entry) {
    try {
      entry.init();
    } catch (error) {
      window.console.error('[FaceCloak] initializer failed:', entry.name, error);
    }
  }

  app.registerInitializer = function(name, init) {
    if (typeof init !== 'function') return;

    const entry = { name: name || 'anonymous', init: init };
    if (booted) runInitializer(entry);
    else initializers.push(entry);
  };

  app.runInitializers = function() {
    if (booted) return;
    booted = true;

    while (initializers.length) {
      runInitializer(initializers.shift());
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', app.runInitializers);
  } else {
    app.runInitializers();
  }
})(window, document);
