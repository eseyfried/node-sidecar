terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# Define a vpc
resource "aws_vpc" "demoVPC" {
  cidr_block = "200.0.0.0/16"
  tags = {
    Name = "ecsDemoVPC"
  }
}

# Internet gateway for the public subnet
resource "aws_internet_gateway" "demoIG" {
  vpc_id = aws_vpc.demoVPC.id
  tags = {
    Name = "ecsDemoIG"
  }
}

# Public subnet
resource "aws_subnet" "demoPubSN0-0" {
  vpc_id = aws_vpc.demoVPC.id
  cidr_block = "200.0.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "ecsDemoPubSN0-0-0"
  }
}
resource "aws_subnet" "demoPubSN0-1" {
  vpc_id = aws_vpc.demoVPC.id
  cidr_block = "200.0.1.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "ecsDemoPubSN0-0-1"
  }
}

# Routing table for public subnet
resource "aws_route_table" "demoPubSN0-0RT" {
  vpc_id = aws_vpc.demoVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demoIG.id
  }
  tags = {
    Name = "demoPubSN0-0RT"
  }
}

# NAT Gateway for Public subnet
resource "aws_eip" "nat" {
  vpc = true
}
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.demoPubSN0-0.id
  depends_on = [aws_internet_gateway.demoIG]
}


resource "aws_route_table" "demoPubSN0-1RT" {
  vpc_id = aws_vpc.demoVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demoIG.id
  }
  tags = {
    Name = "demoPubSN0-1RT"
  }
}


# Associate the routing table to public subnet
resource "aws_route_table_association" "demoPubSN0-0RTAssn" {
  subnet_id = aws_subnet.demoPubSN0-0.id
  route_table_id = aws_route_table.demoPubSN0-0RT.id
}

resource "aws_route_table_association" "demoPubSN0-1RTAssn" {
  subnet_id = aws_subnet.demoPubSN0-1.id
  route_table_id = aws_route_table.demoPubSN0-1RT.id
}

# ECS Instance Security group

resource "aws_security_group" "test_public_sg" {
    name = "test_public_sg"
    description = "Test public access security group"
    vpc_id = aws_vpc.demoVPC.id

   ingress {
       from_port = 22
       to_port = 22
       protocol = "tcp"
       cidr_blocks = [
          "0.0.0.0/0"]
   }

   ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = [
          "0.0.0.0/0"]
   }

   ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      cidr_blocks = [
          "0.0.0.0/0"]
    }

   ingress {
      from_port = 0
      to_port = 0
      protocol = "tcp"
      cidr_blocks = [
         "0.0.0.0/0"]
    }

    egress {
        # allow all traffic to private SN
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = [
            "0.0.0.0/0"]
    }

    tags = { 
       Name = "test_public_sg"
     }
}


resource "aws_iam_role" "ecs-service-role" {
    name                = "ecs-service-role"
    path                = "/"
    assume_role_policy  = data.aws_iam_policy_document.ecs-service-policy.json
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
    role       = aws_iam_role.ecs-service-role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs-service-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ecs.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "ecs-instance-role" {
    name                = "ecs-instance-role"
    path                = "/"
    assume_role_policy  = data.aws_iam_policy_document.ecs-instance-policy.json
}

data "aws_iam_policy_document" "ecs-instance-policy" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
    role       = aws_iam_role.ecs-instance-role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
    name = "ecs-instance-profile"
    path = "/"
    role = aws_iam_role.ecs-instance-role.id
    provisioner "local-exec" {
      command = "sleep 10"
    }
}

resource "aws_alb" "ecs-load-balancer" {
    name                = "ecs-load-balancer"
    security_groups     = [aws_security_group.test_public_sg.id]
    subnets             = [aws_subnet.demoPubSN0-0.id,aws_subnet.demoPubSN0-1.id]

    tags = {
      Name = "ecs-load-balancer"
    }
}

resource "aws_alb_target_group" "ecs-target-group-blue" {
    name                = "ecs-target-group-blue"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = aws_vpc.demoVPC.id

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/api/health-check"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }

    tags = {
      Name = "ecs-target-group-blue"
    }
}

resource "aws_alb_target_group" "ecs-target-group-green" {
    name                = "ecs-target-group-green"
    port                = "80"
    protocol            = "HTTP"
    vpc_id              = aws_vpc.demoVPC.id

    health_check {
        healthy_threshold   = "5"
        unhealthy_threshold = "2"
        interval            = "30"
        matcher             = "200"
        path                = "/api/health-check"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = "5"
    }

    tags = {
      Name = "ecs-target-group-green"
    }
}

resource "aws_alb_listener" "alb-listener-prod" {
    load_balancer_arn = aws_alb.ecs-load-balancer.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        target_group_arn = aws_alb_target_group.ecs-target-group-blue.arn
        type             = "forward"
    }
}

resource "aws_alb_listener" "alb-listener-test" {
    load_balancer_arn = aws_alb.ecs-load-balancer.arn
    port              = "8080"
    protocol          = "HTTP"

    default_action {
        target_group_arn = aws_alb_target_group.ecs-target-group-green.arn
        type             = "forward"
    }
}

resource "aws_launch_configuration" "ecs-launch-configuration" {
    name                        = "ecs-launch-configuration"
    image_id                    = "ami-0ec7896dee795dfa9"
    instance_type               = "t2.micro"
    iam_instance_profile        = aws_iam_instance_profile.ecs-instance-profile.id

    root_block_device {
      volume_type = "standard"
      volume_size = 100
      delete_on_termination = true
    }

    lifecycle {
      create_before_destroy = true
    }

    security_groups             = [aws_security_group.test_public_sg.id]
    associate_public_ip_address = "true"
    user_data                   = <<EOF
                                  #!/bin/bash
                                  echo ECS_CLUSTER=${var.ecs_cluster} >> /etc/ecs/ecs.config
                                  EOF
}

resource "aws_autoscaling_group" "ecs-autoscaling-group" {
    name                        = "ecs-autoscaling-group"
    max_size                    = var.max_instance_size
    min_size                    = var.min_instance_size
    desired_capacity            = var.desired_capacity
    vpc_zone_identifier         = [aws_subnet.demoPubSN0-0.id, aws_subnet.demoPubSN0-1.id]
    launch_configuration        = aws_launch_configuration.ecs-launch-configuration.name
    health_check_type           = "ELB"
    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_ecs_cluster" "test-ecs-cluster" {
    name = var.ecs_cluster
}

data "aws_ecs_task_definition" "microservice_a" {
  task_definition = aws_ecs_task_definition.microservice_a.family
}

resource "aws_ecs_task_definition" "microservice_a" {
    family                = "microservice_a"
    memory                = "256"
    container_definitions = <<DEF
[
  {
    "name": "nginx",
    "image": "477829879262.dkr.ecr.us-east-1.amazonaws.com/nginx-sidecar:latest",
    "memory": 128,
    "cpu": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 0,
        "protocol": "tcp"
      }
    ],
    "links": [
      "app"
    ],
    "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/microservice_a",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs"
          }
    },
    "healthCheck": {
        "retries": 3,
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost/api/health-check || exit 1"
        ],
        "timeout": 5,
        "interval": 30,
        "startPeriod": null
    }
  },
  {
    "name": "app",
    "image": "477829879262.dkr.ecr.us-east-1.amazonaws.com/node-sidecar:latest",
    "memory": 128,
    "cpu": 256,
    "essential": true,
    "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "/ecs/microservice_a",
            "awslogs-region": "us-east-1",
            "awslogs-stream-prefix": "ecs"
          }
    }
  }
]
DEF


}

resource "aws_ecs_service" "test-ecs-service" {
  	name            = "test-ecs-service"
  	# iam_role        = aws_iam_role.ecs-service-role.name
  	cluster         = aws_ecs_cluster.test-ecs-cluster.id
  	task_definition = aws_ecs_task_definition.microservice_a.family
  	desired_count   = var.desired_capacity

    deployment_controller {
        type = "CODE_DEPLOY"
    }

  	load_balancer {
    	target_group_arn  = aws_alb_target_group.ecs-target-group-blue.arn
    	container_port    = 80
    	container_name    = "nginx"
	  }
    # load_balancer {
    # 	target_group_arn  = aws_alb_target_group.ecs-target-group-green.arn
    # 	container_port    = 80
    # 	container_name    = "nginx"
	  # }
  depends_on = [
    aws_alb_listener.alb-listener-prod,
    aws_alb_listener.alb-listener-test
  ]
  
}