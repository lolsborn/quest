/*
Language: Quest
Author: Steven Osborn
Description: Quest language syntax highlighting
Category: scripting
*/

export default function(hljs) {
  const KEYWORDS = {
    keyword:
      'let del if elif else end while for in to until step fun return use as and or not break continue type impl with self',
    literal:
      'true false nil',
    built_in:
      'puts print obj str num bool arr dict'
  };

  const STRING = {
    className: 'string',
    variants: [
      {
        begin: /"""/,
        end: /"""/,
        contains: [hljs.BACKSLASH_ESCAPE]
      },
      {
        begin: /f"/,
        end: /"/,
        contains: [
          hljs.BACKSLASH_ESCAPE,
          {
            className: 'subst',
            begin: /\{/,
            end: /\}/,
            keywords: KEYWORDS
          }
        ]
      },
      {
        begin: /"/,
        end: /"/,
        contains: [hljs.BACKSLASH_ESCAPE]
      }
    ]
  };

  const NUMBER = {
    className: 'number',
    relevance: 0,
    variants: [
      {
        begin: /\b\d+(\.\d+)?/
      }
    ]
  };

  const FUNCTION_CALL = {
    className: 'title.function',
    begin: /\b[a-zA-Z_][a-zA-Z0-9_]*(?=\()/
  };

  const METHOD_CALL = {
    className: 'title.function',
    begin: /\.[a-zA-Z_][a-zA-Z0-9_]*(?=\()/,
    relevance: 0
  };

  const COMMENT = {
    className: 'comment',
    begin: /#/,
    end: /$/,
    relevance: 0
  };

  return {
    name: 'Quest',
    aliases: ['quest', 'q'],
    keywords: KEYWORDS,
    contains: [
      COMMENT,
      STRING,
      NUMBER,
      FUNCTION_CALL,
      METHOD_CALL,
      {
        className: 'variable',
        begin: /\$[a-zA-Z_][a-zA-Z0-9_]*/
      }
    ]
  };
}
