from flask import Flask, request, jsonify, abort, send_file, send_from_directory, redirect
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
from sqlalchemy.engine import URL
from urllib.parse import urljoin
import secrets
import json
import os
from getpass import getpass
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)
app.app_context().push()

UPLOADS_ENGINE = os.getenv('UPLOADS_ENGINE')
assert UPLOADS_ENGINE in ['file', 's3'], 'environment variable UPLOADS_ENGINE must be of value "file" or "s3". Other engines are not currently supported'
if UPLOADS_ENGINE == 's3':
    REGION = os.getenv('REGION')
    UPLOAD_BUCKET = os.getenv('S3_BUCKET')
    import boto3
    ACCESS_KEY = os.getenv('AWS_ACCESS_KEY_ID')
    SECRET_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
    SESSION_TOKEN = os.getenv('AWS_SESSION_TOKEN')
    s3 = boto3.client(
        's3',
        aws_access_key_id=ACCESS_KEY if ACCESS_KEY else None,
        aws_secret_access_key=SECRET_KEY if SECRET_KEY else None,
        aws_session_token=SESSION_TOKEN if SESSION_TOKEN else None
    )
    UPLOAD_ENDPOINT = f'https://{UPLOAD_BUCKET}.s3.{REGION}.amazonaws.com/'
else:
    UPLOAD_FOLDER = 'uploads'
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    UPLOAD_ENDPOINT = '/uploads/'

drivername = os.getenv('DB_DRIVERNAME')
assert drivername in ['sqlite', 'mysql'], 'environment variable DB_DRIVERNAME must be of value "sqlite" or "mysql". Other engines are not currently supported'
port = os.getenv('DB_PORT')
database = os.getenv('DB_DATABASE')

password = ''
if drivername != 'sqlite':
    password = os.getenv('DB_PASSWORD')
    if not password:
        password = getpass('Database password: ')

db_url = URL.create(
    drivername=drivername,
    username=os.getenv('DB_USER'),
    password=password,
    host=os.getenv('DB_HOST'),
    port=port if port else None
)

app.config['SQLALCHEMY_DATABASE_URI'] = db_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
database_init = """
CREATE DATABASE IF NOT EXISTS %s;
USE %s;
""" % (database, database)

with open('schema.sql', 'r') as f:
    if UPLOADS_ENGINE == 'file':
        schema = f.read()
    else:
        schema = database_init + f.read()
    cmds = schema.split(';')
    for cmd in cmds:
        db.session.execute(text(cmd + ';')) if any(c.isalnum() for c in cmd) else None
        db.session.commit()

@app.route('/create', methods=['GET'])
def create_html():
    return send_file('./public/create.html')

@app.route('/deck', methods=['GET'])
def deck_html():
    return send_file('./public/deck.html')

@app.route('/', methods=['GET'])
def index_html():
    return send_file('./public/index.html')

@app.route('/<path:path>', methods=['GET'])
def styles(path):
    return send_from_directory('./public', path)

@app.route('/uploads/<filename>', methods=['GET'])
def get_uploaded_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/endpoint')
def endpoint():
    query = text('SELECT * FROM deck;')
    result = db.session.execute(query)
    decks = [dict(row._mapping) for row in result]
    return jsonify(decks)

@app.route('/create', methods=['POST'])
def create():
    id = secrets.token_urlsafe(16)
    query = text('INSERT INTO deck (id, meta) VALUES (:id, :meta);')
    db.session.execute(query, { "id": id, "meta": json.dumps(request.form.to_dict()) })
    db.session.commit()
    return redirect(f'/deck?id={id}')

@app.route('/deck/endpoint')
def deck_endpoint():
    query = text('SELECT * FROM card WHERE deckId = :deckId ORDER BY created ASC;')
    data = db.session.execute(query, { "deckId": request.args.get('id') })
    results = [dict(row._mapping) for row in data]
    return jsonify(results)

@app.route('/deck', methods=['POST'])
def deck():
    id = secrets.token_urlsafe(16)
    meta = request.form.to_dict()
    frontfile = request.files.get('file-front')
    if frontfile:
        frontfile_id = secrets.token_urlsafe(16)
        meta['file-front'] = UPLOAD_ENDPOINT + frontfile_id
        if UPLOADS_ENGINE == 's3':
            s3.put_object(
                Bucket=UPLOAD_BUCKET,
                Key=frontfile_id,
                Body=frontfile,
                ContentType=request.mimetype
            )
        else:
            frontfile_path = os.path.join(UPLOAD_FOLDER, frontfile_id)
            frontfile.save(frontfile_path)
    backfile = request.files.get('file-back')
    if backfile:
        backfile_id = secrets.token_urlsafe(16)
        meta['file-back'] = UPLOAD_ENDPOINT + backfile_id
        if UPLOADS_ENGINE == 's3':
            s3.put_object(
                Bucket=UPLOAD_BUCKET,
                Key=backfile_id,
                Body=backfile,
                ContentType=request.mimetype
            )
        else:
            backfile_path = os.path.join(UPLOAD_FOLDER, backfile_id)
            backfile.save(backfile_path)
    query = text('INSERT INTO card (id, meta, deckId) VALUES (:id, :meta, :deckId)')
    db.session.execute(query, { 'id': id, 'meta': json.dumps(meta), 'deckId': request.args.get('id') })
    db.session.commit()
    return redirect(request.referrer)

app.run(port=80, host='0.0.0.0')
