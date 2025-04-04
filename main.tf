provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "my-terraform-bucket-${random_id.suffix.hex}"
  # generates a bucket ID with random characters.
  # note: the random characters are needed because no one,
  # not even two different accounts, can have the same
  # bucket ID, so this is to prevent clashing IDs.
}

resource "aws_s3_bucket_public_access_block" "unblock_public_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  # allows public access to the bucket, which is required
  # for our users to access the image URLs over internet (in the form
  # of https://bucket-ID.us-east-1.s3.amazonaws.com/image)

}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "ObjectWriter"
    # for unblocking public access, this is required
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket     = aws_s3_bucket.bucket.id

  depends_on = [aws_s3_bucket_public_access_block.unblock_public_access]
  # depends_on controls the chronological order in which rules are applied.
  # without this, sometimes unblock_public_access ran after bucket_policy which apparently
  # made the deployment break

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
  # this policy allows anyone (even over the internet) to load images from our bucket
  # note: to allow access to images over internet, you need to both
  # unblock public access (see unblock_public_access)
  # and set an open bucket policy (this policy here)

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
  # the above are configurations and capacities of the
  # RDS instance -- what database does it store

  username               = "admin"
  password               = var.db_password
  db_name                = "carddatabase"
  # the above are information required for MySQL

  publicly_accessible    = false
  skip_final_snapshot    = true
  # the above are behaviours of the RDS deployment,
  # we don't need a final snapshot so we'll skip it

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg-"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allows port 3306 traffic to the RDS instance
  # note: MySQL accepts traffic through port 3306
  # by default, so we have to allow any traffic comiing
  # through that port in order to interact with MySQL properly
}

resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
  # generates a key pair which is needed for ssh
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-generated-key"
  public_key = tls_private_key.my_key.public_key_openssh
  # uploads the ssh key pair (at least, the public key) to AWS
  # so that it can be used on EC2 instances there
}

resource "local_file" "private_key" {
  content  = tls_private_key.my_key.private_key_pem
  filename = "${path.module}/my-key.pem"
  # saves the private key in our laptop (terraform needs to see this to communicate with our EC2 instance)
}

resource "aws_instance" "ec2" {

  ami                         = "ami-04b4f1a9cf54c11d0"
  # the ami above is ubuntu server, this determines that the EC2 instance
  # will launch with ubuntu

  instance_type               = "t3.micro"
  associate_public_ip_address = true
  # required if you want any chance of the user
  # having some way to send requests to your
  # application

  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = "LabInstanceProfile"
  # instance profiles give EC2 instances certain permissions
  # for example, this deployment requires our EC2 instances to upload
  # images into an S3 bucket, LabInstanceProfile is configured by AWS
  # to allow that for our instances

  key_name                    = aws_key_pair.generated_key.key_name

  provisioner "file" {
    source      = "./app"
    destination = "/home/ubuntu/"
  }
  # copies this directory's app folder into the EC2 instance

  provisioner "file" {
    source      = "./system"
    destination = "/home/ubuntu/"
  }
  # copies this directory's system folder into the EC2 instance

  provisioner "remote-exec" {
    inline = [

      "cd /home/ubuntu/system",
      "sudo mv server.service /etc/systemd/system/",
      # the above moves the server.service file (which is visible under
      # "system" folder in your vscode") into the appropriate directory within ubuntu. 
      # the server.service file is responsible for running the python server
      # and defining how the python server is run
      # (e.g. what permissions to run it under, when to run it, etc.).

      "echo \"REGION=us-east-1\" >> environment",
      "echo \"UPLOADS_ENGINE=s3\" >> environment",
      "echo \"S3_BUCKET=${aws_s3_bucket.bucket.bucket}\" >> environment",
      "echo \"DB_USER=${aws_db_instance.rds.username}\" >> environment",
      "echo \"DB_HOST=${aws_db_instance.rds.address}\" >> environment",
      "echo \"DB_PORT=${aws_db_instance.rds.port}\" >> environment",
      "echo \"DB_PASSWORD=${var.db_password}\" >> environment",
      "echo \"DB_DRIVERNAME=mysql\" >> environment",
      "echo \"DB_DATABASE=${aws_db_instance.rds.db_name}\" >> environment",
      # these define environment variables, which the app relies on
      # for certain operations, such as "where should i send database requests?"
      # there are a lot of substituted values as these values are
      # taken from other elements of our deployment. some of these values are
      # auto-generated by AWS, so there is no way to hardcode them
      # (but luckily terraform allows us to do it this way)

      "sudo apt update",
      "sudo apt install python3-dev python3.12-venv pkg-config libmysqlclient-dev build-essential -y",
      # downloads software dependencies such as C libraries, the python venv capability
      # and mysql integration for python
      # (apt is the package manager for ubuntu)

      "cd /home/ubuntu/app",
      # cd into app directory (seen here in vscode)

      "rm -f .env",
      # remove .env file to avoid clash (i think it was -rf in the original version, change it to -f)

      "python3 -m venv venv",
      "bash -c 'source venv/bin/activate && python3 -m pip install -r requirements.txt'",
      # install python libraries using virtual environment
      # (the virtual environment was required because of a conflicting
      # python package version built into the instance's global scope,
      # you don't have to explain why a venv was strictly needed, but
      # you can say "the venv helped resolve a conflict between global and
      # local python packages" if you really want to explain)

      "sudo systemctl daemon-reload",
      "sudo systemctl enable server.service",
      "sudo systemctl start server.service",
      "echo 'sudo systemctl start server.service' >> /home/ubuntu/.profile"
      # activates the server.service file from our system folder,
      # meaning this ensures that the python file (app server) is run every time
      # the instance boots up

    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.my_key.private_key_pem
    host        = self.public_ip
    # we will run all the file copying and command execution
    # through this ssh connection, which is a connection to the EC2 instance
    # that provides direct OS-level access to the instance,
    # and ssh requires a key pair to connect so that's why
    # we created the key pair from before
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
  # allow ssh to our application (required for terraform to ssh in, see above)

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allow http requests to our application

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # allow all requests from instance to internet
  # note: usually we allow all  outbound requests
  # because we don't know what requests the instance requires

}
