const assert = require('node:assert/strict');
const { once } = require('node:events');
const { test } = require('node:test');
const { createApp } = require('../dist/app');
const { readConfig } = require('../dist/config');

test('serves all system endpoints and records bounded HTTP metrics', async (t) => {
  const config = readConfig({ APP_COMMIT: 'a8b32cd', APP_ENV: 'demo' });
  let ready = true;
  const server = createApp(config, () => ready).listen(0, '127.0.0.1');
  t.after(() => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())));
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;

  const root = await fetch(base);
  assert.equal(root.status, 200);
  assert.equal((await root.json()).application, 'clouddeploy');
  const requestId = root.headers.get('x-request-id');
  assert.match(requestId, /^[\da-f-]{36}$/i);

  const version = await fetch(base + '/version');
  assert.equal(version.status, 200);
  assert.notEqual(version.headers.get('x-request-id'), requestId);
  assert.equal(version.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await version.json(), config.release);

  const readyResponse = await fetch(base + '/ready');
  assert.equal(readyResponse.status, 200);
  assert.deepEqual(await readyResponse.json(), { status: 'ready' });
  ready = false;
  const unavailable = await fetch(base + '/ready');
  assert.equal(unavailable.status, 503);
  assert.deepEqual(await unavailable.json(), { status: 'not_ready' });
  const health = await fetch(base + '/health');
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: 'ok' });

  for (const path of ['/missing-one', '/missing-two']) {
    const response = await fetch(base + path);
    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), { error: 'not_found' });
  }
  const metrics = await fetch(base + '/metrics');
  assert.equal(metrics.status, 200);
  assert.match(metrics.headers.get('content-type'), /^text\/plain/);
  const body = await metrics.text();
  assert.match(body, /http_requests_total\{method="GET",route="\/ready",status_code="503"\} 1/);
  assert.match(body, /http_requests_total\{method="GET",route="unmatched",status_code="404"\} 2/);
  assert.match(body, /http_request_duration_seconds_count\{method="GET",route="\/version",status_code="200"\} 1/);
  assert.doesNotMatch(body, /missing-one|missing-two/);
});
