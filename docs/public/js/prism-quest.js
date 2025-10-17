/**
 * Quest language definition for Prism.js
 * Adapted from Docusaurus theme
 */
(function (Prism) {
  Prism.languages.quest = {
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
    'keyword': /\b(?:if|elif|else|end|while|for|in|fun|return|let|const|use|as|type|trait|impl|static|pub|and|or|not|nil|true|false|try|catch|ensure|raise|match|with)\b/,

    // Built-in functions
    'builtin': /\b(?:puts|print|len|ticks_ms)\b/,

    // Function definitions and calls
    'function': {
      pattern: /\b[a-zA-Z_]\w*(?=\s*\()/,
      greedy: true
    },

    // Numbers (integers, floats, hex, binary, octal, bigint)
    'number': /\b(?:0x[\da-fA-F]+n?|0b[01]+n?|0o[0-7]+n?|\d+n|\d+\.?\d*(?:e[+-]?\d+)?)\b/i,

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
  Prism.languages.q = Prism.languages.quest;
}(Prism));
