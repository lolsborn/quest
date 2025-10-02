import * as path from 'path';
import { workspace, ExtensionContext, languages, DocumentHighlight, TextDocument, Position, CancellationToken, DocumentHighlightKind } from 'vscode';

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
  'fun', 'type', 'impl', 'trait',
  'while', 'for', 'in',
  'try', 'catch', 'ensure', 'raise',
  'let', 'del', 'return',
  'and', 'or', 'not',
  'true', 'false', 'nil'
]);

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

        // Let VS Code's default highlighting handle other words
        return null;
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
