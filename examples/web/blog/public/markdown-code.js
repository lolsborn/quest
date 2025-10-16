/**
 * Convert markdown code blocks to Prism-compatible HTML
 */
(function() {
  function convertMarkdownCode() {
    // Find all elements that might contain markdown code blocks
    const contentElements = document.querySelectorAll('[style*="line-height"]');

    contentElements.forEach(element => {
      let html = element.innerHTML;

      // Convert ```language\ncode\n``` to <pre><code class="language-xxx">code</code></pre>
      html = html.replace(/```(\w+)\n([\s\S]*?)```/g, function(match, lang, code) {
        // Decode HTML entities in code
        const decoded = code
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&amp;/g, '&')
          .replace(/&quot;/g, '"')
          .replace(/&#39;/g, "'");

        // Re-encode for HTML display
        const encoded = decoded
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;')
          .replace(/'/g, '&#39;');

        return '<pre><code class="language-' + lang + '">' + encoded + '</code></pre>';
      });

      // Convert ```\ncode\n``` (no language) to <pre><code>code</code></pre>
      html = html.replace(/```\n([\s\S]*?)```/g, function(match, code) {
        const decoded = code
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&amp;/g, '&')
          .replace(/&quot;/g, '"')
          .replace(/&#39;/g, "'");

        const encoded = decoded
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;')
          .replace(/'/g, '&#39;');

        return '<pre><code>' + encoded + '</code></pre>';
      });

      element.innerHTML = html;
    });

    // Trigger Prism highlighting
    if (window.Prism) {
      Prism.highlightAll();
    }
  }

  // Run on DOM load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', convertMarkdownCode);
  } else {
    convertMarkdownCode();
  }
})();
