const assert = require('node:assert/strict');
const { once } = require('node:events');
const { get } = require('node:http');
const { test } = require('node:test');
const { readConfig } = require('../dist/config');
const { start } = require('../dist/index');

test('SIGTERM handler stops accepting connections and drains a request', { timeout: 3000 }, async (t) => {
  const server = start({ ...readConfig({}), port: 0 });
  t.after(() => server.close());
  await once(server, 'listening');
  const closed = once(server, 'close');

  // Simulate signal delivery inside an active HTTP request on every OS.
  server.prependOnceListener('request', () => process.emit('SIGTERM', 'SIGTERM'));
  const response = await new Promise((resolve, reject) => {
    get(`http://127.0.0.1:${server.address().port}/health`, (res) => {
      res.resume();
      res.on('end', () => resolve(res.statusCode));
      res.on('error', reject);
    }).on('error', reject);
  });
  assert.equal(response, 200);
  await closed;
  assert.equal(server.listening, false);
});
