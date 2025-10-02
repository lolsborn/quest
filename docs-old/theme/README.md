# Custom Syntax Highlighting for Quest

This directory contains custom syntax highlighting for the Quest language.

## Building Custom highlight.js

To add Quest syntax highlighting to the mdbook:

1. Download highlight.js source:
```bash
git clone https://github.com/highlightjs/highlight.js.git
cd highlight.js
npm install
```

2. Copy the Quest language definition:
```bash
cp /path/to/quest/docs/theme/quest.js extra/quest.js
```

3. Build highlight.js with Quest support:
```bash
node tools/build.js quest javascript python ruby go rust
```

4. Copy the built file to the theme directory:
```bash
cp build/highlight.min.js /path/to/quest/docs/theme/highlight.js
```

5. Rebuild the mdbook:
```bash
mdbook build
```

## Quick Alternative

For development, you can add this script to your book's `theme/head.hbs` or `theme/header.hbs`:

```html
<script>
// Register Quest language dynamically
hljs.registerLanguage('quest', function(hljs) {
  const KEYWORDS = {
    keyword: 'let del if elif else end while for in to until step fun return use as and or not break continue',
    literal: 'true false nil',
    built_in: 'puts print'
  };
  
  return {
    name: 'Quest',
    aliases: ['quest', 'q'],
    keywords: KEYWORDS,
    contains: [
      hljs.COMMENT('#', '$'),
      {
        className: 'string',
        variants: [
          { begin: /"""/, end: /"""/ },
          { begin: /f"/, end: /"/ },
          { begin: /"/, end: /"/ }
        ]
      },
      {
        className: 'number',
        begin: /\b\d+(\.\d+)?/
      },
      {
        className: 'title.function',
        begin: /\b[a-zA-Z_][a-zA-Z0-9_]*(?=\()/
      }
    ]
  };
});
</script>
```

Then use ` ```quest ` in your markdown code blocks.
