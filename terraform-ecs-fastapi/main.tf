#use default vpc
data "aws_vpc" "default" {
  default = true
}


#use default subnet
data "aws_subnets" "default" {
    filter {
        name= "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

#make ecs security group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-security-group"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#make DB Subnet Group 
resource "aws_db_subnet_group" "default" {
  name       = "fastapi-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "fastapi-db-subnet-group"
  }
}

#make rds sg 
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow PORT 5432 FROM sg ecs"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#MAKE RDS INSTANCE
resource "aws_db_instance" "postgres" {
  identifier              = "fastapi-postgres"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp2"

  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password


  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
}

#MAKE ECS CLUSTERS 
resource "aws_ecs_cluster" "main" {
  name = "fastapi-cluster"
}

#MAKE IAM ROLE FOR ECS 
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#MAKE ECR 
resource "aws_ecr_repository" "fastapi_repo" {
  name                 = "fastapi-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}


#LOGIN TO AWS
#CREATE REPOSITORY
#aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 339713020180.dkr.ecr.us-east-1.amazonaws.com 
#339713020180.dkr.ecr.us-east-1.amazonaws.com
#BUIDL IMAGE 
#docker build -t fastapi-app:v1 . 

# TAG ECR 
# docker tag fastapi-app:v1 339713020180.dkr.ecr.ap-southeast-1.amazonaws.com/fastapi-app:v1
#example "docker tag fastapi-app:v1 590183708030.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:v1"

#PUSH ECR 
#docker push 339713020180.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:v1


#CREATE NULL RESOURCE 
resource "null_resource" "docker_build_push" {
  depends_on = [ aws_ecr_repository.fastapi_repo ]
  provisioner "local-exec" {
    command = <<EOT
aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.fastapi_repo.repository_url}
docker build -t fastapi-app:v1 ${path.module}
docker tag fastapi-app:v1 ${aws_ecr_repository.fastapi_repo.repository_url}:v1
docker push ${aws_ecr_repository.fastapi_repo.repository_url}:v1
EOT
    
  }
}



#CREATE TASK DEFINITION 
resource "aws_ecs_task_definition" "fastapi_task" {

  depends_on = [null_resource.docker_build_push] 
  family                   = "fastapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "fastapi-container"
      image     = "${aws_ecr_repository.fastapi_repo.repository_url}:v1" 
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]

      environment = [
        {
          name  = "DATABASE_URL"
          value =local.database_url
        }
      ]
    }
  ])
}

#MAKE SERVICE 

resource "aws_ecs_service" "fastapi_service" {
  name            = "fastapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fastapi_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_ecs_task_definition.fastapi_task
  ]
}