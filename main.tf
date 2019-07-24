provider aws {
  region = "us-east-1"
}

resource aws_ecr_repository envoy-image {
  name = "envoy-ssl"
}

resource aws_ecr_repository app-image {
  name = "flask-app"
}

data template_file envoy-ssl {
  template = file("task-definition.json")
  vars = {
    envoy_image_uri = aws_ecr_repository.envoy-image.repository_url
    app_image_uri = aws_ecr_repository.app-image.repository_url
    service_name = var.service_name
    dns_namespace = aws_service_discovery_private_dns_namespace.envoy-ssl.name
  }
}

resource aws_security_group envoy-ssl {
  name = "${var.service_name}-sg"
  description = "Allow inbound HTTPS traffic only"
  vpc_id = var.vpc_id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource aws_ecs_cluster envoy-ssl {
  name = var.service_name
}

resource aws_ecs_task_definition envoy-ssl {
  family = var.service_name
  container_definitions = data.template_file.envoy-ssl.rendered
  requires_compatibilities = ["FARGATE"]
  memory = "512"
  cpu = "0.25vcpu"
  network_mode = "awsvpc"
  execution_role_arn = var.task_role
  task_role_arn = var.task_role

  provisioner local-exec {
    working_dir = "./docker"
    command = <<EOF
      docker build -t ${aws_ecr_repository.envoy-image.repository_url} -f Dockerfile-sslenvoy .
      docker build -t ${aws_ecr_repository.app-image.repository_url} -f Dockerfile-app .
      docker push ${aws_ecr_repository.envoy-image.repository_url}
      docker push ${aws_ecr_repository.app-image.repository_url}
EOF
  }
}

resource aws_service_discovery_private_dns_namespace envoy-ssl {
  name        = "dev"
  description = "Private namespace for the Envoy SSL tutorial"
  vpc         = var.vpc_id
}

resource aws_service_discovery_service envoy-ssl {
  name = var.service_name
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.envoy-ssl.id

    dns_records {
      ttl = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

resource aws_cloudwatch_log_group envoy-ssl {
  name = "/ecs/${var.service_name}"
}

resource aws_ecs_service envoy-ssl {
  name = var.service_name
  cluster = aws_ecs_cluster.envoy-ssl.id
  task_definition = aws_ecs_task_definition.envoy-ssl.id
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [var.subnet_id]
    security_groups = [aws_security_group.envoy-ssl.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.envoy-ssl.arn
  }
}
