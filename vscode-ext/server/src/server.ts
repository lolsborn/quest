import {
  createConnection,
  TextDocuments,
  ProposedFeatures,
  InitializeParams,
  TextDocumentSyncKind,
  InitializeResult,
  CompletionItem,
  CompletionItemKind,
  Diagnostic,
  DiagnosticSeverity,
  TextDocumentPositionParams,
  Hover,
  MarkupKind,
} from 'vscode-languageserver/node';

import { TextDocument } from 'vscode-languageserver-textdocument';

const connection = createConnection(ProposedFeatures.all);
const documents: TextDocuments<TextDocument> = new TextDocuments(TextDocument);

// Quest language keywords
const KEYWORDS = [
  'if', 'elif', 'else', 'end',
  'let', 'fun', 'type', 'impl',
  'while', 'for', 'in', 'break', 'continue', 'return',
  'and', 'or', 'not',
  'true', 'false', 'nil'
];

// Built-in functions
const BUILTIN_FUNCTIONS = [
  { name: 'puts', doc: 'Print a line to stdout with newline' },
  { name: 'print', doc: 'Print to stdout without newline' }
];

// Common methods organized by type
const METHODS = {
  Num: [
    { name: 'plus', doc: 'Add two numbers' },
    { name: 'minus', doc: 'Subtract two numbers' },
    { name: 'times', doc: 'Multiply two numbers' },
    { name: 'div', doc: 'Divide two numbers' },
    { name: 'mod', doc: 'Modulo operation' },
    { name: '_id', doc: 'Get unique object ID' }
  ],
  Str: [
    { name: 'len', doc: 'Get string length' },
    { name: 'concat', doc: 'Concatenate strings' },
    { name: 'upper', doc: 'Convert to uppercase' },
    { name: 'lower', doc: 'Convert to lowercase' },
    { name: 'capitalize', doc: 'Capitalize first letter' },
    { name: 'title', doc: 'Convert to title case' },
    { name: 'trim', doc: 'Remove leading and trailing whitespace' },
    { name: 'ltrim', doc: 'Remove leading whitespace' },
    { name: 'rtrim', doc: 'Remove trailing whitespace' },
    { name: 'startswith', doc: 'Check if string starts with prefix' },
    { name: 'endswith', doc: 'Check if string ends with suffix' },
    { name: 'count', doc: 'Count occurrences of substring' },
    { name: '_id', doc: 'Get unique object ID' }
  ],
  Bool: [
    { name: 'eq', doc: 'Check equality' },
    { name: 'neq', doc: 'Check inequality' },
    { name: '_id', doc: 'Get unique object ID' }
  ],
  Fun: [
    { name: '_doc', doc: 'Get method documentation' },
    { name: '_str', doc: 'Get string representation' },
    { name: '_rep', doc: 'Get REPL representation' },
    { name: '_id', doc: 'Get unique object ID' }
  ]
};

connection.onInitialize((params: InitializeParams) => {
  const result: InitializeResult = {
    capabilities: {
      textDocumentSync: TextDocumentSyncKind.Incremental,
      completionProvider: {
        resolveProvider: true,
        triggerCharacters: ['.']
      },
      hoverProvider: true
    }
  };
  return result;
});

connection.onInitialized(() => {
  connection.console.log('Quest Language Server initialized');
});

// Provide completions
connection.onCompletion(
  (textDocumentPosition: TextDocumentPositionParams): CompletionItem[] => {
    const document = documents.get(textDocumentPosition.textDocument.uri);
    if (!document) {
      return [];
    }

    const text = document.getText();
    const offset = document.offsetAt(textDocumentPosition.position);

    // Check if we're after a dot (method completion)
    const beforeCursor = text.substring(0, offset);
    const dotMatch = beforeCursor.match(/\.(\w*)$/);

    if (dotMatch) {
      // Provide method completions for all types
      const allMethods: CompletionItem[] = [];
      for (const [typeName, methods] of Object.entries(METHODS)) {
        for (const method of methods) {
          allMethods.push({
            label: method.name,
            kind: CompletionItemKind.Method,
            detail: `${typeName} method`,
            documentation: method.doc
          });
        }
      }
      return allMethods;
    }

    // Provide keyword and built-in completions
    const completions: CompletionItem[] = [];

    // Keywords
    for (const keyword of KEYWORDS) {
      completions.push({
        label: keyword,
        kind: CompletionItemKind.Keyword
      });
    }

    // Built-in functions
    for (const fn of BUILTIN_FUNCTIONS) {
      completions.push({
        label: fn.name,
        kind: CompletionItemKind.Function,
        documentation: fn.doc
      });
    }

    return completions;
  }
);

// Provide hover information
connection.onHover(
  (textDocumentPosition: TextDocumentPositionParams): Hover | null => {
    const document = documents.get(textDocumentPosition.textDocument.uri);
    if (!document) {
      return null;
    }

    const text = document.getText();
    const offset = document.offsetAt(textDocumentPosition.position);

    // Find word at cursor
    const wordPattern = /\b\w+\b/g;
    let match;
    while ((match = wordPattern.exec(text)) !== null) {
      if (offset >= match.index && offset <= match.index + match[0].length) {
        const word = match[0];

        // Check built-in functions
        const fn = BUILTIN_FUNCTIONS.find(f => f.name === word);
        if (fn) {
          return {
            contents: {
              kind: MarkupKind.Markdown,
              value: `**${fn.name}()**\n\n${fn.doc}`
            }
          };
        }

        // Check keywords
        if (KEYWORDS.includes(word)) {
          return {
            contents: {
              kind: MarkupKind.Markdown,
              value: `**${word}** (keyword)`
            }
          };
        }
      }
    }

    return null;
  }
);

// Basic diagnostics for common errors
documents.onDidChangeContent(change => {
  validateTextDocument(change.document);
});

function validateTextDocument(textDocument: TextDocument): void {
  const text = textDocument.getText();
  const diagnostics: Diagnostic[] = [];

  // Check for unbalanced if/end blocks
  const lines = text.split('\n');
  let nestingLevel = 0;
  const nestingStack: { keyword: string; line: number }[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    if (line.match(/^\s*(if|fun|while|for|type|impl)\b/)) {
      const keyword = line.match(/^\s*(\w+)/)?.[1] || '';
      nestingLevel++;
      nestingStack.push({ keyword, line: i });
    } else if (line.match(/^\s*end\b/)) {
      nestingLevel--;
      if (nestingLevel < 0) {
        diagnostics.push({
          severity: DiagnosticSeverity.Error,
          range: {
            start: { line: i, character: 0 },
            end: { line: i, character: line.length }
          },
          message: 'Unexpected "end" without matching block start',
          source: 'quest'
        });
      } else {
        nestingStack.pop();
      }
    }
  }

  if (nestingLevel > 0) {
    for (const item of nestingStack) {
      diagnostics.push({
        severity: DiagnosticSeverity.Error,
        range: {
          start: { line: item.line, character: 0 },
          end: { line: item.line, character: lines[item.line].length }
        },
        message: `Block started with "${item.keyword}" is missing "end"`,
        source: 'quest'
      });
    }
  }

  connection.sendDiagnostics({ uri: textDocument.uri, diagnostics });
}

documents.listen(connection);
connection.listen();
