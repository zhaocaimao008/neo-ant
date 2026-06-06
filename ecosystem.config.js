module.exports = {
  apps: [{
    name: 'neoant-server',
    cwd: '/opt/neoant/server',
    script: 'index.js',
    max_memory_restart: '256M',
    env: { NODE_ENV: 'production' }
  }]
};
