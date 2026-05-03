module.exports = {
  apps: [
    {
      name: 'spicc-next-app',
      cwd: '/var/www/spicc/web',
      script: 'npm',
      args: 'run start',
      exec_mode: 'fork',      // ✅ เปลี่ยนเป็น fork
      instances: 1,           // ✅ รันแค่ 1 instance
      env: {
        NODE_ENV: 'production',
        PORT: 3100
      },
      autorestart: true,
      watch: false,
      max_memory_restart: '1G'
    },

    {
      name: 'spicc-backup',
      cwd: '/var/www/spicc/backup_server',
      script: 'server.js',
      args: 'run start',
      exec_mode: 'fork',
      instances: 1,
      env: {
        NODE_ENV: 'production',
        PORT: 3101
      },
      autorestart: true,
      watch: false,
      max_memory_restart: '512M'
    },
     {
      name: 'srvmusic',
      cwd: '/var/www/srvmusic',
      script: 'server.js',
      args: 'run start',
      exec_mode: 'fork',
      instances: 1,
      env: {
        NODE_ENV: 'production',
        PORT: 3456
      },
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      error_file: '/var/www/srvmusic/logs/error.log',
      out_file: '/var/www/srvmusic/logs/out.log',
      combine_logs: true,
      time: true,
      autorestart: true,
      restart_delay: 5000,
      max_restarts: 10,
      min_uptime: 10000,
    }
  ]
};
