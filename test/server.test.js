'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { createServer } = require('../server');

const silentLogger = { log() {} };

async function withServer(run) {
  const server = createServer({ logger: silentLogger });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    await run(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('GET /health returns the liveness payload', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`);

    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type'), /application\/json/);
    assert.ok(response.headers.get('x-request-id'));

    const body = await response.json();
    assert.equal(body.status, 'ok');
    assert.equal(typeof body.version, 'string');
    assert.equal(typeof body.uptimeSeconds, 'number');
  });
});

test('GET /ready returns the readiness payload', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/ready`);

    assert.equal(response.status, 200);
    assert.equal((await response.json()).status, 'ready');
  });
});

test('GET / returns the greeting', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/`);

    assert.equal(response.status, 200);
    assert.equal(await response.text(), 'Hello from ECS on Fargate!\n');
  });
});

test('an unknown path returns 404', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/does-not-exist`);

    assert.equal(response.status, 404);
    assert.equal((await response.json()).error, 'not_found');
  });
});

test('a non-read method on /health returns 405', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`, { method: 'POST' });

    assert.equal(response.status, 405);
    assert.equal((await response.json()).error, 'method_not_allowed');
  });
});

test('the incoming x-request-id is echoed back', async () => {
  await withServer(async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`, {
      headers: { 'x-request-id': 'test-request-id' },
    });

    assert.equal(response.headers.get('x-request-id'), 'test-request-id');
  });
});
