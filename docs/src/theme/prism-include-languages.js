/**
 * This file tells Docusaurus to load our custom Quest language definition
 */

import siteConfig from '@generated/docusaurus.config';

export default function prismIncludeLanguages(PrismObject) {
  const {
    themeConfig: {prism: {additionalLanguages = []} = {}},
  } = siteConfig;

  globalThis.Prism = PrismObject;

  // Define Quest language inline
  PrismObject.languages.quest = {
    // Comments
    'comment': {
      pattern: /#.*/,
      greedy: true
    },

    // Multi-line strings and docstrings
    'string': {
      pattern: /"""[\s\S]*?"""|"(?:\\.|[^\\"\r\n])*"/,
      greedy: true
    },

    // Keywords
    'keyword': /\b(?:if|elif|else|end|while|for|in|fun|return|let|use|as|type|trait|impl|static|and|or|not|nil|true|false)\b/,

    // Built-in functions
    'builtin': /\b(?:puts|print|len|ticks_ms)\b/,

    // Function definitions and calls
    'function': {
      pattern: /\b[a-zA-Z_]\w*(?=\s*\()/,
      greedy: true
    },

    // Numbers (integers and floats)
    'number': /\b(?:0x[\da-f]+|\d+\.?\d*(?:e[+-]?\d+)?)\b/i,

    // Operators
    'operator': /\.\.|\+\+|--|==|!=|<=|>=|&&|\|\||<<|>>|[+\-*\/%<>=!&|^~]|::/,

    // Method calls and member access
    'property': /(?:\.)\s*[a-zA-Z_]\w*/,

    // Punctuation
    'punctuation': /[{}[\]();,.:]/,

    // Boolean values
    'boolean': /\b(?:true|false)\b/,

    // Nil value
    'constant': /\bnil\b/,

    // Class/Type names (capitalized identifiers)
    'class-name': /\b[A-Z]\w*\b/
  };

  // Add 'q' as an alias for quest
  PrismObject.languages.q = PrismObject.languages.quest;

  // Load other additional languages
  additionalLanguages.forEach((lang) => {
    if (lang !== 'quest' && lang !== 'q') {
      require(`prismjs/components/prism-${lang}`);
    }
  });

  delete globalThis.Prism;
}
