import { randomUUID } from 'node:crypto';
import type { RequestHandler } from 'express';
import { Counter, Histogram, Registry } from '@prometheus-io/client';
import { log } from '../log';

const methods = new Set(['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'CONNECT', 'TRACE']);
const labelNames = ['method', 'route', 'status_code'] as const;

export function createObservability() {
  const registry = new Registry();
  const requests = new Counter({
    name: 'http_requests_total',
    help: 'Number of HTTP requests handled.',
    labelNames,
    registers: [registry],
  });
  const latency = new Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds.',
    labelNames,
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [registry],
  });

  const middleware: RequestHandler = (req, res, next) => {
    const requestId = randomUUID();
    const started = process.hrtime.bigint();
    res.setHeader('X-Request-ID', requestId);

    res.once('close', () => {
      const durationSeconds = Number(process.hrtime.bigint() - started) / 1e9;
      const method = methods.has(req.method) ? req.method : 'OTHER';
      const route = typeof req.route?.path === 'string' ? req.route.path : 'unmatched';
      const status = res.writableFinished ? res.statusCode : 499;
      const labels = { method, route, status_code: String(status) };
      requests.inc(labels);
      latency.observe(labels, durationSeconds);
      log('info', 'http_request', { requestId, method, route, status, durationMs: durationSeconds * 1000 });
    });

    next();
  };

  return { middleware, registry };
}
