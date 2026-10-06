#!/bin/bash
# SessionStart hook — Claude Code on the web only (docs/chantiers/ci-cloud-claude/memo.md).
# Gives a fresh cloud session what `bin/ci` needs, like a developer's machine: the Ruby and Node of the
# repository, a running PostgreSQL with the role of config/database.yml, a chromedriver that matches the
# preinstalled Chromium, then `bin/setup` (bundle, yarn, database). Idempotent: every step skips what is there.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"
ENV_FILE="${CLAUDE_ENV_FILE:-/dev/null}"
log() { echo "[session-start] $*" >&2; }

# The proxy's no_proxy list is long; the tools below only need loopback to bypass it.
export no_proxy="localhost,127.0.0.1,::1" NO_PROXY="localhost,127.0.0.1,::1"
# No locale in a fresh session: Ruby would read the sources as US-ASCII (the guards fail). UTF-8, like GitHub.
export LANG=C.UTF-8 LC_ALL=C.UTF-8

# --- Ruby (.ruby-version), built once by rbenv: the container keeps it after the hook ---------------------
RUBY_VERSION_WANTED="$(cat .ruby-version)"
export RBENV_ROOT=/opt/rbenv
export PATH="$RBENV_ROOT/shims:$RBENV_ROOT/bin:$PATH"
if ! rbenv versions --bare | grep -qx "$RUBY_VERSION_WANTED"; then
  log "building Ruby $RUBY_VERSION_WANTED (once, a few minutes)"
  git -C "$RBENV_ROOT/plugins/ruby-build" pull --quiet || true
  MAKE_OPTS="-j$(nproc)" rbenv install --skip-existing "$RUBY_VERSION_WANTED"
fi
export RBENV_VERSION="$RUBY_VERSION_WANTED"

# --- Node (.node-version) with Yarn through corepack -------------------------------------------------------
NODE_VERSION_WANTED="$(cat .node-version)"
NODE_DIR="/opt/node-$NODE_VERSION_WANTED"
if [ ! -x "$NODE_DIR/bin/node" ]; then
  log "installing Node $NODE_VERSION_WANTED"
  mkdir -p "$NODE_DIR"
  curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION_WANTED/node-v$NODE_VERSION_WANTED-linux-x64.tar.xz" |
    tar -xJ -C "$NODE_DIR" --strip-components=1
fi
export PATH="$NODE_DIR/bin:$PATH"
corepack enable

# --- Chrome for the system tests: the preinstalled Chromium and the chromedriver of the same version ------
CHROME_BIN="$(ls -d /opt/pw-browsers/chromium-*/chrome-linux/chrome 2>/dev/null | sort -V | tail -1)"
if [ -n "$CHROME_BIN" ]; then
  CHROME_VERSION="$("$CHROME_BIN" --version | grep -oE '[0-9]+(\.[0-9]+){3}')"
  CHROMEDRIVER_PATH="/opt/chromedriver-$CHROME_VERSION/chromedriver"
  if [ ! -x "$CHROMEDRIVER_PATH" ]; then
    log "installing chromedriver $CHROME_VERSION"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/driver.zip" \
      "https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chromedriver-linux64.zip"
    mkdir -p "$(dirname "$CHROMEDRIVER_PATH")"
    unzip -q -j -o "$tmp/driver.zip" -d "$(dirname "$CHROMEDRIVER_PATH")"
    rm -rf "$tmp"
  fi
  export CHROME_BIN CHROMEDRIVER_PATH
else
  log "no Chromium under /opt/pw-browsers: bin/check-chrome will say so"
fi

# --- PostgreSQL: start the local cluster, create the role of config/database.yml --------------------------
PG_CLUSTER="$(pg_lsclusters --no-header | awk 'NR==1 { print $1 " " $2 }')"
if [ -n "$PG_CLUSTER" ]; then
  # shellcheck disable=SC2086
  pg_ctlcluster $PG_CLUSTER start 2>/dev/null || true
  for _ in $(seq 1 30); do pg_isready -q -h localhost && break; sleep 1; done
  su postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname = 'dev-rails'\"" | grep -q 1 ||
    su postgres -c "psql -qc \"CREATE ROLE \\\"dev-rails\\\" LOGIN SUPERUSER PASSWORD 'dev-rails'\""
fi

# --- What the session's shell needs, then the repository's own setup --------------------------------------
# Also kept in ~/.lnclass-ci-env: script/ci/cloud-check sources it when the hook ran by hand (a routine's session).
{
  echo "export RBENV_ROOT=$RBENV_ROOT"
  echo "export RBENV_VERSION=$RUBY_VERSION_WANTED"
  echo "export PATH=\"$NODE_DIR/bin:$RBENV_ROOT/shims:$RBENV_ROOT/bin:\$PATH\""
  echo "export no_proxy=localhost,127.0.0.1,::1 NO_PROXY=localhost,127.0.0.1,::1"
  echo "export LANG=C.UTF-8 LC_ALL=C.UTF-8"
  if [ -n "${CHROME_BIN:-}" ]; then echo "export CHROME_BIN=$CHROME_BIN CHROMEDRIVER_PATH=$CHROMEDRIVER_PATH"; fi
} > "$HOME/.lnclass-ci-env"
cat "$HOME/.lnclass-ci-env" >> "$ENV_FILE"

# db:prepare dumps db/schema.rb again, and PostgreSQL 16 writes some constraints differently from the 17 of the
# developers: an untouched schema is put back, so the session starts on a clean worktree (script/ci/cloud-check).
schema_clean=false
git diff --quiet -- db/schema.rb && schema_clean=true
log "bin/setup --skip-server"
bin/setup --skip-server >&2
if [ "$schema_clean" = true ]; then git checkout --quiet -- db/schema.rb; fi
log "ready: $(ruby -v | cut -d' ' -f1-2), node $(node -v), $(pg_isready -h localhost)"
