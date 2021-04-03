[
  {
    "name": "nginx",
    "image": "477829879262.dkr.ecr.us-east-1.amazonaws.com/helloworld:latest",
    "memory": 256,
    "cpu": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/helloworld",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs"
          }
    },
    "healthCheck": {
        "retries": 3,
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost/ || exit 1"
        ],
        "timeout": 5,
        "interval": 30,
        "startPeriod": null
    }
  }
]