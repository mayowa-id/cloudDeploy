import express, { type ErrorRequestHandler } from 'express';
import type { Config } from './config';
import { log } from './log';
import { createObservability } from './middleware/observability';
import { systemRoutes } from './routes/system';

export function createApp(config: Config, isReady: () => boolean) {
  const app = express();
  const { middleware, registry } = createObservability();
  const handleError: ErrorRequestHandler = (error, _req, res, next) => {
    log('error', 'http_error', { requestId: res.getHeader('X-Request-ID') });
    if (res.headersSent) {
      next(error);
      return;
    }
    res.status(500).json({ error: 'internal_server_error' });
  };

  app.disable('x-powered-by');
  app.use(middleware);
  app.use(systemRoutes(config.release, isReady, registry));
  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));
  app.use(handleError);
  return app;
}
