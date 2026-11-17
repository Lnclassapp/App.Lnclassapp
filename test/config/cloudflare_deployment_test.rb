require "test_helper"

# Chantier hebergement-cloudflare: production runs on Cloudflare Containers behind cloudflare/worker.js. The container
# prepares the database itself (PREPARE_DATABASE=1), with the command Railway runs before each deploy.
class CloudflareDeploymentTest < ActiveSupport::TestCase
  WRANGLER = Rails.root.join("wrangler.jsonc")
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint")
  WORKER = Rails.root.join("cloudflare/worker.js")

  test "wrangler.jsonc builds the Rails Dockerfile and binds no domain until the cutover" do
    config = WRANGLER.read

    assert_includes config, '"name": "app-lnclassapp"'
    assert_includes config, '"main": "cloudflare/worker.js"'
    assert_includes config, '"dockerfile": "./Dockerfile"'
    assert_includes config, '"crons": ["*/5 * * * *"]'
    assert_no_match(/"routes"|custom_domain|lnclass\.com"/, config)
  end

  test "the entrypoint prepares the database like Railway's pre-deploy command, only when the Worker asks" do
    railway_pre_deploy = Rails.root.join(".railway/railway.ts").read[/preDeploy: "([^"]+)"/, 1]
    entrypoint = ENTRYPOINT.read

    assert_includes entrypoint, %(if [ "${PREPARE_DATABASE}" == "1" ]; then\n  ./#{railway_pre_deploy}\nfi)
    assert_includes WORKER.read, 'env.PREPARE_DATABASE = "1"'
  end

  test "the Worker forwards to the port Thruster listens on and keeps the public host" do
    worker = WORKER.read

    assert_includes worker, "const PORT = 8080;"
    assert_includes worker, "env.PORT = String(PORT);"
    assert_no_match(/headers\.delete\("host"\)/, worker)
  end
end
