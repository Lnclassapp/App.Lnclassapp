# Deploys deploy/hostinger/compose.yaml as the Docker project "lnclass" on the Hostinger VPS, with the production
# variables read from Railway (app service + shared variables). Prints names and statuses only, never a value.
# Usage: python3 -I script/hostinger/deployer.py deploy/hostinger/compose.yaml <sha>   (APP_REPLICAS=0 to stop the app)
#        python3 -I script/hostinger/deployer.py construction deploy/hostinger/construction.yaml <sha>
#        python3 -I script/hostinger/deployer.py bascule deploy/hostinger/bascule.yaml fichiers|base [--remplacer-la-base-du-vps] [--dry-run]
# <sha>: a full commit of origin/main. One-off projects (construction, bascule) are deleted from the VPS once their
# container has finished, so the tokens of their .env do not stay on the server.
# Needs RAILWAY_API_TOKEN (variables read from Railway production) and a Hostinger API token injected by the proxy.
import json, os, re, subprocess, sys, time, urllib.parse, urllib.request, urllib.error

VM = 2172236
API = f"https://developers.hostinger.com/api/vps/v1/virtual-machines/{VM}"
PROJECT = "e2d4616e-2a72-4f93-a55b-d233c7502d1b"
ENV_PROD = "2169ce6a-54a4-4150-9d12-bdb6cb98f54c"
APP_SERVICE = "c37094d3-f5dd-4aae-9f05-ade0d6e831d8"
POSTGRES_SERVICE = "d4042db9-45ae-4cad-ad13-0a2eff0f6236"
TEST_HOST = "srv2172236.hstgr.cloud"
R2_ENDPOINT = "https://52eb657a0814d7799bf3eb3e735109ad.r2.cloudflarestorage.com"

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


def hostinger(path, payload=None, method="GET"):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(API + path, data, {"content-type": "application/json", "User-Agent": "curl/8.5.0"},
                                 method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as error:
        # Only the message: the body of a refused request could echo the .env sent.
        try:
            body = json.load(error)
        except ValueError:
            body = {}
        sys.exit(f"Hostinger {method} {path}: {error.code} {body.get('message', '')}")


# Compose's .env: single quotes are literal; double quotes interpolate ${...}, so a value holding both ' and $ is
# refused rather than silently changed.
def quote(value):
    if any(c in value for c in "\n\r\0"):
        sys.exit("valeur sur plusieurs lignes ou avec un caractère nul refusée")
    if "'" not in value:
        return "'" + value + "'"
    if "$" in value:
        sys.exit("valeur avec à la fois ' et $ refusée")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


# Only a full commit already on main goes to production: a branch name would reuse a stale image tag.
def checked_revision(sha):
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        sys.exit("révision : le SHA complet (40 caractères) d'un commit de main est attendu")
    subprocess.run(["git", "fetch", "-q", "origin", "main"], check=True)
    if subprocess.run(["git", "merge-base", "--is-ancestor", sha, "FETCH_HEAD"]).returncode != 0:
        sys.exit("révision absente de origin/main : rien envoyé")
    return sha


def main():
    if sys.argv[1] == "bascule":
        return bascule(sys.argv[2], sys.argv[3])
    if sys.argv[1] == "construction":
        env = {"APP_REVISION": checked_revision(sys.argv[3]), "GH_DEPLOY_TOKEN": railway_vars()["GH_DEPLOY_TOKEN"]}
        return run_once("lnclass-construction", sys.argv[2], env, "CONSTRUCTION OK", "CONSTRUCTION ECHEC", 3600)
    compose_path, revision = sys.argv[1], checked_revision(sys.argv[2])
    app = railway_vars(APP_SERVICE)
    shared = railway_vars()
    env = {name: app[name] for name in COPIED if app.get(name)}
    env["APP_REPLICAS"] = os.environ.get("APP_REPLICAS", "1")
    env["SITE_ADDRESSES"] = os.environ.get("SITE_ADDRESSES", "lnclass.com, www.lnclass.com")
    sites = [h.strip() for h in env["SITE_ADDRESSES"].split(",") if h.strip()]
    hosts = [h.strip() for h in app.get("APP_HOSTS", "").split(",") if h.strip()]
    # The server's own name is only allowed while a test serves it (it is behind the Cloudflare-only firewall).
    env["APP_HOSTS"] = ",".join(hosts + ([TEST_HOST] if TEST_HOST in sites else []))
    env["BUCKET_ENDPOINT"] = R2_ENDPOINT
    env["BUCKET_NAME"] = "lnclass-production"
    env["BUCKET_REGION"] = "auto"
    env["BUCKET_ACCESS_KEY_ID"] = shared["CIBLE_BUCKET_ACCESS_KEY_ID"]
    env["BUCKET_SECRET_ACCESS_KEY"] = shared["CIBLE_BUCKET_SECRET_ACCESS_KEY"]
    env["APP_REVISION"] = revision
    missing = [name for name in COPIED if name not in env]
    print("variables:", ", ".join(sorted(env)), "| absentes de Railway:", missing or "aucune")
    if "RAILS_MASTER_KEY" not in env and "MASTER_KEY" not in env:
        sys.exit("ni RAILS_MASTER_KEY ni MASTER_KEY dans Railway : l'application ne démarrerait pas")
    uncovered = [h for h in sites if h not in env["APP_HOSTS"].split(",")]
    if uncovered:
        sys.exit(f"hôtes servis par Caddy absents d'APP_HOSTS (Rails les refuserait) : {uncovered}")
    if "--dry-run" in sys.argv:
        return
    send("lnclass", compose_path, env)


# "fichiers": any time, replayable. "base": once, the application stopped first (APP_REPLICAS=0); the copy script
# itself refuses when an earlier copy already ran (lnclass_production_old exists).
def bascule(compose_path, profile):
    if profile not in ("fichiers", "base"):
        sys.exit(f"profil inconnu : {profile} (fichiers ou base)")
    if profile == "base" and "--remplacer-la-base-du-vps" not in sys.argv:
        sys.exit("la copie de la base remplace celle du VPS : relancer avec --remplacer-la-base-du-vps")
    app = railway_vars(APP_SERVICE)
    shared = railway_vars()
    env = {"COMPOSE_PROFILES": profile}
    if profile == "fichiers":
        env.update({"SOURCE_BUCKET_NAME": app["BUCKET_NAME"],
                    "RCLONE_CONFIG_SRC_ENDPOINT": app["BUCKET_ENDPOINT"],
                    "RCLONE_CONFIG_SRC_REGION": app.get("BUCKET_REGION", "auto"),
                    "RCLONE_CONFIG_SRC_ACCESS_KEY_ID": app["BUCKET_ACCESS_KEY_ID"],
                    "RCLONE_CONFIG_SRC_SECRET_ACCESS_KEY": app["BUCKET_SECRET_ACCESS_KEY"],
                    "BUCKET_NAME": "lnclass-production",
                    "RCLONE_CONFIG_DST_ENDPOINT": R2_ENDPOINT,
                    "RCLONE_CONFIG_DST_ACCESS_KEY_ID": shared["CIBLE_BUCKET_ACCESS_KEY_ID"],
                    "RCLONE_CONFIG_DST_SECRET_ACCESS_KEY": shared["CIBLE_BUCKET_SECRET_ACCESS_KEY"]})
    else:
        # SOURCE_ENV: another Railway environment (Staging) for a rehearsal.
        pg = railway_vars(POSTGRES_SERVICE, os.environ.get("SOURCE_ENV", ENV_PROD))
        if not pg.get("RAILWAY_TCP_PROXY_DOMAIN"):
            sys.exit("proxy TCP absent : créer le proxy TCP du Postgres Railway d'abord")
        env["SOURCE_DATABASE_URL"] = (
            f"postgresql://{urllib.parse.quote(pg['PGUSER'])}:{urllib.parse.quote(pg['PGPASSWORD'], safe='')}"
            f"@{pg['RAILWAY_TCP_PROXY_DOMAIN']}:{pg['RAILWAY_TCP_PROXY_PORT']}/{pg['PGDATABASE']}"
            "?sslmode=require&channel_binding=require")
        env["CONFIRMER_REMPLACEMENT"] = "base-du-vps"
    print("variables:", ", ".join(sorted(env)))
    if "--dry-run" not in sys.argv:
        marker = profile.upper()
        run_once("lnclass-bascule", compose_path, env, f"{marker} OK", f"{marker} ECHEC", 3600)


def send(project, compose_path, env):
    result = hostinger("/docker", {"project_name": project, "content": open(compose_path).read(),
                                   "environment": "\n".join(f"{k}={quote(v)}" for k, v in env.items()) + "\n"}, "POST")
    print("Hostinger:", {k: result.get(k) for k in ("id", "name", "state") if k in result})
    wait_for_action(result["id"])


# A 2xx only means "queued": the compose "up" itself can still fail (missing image, bad file).
def wait_for_action(action_id, timeout=900):
    deadline, delay, state = time.time() + timeout, 3, None
    while time.time() < deadline:
        time.sleep(delay)
        state = hostinger(f"/actions/{action_id}").get("state")
        if state == "success":
            print("Hostinger: action terminée")
            return
        if state == "error":
            sys.exit("Hostinger: action en ÉCHEC, lire script/hostinger/journaux.py <projet>")
        delay = min(delay * 2, 30)
    sys.exit(f"Hostinger: action toujours « {state} » après {timeout} s")


# A one-off project: started, followed in its logs until its OK or ECHEC line, then deleted from the VPS
# (containers and .env), whatever the outcome.
def run_once(project, compose_path, env, ok, failed, timeout):
    send(project, compose_path, env)
    deadline, outcome, lines = time.time() + timeout, None, []
    while outcome is None and time.time() < deadline:
        time.sleep(20)
        lines = [e.get("line", "") for s in hostinger(f"/docker/{project}/logs") for e in s.get("entries", [])]
        outcome = failed if any(failed in l for l in lines) else ok if any(ok in l for l in lines) else None
    result = hostinger(f"/docker/{project}/down", method="DELETE")
    if result.get("id"):
        wait_for_action(result["id"])
    print(f"projet {project} supprimé du VPS")
    if outcome != ok:
        # The logs leave with the project: the end is printed here, secrets masked.
        print("\n".join(re.sub(r"\w+://[^:/\s]+:[^@\s]+@|github_pat_\S+|ghp_\S+", "[masqué]", l)[:300] for l in lines[-30:]))
        sys.exit(f"{project} : {outcome or 'aucun verdict après ' + str(timeout) + ' s'}")
    print(outcome)


main()
