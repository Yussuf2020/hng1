from flask import Flask
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def home():
    now = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    return f"""
    <h1> Welcome to My Cool Keeds App!</h1>
    <p>I'll be writing a bash script for deployment and automation.</p>
    <p><strong>Current Server Time:</strong> {now}</p>
    """

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
