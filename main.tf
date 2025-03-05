provider "aws" {
  region = "us-east-1" # Change as needed
}

resource "aws_s3_bucket" "bucket" {
  bucket = "my-terraform-bucket-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "unblock_public_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket     = aws_s3_bucket.bucket.id
  depends_on = [aws_s3_bucket_public_access_block.unblock_public_access]
  policy     = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "${aws_s3_bucket.bucket.arn}/*"
    }
  ]
}
POLICY
}

variable "db_password" {
  default = "mypassword123"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_db_instance" "rds" {
  allocated_storage      = 20
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  identifier             = "my-rds-instance"
  username               = "admin"
  password               = var.db_password
  db_name                = "carddatabase"
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg-"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict in production
  }
}

resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-generated-key"
  public_key = tls_private_key.my_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.my_key.private_key_pem
  filename = "${path.module}/my-key.pem"
}

resource "null_resource" "always_run" {
  triggers = {
    timestamp = "${timestamp()}"
  }
}

resource "aws_instance" "ec2" {
  ami                         = "ami-04b4f1a9cf54c11d0" # Change to latest Amazon Linux
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = "LabInstanceProfile"
  key_name                    = aws_key_pair.generated_key.key_name

  provisioner "file" {
    source      = "./app"
    destination = "/home/ubuntu/"
  }

  provisioner "file" {
    source      = "./system"
    destination = "/home/ubuntu/"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/ubuntu/system",
      "sudo mv server.service /etc/systemd/system/",
      "echo \"REGION=us-east-1\" >> environment",
      "echo \"UPLOADS_ENGINE=s3\" >> environment",
      "echo \"S3_BUCKET=${aws_s3_bucket.bucket.bucket}\" >> environment",
      "echo \"DB_USER=${aws_db_instance.rds.username}\" >> environment",
      "echo \"DB_HOST=${aws_db_instance.rds.address}\" >> environment",
      "echo \"DB_PORT=${aws_db_instance.rds.port}\" >> environment",
      "echo \"DB_PASSWORD=${var.db_password}\" >> environment",
      "echo \"DB_DRIVERNAME=mysql\" >> environment",
      "echo \"DB_DATABASE=${aws_db_instance.rds.db_name}\" >> environment",
      "sudo apt update",
      "sudo apt install python3-dev python3.12-venv pkg-config libmysqlclient-dev build-essential -y",
      "cd /home/ubuntu/app",
      "rm -rf .env",
      "python3 -m venv venv",
      "bash -c 'source venv/bin/activate && python3 -m pip install -r requirements.txt'",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable server.service",
      "sudo systemctl start server.service",
      "echo 'sudo systemctl start server.service' >> /home/ubuntu/.profile"
    ]
  }

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.my_key.private_key_pem
    host        = self.public_ip
  }
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
