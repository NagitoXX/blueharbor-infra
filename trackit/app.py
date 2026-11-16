import json, os, socket, urllib.parse, urllib.request
from flask import Flask, jsonify

app = Flask(__name__)
VERSION = os.getenv("APP_VERSION", "1.0.1")
cache = None
if os.getenv("REDIS_HOST"):
    import redis
    cache = redis.Redis(host=os.getenv("REDIS_HOST"), port=6379)


def fetch_shipment(sid):
    """Read one shipment from Supabase through its REST API."""
    base = os.environ["SUPABASE_URL"].rstrip("/")
    url = f"{base}/rest/v1/shipments?id=eq.{urllib.parse.quote(sid)}&select=*"
    req = urllib.request.Request(url, headers={"apikey": os.environ["SUPABASE_KEY"]})
    with urllib.request.urlopen(req, timeout=5) as r:
        rows = json.load(r)
    return rows[0] if rows else None


@app.get("/")
def index():
    visits = cache.incr("visits") if cache else "n/a"
    return (f"<h1>BlueHarbor TrackIt</h1><p>Version {VERSION} served by "
            f"{socket.gethostname()} - visits: {visits}</p>")


@app.get("/health")
def health():
    return jsonify(status="ok", version=VERSION)


@app.get("/api/shipments/<sid>")
def shipment(sid):
    if os.getenv("SUPABASE_URL") and os.getenv("SUPABASE_KEY"):
        row = fetch_shipment(sid)
        return (jsonify(row), 200) if row else (jsonify(error="not found"), 404)
    return jsonify(id=sid, status="in transit", hub="Lille", source="static")
