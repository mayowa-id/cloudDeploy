import { Router } from 'express';
import type { Registry } from '@prometheus-io/client';
import type { Config } from '../config';

export function systemRoutes(release: Config['release'], isReady: () => boolean, registry: Registry) {
  const router = Router();
  router.get('/', (_req, res) => {
    res.json({ application: release.application, description: 'CloudDeploy deployment demo API' });
  });
  router.get('/health', (_req, res) => res.json({ status: 'ok' }));
  router.get('/ready', (_req, res) => {
    const ready = isReady();
    res.status(ready ? 200 : 503).json({ status: ready ? 'ready' : 'not_ready' });
  });
  router.get('/version', (_req, res) => res.set('Cache-Control', 'no-store').json(release));
  router.get('/metrics', async (_req, res) => {
    res.set('Content-Type', registry.contentType).send(await registry.metrics());
  });
  return router;
}
