# Mesure réseau (chantier politique-cache) : ce que coûte un aller-retour jusqu'à l'application sur Railway, comparé
# à une réponse servie par le cache de Cloudflare, vu depuis la machine qui lance le script. Sans compte ni
# connexion : seules des pages publiques et la feuille de style sont demandées. Ruby seul, sans Rails.
#
#   ruby script/perf/measure_network.rb                       # https://lnclass.com par défaut
#   ruby script/perf/measure_network.rb https://app-develop.lnclass.com
#
# Par cible : 3 requêtes de chauffe, puis PERF_RUNS (30 par défaut) requêtes mesurées sur une connexion gardée
# ouverte, comme une navigation Turbo. « Connexion neuve » ouvre une connexion par requête (DNS, TCP, TLS), comme une
# première visite ; derrière un proxy d'entreprise, cette ligne mesure surtout le proxy. Le script se lance 3 fois et
# on retient la médiane des 3. Il écrit tmp/perf-network.json.
require "json"
require "time"
require "net/http"
require "uri"

module PerfNetwork
  RUNS = Integer(ENV.fetch("PERF_RUNS", 30))
  FRESH_RUNS = 10
  WARMUP = 3
  ORIGIN_PATHS = %w[/up /login /].freeze

  module_function

  def percentile(values, rank)
    sorted = values.sort
    sorted[((sorted.size - 1) * rank).round]
  end

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Le nom de la feuille de style change à chaque déploiement : on le lit dans la page de connexion.
  def stylesheet_path(http)
    http.get("/login").body[%r{href="(/assets/application-[0-9a-f]+\.css)"}, 1] or abort "feuille de style introuvable dans /login"
  end

  def sample(http, path)
    started = clock
    response = http.get(path)
    { ms: (clock - started) * 1000, server: response["x-runtime"].to_f * 1000, status: response.code.to_i,
      cache: response["cf-cache-status"], pop: response["cf-ray"].to_s.split("-").last, edge: response["x-railway-edge"] }
  end

  def summarize(name, path, samples)
    times = samples.map { it[:ms] }
    server = percentile(samples.map { it[:server] }, 0.5)
    last = samples.last
    { name:, path:, status: last[:status], cache: last[:cache], pop: last[:pop], edge: last[:edge],
      p50: percentile(times, 0.5).round(1), p95: percentile(times, 0.95).round(1), server: server.round(1),
      network: (percentile(times, 0.5) - server).round(1) }
  end

  def measure_kept_alive(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      targets = ORIGIN_PATHS.map { [ "origine", it ] } << [ "cache Cloudflare", stylesheet_path(http) ]
      targets.map do |name, path|
        WARMUP.times { sample(http, path) }
        summarize(name, path, Array.new(RUNS) { sample(http, path) })
      end
    end
  end

  def measure_fresh(uri)
    samples = Array.new(FRESH_RUNS) do
      started = clock
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| sample(http, "/login") }.merge(ms: (clock - started) * 1000)
    end
    summarize("connexion neuve", "/login", samples)
  end

  def print_table(uri, results)
    puts "Cible : #{uri} · #{RUNS} requêtes par ligne (#{FRESH_RUNS} en connexion neuve) · #{Time.now.utc.iso8601}"
    puts
    puts "| Servie par | Chemin | HTTP | cf-cache-status | PoP Cloudflare | Edge Railway | p50 ms | p95 ms | Serveur p50 ms | Hors serveur p50 ms |"
    puts "|---|---|--:|---|---|---|--:|--:|--:|--:|"
    results.each do |row|
      puts "| #{row.values_at(:name, :path, :status, :cache, :pop, :edge, :p50, :p95, :server, :network).join(' | ')} |"
    end
    origin = results.select { it[:name] == "origine" }.map { it[:network] }
    edge = results.find { it[:name] == "cache Cloudflare" }[:network]
    puts
    puts "Aller-retour jusqu'à l'origine, hors serveur (médiane des pages) : #{percentile(origin, 0.5).round} ms"
    puts "Aller-retour jusqu'au cache Cloudflare : #{edge.round} ms"
    puts "Surcoût de chaque requête qui va jusqu'à l'origine : #{(percentile(origin, 0.5) - edge).round} ms"
  end

  def run(base)
    uri = URI(base)
    results = measure_kept_alive(uri) << measure_fresh(uri)
    print_table(uri, results)
    Dir.mkdir("tmp") unless Dir.exist?("tmp")
    File.write("tmp/perf-network.json", JSON.pretty_generate(target: base, measured_at: Time.now.utc.iso8601, results:))
  end
end

PerfNetwork.run(ARGV.first || "https://lnclass.com")
