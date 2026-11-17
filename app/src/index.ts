import { createApp } from './app';
import { readConfig, type Config } from './config';
import { log } from './log';

export function start(config: Config) {
  let ready = false;
  let shuttingDown = false;
  const server = createApp(config, () => ready).listen(config.port, '0.0.0.0', () => {
    ready = true;
    const address = server.address();
    log('info', 'server_started', { port: typeof address === 'object' ? address?.port : config.port, ...config.release });
  });

  function shutdown(signal: NodeJS.Signals) {
    if (shuttingDown) return;
    shuttingDown = true;
    ready = false;
    log('info', 'shutdown_started', { signal });

    const deadline = setTimeout(() => {
      log('error', 'shutdown_timeout');
      process.exitCode = 1;
      server.closeAllConnections();
    }, 10_000);
    deadline.unref();

    server.close((error) => {
      clearTimeout(deadline);
      if (error) process.exitCode = 1;
      log(error ? 'error' : 'info', 'server_closed', { signal, success: !error && !process.exitCode });
    });
  }

  server.prependListener('request', (_req, res) => {
    res.once('finish', () => {
      if (shuttingDown) setImmediate(() => server.closeIdleConnections());
    });
  });
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
  function removeSignalHandlers() {
    process.off('SIGTERM', shutdown);
    process.off('SIGINT', shutdown);
  }
  server.once('close', removeSignalHandlers);
  server.on('error', (error: NodeJS.ErrnoException) => {
    removeSignalHandlers();
    log('error', 'server_error', { code: error.code });
    process.exitCode = 1;
  });
  return server;
}

if (require.main === module) {
  try {
    start(readConfig());
  } catch (error) {
    log('error', 'startup_failed', { message: error instanceof Error ? error.message : 'Unknown error' });
    process.exitCode = 1;
  }
}
