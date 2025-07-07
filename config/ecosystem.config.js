module.exports = {
  apps: [{
    name: 'webxr-mesh-exporter',
    script: 'src/server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'development',
      PORT: 80
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 80
    },
    error_file: './data/logs/err.log',
    out_file: './data/logs/out.log',
    log_file: './data/logs/combined.log',
    time: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
