module.exports = {
  apps: [
    {
      name: "snape-be",
      cwd: "/home/voldemort/project/snape/snape_be",
      script: "/home/voldemort/project/snape/snape_be/.venv/bin/uvicorn",
      args: "app.main:app --host 127.0.0.1 --port 8000 --workers 2",
      interpreter: "none",
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      env: {
        NODE_ENV: "production",
        PYTHONPATH: "/home/voldemort/project/snape/snape_be"
      }
    }
  ]
};
