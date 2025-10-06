"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const node_1 = require("vscode-languageserver/node");
const vscode_languageserver_textdocument_1 = require("vscode-languageserver-textdocument");
const connection = (0, node_1.createConnection)(node_1.ProposedFeatures.all);
const documents = new node_1.TextDocuments(vscode_languageserver_textdocument_1.TextDocument);
// Track module aliases per document
const documentModuleAliases = new Map();
// Quest language keywords
const KEYWORDS = [
    'if', 'elif', 'else', 'end',
    'let', 'fun', 'type', 'impl',
    'while', 'for', 'in', 'break', 'continue', 'return',
    'and', 'or', 'not',
    'true', 'false', 'nil'
];
// Built-in functions (truly global, no module needed)
const BUILTIN_FUNCTIONS = [
    { name: 'puts', doc: 'Print arguments to stdout with newline' },
    { name: 'print', doc: 'Print arguments to stdout without newline' }
];
// Standard library modules
const STD_MODULES = [
    { path: 'std/math', doc: 'Math functions (sin, cos, tan, floor, ceil, round, pi, tau)' },
    { path: 'std/test', doc: 'Testing framework (module, describe, it, assert_eq, assert_raises)' },
    { path: 'std/encoding/json', doc: 'JSON parsing and stringification (parse, stringify, stringify_pretty)' },
    { path: 'std/encoding/b64', doc: 'Base64 encoding/decoding (encode, decode, encode_url, decode_url)' },
    { path: 'std/hash', doc: 'Cryptographic hashing (md5, sha1, sha256, sha512, crc32, bcrypt)' },
    { path: 'std/crypto', doc: 'Cryptographic operations (hmac_sha256, hmac_sha512)' },
    { path: 'std/io', doc: 'File I/O operations (read, write, append, remove, exists, is_file, is_dir, size, glob)' },
    { path: 'std/term', doc: 'Terminal styling and colors' },
    { path: 'std/time', doc: 'Date and time handling (now, parse, datetime, ticks_ms, sleep)' },
    { path: 'std/log', doc: 'Logging utilities' }
];
// Module methods
const MODULE_METHODS = {
    'std/math': [
        { name: 'pi', doc: 'Mathematical constant π (3.14159...)' },
        { name: 'tau', doc: 'Mathematical constant τ (2π)' },
        { name: 'sin', doc: 'Calculate sine of angle in radians' },
        { name: 'cos', doc: 'Calculate cosine of angle in radians' },
        { name: 'tan', doc: 'Calculate tangent of angle in radians' },
        { name: 'asin', doc: 'Calculate arcsine (inverse sine)' },
        { name: 'acos', doc: 'Calculate arccosine (inverse cosine)' },
        { name: 'atan', doc: 'Calculate arctangent (inverse tangent)' },
        { name: 'abs', doc: 'Calculate absolute value' },
        { name: 'sqrt', doc: 'Calculate square root' },
        { name: 'ln', doc: 'Calculate natural logarithm (base e)' },
        { name: 'log10', doc: 'Calculate logarithm base 10' },
        { name: 'exp', doc: 'Calculate e raised to the power' },
        { name: 'floor', doc: 'Round down to nearest integer' },
        { name: 'ceil', doc: 'Round up to nearest integer' },
        { name: 'round', doc: 'Round to nearest integer or decimal places' }
    ],
    'std/hash': [
        { name: 'md5', doc: 'Calculate MD5 hash' },
        { name: 'sha1', doc: 'Calculate SHA-1 hash' },
        { name: 'sha256', doc: 'Calculate SHA-256 hash' },
        { name: 'sha512', doc: 'Calculate SHA-512 hash' },
        { name: 'hmac_sha256', doc: 'Calculate HMAC-SHA256' },
        { name: 'hmac_sha512', doc: 'Calculate HMAC-SHA512' },
        { name: 'crc32', doc: 'Calculate CRC32 checksum' }
    ],
    'std/crypto': [
        { name: 'hmac_sha256', doc: 'HMAC-SHA256: crypto.hmac_sha256(message, key)' },
        { name: 'hmac_sha512', doc: 'HMAC-SHA512: crypto.hmac_sha512(message, key)' }
    ],
    'std/encoding/json': [
        { name: 'parse', doc: 'Parse JSON string into Quest value' },
        { name: 'try_parse', doc: 'Try to parse JSON, return nil on error' },
        { name: 'is_valid', doc: 'Check if string is valid JSON' },
        { name: 'stringify', doc: 'Convert Quest value to JSON string' },
        { name: 'stringify_pretty', doc: 'Convert to pretty-printed JSON' },
        { name: 'is_array', doc: 'Check if value is an array' }
    ],
    'std/encoding/b64': [
        { name: 'encode', doc: 'Encode data to base64' },
        { name: 'decode', doc: 'Decode base64 data' },
        { name: 'encode_url', doc: 'Encode data to URL-safe base64' },
        { name: 'decode_url', doc: 'Decode URL-safe base64 data' }
    ],
    'std/io': [
        { name: 'read', doc: 'Read entire file contents as string' },
        { name: 'write', doc: 'Write string to file (overwrites)' },
        { name: 'append', doc: 'Append string to file' },
        { name: 'exists', doc: 'Check if path exists' },
        { name: 'is_file', doc: 'Check if path is a file' },
        { name: 'is_dir', doc: 'Check if path is a directory' },
        { name: 'size', doc: 'Get file size in bytes' },
        { name: 'copy', doc: 'Copy file from source to destination' },
        { name: 'move', doc: 'Move/rename file from source to destination' },
        { name: 'remove', doc: 'Remove file or directory' },
        { name: 'glob', doc: 'Find all files matching a glob pattern' },
        { name: 'glob_match', doc: 'Check if path matches glob pattern' }
    ],
    'std/term': [
        { name: 'color', doc: 'Return colored text with optional attributes' },
        { name: 'on_color', doc: 'Return text with background color' },
        { name: 'red', doc: 'Return red colored text' },
        { name: 'green', doc: 'Return green colored text' },
        { name: 'yellow', doc: 'Return yellow colored text' },
        { name: 'blue', doc: 'Return blue colored text' },
        { name: 'magenta', doc: 'Return magenta colored text' },
        { name: 'cyan', doc: 'Return cyan colored text' },
        { name: 'white', doc: 'Return white colored text' },
        { name: 'grey', doc: 'Return grey colored text' },
        { name: 'bold', doc: 'Return bold text' },
        { name: 'dimmed', doc: 'Return dimmed text' },
        { name: 'underline', doc: 'Return underlined text' },
        { name: 'blink', doc: 'Return blinking text' },
        { name: 'reverse', doc: 'Return text with reversed foreground/background' },
        { name: 'hidden', doc: 'Return hidden text' },
        { name: 'move_up', doc: 'Move cursor up n lines' },
        { name: 'move_down', doc: 'Move cursor down n lines' },
        { name: 'move_left', doc: 'Move cursor left n columns' },
        { name: 'move_right', doc: 'Move cursor right n columns' },
        { name: 'move_to', doc: 'Move cursor to specific position' },
        { name: 'save_cursor', doc: 'Save current cursor position' },
        { name: 'restore_cursor', doc: 'Restore previously saved cursor position' },
        { name: 'clear', doc: 'Clear entire screen' },
        { name: 'clear_line', doc: 'Clear current line' },
        { name: 'clear_to_end', doc: 'Clear from cursor to end of screen' },
        { name: 'clear_to_start', doc: 'Clear from cursor to start of screen' },
        { name: 'width', doc: 'Get terminal width in columns' },
        { name: 'height', doc: 'Get terminal height in rows' },
        { name: 'size', doc: 'Get terminal size as [height, width]' },
        { name: 'styled', doc: 'Apply multiple styles at once' },
        { name: 'reset', doc: 'Return ANSI reset code' },
        { name: 'strip_colors', doc: 'Remove all ANSI color codes from text' }
    ],
    'std/test': [
        { name: 'module', doc: 'Define a test module (organizational header)' },
        { name: 'describe', doc: 'Define a test suite/group' },
        { name: 'it', doc: 'Define a single test case' },
        { name: 'before', doc: 'Run setup before each test' },
        { name: 'after', doc: 'Run teardown after each test' },
        { name: 'before_all', doc: 'Run setup once before all tests in suite' },
        { name: 'after_all', doc: 'Run teardown once after all tests in suite' },
        { name: 'assert', doc: 'Assert condition is true' },
        { name: 'assert_eq', doc: 'Assert equality' },
        { name: 'assert_neq', doc: 'Assert inequality' },
        { name: 'assert_gt', doc: 'Assert greater than' },
        { name: 'assert_lt', doc: 'Assert less than' },
        { name: 'assert_gte', doc: 'Assert greater than or equal' },
        { name: 'assert_lte', doc: 'Assert less than or equal' },
        { name: 'assert_nil', doc: 'Assert value is nil' },
        { name: 'assert_not_nil', doc: 'Assert value is not nil' },
        { name: 'assert_type', doc: 'Assert value has specific type' },
        { name: 'assert_near', doc: 'Assert approximate equality' },
        { name: 'assert_raises', doc: 'Assert function raises specific exception' },
        { name: 'skip', doc: 'Skip current test' },
        { name: 'fail', doc: 'Explicitly fail test' },
        { name: 'stats', doc: 'Print summary of test results' },
        { name: 'find_tests', doc: 'Discover test files from array of paths' },
        { name: 'find_tests_dir', doc: 'Discover test files in a directory' },
        { name: 'set_colors', doc: 'Enable or disable colored output' }
    ],
    'std/time': [
        { name: 'now', doc: 'Get the current instant as a UTC timestamp' },
        { name: 'now_local', doc: 'Get the current datetime in the system\'s local timezone' },
        { name: 'today', doc: 'Get today\'s date in the local timezone' },
        { name: 'time_now', doc: 'Get the current time of day in the local timezone' },
        { name: 'parse', doc: 'Parse a datetime string in various formats' },
        { name: 'datetime', doc: 'Create a timezone-aware datetime from components' },
        { name: 'date', doc: 'Create a calendar date' },
        { name: 'time', doc: 'Create a time of day' },
        { name: 'span', doc: 'Create a span from components' },
        { name: 'days', doc: 'Create a span of n days' },
        { name: 'hours', doc: 'Create a span of n hours' },
        { name: 'minutes', doc: 'Create a span of n minutes' },
        { name: 'seconds', doc: 'Create a span of n seconds' },
        { name: 'sleep', doc: 'Sleep for a specified duration in seconds' },
        { name: 'is_leap_year', doc: 'Check if a year is a leap year' },
        { name: 'ticks_ms', doc: 'Get milliseconds elapsed since program start' }
    ]
};
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
    ],
    Array: [
        { name: 'len', doc: 'Get number of elements in array' },
        { name: 'push', doc: 'Return new array with element added to end' },
        { name: 'pop', doc: 'Return new array with last element removed' },
        { name: 'shift', doc: 'Return new array with first element removed' },
        { name: 'unshift', doc: 'Return new array with element added to beginning' },
        { name: 'get', doc: 'Get element at index' },
        { name: 'first', doc: 'Get first element' },
        { name: 'last', doc: 'Get last element' },
        { name: 'reverse', doc: 'Return new array with elements in reverse order' },
        { name: 'slice', doc: 'Return subarray from start to end index' },
        { name: 'concat', doc: 'Combine this array with another array' },
        { name: 'join', doc: 'Convert array to string with separator' },
        { name: 'contains', doc: 'Check if array contains a value' },
        { name: 'index_of', doc: 'Find index of first occurrence of value' },
        { name: 'count', doc: 'Count occurrences of value' },
        { name: 'empty', doc: 'Check if array is empty' },
        { name: 'sort', doc: 'Return sorted array (ascending order)' },
        { name: 'map', doc: 'Transform each element with function' },
        { name: 'filter', doc: 'Select elements matching predicate function' },
        { name: 'each', doc: 'Iterate over elements (for side effects)' },
        { name: 'reduce', doc: 'Reduce array to single value with function' },
        { name: 'any', doc: 'Check if any element matches predicate' },
        { name: 'all', doc: 'Check if all elements match predicate' },
        { name: 'find', doc: 'Find first element matching predicate' },
        { name: 'find_index', doc: 'Find index of first element matching predicate' },
        { name: '_id', doc: 'Get unique object ID' }
    ],
    Dict: [
        { name: 'len', doc: 'Get number of key-value pairs' },
        { name: 'keys', doc: 'Get array of all keys' },
        { name: 'values', doc: 'Get array of all values' },
        { name: 'has', doc: 'Check if key exists' },
        { name: 'get', doc: 'Get value for key (with optional default)' },
        { name: 'set', doc: 'Return new dict with key set to value' },
        { name: 'remove', doc: 'Return new dict with key removed' },
        { name: 'each', doc: 'Iterate over key-value pairs' },
        { name: '_id', doc: 'Get unique object ID' }
    ]
};
connection.onInitialize((params) => {
    const result = {
        capabilities: {
            textDocumentSync: node_1.TextDocumentSyncKind.Incremental,
            completionProvider: {
                resolveProvider: true,
                triggerCharacters: ['.', '"', "'"]
            },
            hoverProvider: true
        }
    };
    return result;
});
connection.onInitialized(() => {
    connection.console.log('Quest Language Server initialized');
});
// Extract module aliases from use statements in a document
function extractModuleAliases(text) {
    const aliases = new Map();
    // Match: use "path" as alias OR use "path"
    const usePattern = /use\s+["']([^"']+)["'](?:\s+as\s+(\w+))?/g;
    let match;
    while ((match = usePattern.exec(text)) !== null) {
        const modulePath = match[1];
        let alias = match[2]; // Explicit alias if provided
        // If no alias provided, derive from last segment of path
        if (!alias) {
            const pathSegments = modulePath.split('/');
            alias = pathSegments[pathSegments.length - 1];
        }
        aliases.set(alias, modulePath);
    }
    return aliases;
}
// Provide completions
connection.onCompletion((textDocumentPosition) => {
    const document = documents.get(textDocumentPosition.textDocument.uri);
    if (!document) {
        return [];
    }
    const text = document.getText();
    const offset = document.offsetAt(textDocumentPosition.position);
    const beforeCursor = text.substring(0, offset);
    // Check if we're inside a use statement with a string literal
    // Pattern: use "..." or use '...'
    const useMatch = beforeCursor.match(/use\s+["']([^"']*)$/);
    if (useMatch) {
        const partialPath = useMatch[1];
        // Provide std module completions
        return STD_MODULES
            .filter(mod => mod.path.startsWith(partialPath))
            .map(mod => ({
            label: mod.path,
            kind: node_1.CompletionItemKind.Module,
            detail: 'Standard library module',
            documentation: mod.doc,
            insertText: mod.path
        }));
    }
    // Check if we're after a dot (method completion or module method completion)
    const dotMatch = beforeCursor.match(/(\w+)\.(\w*)$/);
    if (dotMatch) {
        const objectName = dotMatch[1];
        const partialMethod = dotMatch[2];
        // Extract module aliases from the document
        const moduleAliases = extractModuleAliases(text);
        // Check if this is a module method completion
        if (moduleAliases.has(objectName)) {
            const modulePath = moduleAliases.get(objectName);
            const moduleMethods = MODULE_METHODS[modulePath];
            if (moduleMethods) {
                return moduleMethods
                    .filter(method => method.name.startsWith(partialMethod))
                    .map(method => ({
                    label: method.name,
                    kind: node_1.CompletionItemKind.Method,
                    detail: `${modulePath} method`,
                    documentation: method.doc
                }));
            }
        }
        // Fallback: Provide method completions for all types
        const allMethods = [];
        for (const [typeName, methods] of Object.entries(METHODS)) {
            for (const method of methods) {
                allMethods.push({
                    label: method.name,
                    kind: node_1.CompletionItemKind.Method,
                    detail: `${typeName} method`,
                    documentation: method.doc
                });
            }
        }
        return allMethods;
    }
    // Provide keyword and built-in completions
    const completions = [];
    // Keywords
    for (const keyword of KEYWORDS) {
        completions.push({
            label: keyword,
            kind: node_1.CompletionItemKind.Keyword
        });
    }
    // Built-in functions
    for (const fn of BUILTIN_FUNCTIONS) {
        completions.push({
            label: fn.name,
            kind: node_1.CompletionItemKind.Function,
            documentation: fn.doc
        });
    }
    return completions;
});
// Provide hover information
connection.onHover((textDocumentPosition) => {
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
                        kind: node_1.MarkupKind.Markdown,
                        value: `**${fn.name}()**\n\n${fn.doc}`
                    }
                };
            }
            // Check keywords
            if (KEYWORDS.includes(word)) {
                return {
                    contents: {
                        kind: node_1.MarkupKind.Markdown,
                        value: `**${word}** (keyword)`
                    }
                };
            }
        }
    }
    return null;
});
// Basic diagnostics for common errors
documents.onDidChangeContent(change => {
    validateTextDocument(change.document);
});
function validateTextDocument(textDocument) {
    const text = textDocument.getText();
    const diagnostics = [];
    // Check for unbalanced if/end blocks
    const lines = text.split('\n');
    let nestingLevel = 0;
    const nestingStack = [];
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.match(/^\s*(if|fun|while|for|type|impl)\b/)) {
            const keyword = line.match(/^\s*(\w+)/)?.[1] || '';
            nestingLevel++;
            nestingStack.push({ keyword, line: i });
        }
        else if (line.match(/^\s*end\b/)) {
            nestingLevel--;
            if (nestingLevel < 0) {
                diagnostics.push({
                    severity: node_1.DiagnosticSeverity.Error,
                    range: {
                        start: { line: i, character: 0 },
                        end: { line: i, character: line.length }
                    },
                    message: 'Unexpected "end" without matching block start',
                    source: 'quest'
                });
            }
            else {
                nestingStack.pop();
            }
        }
    }
    if (nestingLevel > 0) {
        for (const item of nestingStack) {
            diagnostics.push({
                severity: node_1.DiagnosticSeverity.Error,
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
//# sourceMappingURL=server.js.map