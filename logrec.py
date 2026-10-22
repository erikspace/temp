#!/usr/bin/env python3
#
# run server -
# gunicorn --bind 0.0.0.0:8080 app:app
#
# client send -
# curl -F "file=@build.zip" http://your-host:8080/upload
#
# response in json -
# {
#    "filename": "build.zip",
#    "path": "uploads/build.zip",
#    "size": 12345678,
#    "status": "ok"
# }
#
# alternate upload dir -
# UPLOAD_DIR=/data/builds gunicorn --bind 0.0.0.0:8080 app:app

import os
from pathlib import Path

from flask import Flask, jsonify, request
from werkzeug.utils import secure_filename

app = Flask(__name__)

UPLOAD_DIR = Path(os.environ.get("UPLOAD_DIR", "./uploads"))

# max upload 1gb
app.config["MAX_CONTENT_LENGTH"] = 1024 * 1024 * 1024

@app.get("/health")
def health():
    return jsonify(status="ok")

@app.post("/upload")
def upload():
    if "file" not in request.files:
        return jsonify(error="no file supplied"), 400

    file = request.files["file"]

    if not file.filename:
        return jsonify(error="empty filename"), 400

    filename = secure_filename(file.filename)

    if not filename:
        return jsonify(error="invalid filename"), 400

    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    destination = UPLOAD_DIR / filename
    file.save(destination)

    return jsonify(
        status="ok",
        filename=filename,
        path=str(destination),
        size=destination.stat().st_size,
    ), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
