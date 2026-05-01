const request = require('supertest');
const { server } = require('../src/app');

afterAll((done) => {
  server.close(done);
});

describe('GET /health', () => {
  it('returns 200 with healthy status', async () => {
    const res = await request(server).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('healthy');
  });

  it('includes timestamp, hostname, and uptime', async () => {
    const res = await request(server).get('/health');

    expect(res.body).toHaveProperty('timestamp');
    expect(res.body).toHaveProperty('hostname');
    expect(res.body).toHaveProperty('uptime');
    expect(typeof res.body.uptime).toBe('number');
  });

  it('includes memory usage object', async () => {
    const res = await request(server).get('/health');

    expect(res.body).toHaveProperty('memory');
    expect(res.body.memory).toHaveProperty('rss');
    expect(res.body.memory).toHaveProperty('heapTotal');
    expect(res.body.memory).toHaveProperty('heapUsed');
  });

  it('reports database and s3_bucket fields', async () => {
    const res = await request(server).get('/health');

    expect(res.body).toHaveProperty('database');
    expect(res.body).toHaveProperty('s3_bucket');
  });
});

describe('GET /', () => {
  it('returns 200 with welcome message', async () => {
    const res = await request(server).get('/');

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Welcome to the Fullstack App');
  });

  it('lists available endpoints', async () => {
    const res = await request(server).get('/');

    expect(Array.isArray(res.body.endpoints)).toBe(true);
    expect(res.body.endpoints).toContain('/health');
    expect(res.body.endpoints).toContain('/metrics');
    expect(res.body.endpoints).toContain('/api/status');
  });
});

describe('GET /metrics', () => {
  it('returns 200 with Prometheus-format metrics', async () => {
    const res = await request(server).get('/metrics');

    expect(res.status).toBe(200);
    expect(res.type).toMatch(/text\/plain/);
  });

  it('includes required metric names', async () => {
    const res = await request(server).get('/metrics');

    expect(res.text).toContain('node_memory_rss_bytes');
    expect(res.text).toContain('node_memory_heap_total_bytes');
    expect(res.text).toContain('node_memory_heap_used_bytes');
    expect(res.text).toContain('node_uptime_seconds');
    expect(res.text).toContain('http_requests_total');
  });

  it('includes HELP and TYPE annotations', async () => {
    const res = await request(server).get('/metrics');

    expect(res.text).toContain('# HELP');
    expect(res.text).toContain('# TYPE');
  });
});

describe('GET /api/status', () => {
  it('returns 200 with service info', async () => {
    const res = await request(server).get('/api/status');

    expect(res.status).toBe(200);
    expect(res.body.service).toBe('fullstack-app');
    expect(res.body.version).toBe('1.0.0');
  });

  it('includes runtime details', async () => {
    const res = await request(server).get('/api/status');

    expect(res.body).toHaveProperty('environment');
    expect(res.body).toHaveProperty('hostname');
    expect(res.body).toHaveProperty('uptime');
    expect(res.body).toHaveProperty('totalRequests');
  });

  it('includes database and s3_bucket configuration', async () => {
    const res = await request(server).get('/api/status');

    expect(res.body).toHaveProperty('database');
    expect(res.body).toHaveProperty('s3_bucket');
  });
});

describe('Unknown route', () => {
  it('returns 200 with welcome response for undefined paths', async () => {
    const res = await request(server).get('/nonexistent');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('message');
  });
});
