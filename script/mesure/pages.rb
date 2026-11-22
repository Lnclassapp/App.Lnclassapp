# Mesure des pages par rôle en production locale (chantier pages-sous-600ms) : temps serveur p50/p95, requêtes SQL,
# allocations et poids de chaque page de l'élève, de l'enseignant et de la direction du grand établissement du jeu
# standard. Lancé par script/mesure/pages (qui pose l'environnement de production locale et refuse une base distante).
#
# Par page : MESURE_CHAUFFE (2) visites de chauffe, puis MESURE_PASSES (20) visites mesurées par la pile Rack complète
# (Integration::Session, sans réseau ni navigateur). Comptes et pages : ceux de script/pages_lentes.rb, plus l'entrée
# élève (/student), la vue d'une matière (/courses?material=) et l'accueil public. Écrit tmp/mesure-pages.json, que
# script/mesure/pages_navigateur.cjs relit pour mesurer les mêmes pages dans Chromium à 390 px.
require "json"
require "zlib"
require Rails.root.join("script/pages_lentes")

module MesurePages
  PIN = "2468".freeze
  IGNORED = %w[SCHEMA TRANSACTION].freeze

  module_function

  def percentile(values, rank)
    sorted = values.sort
    sorted[((sorted.size - 1) * rank).round]
  end

  def fingerprint(sql)
    sql.gsub(/'(?:[^']|'')*'/, "?").gsub(/\$\d+/, "?").gsub(/\b\d+\b/, "?").gsub(/\(\?(?:, ?\?)*\)/, "(?)").squish
  end

  class Runner < PagesLentes::Runner
    attr_reader :rows, :accounts

    def initialize(school:, roles:, runs:, warmup:)
      super(school:, roles:, warmup:)
      @runs = runs
      @rows = []
      @accounts = {}
    end

    def call
      visitor = anonymous
      [ [ "accueil public", "/" ], [ "entrée élève", "/student" ], [ "connexion", "/login" ] ].each { |page, path| sample("visiteur", visitor, page, path, {}) }
      @roles.each_with_index do |role, index|
        user = account(role)
        next @notes << "#{role} : aucun compte dans cet établissement, rôle ignoré" if user.nil?

        session = sign_in(user, index)
        next @notes << "#{role} : connexion refusée, rôle ignoré" if session.nil?

        @accounts[role] = user.contact
        pages(role, user).each { |page, path, headers| sample(role, session, page, path, headers || {}) }
      end
      self
    end

    private

    def anonymous
      ActionDispatch::Integration::Session.new(Rails.application).tap do |session|
        session.host! "localhost"
        session.https!
      end
    end

    def sign_in(user, index)
      session = anonymous
      session.remote_addr = "10.9.1.#{index + 1}"
      session.post "/session", params: { session: { contact: user.contact, pin: PIN } }
      session.response.redirect? ? session : nil
    end

    # La vue d'une matière (/courses?material=) en plus des pages de script/pages_lentes.rb.
    def eleve_pages(user)
      pages = super
      material = Orm::Material.joins(:courses).merge(Orm::Course.where(status: "published")).order(:id).pick(:slug)
      pages.insert(7, [ "matière", "/courses?material=#{material}" ]) if material
      pages
    end

    def sample(role, session, page, path, headers)
      @warmup.times { measure(session, path, headers) }
      samples = Array.new(@runs) { measure(session, path, headers) }
      times = samples.map { it[:ms] }
      last = samples.last
      repeated = last[:queries].map { MesurePages.fingerprint(it) }.tally.max_by(&:last)
      @rows << { role:, page:, path:, headers:, status: last[:status],
                 p50: MesurePages.percentile(times, 0.5).round(1), p95: MesurePages.percentile(times, 0.95).round(1),
                 sql: last[:queries].size, allocations: MesurePages.percentile(samples.map { it[:allocations] }, 0.5),
                 kb: (last[:bytes] / 1024.0).round(1), kb_gzip: (last[:gzip] / 1024.0).round(1),
                 repeated: repeated ? repeated.last : 0, repeated_sql: repeated&.first.to_s.first(200) }
    end

    def measure(session, path, headers)
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        queries << payload[:sql] unless IGNORED.include?(payload[:name]) || payload[:cached]
      end
      allocated = GC.stat(:total_allocated_objects)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      session.get(path, headers:)
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      body = session.response.body
      { ms: elapsed, allocations: GC.stat(:total_allocated_objects) - allocated, queries:, status: session.response.status,
        bytes: body.bytesize, gzip: Zlib.gzip(body).bytesize }
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  def table(rows)
    lines = [ "| Rôle | Page | HTTP | p50 ms | p95 ms | SQL | Allocations | Ko | Ko gzip | Même requête × |", "|---|---|--:|--:|--:|--:|--:|--:|--:|--:|" ]
    rows.each do |row|
      lines << "| #{row.values_at(:role, :page, :status, :p50, :p95, :sql, :allocations, :kb, :kb_gzip, :repeated).join(' | ')} |"
    end
    lines.join("\n")
  end

  def run
    names = YAML.load_file(Rails.root.join("db/seeds/standard/noms.yml"))
    name = ENV["MESURE_ECOLE"].presence || Entities::School::FictitiousIdentity.new(names).school_name("grand")
    school = Orm::School.find_by(name:) or abort("[mesure-pages] établissement introuvable : #{name.inspect} (bin/jeu-standard d'abord).")
    roles = ENV["MESURE_ROLE"].presence&.split(",") || %w[eleve enseignant direction]
    ActiveRecord::Base.connection.execute("ANALYZE")
    # La connexion se fait sans lire de formulaire : la protection CSRF ne mesure rien ici.
    ActionController::Base.allow_forgery_protection = false
    runner = Runner.new(school:, roles:, runs: Integer(ENV.fetch("MESURE_PASSES", "20")), warmup: Integer(ENV.fetch("MESURE_CHAUFFE", "2"))).call
    puts "#{school.name} (#{Orm::Classroom.where(school_id: school.id).count} classes) — RAILS_ENV=#{Rails.env}, cache #{Rails.cache.class.name.demodulize}, " \
         "#{ENV.fetch('MESURE_PASSES', '20')} passes par page après chauffe, temps serveur sans réseau."
    puts table(runner.rows)
    runner.notes.each { puts it }
    runner.rows.select { it[:repeated] > 2 }.each { puts "\n#{it[:role]} · #{it[:page]} : ×#{it[:repeated]} #{it[:repeated_sql]}" }
    File.write(Rails.root.join("tmp/mesure-pages.json"), JSON.pretty_generate(accounts: runner.accounts, pin: PIN, rows: runner.rows))
    # exit! : un SystemExit levé dans l'exécuteur de `rails runner` produit une trace parasite.
    $stdout.flush
    exit!(1) if runner.notes.any? || runner.rows.any? { it[:status] != 200 }
  end
end

MesurePages.run
