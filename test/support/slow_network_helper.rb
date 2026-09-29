# Chantier tests-instables: a loaded run (the full system suite, 2 vCPU in CI) makes every answer of the server late.
# A test that proves it waits for the right thing replays its step here, where every request of the browser waits
# SLOW_NETWORK_LATENCY ms more; what the browser draws without asking the server (Turbo's cache) stays immediate.
module SlowNetworkHelper
  ActionDispatch::SystemTestCase.include(self)

  SLOW_NETWORK_LATENCY = 1000

  # Latency back to 0 afterwards: chromedriver's own reset (delete_network_conditions) breaks the next visit.
  def on_a_slow_network
    browser = page.driver.browser
    browser.network_conditions = { offline: false, latency: SLOW_NETWORK_LATENCY, throughput: -1 }
    yield
  ensure
    browser.network_conditions = { offline: false, latency: 0, throughput: -1 }
  end
end
