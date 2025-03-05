## Prerequisites

- Python 3.12
- Terraform 1.11
- MySQL Server, Router 8.0
- AWS CLI 2.17
- Git 2.46 (if cloning this from Github. If you obtained this through zip file, this isn't necessary)
- AWS Credentials have been set up

Verify the above with the following (Windows):

```
python --version
terraform --version
netstat -na | select-string '3306 ' # to ensure mysql server is installed and contactable
git config user.name # to ensure git is installed and credentials are signed in
aws sts get-caller-identity # to ensure AWS CLI is installed and credentials are signed in
```

If cloning from Github, run the following in an empty folder (this is not necessary if obtained via zip file):

```
git clone https://github.com/jh2946/terraform-demo.git .
```

Throughout the entire process, do not manually edit any files except for `app/.env` (the full cloud deployment run doesn't even depend on `app/.env`). If you see any errors, please screenshot, document the steps you took to arrive at the error, and inform me.

## Deploying local (sqlite + local disk)

Copy the following into `app/.env`:

```
DB_DRIVERNAME='sqlite'
UPLOADS_ENGINE='file'
DB_DATABASE='database.db'
```

Run the following to build:

```
cd app
pip install -r requirements.txt
```

Run the following to start server:

```
python server.py
```

Go to http://localhost on your browser.

## Deploying local (MySQL + local disk)

Same as above, but modify `.env` as follows before building:

```
UPLOADS_ENGINE='file'
DB_DRIVERNAME='mysql'
DB_DATABASE='carddatabase'
DB_USER='root'
DB_HOST='localhost'
DB_DRIVERNAME='mysql'
DB_PASSWORD='' # enter your database password here
```

## Deploying local (sqlite + S3)

Create an S3 bucket in your AWS account.

The rest is the same as above, but modify `.env` as follows before building:

```
REGION='us-east-1'
DB_DRIVERNAME='sqlite'
DB_DATABASE='database.db'
UPLOADS_ENGINE='s3'
AWS_ACCESS_KEY_ID='' # enter your AWS access key (if on learner lab, go to AWS Details -> AWS CLI and copy the corresponding variable)
AWS_SECRET_ACCESS_KEY='' # enter your AWS key secret
AWS_SESSION_TOKEN='' # enter your AWS session token
S3_BUCKET='example-bucket-0123456789' # enter the name of your S3 bucket here
```

## Deploying local (MySQL + S3)

Create an S3 bucket in your AWS account.

The rest is the same as above, but modify `.env` as follows before building:

```
REGION='us-east-1'
DB_USER='root'
DB_HOST='localhost'
DB_PORT='3306'
DB_PASSWORD='' # enter your database password here
DB_DRIVERNAME='mysql'
DB_DATABASE='carddatabase'
UPLOADS_ENGINE='s3'
AWS_ACCESS_KEY_ID='' # enter your AWS access key
AWS_SECRET_ACCESS_KEY='' # enter your AWS key secret
AWS_SESSION_TOKEN='' # enter your AWS session token
S3_BUCKET='example-bucket-0123456789' # enter the name of your S3 bucket here
```

## Deploying cloud (EC2 + MySQL + S3)

Stay in this folder, run the following:

```
terraform init
terraform apply
```

The apply command may take up to 15 minutes.

Once successful, locate the freshly created EC2 instance in your AWS account and copy the public IP address, then visit `http://<public-ip>` in your browser.
