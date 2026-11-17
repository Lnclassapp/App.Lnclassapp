// Chantier hebergement-cloudflare: the Worker in front of the Rails container (wrangler.jsonc).
// One instance only, named "production", placed in western Europe near the database: Solid Queue, Solid Cache and
// Solid Cable live in Postgres, so a second instance would work, but one is what Railway ran and what the bill assumes.
import { DurableObject } from "cloudflare:workers";

const PORT = 8080;
const INSTANCE_NAME = "production";
const LOCATION_HINT = "weur";
// 1/4 vCPU and 1.5 GiB: Railway measured 0.63 GB on average and 1.13 GB at peak over 7 days (2026-11-17).
const INSTANCE = { vcpu: 0.25, memoryMib: 1536, diskMb: 6000 };
// The cron of wrangler.jsonc pings every 5 minutes, so the container never reaches this timeout and stays up.
const INACTIVITY_TIMEOUT_MS = 30 * 60 * 1000;
// db:prepare (migrations) then the boot of Rails run before /up answers: allow 3 minutes.
const READINESS_DEADLINE_MS = 3 * 60 * 1000;

export class RailsApp extends DurableObject {
  starting;
  monitoring;

  constructor(ctx, env) {
    super(ctx, env);
    const container = ctx.container;
    if (container?.running) {
      // A restarted Durable Object (after a deploy) starts without a timeout: set it again.
      void ctx.blockConcurrencyWhile(() => container.setInactivityTimeout(INACTIVITY_TIMEOUT_MS));
      this.observeExit();
    }
  }

  async fetch(request) {
    // Concurrent requests share one startup; a failed one is retried by the next request.
    this.starting ??= this.startAndWaitForPort().finally(() => {
      this.starting = undefined;
    });
    try {
      await this.starting;
    } catch (error) {
      console.error("Rails is not ready:", error);
      return new Response("Service indisponible", { status: 503, headers: { "Retry-After": "30" } });
    }

    // Keep the public host: Rails checks it against APP_HOSTS (config.hosts). Cloudflare terminated TLS.
    const url = new URL(request.url);
    url.protocol = "http:";
    const forwarded = new Request(url, request);
    forwarded.headers.set("X-Forwarded-Proto", "https");
    const clientIp = request.headers.get("CF-Connecting-IP");
    if (clientIp) forwarded.headers.set("X-Forwarded-For", clientIp);
    return this.ctx.container.getTcpPort(PORT).fetch(forwarded);
  }

  async startAndWaitForPort() {
    const container = this.ctx.container;
    if (!container.running) {
      container.start({
        image: container.images.rails,
        instance: INSTANCE,
        enableInternet: true, // Postgres, R2, OpenRouter
        env: this.containerEnv(),
      });
    }
    this.observeExit();
    await container.setInactivityTimeout(INACTIVITY_TIMEOUT_MS);

    // /up is excluded from the host check and the HTTPS redirect (config/environments/production.rb).
    const port = container.getTcpPort(PORT);
    const deadline = Date.now() + READINESS_DEADLINE_MS;
    let lastError;
    while (Date.now() < deadline) {
      // bin/docker-entrypoint exits when db:prepare or db:seed fails: say so now, not after the deadline.
      if (!container.running) {
        throw new Error("Rails container exited during startup (db:prepare or db:seed?)", { cause: lastError });
      }
      try {
        const response = await port.fetch("http://localhost/up", { signal: AbortSignal.timeout(2000) });
        await response.body?.cancel();
        if (response.ok) return;
        lastError = new Error(`/up returned ${response.status}`);
      } catch (error) {
        lastError = error;
      }
      await scheduler.wait(500);
    }
    // A running but stuck Rails would never reach the inactivity timeout (the cron keeps it busy): replace it.
    await container.destroy();
    throw new Error(`Rails did not answer /up on port ${PORT}`, { cause: lastError });
  }

  // Every text variable and secret of the Worker goes to Rails, plus what this deployment fixes.
  containerEnv() {
    const env = {};
    for (const [name, value] of Object.entries(this.env)) {
      if (typeof value === "string") env[name] = value;
    }
    env.PORT = String(PORT); // Thruster listens on PORT (Dockerfile CMD)
    env.PREPARE_DATABASE = "1"; // bin/docker-entrypoint: db:prepare db:seed, Railway's preDeploy
    return env;
  }

  observeExit() {
    if (this.monitoring) return;
    this.monitoring = this.ctx.container
      .monitor()
      .then(() => console.log("Rails container exited"))
      .catch((error) => console.error("Rails container failed:", error))
      .finally(() => {
        this.monitoring = undefined;
      });
    this.ctx.waitUntil(this.monitoring);
  }
}

function railsApp(env) {
  const id = env.RAILS_APP.idFromName(INSTANCE_NAME);
  return env.RAILS_APP.get(id, { locationHint: LOCATION_HINT });
}

export default {
  fetch(request, env) {
    // Rails trusts X-Forwarded-Proto: https (assume_ssl), so force_ssl never sees plain HTTP: redirect it here, as
    // Railway's edge did, before a sign-in form is served in clear.
    const url = new URL(request.url);
    if (url.protocol === "http:") {
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }
    return railsApp(env).fetch(request);
  },

  // Keeps the container awake so that Solid Queue runs the recurring jobs (config/recurring.yml).
  // A failed ping fails the cron run, so the dashboard shows it.
  async scheduled(_event, env) {
    const response = await railsApp(env).fetch(new Request("https://localhost/up"));
    await response.body?.cancel();
    if (!response.ok) {
      console.error(`Keep-alive: /up returned ${response.status}`);
      throw new Error(`Keep-alive: /up returned ${response.status}`);
    }
  },
};
