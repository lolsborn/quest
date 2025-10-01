// Quest language definition for highlight.js
// This must load BEFORE book.js processes code blocks

(function() {
  'use strict';
  
  // Register immediately when this script loads
  if (typeof hljs !== 'undefined') {
    console.log('Registering Quest language for highlight.js');
    
    hljs.registerLanguage('quest', function(hljs) {
      const KEYWORDS = {
        keyword: 'let del if elif else end while for in to until step fun return use as and or not break continue type impl with self',
        literal: 'true false nil',
        built_in: 'puts print'
      };

      const STRING = {
        className: 'string',
        variants: [
          { begin: /"""/, end: /"""/, contains: [hljs.BACKSLASH_ESCAPE] },
          {
            begin: /f"/,
            end: /"/,
            contains: [
              hljs.BACKSLASH_ESCAPE,
              { className: 'subst', begin: /\{/, end: /\}/ }
            ]
          },
          { begin: /"/, end: /"/, contains: [hljs.BACKSLASH_ESCAPE] }
        ]
      };

      return {
        name: 'Quest',
        aliases: ['quest', 'q'],
        keywords: KEYWORDS,
        contains: [
          hljs.COMMENT('#', '$'),
          STRING,
          {
            className: 'number',
            begin: /\b\d+(\.\d+)?/,
            relevance: 0
          },
          {
            className: 'title.function',
            begin: /\b[a-zA-Z_][a-zA-Z0-9_]*(?=\()/
          },
          {
            className: 'title.function',
            begin: /\.[a-zA-Z_][a-zA-Z0-9_]*(?=\()/
          }
        ]
      };
    });
    
    console.log('Quest language registered. Available languages:', hljs.listLanguages());
  } else {
    console.error('highlight.js (hljs) not found!');
  }
})();
