# Deploys deploy/hostinger/compose.yaml as the Docker project "lnclass" on the Hostinger VPS, with the production
# variables read from Railway (app service + shared variables). Prints names and statuses only, never a value.
# Usage: python3 -I script/hostinger/deployer.py deploy/hostinger/compose.yaml <sha>   (APP_REPLICAS=0 to stop the app)
#        python3 -I script/hostinger/deployer.py construction deploy/hostinger/construction.yaml <sha>
#        python3 -I script/hostinger/deployer.py bascule deploy/hostinger/bascule.yaml fichiers|base|tout [--dry-run]
# Needs RAILWAY_API_TOKEN (variables read from Railway production) and a Hostinger API token injected by the proxy.
import json, os, sys, urllib.parse, urllib.request, urllib.error

VM = 2172236
PROJECT = "e2d4616e-2a72-4f93-a55b-d233c7502d1b"
ENV_PROD = "2169ce6a-54a4-4150-9d12-bdb6cb98f54c"
APP_SERVICE = "c37094d3-f5dd-4aae-9f05-ade0d6e831d8"
POSTGRES_SERVICE = "d4042db9-45ae-4cad-ad13-0a2eff0f6236"
TEST_HOST = "srv2172236.hstgr.cloud"

COPIED = ["RAILS_MASTER_KEY", "MASTER_KEY", "ANDROID_CERT_FINGERPRINTS", "CANONICAL_HOST", "TEAM_BOOTSTRAP_CONTACT",
          "CLAUDE_AGENTAI_CONTACT", "CLAUDE_AGENTAI_SECRET", "RAILWAY_ENVIRONMENT_NAME"]


def railway_vars(service_id=None, environment_id=ENV_PROD):
    args = f'projectId: "{PROJECT}", environmentId: "{environment_id}"'
    if service_id:
        args += f', serviceId: "{service_id}"'
    body = json.dumps({"query": f"query {{ variables({args}) }}"}).encode()
    req = urllib.request.Request("https://backboard.railway.com/graphql/v2", body, {
        "content-type": "application/json", "User-Agent": "curl/8.5.0",
        "Authorization": f"Bearer {os.environ['RAILWAY_API_TOKEN']}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    if data.get("errors"):
        sys.exit(f"Railway: {data['errors'][0].get('message')}")
    return data["data"]["variables"]


def quote(value):
    if "\n" in value:
        sys.exit("multi-line value refused")
    return "'" + value + "'" if "'" not in value else '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if sys.argv[1] == "bascule":
        return bascule(sys.argv[2], sys.argv[3])
    if sys.argv[1] == "construction":
        return send("lnclass-construction", sys.argv[2],
                    {"APP_REVISION": sys.argv[3], "GH_DEPLOY_TOKEN": railway_vars()["GH_DEPLOY_TOKEN"]})
    compose_path, revision = sys.argv[1], sys.argv[2]
    app = railway_vars(APP_SERVICE)
    shared = railway_vars()
    env = {name: app[name] for name in COPIED if app.get(name)}
    env["APP_REPLICAS"] = os.environ.get("APP_REPLICAS", "1")
    hosts = [h.strip() for h in app.get("APP_HOSTS", "").split(",") if h.strip()]
    env["APP_HOSTS"] = ",".join(hosts + [TEST_HOST])
    env["SITE_ADDRESSES"] = os.environ.get("SITE_ADDRESSES", "lnclass.com, www.lnclass.com")
    env["BUCKET_ENDPOINT"] = "https://52eb657a0814d7799bf3eb3e735109ad.r2.cloudflarestorage.com"
    env["BUCKET_NAME"] = "lnclass-production"
    env["BUCKET_REGION"] = "auto"
    env["BUCKET_ACCESS_KEY_ID"] = shared["CIBLE_BUCKET_ACCESS_KEY_ID"]
    env["BUCKET_SECRET_ACCESS_KEY"] = shared["CIBLE_BUCKET_SECRET_ACCESS_KEY"]
    env["APP_REVISION"] = revision
    missing = [name for name in COPIED if name not in env]
    print("variables:", ", ".join(sorted(env)), "| absentes de Railway:", missing or "aucune")
    if "--dry-run" in sys.argv:
        return

    send("lnclass", compose_path, env)


# Profile "fichiers" (any time, replayable) or "base" (application stopped first: APP_REPLICAS=0).
def bascule(compose_path, profile):
    app = railway_vars(APP_SERVICE)
    shared = railway_vars()
    env = {"COMPOSE_PROFILES": profile,
           "SOURCE_BUCKET_NAME": app["BUCKET_NAME"],
           "RCLONE_CONFIG_SRC_ENDPOINT": app["BUCKET_ENDPOINT"],
           "RCLONE_CONFIG_SRC_REGION": app.get("BUCKET_REGION", "auto"),
           "RCLONE_CONFIG_SRC_ACCESS_KEY_ID": app["BUCKET_ACCESS_KEY_ID"],
           "RCLONE_CONFIG_SRC_SECRET_ACCESS_KEY": app["BUCKET_SECRET_ACCESS_KEY"],
           "BUCKET_NAME": "lnclass-production",
           "RCLONE_CONFIG_DST_ENDPOINT": "https://52eb657a0814d7799bf3eb3e735109ad.r2.cloudflarestorage.com",
           "RCLONE_CONFIG_DST_ACCESS_KEY_ID": shared["CIBLE_BUCKET_ACCESS_KEY_ID"],
           "RCLONE_CONFIG_DST_SECRET_ACCESS_KEY": shared["CIBLE_BUCKET_SECRET_ACCESS_KEY"]}
    if profile in ("base", "tout"):
        # SOURCE_ENV: another Railway environment (Staging) for a rehearsal.
        pg = railway_vars(POSTGRES_SERVICE, os.environ.get("SOURCE_ENV", ENV_PROD))
        if not pg.get("RAILWAY_TCP_PROXY_DOMAIN"):
            sys.exit("proxy TCP absent : créer le proxy TCP du Postgres Railway d'abord")
        source = (f"postgresql://{urllib.parse.quote(pg['PGUSER'])}:{urllib.parse.quote(pg['PGPASSWORD'], safe='')}"
                  f"@{pg['RAILWAY_TCP_PROXY_DOMAIN']}:{pg['RAILWAY_TCP_PROXY_PORT']}/{pg['PGDATABASE']}")
        env["SOURCE_DATABASE_URL"] = source + ("&" if "?" in source else "?") + "sslmode=require"
        env["CONFIRMER_REMPLACEMENT"] = "base-du-vps"
    print("variables:", ", ".join(sorted(env)))
    if "--dry-run" not in sys.argv:
        send("lnclass-bascule", compose_path, env)


def send(project, compose_path, env):
    payload = {"project_name": project, "content": open(compose_path).read(),
               "environment": "\n".join(f"{k}={quote(v)}" for k, v in env.items()) + "\n"}
    req = urllib.request.Request(f"https://developers.hostinger.com/api/vps/v1/virtual-machines/{VM}/docker",
                                 json.dumps(payload).encode(), {"content-type": "application/json", "User-Agent": "curl/8.5.0"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            result = json.load(r)
            print("Hostinger:", r.status, {k: result.get(k) for k in ("id", "name", "state") if k in result})
    except urllib.error.HTTPError as error:
        print("Hostinger:", error.code, error.read()[:500].decode(errors="replace"))
        sys.exit(1)


main()
