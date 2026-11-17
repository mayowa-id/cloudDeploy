const assert = require('node:assert/strict');
const { hostname } = require('node:os');
const { test } = require('node:test');
const { readConfig } = require('../dist/config');

test('uses local defaults when environment variables are absent', () => {
  assert.deepEqual(readConfig({}), {
    port: 3000,
    release: {
      application: 'clouddeploy',
      version: '1.0.0',
      commit: 'local',
      environment: 'local',
      instance: hostname(),
    },
  });
});

test('reads release metadata and port from the environment', () => {
  const config = readConfig({
    PORT: '8080',
    APP_VERSION: '2.0.0',
    APP_COMMIT: 'a8b32cd',
    APP_ENV: 'demo',
    INSTANCE_NAME: 'clouddeploy-api-abc123',
  });
  assert.equal(config.port, 8080);
  assert.deepEqual(config.release, {
    application: 'clouddeploy',
    version: '2.0.0',
    commit: 'a8b32cd',
    environment: 'demo',
    instance: 'clouddeploy-api-abc123',
  });
});

test('rejects invalid ports', () => {
  for (const PORT of ['', 'oops', '0', '-1', '12.5', '65536']) {
    assert.throws(() => readConfig({ PORT }), /PORT must be an integer/);
  }
});
