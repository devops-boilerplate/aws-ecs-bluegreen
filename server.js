'use strict';

const http = require('node:http');
const { randomUUID } = require('node:crypto');

const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT || 8080);
const APP_VERSION = process.env.APP_VERSION || 'dev';
const STARTED_AT = Date.now();

function writeResponse(req, res, statusCode, headers, body, requestId) {
  const payload = Buffer.from(body, 'utf8');
  res.writeHead(statusCode, {
    ...headers,
    'content-length': payload.length,
    'cache-control': 'no-store',
    'x-request-id': requestId,
  });
  res.end(req.method === 'HEAD' ? undefined : payload);
}

function sendJson(req, res, statusCode, payload, requestId) {
  writeResponse(
    req,
    res,
    statusCode,
    { 'content-type': 'application/json; charset=utf-8' },
    `${JSON.stringify(payload)}\n`,
    requestId,
  );
}

function sendText(req, res, statusCode, text, requestId) {
  writeResponse(
    req,
    res,
    statusCode,
    { 'content-type': 'text/plain; charset=utf-8' },
    text,
    requestId,
  );
}

function uptimeSeconds() {
  return Math.round((Date.now() - STARTED_AT) / 1000);
}

function createServer({ logger = console } = {}) {
  return http.createServer((req, res) => {
    const startedAt = Date.now();
    const requestId = req.headers['x-request-id'] || randomUUID();

    let path;
    try {
      path = new URL(req.url, 'http://localhost').pathname;
    } catch {
      return sendJson(req, res, 400, { error: 'bad_request' }, requestId);
    }

    res.on('finish', () => {
      logger.log(
        JSON.stringify({
          level: 'info',
          msg: 'request',
          requestId,
          method: req.method,
          path,
          status: res.statusCode,
          durationMs: Date.now() - startedAt,
        }),
      );
    });

    const isRead = req.method === 'GET' || req.method === 'HEAD';

    if (path === '/health') {
      if (!isRead) {
        return sendJson(req, res, 405, { error: 'method_not_allowed' }, requestId);
      }
      return sendJson(
        req,
        res,
        200,
        { status: 'ok', version: APP_VERSION, uptimeSeconds: uptimeSeconds() },
        requestId,
      );
    }

    if (path === '/ready') {
      if (!isRead) {
        return sendJson(req, res, 405, { error: 'method_not_allowed' }, requestId);
      }
      return sendJson(
        req,
        res,
        200,
        { status: 'ready', version: APP_VERSION, uptimeSeconds: uptimeSeconds() },
        requestId,
      );
    }

    if (path === '/') {
      if (!isRead) {
        return sendJson(req, res, 405, { error: 'method_not_allowed' }, requestId);
      }
      return sendText(req, res, 200, 'Hello from ECS on Fargate!\n', requestId);
    }

    return sendJson(req, res, 404, { error: 'not_found', path }, requestId);
  });
}

function start() {
  const server = createServer();

  server.listen(PORT, HOST, () => {
    console.log(
      JSON.stringify({
        level: 'info',
        msg: 'server_started',
        host: HOST,
        port: PORT,
        version: APP_VERSION,
      }),
    );
  });

  const shutdown = (signal) => {
    console.log(JSON.stringify({ level: 'info', msg: 'shutdown', signal }));
    const forceExit = setTimeout(() => process.exit(1), 10_000);
    forceExit.unref();
    server.close((error) => process.exit(error ? 1 : 0));
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);

  return server;
}

if (require.main === module) {
  start();
}

module.exports = { createServer, start };
