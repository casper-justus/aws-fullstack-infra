const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 8000;
const DATABASE_URL = process.env.DATABASE_URL || null;
const AWS_S3_BUCKET = process.env.AWS_S3_BUCKET || null;

let requestCount = 0;

const server = http.createServer((req, res) => {
  requestCount++;

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        hostname: os.hostname(),
        uptime: Math.floor(process.uptime()),
        memory: process.memoryUsage(),
        database: DATABASE_URL ? 'connected' : 'not configured',
        s3_bucket: AWS_S3_BUCKET || 'not configured',
      }),
    );
    return;
  }

  if (req.url === '/metrics') {
    const memUsage = process.memoryUsage();
    const uptimeSec = process.uptime();
    const metrics =
      [
        '# HELP node_memory_rss_bytes Process RSS memory in bytes',
        '# TYPE node_memory_rss_bytes gauge',
        `node_memory_rss_bytes ${memUsage.rss}`,
        '# HELP node_memory_heap_total_bytes Process heap total in bytes',
        '# TYPE node_memory_heap_total_bytes gauge',
        `node_memory_heap_total_bytes ${memUsage.heapTotal}`,
        '# HELP node_memory_heap_used_bytes Process heap used in bytes',
        '# TYPE node_memory_heap_used_bytes gauge',
        `node_memory_heap_used_bytes ${memUsage.heapUsed}`,
        '# HELP node_uptime_seconds Process uptime in seconds',
        '# TYPE node_uptime_seconds gauge',
        `node_uptime_seconds ${uptimeSec.toFixed(0)}`,
        '# HELP http_requests_total Total HTTP requests',
        '# TYPE http_requests_total counter',
        `http_requests_total ${requestCount}`,
      ].join('\n') + '\n';
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
    res.end(metrics);
    return;
  }

  if (req.url === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        service: 'fullstack-app',
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        hostname: os.hostname(),
        platform: os.platform(),
        uptime: Math.floor(process.uptime()),
        totalRequests: requestCount,
        database: DATABASE_URL ? 'configured' : 'not configured',
        s3_bucket: AWS_S3_BUCKET || 'not configured',
        timestamp: new Date().toISOString(),
      }),
    );
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(
    JSON.stringify({
      message: 'Welcome to the Fullstack App',
      endpoints: ['/health', '/metrics', '/api/status'],
      environment: process.env.NODE_ENV || 'development',
      hostname: os.hostname(),
      timestamp: new Date().toISOString(),
    }),
  );
});

function start() {
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Metrics: http://localhost:${PORT}/metrics`);
  });
}

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

module.exports = { server, start };
