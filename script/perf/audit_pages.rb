# Audit de toutes les pages (chantier politique-cache, lot E) : chaque page GET qu'un profil peut atteindre est visitée
# comme un clic Turbo, puis comparée à la politique de cache (ADR-0076) et aux budgets d'écran (ADR-0067).
#
# Exploration : pour chaque profil (visiteur, élève, enseignant, direction, équipe), on part de toutes les routes GET sans
# paramètre et on suit les liens, les frames à source et les formulaires GET de chaque page. On garde au plus une adresse
# par forme (route, frame visé et noms des paramètres) et PERF_PER_ROUTE adresses par route. Un lien qui change l'état
# (data-turbo-method autre que get) n'est jamais suivi. Les fichiers (photo, image, audio) sont relevés sans être lus :
# le bucket est factice.
#
# Relevé par page :
# - statut et Cache-Control ;
# - requêtes en série d'un clic : redirections, rechargement forcé et frames à source ;
# - liens de la page qui mènent à une redirection ;
# - requêtes SQL et forme la plus répétée dans un rendu (soupçon de N+1) ;
# - temps serveur p50 et p95 sur PERF_RUNS visites après chauffe ;
# - poids du HTML brut.
#
# En mode production sur la base du jeu de mesure (script/perf/seed_dataset.rb), comme measure_screens.rb :
#
#   RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=warn \
#   BUCKET_NAME=bench BUCKET_ENDPOINT=http://127.0.0.1:9 BUCKET_ACCESS_KEY_ID=x BUCKET_SECRET_ACCESS_KEY=x \
#   DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5432/app_lnclassapp_development<suffixe> \
#   bin/rails runner script/perf/audit_pages.rb
#
# PERF_ONLY=team,admin limite aux profils nommés. Écrit tmp/perf-audit.json.
require "json"
require "securerandom"

module PerfAudit
  RUNS = Integer(ENV.fetch("PERF_RUNS", 15))
  WARMUP = 2
  PER_ROUTE = Integer(ENV.fetch("PERF_PER_ROUTE", 3))
  PIN = "2468".freeze
  ACTORS = { visitor: nil, student: "0120000001", teacher: "0520000001", admin: "0720000001", team: "0700000000" }.freeze
  TURBO_VISIT = "text/html, application/xhtml+xml".freeze
  IGNORED_SQL = %w[SCHEMA TRANSACTION].freeze
  # ADR-0067 : le pilotage a 300 ms, tout autre écran 100 ms ; 150 Ko de HTML brut pour tous.
  BUDGET_MS = Hash.new(100).merge("teams/dashboards#show" => 300).freeze
  BUDGET_KB = 150
  # ADR-0076 §4.2 : seuls les accueils élève et équipe différent une partie de la page (UDR-0010, UDR-0018).
  DEFERRED_ALLOWED = %w[classroom/student_homes#show teams/homes#show].freeze
  # Servis depuis le bucket : relevés, pas lus.
  FILES = %w[identity/account_photos#show communication/message_files#show communication/article_images#show].freeze
  NOT_PAGES = %w[rails/health#show communication/sitemaps#show communication/sitemaps#robots turbo/native/navigation#recede
                 turbo/native/navigation#refresh turbo/native/navigation#resume].freeze
  REPEATED = 3

  module_function

  def percentile(values, rank)
    sorted = values.sort
    sorted[((sorted.size - 1) * rank).round]
  end

  def fingerprint(sql)
    sql.gsub(/'(?:[^']|'')*'/, "?").gsub(/\$\d+/, "?").gsub(/\b\d+\b/, "?").gsub(/\(\?(?:, ?\?)*\)/, "(?)").squish
  end

  def new_session
    ActionDispatch::Integration::Session.new(Rails.application).tap do |session|
      session.host = "localhost"
      session.https!
      # La connexion est limitée à 5 par minute et par adresse : une adresse privée tirée au hasard par profil.
      session.remote_addr = "10.#{Array.new(3) { rand(1..254) }.join('.')}"
    end
  end

  def session_for(role)
    session = new_session
    contact = ACTORS.fetch(role) or return session
    session.post("/session", params: { session: { contact:, pin: PIN } })
    raise "connexion refusée pour #{contact} (#{session.response.status})" unless session.response.redirect?

    # Le second facteur de l'équipe est validé en base : l'audit ne lit pas le secret TOTP chiffré.
    Orm::Session.where(user_id: Orm::User.where(contact:).select(:id)).update_all(second_factor_verified_at: Time.current) if role == :team
    # L'accueil consomme le rechargement de la nouvelle session (ADR-0049) : la première page explorée n'en hérite pas.
    session.get("/")
    session.get(session.response.location) if session.response.redirect?
    session
  end

  def route_of(path)
    params = Rails.application.routes.recognize_path(path.split("?").first, method: :get)
    "#{params[:controller]}##{params[:action]}"
  rescue ActionController::RoutingError
    nil
  end

  # Toutes les routes GET sans paramètre de chemin : le point de départ de chaque profil.
  def entry_points
    Rails.application.routes.routes.filter_map do |route|
      next unless route.verb.to_s.include?("GET")

      path = route.path.spec.to_s.sub("(.:format)", "")
      path unless path.include?(":") || path.include?("*") || path.start_with?("/rails/", "/cable") || route_of(path).nil?
    end.uniq.sort
  end

  # Adresses à paramètres qu'aucun lien du jeu de mesure n'atteint : tirées de la base, par profil. Une ligne absente du
  # jeu (aucun brouillon, aucun import) est sautée.
  def extra_entry_points(role)
    student = Orm::User.find_by(contact: ACTORS[:student])
    classroom = Orm::ClassroomStudent.find_by(student_id: student&.id)&.classroom
    paths = {
      visitor: -> { [ ("/c/#{classroom.join_code}" if classroom&.join_code), ("/drenas/#{Orm::Drena.order(:id).pick(:public_id)}/schools") ] },
      student: lambda {
        session = Orm::ExerciseSession.where(student_id: student&.id).where.not(status: "completed").order(:id).pick(:public_id)
        [ ("/sessions/#{session}" if session) ]
      },
      team: lambda {
        import = Orm::ImportReport.order(id: :desc).pick(:public_id)
        [ ("/teams/imports/#{import}" if import), "/teams/accounts/#{student.public_id}/deletion-request/new",
          "/teams/accounts/#{student.public_id}/deletion/new" ]
      }
    }
    Array(paths[role]&.call).compact
  rescue ActiveRecord::ActiveRecordError, NoMethodError
    []
  end

  def local_path(url)
    uri = URI.parse(url)
    return if uri.scheme && !%w[http https].include?(uri.scheme)
    return if uri.host && !%w[localhost lnclass.com www.lnclass.com].include?(uri.host)

    path = uri.path.presence or return
    return unless path.start_with?("/") && !path.start_with?("/assets/", "//")

    uri.query ? "#{path}?#{uri.query}" : path
  rescue URI::InvalidURIError
    nil
  end

  # Turbo charge un lien dans le frame que vise data-turbo-frame, sinon dans le frame qui l'entoure, sauf target="_top".
  def frame_target(link)
    explicit = link.xpath("ancestor-or-self::*[@data-turbo-frame]").last&.[]("data-turbo-frame")
    return (explicit unless %w[_top _self].include?(explicit)) if explicit

    frame = link.ancestors("turbo-frame").first
    frame["id"] if frame && frame["target"] != "_top"
  end

  # Ce que la page déclenche ou propose : liens (avec le frame visé), frames à source, formulaires GET, fichiers.
  def outgoing(document)
    links = document.css("a[href]").filter_map do |link|
      method = link["data-turbo-method"] || link["data-method"]
      next if method && method.downcase != "get"

      path = local_path(link["href"]) or next
      [ path, frame_target(link) ]
    end
    frames = document.css("turbo-frame[src]").filter_map { |frame| (path = local_path(frame["src"])) && [ path, frame["id"] ] }
    forms = document.css("form").filter_map do |form|
      next unless form["method"].to_s.downcase == "get" || form["method"].blank?
      next if form.at_css("input[name=_method]")

      (path = local_path(form["action"].to_s)) && [ path, nil ]
    end
    files = document.css("img[src], audio[src], source[src]").filter_map { local_path(it["src"]) }
    { links: links.uniq, frames: frames.uniq, forms: forms.uniq, files: files.uniq }
  end

  def shape_of(route, path, frame)
    query = Rack::Utils.parse_query(URI.parse(path).query.to_s).keys.sort
    [ route, frame, query ].to_json
  end

  def headers_for(frame)
    headers = { "Accept" => TURBO_VISIT, "X-Turbo-Request-Id" => SecureRandom.uuid }
    frame ? headers.merge("Turbo-Frame" => frame) : headers
  end

  def visit(session, path, frame)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, start, finish, _, payload|
      queries << [ payload[:sql], (finish - start) * 1000 ] unless IGNORED_SQL.include?(payload[:name]) || payload[:cached]
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    session.get(path, headers: headers_for(frame))
    { ms: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000, queries:, response: session.response }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def secret_route?(route)
    controller, action = route.split("#")
    "#{controller}_controller".camelize.constantize.try(:secret_actions).to_a.include?(action)
  rescue NameError
    false
  end

  def explore(role)
    session = session_for(role)
    queue = (entry_points + extra_entry_points(role)).map { [ it, nil, nil ] }
    seen = Set.new
    shapes = {}
    per_route = Hash.new(0)
    pages = []
    files = Hash.new { |hash, key| hash[key] = Set.new }
    while (path, frame, from = queue.shift)
      next unless seen.add?([ path, frame ])

      route = route_of(path) or next
      shape = shape_of(route, path, frame)
      (files[route] << from) and next if FILES.include?(route)
      next if shapes.key?(shape) || per_route[route] >= PER_ROUTE

      per_route[route] += 1
      first = visit(session, path, frame)
      response = first[:response]
      page = { role:, route:, path:, frame:, from:, status: response.status, cache_control: response.headers["Cache-Control"].to_s,
               content_type: response.media_type.to_s, secret: secret_route?(route) }
      shapes[shape] = page
      if response.redirect?
        page[:location] = local_path(response.location)
        queue << [ page[:location], frame, path ] if page[:location]
      elsif response.media_type == "text/html"
        document = Nokogiri::HTML(response.body)
        out = outgoing(document)
        page[:reload] = document.at_css('meta[name="turbo-visit-control"][content="reload"]').present?
        # Un frame data-turbo-permanent est gardé par Turbo d'une page à l'autre : il n'est demandé qu'à l'arrivée par un
        # chargement complet, jamais à un clic depuis une page qui le porte déjà.
        permanent = document.css("turbo-frame[src][data-turbo-permanent]").map { it["id"] }
        page[:frames], page[:permanent_frames] = out[:frames].partition { |_, id| !permanent.include?(id) }.map { it.map(&:first) }
        page[:links] = out[:links].map { |link, target| [ link, target ] }
        page[:files] = out[:files]
        (out[:frames] + out[:links] + out[:forms]).each { |link, target| queue << [ link, target, path ] }
        out[:files].each { queue << [ it, nil, path ] }
        measure(session, path, frame, page) if response.successful?
      end
      pages << page
    end
    resolve_link_redirects(pages, shapes)
    [ pages, files.transform_values(&:to_a) ]
  end

  def measure(session, path, frame, page)
    WARMUP.times { visit(session, path, frame) }
    samples = Array.new(RUNS) { visit(session, path, frame) }
    last = samples.last
    times = samples.map { it[:ms] }
    repeated = last[:queries].map { fingerprint(it.first) }.tally.max_by(&:last)
    page.merge!(p50: percentile(times, 0.5).round(1), p95: percentile(times, 0.95).round(1), sql: last[:queries].size,
                sql_ms: last[:queries].sum(&:last).round(1), repeated: repeated&.last.to_i, repeated_sql: repeated&.first.to_s.first(200),
                kb: (last[:response].body.bytesize / 1024.0).round(1),
                slowest: last[:queries].max_by(3, &:last).map { |sql, ms| [ ms.round(1), sql.squish.first(240) ] })
  end

  # Un lien vers une adresse qui redirige coûte une requête en série de plus. Les adresses non visitées prennent le
  # résultat de l'adresse visitée de même forme.
  def resolve_link_redirects(pages, shapes)
    pages.each do |page|
      page[:redirecting_links] = page.delete(:links).to_a.filter_map do |link, frame|
        route = route_of(link) or next
        target = shapes[shape_of(route, link, frame)]
        "#{link} → #{target[:location]}" if target && target[:location]
      end.uniq
    end
  end

  def series(page)
    return 1 unless page[:status] == 200

    1 + (page[:reload] ? 1 : 0) + (page[:frames].to_a.any? ? 1 : 0)
  end

  def gaps(page)
    gaps = []
    html = page[:content_type] == "text/html"
    gaps << "HTML en cache public" if html && page[:cache_control].include?("public")
    gaps << "secret sans no-store" if page[:secret] && !page[:cache_control].include?("no-store")
    gaps << "#{page[:frames].size} frame(s) en série" if page[:frames].to_a.any? && !DEFERRED_ALLOWED.include?(page[:route]) && page[:frame].nil?
    gaps << "rechargement forcé" if page[:reload]
    gaps << "p95 #{page[:p95]} ms > #{BUDGET_MS[page[:route]]}" if page[:p95] && page[:p95] > BUDGET_MS[page[:route]]
    gaps << "#{page[:kb]} Ko > #{BUDGET_KB}" if page[:kb] && page[:kb] > BUDGET_KB
    gaps << "même requête ×#{page[:repeated]}" if page[:repeated].to_i >= REPEATED
    gaps << "#{page[:redirecting_links].size} lien(s) qui redirigent" if page[:redirecting_links].to_a.any?
    gaps
  end

  def print_report(pages, files, unreached)
    puts "| Profil | Route | Adresse | HTTP | Cache-Control | Série | SQL | Même × | p50 ms | p95 ms | Ko | Écarts |"
    puts "|---|---|---|--:|---|--:|--:|--:|--:|--:|--:|---|"
    # Une adresse de départ qui redirige (page protégée vue sans compte, par exemple) n'est pas un clic : hors tableau.
    pages.reject { it[:location] && it[:from].nil? }.each do |page|
      path = page[:frame] ? "#{page[:path]} [#{page[:frame]}]" : page[:path]
      path += " → #{page[:location]}" if page[:location]
      row = [ page[:role], page[:route], path, page[:status], page[:cache_control], series(page), page[:sql], page[:repeated],
              page[:p50], page[:p95], page[:kb], gaps(page).join(" ; ") ]
      puts "| #{row.join(' | ')} |"
    end
    puts "\n## Frames permanents (une requête à l'arrivée par chargement complet, aucune à un clic)"
    pages.select { it[:permanent_frames].to_a.any? }.group_by { it[:permanent_frames] }.each do |frames, on|
      puts "- #{frames.join(', ')} : #{on.size} page(s), profil(s) #{on.map { it[:role] }.uniq.join(', ')}"
    end
    puts "\n## Liens qui redirigent"
    pages.select { it[:redirecting_links].any? }.each { puts "- #{it[:role]} #{it[:path]} : #{it[:redirecting_links].join(', ')}" }
    puts "\n## Requêtes répétées (≥ #{REPEATED})"
    pages.select { it[:repeated].to_i >= REPEATED }.each { puts "- #{it[:role]} #{it[:path]} ×#{it[:repeated]} : #{it[:repeated_sql]}" }
    puts "\n## Fichiers (non lus) et pages où ils apparaissent"
    files.each { |route, from| puts "- #{route} : #{from.compact.first(5).join(', ')}" }
    puts "\n## Routes GET jamais atteintes\n#{unreached.map { "- #{it}" }.join("\n")}"
  end

  def run
    ActiveRecord::Base.connection.execute("ANALYZE")
    ActionController::Base.allow_forgery_protection = false
    only = ENV["PERF_ONLY"].to_s.split(",").map(&:to_sym)
    pages = []
    files = Hash.new { |hash, key| hash[key] = [] }
    ACTORS.each_key do |role|
      next if only.any? && !only.include?(role)

      found, seen_files = explore(role)
      pages.concat(found)
      seen_files.each { |route, from| files[route].concat(from) }
    end
    pages.reject! { NOT_PAGES.include?(it[:route]) }
    all_routes = Rails.application.routes.routes.filter_map do |route|
      next unless route.verb.to_s.include?("GET")

      name = "#{route.defaults[:controller]}##{route.defaults[:action]}"
      name if route.defaults[:controller] && !route.defaults[:controller].start_with?("rails/", "active_storage", "action_mailbox", "turbo/")
    end.uniq
    unreached = all_routes - pages.map { it[:route] } - files.keys - NOT_PAGES
    print_report(pages, files, unreached.sort)
    pages.each { it[:gaps] = gaps(it) }
    File.write(Rails.root.join("tmp/perf-audit.json"), JSON.pretty_generate(pages:, files:, unreached:))
  end
end

PerfAudit.run
