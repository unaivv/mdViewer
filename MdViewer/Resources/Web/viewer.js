/*
 * MdViewer page runtime: syntax highlighting, math, diagrams, in-page anchors,
 * active-heading reporting, live theme changes and print preparation.
 *
 * Settings are injected by the app before the page loads as `window.mdViewerSettings`:
 *   { theme: "github", mermaidTheme: { light: "default", dark: "dark" } }
 */
(function () {
  'use strict';

  var settings = window.mdViewerSettings || {
    theme: 'github',
    mermaidTheme: { light: 'default', dark: 'dark' }
  };
  var darkQuery = window.matchMedia('(prefers-color-scheme: dark)');
  var isPrinting = false;

  function highlightCode() {
    if (!window.hljs) { return; }
    document.querySelectorAll('pre code').forEach(function (block) {
      window.hljs.highlightElement(block);
    });
  }

  function renderMath() {
    if (!window.katex) { return; }
    document.querySelectorAll('.math').forEach(function (element) {
      var tex = element.textContent;
      try {
        window.katex.render(tex, element, {
          displayMode: element.classList.contains('math-display'),
          throwOnError: false
        });
      } catch (error) {
        element.classList.add('math-error');
        element.title = String(error);
      }
    });
  }

  // Mermaid replaces the block's text with an SVG; keep the sources to re-render on theme changes.
  var mermaidBlocks = Array.prototype.slice.call(document.querySelectorAll('pre.mermaid'));
  var mermaidSources = mermaidBlocks.map(function (block) { return block.textContent; });

  function currentMermaidTheme() {
    if (isPrinting) { return settings.mermaidTheme.light; }
    return darkQuery.matches ? settings.mermaidTheme.dark : settings.mermaidTheme.light;
  }

  // Reading position as "this block, this far from the top of the viewport", which
  // survives reflows (font changes, re-rendered diagrams) unlike a raw scrollY.
  function captureReadingPosition() {
    var blocks = document.querySelectorAll('.markdown-body > *');
    for (var i = 0; i < blocks.length; i++) {
      var rect = blocks[i].getBoundingClientRect();
      if (rect.bottom > 0) { return { element: blocks[i], top: rect.top }; }
    }
    return null;
  }

  function restoreReadingPosition(position) {
    if (!position || !position.element.isConnected) { return; }
    var delta = position.element.getBoundingClientRect().top - position.top;
    if (Math.abs(delta) >= 1) { window.scrollBy(0, delta); }
  }

  function renderMermaid() {
    if (!window.mermaid || mermaidBlocks.length === 0) { return Promise.resolve(); }
    var position = captureReadingPosition();
    mermaidBlocks.forEach(function (block, index) {
      // Keep the current height while re-rendering so the scroll position does not jump.
      block.style.minHeight = block.offsetHeight ? block.offsetHeight + 'px' : '';
      block.removeAttribute('data-processed');
      block.textContent = mermaidSources[index];
    });
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: currentMermaidTheme()
    });
    return window.mermaid.run({ nodes: mermaidBlocks })
      .catch(function () { /* Mermaid renders its own error diagram. */ })
      .then(function () {
        mermaidBlocks.forEach(function (block) { block.style.minHeight = ''; });
        restoreReadingPosition(position);
      });
  }

  function installAnchorScrolling() {
    document.addEventListener('click', function (event) {
      var link = event.target.closest('a[href^="#"]');
      if (!link) { return; }
      var target = document.getElementById(decodeURIComponent(link.getAttribute('href').slice(1)));
      if (target) {
        event.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  }

  function installActiveHeadingReporting() {
    var handlers = window.webkit && window.webkit.messageHandlers;
    var handler = handlers && handlers.activeHeading;
    if (!handler) { return; }
    var headings = Array.prototype.slice.call(
      document.querySelectorAll('.markdown-body :is(h1, h2, h3, h4, h5, h6)[id]'));
    var lastReported = null;
    function report() {
      var active = headings.length ? headings[0].id : '';
      for (var i = 0; i < headings.length; i++) {
        if (headings[i].getBoundingClientRect().top <= 80) { active = headings[i].id; } else { break; }
      }
      if (active !== lastReported) {
        lastReported = active;
        handler.postMessage(active);
      }
    }
    var scheduled = false;
    window.addEventListener('scroll', function () {
      if (scheduled) { return; }
      scheduled = true;
      window.requestAnimationFrame(function () { scheduled = false; report(); });
    }, { passive: true });
    window.addEventListener('resize', report);
    report();
  }

  window.mdViewer = {
    /** Applies new settings live (theme switch) without reloading the page. */
    applySettings: function (newSettings) {
      var mermaidChanged = JSON.stringify(newSettings.mermaidTheme) !== JSON.stringify(settings.mermaidTheme);
      var position = captureReadingPosition();
      settings = newSettings;
      document.documentElement.dataset.theme = settings.theme;
      restoreReadingPosition(position);
      return mermaidChanged ? renderMermaid() : Promise.resolve();
    },
    /** Switches diagrams to their light variant before printing / exporting. */
    prepareForPrint: function () {
      isPrinting = true;
      return renderMermaid();
    },
    finishPrint: function () {
      isPrinting = false;
      return renderMermaid();
    },
    scrollToHeading: function (id) {
      var target = document.getElementById(id);
      if (target) { target.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    }
  };

  document.documentElement.dataset.theme = settings.theme;
  highlightCode();
  renderMath();
  renderMermaid();
  darkQuery.addEventListener('change', function () { renderMermaid(); });
  installAnchorScrolling();
  installActiveHeadingReporting();
})();
