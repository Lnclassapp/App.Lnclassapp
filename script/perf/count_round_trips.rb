# Allers-retours vers le serveur par parcours (chantier politique-cache) : combien de requêtes un navigateur doit
# attendre, l'une après l'autre, avant qu'une page soit complète. Chaque requête qui atteint le serveur paie le trajet
# jusqu'à la région Railway (mesuré par script/perf/measure_network.rb) ; ce script compte ces requêtes.
#
# En mode production sur la base de développement (comptes de db/seeds, PIN 2468), comme measure_screens.rb :
#
#   RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=warn \
#   BUCKET_NAME=bench BUCKET_ENDPOINT=http://127.0.0.1:9 BUCKET_ACCESS_KEY_ID=x BUCKET_SECRET_ACCESS_KEY=x \
#   DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5432/app_lnclassapp_development<suffixe> \
#   bin/rails runner script/perf/count_round_trips.rb
#
# Le navigateur est simulé par Integration::Session, comme Turbo 8 le ferait : une visite Turbo envoie
# X-Turbo-Request-Id, fetch suit les redirections, la balise turbo-visit-control « reload » recharge le document, et
# chaque <turbo-frame src> de la page arrivée est demandé avec l'en-tête Turbo-Frame (on suppose le frame visible).
# Les assets ne sont pas comptés : sur une visite répétée, le navigateur les garde un an. Le compte ne dépend ni de la
# machine ni du réseau ; le temps serveur affiché est local et indicatif. Écrit tmp/perf-round-trips.json.
require "json"
require "securerandom"

module PerfRoundTrips
  PIN = "2468".freeze
  ACTORS = { student: "0100000001", teacher: "0500000001", team: "0700000000" }.freeze
  TURBO_VISIT = "text/html, application/xhtml+xml".freeze
  TURBO_FORM = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".freeze

  module_function

  def new_session
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host = "localhost"
    session.https!
    # La connexion est limitée à 5 par minute et par adresse : une adresse privée tirée au hasard par parcours.
    session.remote_addr = "10.#{Array.new(3) { rand(1..254) }.join('.')}"
    session
  end

  # Une requête = un aller-retour. On garde la profondeur : les frames d'une même page partent ensemble.
  def request(session, trips, depth, verb, path, headers: {}, params: nil)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    session.public_send(verb, path, headers:, params:)
    ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    trips << { depth:, request: "#{verb.upcase} #{path}#{" [#{headers['Turbo-Frame']}]" if headers['Turbo-Frame']}",
               status: session.response.status, server_ms: ms.round(1) }
    session.response
  end

  # Suit les redirections comme fetch ou le navigateur, puis le rechargement forcé, puis les frames différés.
  def arrive(session, trips, depth, response, turbo:)
    while response.redirect?
      depth += 1
      location = path_of(response.location)
      response = request(session, trips, depth, :get, location, headers: turbo ? turbo_headers(TURBO_VISIT) : {})
    end
    document = Nokogiri::HTML(response.body)
    if turbo && document.at_css('meta[name="turbo-visit-control"][content="reload"]')
      depth += 1
      response = request(session, trips, depth, :get, path_of(session.request.url))
      document = Nokogiri::HTML(response.body)
    end
    frames = document.css("turbo-frame[src]")
    depth += 1 if frames.any?
    frames.each do |frame|
      request(session, trips, depth, :get, path_of(frame["src"]), headers: turbo_headers(TURBO_VISIT).merge("Turbo-Frame" => frame["id"]))
    end
    depth
  end

  def path_of(url) = URI(url).then { it.is_a?(URI::HTTP) ? it.request_uri : url }

  def turbo_headers(accept) = { "Accept" => accept, "X-Turbo-Request-Id" => SecureRandom.uuid }

  # Turbo soumet un formulaire (ou un lien data-turbo-method) sauf si lui-même ou un parent porte data-turbo="false" ;
  # le navigateur le soumet alors seul.
  def turbo_form?(body, selector)
    node = Nokogiri::HTML(body).at_css(selector) or raise "contrôle #{selector} introuvable"
    node.xpath("ancestor-or-self::*[@data-turbo]").last&.[]("data-turbo") != "false"
  end

  def form_headers(turbo) = turbo ? turbo_headers(TURBO_FORM) : { "Accept" => "text/html" }

  # Compté à partir du clic sur « Se connecter » : la page de connexion est déjà affichée.
  def sign_in(session, trips, contact)
    turbo = turbo_form?(request(session, [], 0, :get, "/login").body, "form#session-form")
    response = request(session, trips, 1, :post, "/session", headers: form_headers(turbo), params: { session: { contact:, pin: PIN } })
    depth = arrive(session, trips, 1, response, turbo:)
    verify_team_second_factor(contact)
    depth
  end

  # Compté à partir du clic sur « Se déconnecter », depuis la page donnée.
  def sign_out(session, trips, from)
    sign_out = 'a[href$="/session"][data-turbo-method="delete"], form[action$="/session"]:has(input[name="_method"][value="delete"])'
    turbo = turbo_form?(request(session, [], 0, :get, from).body, sign_out)
    arrive(session, trips, 1, request(session, trips, 1, :delete, "/session", headers: form_headers(turbo)), turbo:)
  end

  # Le second facteur de l'équipe est validé en base : le parcours ne lit pas le secret TOTP.
  def verify_team_second_factor(contact)
    return unless contact == ACTORS[:team]

    Orm::Session.where(user_id: Orm::User.where(contact:).select(:id)).update_all(second_factor_verified_at: Time.current)
  end

  def journey(name)
    session = new_session
    trips = []
    setup = []
    depth = yield(session, trips, setup)
    { name:, round_trips: trips.size, sequential: depth, server_ms: trips.sum { it[:server_ms] }.round(1), trips: }
  end

  def journeys
    [
      journey("Connexion élève (formulaire → accueil)") { |s, t| sign_in(s, t, ACTORS[:student]) },
      journey("Connexion enseignant (formulaire → accueil)") { |s, t| sign_in(s, t, ACTORS[:teacher]) },
      journey("Ouverture de lnclass.com, élève déjà connecté") do |s, t, setup|
        sign_in(s, setup, ACTORS[:student])
        arrive(s, t, 1, request(s, t, 1, :get, "/"), turbo: false)
      end,
      *{ student: "/students", teacher: "/teachers", team: "/teams" }.map do |role, path|
        journey("Clic vers l'accueil (#{role})") do |s, t, setup|
          sign_in(s, setup, ACTORS.fetch(role))
          arrive(s, t, 1, request(s, t, 1, :get, path, headers: turbo_headers(TURBO_VISIT)), turbo: true)
        end
      end,
      journey("Clic vers le catalogue (élève)") do |s, t, setup|
        sign_in(s, setup, ACTORS[:student])
        arrive(s, t, 1, request(s, t, 1, :get, "/courses", headers: turbo_headers(TURBO_VISIT)), turbo: true)
      end,
      journey("Déconnexion (élève)") do |s, t, setup|
        sign_in(s, setup, ACTORS[:student])
        sign_out(s, t, "/students")
      end
    ]
  end

  def run
    ActionController::Base.allow_forgery_protection = false
    journeys # chauffe : gabarits compilés et caches remplis, comme en production
    results = journeys
    puts "| Parcours | Requêtes vers le serveur | Dont en série | Temps serveur cumulé ms (local) | Détail |"
    puts "|---|--:|--:|--:|---|"
    results.each do |row|
      detail = row[:trips].map { "#{it[:request]} → #{it[:status]}" }.join(" · ")
      puts "| #{row[:name]} | #{row[:round_trips]} | #{row[:sequential]} | #{row[:server_ms]} | #{detail} |"
    end
    File.write(Rails.root.join("tmp/perf-round-trips.json"), JSON.pretty_generate(results))
  end
end

PerfRoundTrips.run
