"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const path = __importStar(require("path"));
const vscode_1 = require("vscode");
const node_1 = require("vscode-languageclient/node");
let client;
// Keywords to exclude from occurrence highlighting
const EXCLUDED_KEYWORDS = new Set([
    'if', 'elif', 'else', 'end',
    'fun', 'type', 'impl', 'trait', 'static',
    'while', 'for', 'in', 'break', 'continue',
    'try', 'catch', 'ensure', 'raise',
    'let', 'del', 'return', 'use', 'as',
    'and', 'or', 'not',
    'true', 'false', 'nil'
]);
// Helper function to escape regex special characters
function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
function activate(context) {
    const serverModule = context.asAbsolutePath(path.join('out', 'server', 'server.js'));
    const serverOptions = {
        run: { module: serverModule, transport: node_1.TransportKind.ipc },
        debug: {
            module: serverModule,
            transport: node_1.TransportKind.ipc,
            options: { execArgv: ['--nolazy', '--inspect=6009'] }
        }
    };
    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: 'quest' }],
        synchronize: {
            fileEvents: vscode_1.workspace.createFileSystemWatcher('**/.q')
        }
    };
    client = new node_1.LanguageClient('questLanguageServer', 'Quest Language Server', serverOptions, clientOptions);
    client.start();
    // Register document highlight provider to exclude keywords
    context.subscriptions.push(vscode_1.languages.registerDocumentHighlightProvider('quest', {
        provideDocumentHighlights(document, position, _token) {
            const wordRange = document.getWordRangeAtPosition(position);
            if (!wordRange) {
                return null;
            }
            const word = document.getText(wordRange);
            // Don't highlight excluded keywords
            if (EXCLUDED_KEYWORDS.has(word)) {
                return null;
            }
            // Find all occurrences of the word in the document
            const text = document.getText();
            const highlights = [];
            // Create a regex to match whole words only
            const regex = new RegExp(`\\b${escapeRegex(word)}\\b`, 'g');
            let match;
            while ((match = regex.exec(text)) !== null) {
                const startPos = document.positionAt(match.index);
                const endPos = document.positionAt(match.index + word.length);
                highlights.push(new vscode_1.DocumentHighlight(new vscode_1.Range(startPos, endPos), vscode_1.DocumentHighlightKind.Text));
            }
            return highlights.length > 0 ? highlights : null;
        }
    }));
}
function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
//# sourceMappingURL=extension.js.map