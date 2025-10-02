import * as path from 'path';
import { workspace, ExtensionContext, languages, DocumentHighlight, TextDocument, Position, CancellationToken, DocumentHighlightKind, Range } from 'vscode';

import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

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
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function activate(context: ExtensionContext) {
  const serverModule = context.asAbsolutePath(
    path.join('out', 'server', 'server.js')
  );

  const serverOptions: ServerOptions = {
    run: { module: serverModule, transport: TransportKind.ipc },
    debug: {
      module: serverModule,
      transport: TransportKind.ipc,
      options: { execArgv: ['--nolazy', '--inspect=6009'] }
    }
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'quest' }],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher('**/.q')
    }
  };

  client = new LanguageClient(
    'questLanguageServer',
    'Quest Language Server',
    serverOptions,
    clientOptions
  );

  client.start();

  // Register document highlight provider to exclude keywords
  context.subscriptions.push(
    languages.registerDocumentHighlightProvider('quest', {
      provideDocumentHighlights(
        document: TextDocument,
        position: Position,
        _token: CancellationToken
      ): DocumentHighlight[] | null {
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
        const highlights: DocumentHighlight[] = [];

        // Create a regex to match whole words only
        const regex = new RegExp(`\\b${escapeRegex(word)}\\b`, 'g');
        let match: RegExpExecArray | null;

        while ((match = regex.exec(text)) !== null) {
          const startPos = document.positionAt(match.index);
          const endPos = document.positionAt(match.index + word.length);

          highlights.push(
            new DocumentHighlight(
              new Range(startPos, endPos),
              DocumentHighlightKind.Text
            )
          );
        }

        return highlights.length > 0 ? highlights : null;
      }
    })
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
