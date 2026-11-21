# Deploys the Lnclass environments on the Hostinger VPS (ADR-0140). Prints names and statuses only, never a value.
# Usage: python3 -I script/hostinger/deployer.py deploy/hostinger/compose.yaml <sha>          production ("lnclass")
#        python3 -I script/hostinger/deployer.py test deploy/hostinger/test.yaml staging|develop <sha>
#        python3 -I script/hostinger/deployer.py construction deploy/hostinger/construction.yaml <sha>
#        python3 -I script/hostinger/deployer.py bascule deploy/hostinger/bascule.yaml fichiers|base [--remplacer-la-base-du-vps]
#        --dry-run on any of them: prints the variable names, sends nothing.
# Where the variables come from, first found wins:
#   1. the session's environment, for the secrets: LNCLASS_RAILS_MASTER_KEY, LNCLASS_R2_ACCESS_KEY_ID,
#      LNCLASS_R2_SECRET_ACCESS_KEY, LNCLASS_CLAUDE_AGENTAI_SECRET, GH_DEPLOY_TOKEN (variables of the Claude Code
#      environment, set by the owner, or secrets of the GitHub Environments, .github/workflows/deploiement.yml),
#      plus HOSTINGER_API_TOKEN (the Hostinger API token, sent as a Bearer header when set);
#   2. the .env the project already has on the VPS (read back through the Hostinger API): a redeploy keeps it;
#   3. Railway, only to create a project that is not on the VPS yet (and for "bascule"), while Railway exists.
# <sha>: a full commit of origin/main (production), origin/Staging or origin/Develop. One-off projects (construction,
# bascule) are deleted from the VPS once their container has finished.
import json, os, re, subprocess, sys, time, urllib.parse, urllib.request, urllib.error

VM = 2172236
API = f"https://developers.hostinger.com/api/vps/v1/virtual-machines/{VM}"
PROJECT = "e2d4616e-2a72-4f93-a55b-d233c7502d1b"
APP_SERVICE = "c37094d3-f5dd-4aae-9f05-ade0d6e831d8"
POSTGRES_SERVICE = "d4042db9-45ae-4cad-ad13-0a2eff0f6236"
TEST_HOST = "srv2172236.hstgr.cloud"
R2_ENDPOINT = "https://52eb657a0814d7799bf3eb3e735109ad.r2.cloudflarestorage.com"

ENVIRONMENTS = {
    "production": {"project": "lnclass", "branch": "main", "railway": "2169ce6a-54a4-4150-9d12-bdb6cb98f54c"},
    "staging": {"project": "lnclass-staging", "branch": "Staging", "railway": "5b9f0f3c-63d5-4633-b911-df9478759a05",
                "alias": "staging-app", "sites": ["staging.lnclass.com", "app-staging.lnclass.com"]},
    "develop": {"project": "lnclass-develop", "branch": "Develop", "railway": "cda56ffe-3773-4614-a1ea-01b021734b9b",
                "alias": "develop-app", "sites": ["develop.lnclass.com", "app-develop.lnclass.com"]},
}
ENV_PROD = ENVIRONMENTS["production"]["railway"]
COPIED = ["RAILS_MASTER_KEY", "MASTER_KEY", "ANDROID_CERT_FINGERPRINTS", "ANDROID_PACKAGE_NAME",
          "ANDROID_TEACHER_PACKAGE_NAME", "CANONICAL_HOST", "APP_HOSTS", "TEAM_BOOTSTRAP_CONTACT",
          "CLAUDE_AGENTAI_CONTACT", "CLAUDE_AGENTAI_SECRET", "RAILWAY_ENVIRONMENT_NAME"]
# Secrets the owner keeps in the Claude Code environment (2026-11-17), so that Railway can go.
SESSION_SECRETS = {"RAILS_MASTER_KEY": "LNCLASS_RAILS_MASTER_KEY", "MASTER_KEY": "LNCLASS_RAILS_MASTER_KEY",
                   "CLAUDE_AGENTAI_SECRET": "LNCLASS_CLAUDE_AGENTAI_SECRET"}
R2_SECRETS = {"BUCKET_ACCESS_KEY_ID": "LNCLASS_R2_ACCESS_KEY_ID", "BUCKET_SECRET_ACCESS_KEY": "LNCLASS_R2_SECRET_ACCESS_KEY"}


def railway_vars(service_id=None, environment_id=ENV_PROD):
    if not os.environ.get("RAILWAY_API_TOKEN"):
        sys.exit("Railway n'est plus joignable (RAILWAY_API_TOKEN absent) et la variable cherchée n'est ni dans la "
                 "session ni sur le VPS")
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


def hostinger(path, payload=None, method="GET", missing_ok=False):
    data = json.dumps(payload).encode() if payload is not None else None
    headers = {"content-type": "application/json", "User-Agent": "curl/8.5.0"}
    # In a Claude Code session the proxy adds the token; in GitHub Actions it is the secret of the Environment.
    if os.environ.get("HOSTINGER_API_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["HOSTINGER_API_TOKEN"]
    req = urllib.request.Request(API + path, data, headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as error:
        if missing_ok and error.code == 404:
            return None
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


def unquote(value):
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1]
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return re.sub(r'\\(["\\])', r"\1", value[1:-1])
    return value


# The .env a project has on the VPS, or None when the project is not there.
def vps_env(project):
    found = hostinger(f"/docker/{project}", missing_ok=True)
    # An absent project answers 200 with an empty compose file and no environment.
    if found is None or (isinstance(found, dict) and not found.get("content") and found.get("environment") is None):
        return None
    if not isinstance(found, dict) or not isinstance(found.get("environment"), str):
        sys.exit(f"Hostinger : .env du projet {project} illisible, rien envoyé")
    pairs = (line.split("=", 1) for line in found["environment"].splitlines() if "=" in line)
    return {key.strip(): unquote(value.strip()) for key, value in pairs}


def overlay_session_secrets(env, names):
    for name, variable in names.items():
        if os.environ.get(variable):
            env[name] = os.environ[variable]


# Only a full commit already on the environment's branch: a branch name would reuse a stale image tag.
def checked_revision(sha, branch):
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        sys.exit(f"révision : le SHA complet (40 caractères) d'un commit de {branch} est attendu")
    subprocess.run(["git", "fetch", "-q", "origin", branch], check=True)
    if subprocess.run(["git", "merge-base", "--is-ancestor", sha, "FETCH_HEAD"]).returncode != 0:
        sys.exit(f"révision absente de origin/{branch} : rien envoyé")
    return sha


def main():
    if sys.argv[1] == "bascule":
        return bascule(sys.argv[2], sys.argv[3])
    if sys.argv[1] == "construction":
        return construction(sys.argv[2], sys.argv[3])
    if sys.argv[1] == "test":
        return deploy_test(sys.argv[2], sys.argv[3], sys.argv[4])
    return deploy_production(sys.argv[1], sys.argv[2])


def construction(compose_path, sha):
    branches = [e["branch"] for e in ENVIRONMENTS.values()]
    on_branch = lambda b: (subprocess.run(["git", "fetch", "-q", "origin", b]).returncode == 0 and
                           subprocess.run(["git", "merge-base", "--is-ancestor", sha, "FETCH_HEAD"]).returncode == 0)
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or not any(on_branch(b) for b in branches):
        sys.exit(f"révision : SHA complet d'un commit de {', '.join(branches)} attendu")
    token = os.environ.get("GH_DEPLOY_TOKEN") or railway_vars()["GH_DEPLOY_TOKEN"]
    env = {"APP_REVISION": sha, "GH_DEPLOY_TOKEN": token}
    if "--dry-run" in sys.argv:
        return print("variables:", ", ".join(sorted(env)))
    run_once("lnclass-construction", compose_path, env, "CONSTRUCTION OK", "CONSTRUCTION ECHEC", 3600)


def deploy_production(compose_path, sha):
    revision = checked_revision(sha, "main")
    env = vps_env("lnclass")
    if env is None:
        app, shared = railway_vars(APP_SERVICE), railway_vars()
        env = {name: app[name] for name in COPIED if app.get(name)}
        env.update({"BUCKET_ACCESS_KEY_ID": shared["CIBLE_BUCKET_ACCESS_KEY_ID"],
                    "BUCKET_SECRET_ACCESS_KEY": shared["CIBLE_BUCKET_SECRET_ACCESS_KEY"]})
    overlay_session_secrets(env, {**SESSION_SECRETS, **R2_SECRETS})
    env.update({"BUCKET_ENDPOINT": R2_ENDPOINT, "BUCKET_NAME": "lnclass-production", "BUCKET_REGION": "auto",
                "APP_REVISION": revision})
    env["APP_REPLICAS"] = os.environ.get("APP_REPLICAS") or env.get("APP_REPLICAS") or "1"
    env["SITE_ADDRESSES"] = os.environ.get("SITE_ADDRESSES") or env.get("SITE_ADDRESSES") or "lnclass.com, www.lnclass.com"
    sites = [h.strip() for h in env["SITE_ADDRESSES"].split(",") if h.strip()]
    # The server's own name is only allowed while a test serves it (it is behind the Cloudflare-only firewall).
    hosts = [h for h in env.get("APP_HOSTS", "").split(",") if h and h != TEST_HOST]
    env["APP_HOSTS"] = ",".join(hosts + ([TEST_HOST] if TEST_HOST in sites else []))
    check_and_send("lnclass", compose_path, env, sites)


def deploy_test(compose_path, name, sha):
    if name not in ("staging", "develop"):
        sys.exit(f"environnement inconnu : {name} (staging ou develop)")
    spec = ENVIRONMENTS[name]
    revision = checked_revision(sha, spec["branch"])
    env = vps_env(spec["project"])
    if env is None:
        # Created from Railway, with a new base (db:seed fills the standard set); the Railway bucket stays in the .env
        # for images older than ACTIVE_STORAGE_SERVICE.
        app = railway_vars(APP_SERVICE, spec["railway"])
        env = {key: app[key] for key in COPIED + list(R2_SECRETS) + ["BUCKET_NAME", "BUCKET_ENDPOINT", "BUCKET_REGION"]
               if app.get(key)}
    overlay_session_secrets(env, {k: v for k, v in SESSION_SECRETS.items() if k != "CLAUDE_AGENTAI_SECRET"})
    env.update({"APP_REVISION": revision, "WEB_ALIAS": spec["alias"]})
    check_and_send(spec["project"], compose_path, env, spec["sites"])


def check_and_send(project, compose_path, env, sites):
    print(f"{project} — variables:", ", ".join(sorted(env)))
    if "RAILS_MASTER_KEY" not in env and "MASTER_KEY" not in env:
        sys.exit("ni RAILS_MASTER_KEY ni MASTER_KEY : l'application ne démarrerait pas")
    uncovered = [h for h in sites if h not in env.get("APP_HOSTS", "").split(",")]
    if uncovered:
        sys.exit(f"hôtes servis par Caddy absents d'APP_HOSTS (Rails les refuserait) : {uncovered}")
    if "--dry-run" not in sys.argv:
        send(project, compose_path, env)


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
    content = open(compose_path).read()
    # Hostinger refuses a compose file over 8192 characters with a bare 422: say which file and by how much.
    if len(content) > 8192:
        sys.exit(f"{compose_path}: {len(content)} caractères, Hostinger en accepte 8192 au plus")
    result = hostinger("/docker", {"project_name": project, "content": content,
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
    # Another environment's build holds the same project name: wait for it to be gone, 20 min at most.
    waited = 0
    while vps_env(project) is not None:
        if waited >= 1200:
            sys.exit(f"{project} toujours sur le VPS après 20 min : un autre déploiement construit, ou un projet "
                     f"orphelin à supprimer (script/hostinger/journaux.py {project})")
        print(f"{project} déjà sur le VPS : attente ({waited // 60} min)")
        time.sleep(20)
        waited += 20
    send(project, compose_path, env)
    deadline, outcome, lines = time.time() + timeout, None, []
    # The verdict must name this revision: two deployments of other branches may start in the same 20 s.
    revision = env.get("APP_REVISION", "")
    while outcome is None and time.time() < deadline:
        time.sleep(20)
        current = vps_env(project) or {}
        if current.get("APP_REVISION", "") != revision:
            # Another deployment replaced this project: it is its build now, left running.
            sys.exit(f"{project} remplacé sur le VPS par un autre déploiement : rien supprimé, relancer ce run")
        lines = [e.get("line", "") for s in hostinger(f"/docker/{project}/logs") for e in s.get("entries", [])]
        outcome = (failed if any(failed in l for l in lines) else
                   ok if any(ok in l and revision in l for l in lines) else None)
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
