// CX VS Code extension.
//
// Activation: any `.cx` / `.cxs` file open. The extension spawns
// `<cx.serverPath> <cx.serverArgs>` (default `cx lsp`) and wires it as the
// language server via vscode-languageclient. The server speaks JSON-RPC
// 2.0 over stdio with LSP Content-Length framing.
//
// We don't ship a server binary in the .vsix — users install `cx` via
// `brew install cx-home/tap/cx` (or build from source). If `cx` isn't
// on $PATH, the extension surfaces a one-time install hint and stays
// dormant.

import { workspace, window, commands, ExtensionContext } from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export async function activate(context: ExtensionContext): Promise<void> {
  const config = workspace.getConfiguration('cx');
  const serverPath = config.get<string>('serverPath', 'cx');
  const serverArgs = config.get<string[]>('serverArgs', ['lsp']);
  const trace = config.get<string>('trace.server', 'off');

  const serverOptions: ServerOptions = {
    run: {
      command: serverPath,
      args: serverArgs,
      transport: TransportKind.stdio,
    },
    debug: {
      command: serverPath,
      args: [...serverArgs, '--verbose'],
      transport: TransportKind.stdio,
    },
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: 'file', language: 'cx' },
    ],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher('**/*.{cx,cxs,cxl}'),
    },
    initializationOptions: {
      traceServer: trace,
    },
  };

  client = new LanguageClient(
    'cx',
    'CX Language Server',
    serverOptions,
    clientOptions,
  );

  try {
    await client.start();
  } catch (err) {
    window.showWarningMessage(
      `CX: failed to start language server (${serverPath} ${serverArgs.join(' ')}). ` +
      `Install with \`brew install cx-home/tap/cx\` or set \`cx.serverPath\` in settings.`,
    );
    return;
  }

  context.subscriptions.push(
    commands.registerCommand('cx.restartServer', async () => {
      if (!client) return;
      await client.stop();
      await client.start();
      window.showInformationMessage('CX language server restarted.');
    }),
    commands.registerCommand('cx.showServerVersion', () => {
      if (!client) return;
      window.showInformationMessage(`CX server initialized: ${client.initializeResult?.serverInfo?.name} ${client.initializeResult?.serverInfo?.version}`);
    }),
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) return undefined;
  return client.stop();
}
