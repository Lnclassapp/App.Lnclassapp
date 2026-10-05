# Mesure des écrans lourds (chantier cache-ecrans-lourds) : temps serveur p50/p95, requêtes SQL, allocations et
# requêtes répétées (soupçon de N+1), écran par écran, sur le jeu de script/perf/seed_dataset.rb.
#
# En mode production (eager load, gabarits compilés une fois, cache Solid Cache actif) sur la base de développement :
#
#   RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=warn \
#   BUCKET_NAME=bench BUCKET_ENDPOINT=http://127.0.0.1:9 BUCKET_ACCESS_KEY_ID=x BUCKET_SECRET_ACCESS_KEY=x \
#   DATABASE_URL=postgres://dev-rails:dev-rails@localhost:5432/app_lnclassapp_development_wt_perf \
#   bin/rails runner script/perf/measure_screens.rb
#
# PERF_RUNS (30 par défaut) requêtes mesurées par écran, après 3 de chauffe ; PERF_ONLY=dashboard,schools limite
# aux écrans nommés. PERF_COLD=1 vide le cache (Rails.cache) avant chaque requête, hors du temps mesuré : la mesure à
# froid du pilotage « année », dont les chiffres sont gardés 5 minutes (ADR-0062, amendement du 2026-09-29). La requête passe par toute la pile Rack (Integration::Session), sans réseau ni navigateur.
# Aucune donnée n'est écrite, sauf les sessions de connexion des quatre comptes de mesure et le compteur de lectures de
# l'article mesuré : la lecture d'un visiteur compte, et son UPDATE entre dans le budget (ADR-0074 §4.7). Le blog
# (/blog, /blog?page=2, /blog/:slug) est lu sans compte, par la session `visitor` : sous 100 ms p95 et 150 Ko (ADR-0067).
# Le suivi d'un exercice assigné (UDR-0072, ADR-0079) est lu sur l'assignation active la plus faite de la classe mesurée :
# la page entière, puis le seul cadre d'une catégorie choisie (Turbo-Frame comprehension_frame).
require "json"
require "zlib"

module PerfScreens
  RUNS = Integer(ENV.fetch("PERF_RUNS", 30))
  WARMUP = 3
  PIN = "2468".freeze
  ACTORS = { team: "0700000000", teacher: "0520000001", student: "0120000001", admin: "0720000001" }.freeze
  IGNORED = %w[SCHEMA TRANSACTION].freeze
  SLOWEST = 3
  SLOW_DB_MS = 50
  COLD = ENV["PERF_COLD"] == "1"
  # Sans agent, une requête passe pour un robot et la lecture n'est pas comptée (Entities::Communication::ArticleRead).
  PHONE = { "User-Agent" => "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Mobile Safari/537.36" }.freeze

  module_function

  def percentile(values, rank)
    sorted = values.sort
    sorted[((sorted.size - 1) * rank).round]
  end

  # Un littéral devient « ? » : deux requêtes de même forme se reconnaissent, quels que soient leurs paramètres.
  def fingerprint(sql)
    sql.gsub(/'(?:[^']|'')*'/, "?").gsub(/\$\d+/, "?").gsub(/\b\d+\b/, "?").gsub(/\(\?(?:, ?\?)*\)/, "(?)").squish
  end

  def anonymous_session
    ActionDispatch::Integration::Session.new(Rails.application).tap do |session|
      session.host = "localhost"
      session.https!
    end
  end

  def session_for(contact)
    session = anonymous_session
    # La connexion est limitée à 5 par minute et par adresse : une adresse privée tirée au hasard par compte.
    session.remote_addr = "10.#{Array.new(3) { rand(1..254) }.join('.')}"
    session.post("/session", params: { session: { contact:, pin: PIN } })
    raise "connexion refusée pour #{contact} (#{session.response.status})" unless session.response.redirect?

    session
  end

  # Le second facteur de l'équipe est validé en base : la mesure ne lit pas le secret TOTP chiffré.
  def sessions
    ACTORS.to_h do |role, contact|
      session = session_for(contact)
      Orm::Session.where(user_id: Orm::User.where(contact:).select(:id)).update_all(second_factor_verified_at: Time.current) if role == :team
      [ role, session ]
    end.merge(visitor: anonymous_session)
  end

  def screens
    admin_school = Orm::SchoolStaff.joins(:user).find_by!(users: { contact: ACTORS[:admin] }).school_id
    focus = Orm::School.find(admin_school)
    student_classroom = Orm::ClassroomStudent.joins(:student).find_by!(users: { contact: ACTORS[:student] }).classroom
    teacher_classroom = Orm::TeacherClassroom.joins("JOIN users ON users.id = teacher_classrooms.teacher_id")
                                             .where(users: { contact: ACTORS[:teacher] }).order(:id).first.classroom
    assigned_course = Orm::ClassroomAssignment.where(classroom: teacher_classroom, assignable_type: "Course").pick(:assignable_id)
    course = Orm::Course.find(assigned_course || Orm::Course.where(status: "published").order(:id).pick(:id))
    essential = course.essentials.order(:position).first
    exercise = essential.exercises.order(:position).first
    done = "(SELECT COUNT(*) FROM exercise_sessions s WHERE s.classroom_assignment_id = classroom_assignments.id AND s.status = 'completed')"
    follow_up = Orm::ClassroomAssignment.where(classroom: teacher_classroom, status: "active")
                                        .order(Arel.sql("#{done} DESC"), :id).pick(:public_id)
    follow_up_path = "/classrooms/#{teacher_classroom.public_id}/assignments/#{follow_up}"
    article = Orm::Article.where(status: "published").order(published_at: :desc, id: :desc).pick(:slug) or
      raise "aucun article publié : semer le jeu (script/perf/seed_dataset.rb)"
    [
      [ "teams_home", :team, "/teams" ],
      [ "dashboard_7d", :team, "/teams/dashboard" ],
      [ "dashboard_year", :team, "/teams/dashboard?period=year" ],
      [ "dashboard_drena", :team, "/teams/dashboard?drena=#{focus.drena.public_id}" ],
      [ "dashboard_search", :team, "/teams/dashboard?q=kou", { "Turbo-Frame" => "team_dashboard_search" } ],
      [ "growth", :team, "/teams/growth" ],
      [ "schools", :team, "/teams/schools" ],
      [ "schools_search", :team, "/teams/schools?search=bouake" ],
      [ "schools_page_6", :team, "/teams/schools?page=6" ],
      [ "school_show", :team, "/teams/schools/#{focus.public_id}" ],
      [ "courses_team", :team, "/courses" ],
      [ "imports", :team, "/teams/imports" ],
      [ "teacher_home", :teacher, "/teachers" ],
      [ "teacher_classrooms", :teacher, "/teachers/classrooms" ],
      [ "classroom_show", :teacher, "/classrooms/#{teacher_classroom.public_id}" ],
      [ "assignment_follow_up", :teacher, follow_up_path ],
      [ "assignment_follow_up_fragile", :teacher, "#{follow_up_path}?category=fragile", { "Turbo-Frame" => "comprehension_frame" } ],
      [ "classroom_course", :teacher, "/classrooms/#{teacher_classroom.public_id}/courses/#{course.slug}" ],
      [ "course_assignments", :teacher, "/courses/#{course.slug}/assignments" ],
      [ "courses_teacher", :teacher, "/courses" ],
      [ "course_show", :teacher, "/courses/#{course.slug}" ],
      [ "essential_show", :teacher, "/courses/#{course.slug}/essentials/#{essential.slug}" ],
      [ "student_home", :student, "/students" ],
      [ "student_home_activity", :student, "/students", { "Turbo-Frame" => "student_home_recent_activity" } ],
      [ "student_classroom", :student, "/students/classroom" ],
      [ "courses_student", :student, "/courses" ],
      [ "exercise_show", :student, "/exercises/#{exercise.public_id}" ],
      [ "admin_classrooms", :admin, "/school-admin/classrooms" ],
      [ "admin_classroom", :admin, "/school-admin/classrooms/#{student_classroom.public_id}" ],
      [ "admin_teachers", :admin, "/school-admin/teachers" ],
      [ "admin_departed_students", :admin, "/school-admin/students/departed" ],
      [ "blog", :visitor, "/blog", PHONE ],
      [ "blog_page_2", :visitor, "/blog?page=2", PHONE ],
      [ "blog_article", :visitor, "/blog/#{article}", PHONE ]
    ]
  end

  def measure(session, path, headers)
    Rails.cache.clear if COLD # avant les abonnements : ni compté ni chronométré
    queries = []
    cached = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, start, finish, _, payload|
      next if IGNORED.include?(payload[:name])

      payload[:cached] ? cached += 1 : queries << [ payload[:sql], (finish - start) * 1000 ]
    end
    controller = {}
    action = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
      controller = payload.slice(:db_runtime, :view_runtime)
    end
    allocated = GC.stat(:total_allocated_objects)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    session.get(path, headers:)
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
    { ms: elapsed, allocations: GC.stat(:total_allocated_objects) - allocated, queries:, cached:, status: session.response.status,
      bytes: session.response.body.bytesize, gzip: Zlib.gzip(session.response.body).bytesize, db: controller[:db_runtime].to_f, view: controller[:view_runtime].to_f }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
    ActiveSupport::Notifications.unsubscribe(action)
  end

  def run
    ActiveRecord::Base.connection.execute("ANALYZE")
    ActionController::Base.allow_forgery_protection = false
    only = ENV["PERF_ONLY"].to_s.split(",")
    actors = sessions
    results = screens.filter_map do |name, role, path, headers = {}|
      next if only.any? && only.none? { name.include?(it) }

      WARMUP.times { measure(actors.fetch(role), path, headers) }
      samples = Array.new(RUNS) { measure(actors.fetch(role), path, headers) }
      summarize(name, path, samples)
    end
    print_table(results)
    File.write(Rails.root.join("tmp/perf-screens.json"), JSON.pretty_generate(results))
  end

  def summarize(name, path, samples)
    times = samples.map { it[:ms] }
    last = samples.last
    repeated = last[:queries].map { fingerprint(it.first) }.tally.max_by(&:last)
    { name:, path:, status: last[:status], p50: percentile(times, 0.5).round(1), p95: percentile(times, 0.95).round(1),
      db: percentile(samples.map { it[:db] }, 0.5).round(1), view: percentile(samples.map { it[:view] }, 0.5).round(1),
      sql: last[:queries].size, cached: last[:cached], allocations: percentile(samples.map { it[:allocations] }, 0.5),
      kb: (last[:bytes] / 1024.0).round(1), kb_gzip: (last[:gzip] / 1024.0).round(1), repeated: repeated ? repeated.last : 0, repeated_sql: repeated&.first.to_s.first(160),
      slowest: last[:queries].max_by(SLOWEST, &:last).map { |sql, ms| [ ms.round(1), sql.squish.first(300) ] } }
  end

  def print_table(results)
    puts "| Écran | Chemin | HTTP | p50 ms | p95 ms | SQL ms p50 | Vue ms p50 | Requêtes | En cache AR | Allocations | Ko | Ko gzip | Même requête × |"
    puts "|---|---|---|---|---|---|---|---|---|---|---|---|---|"
    results.each do |row|
      puts "| #{row.values_at(:name, :path, :status, :p50, :p95, :db, :view, :sql, :cached, :allocations, :kb, :kb_gzip, :repeated).join(' | ')} |"
    end
    results.select { it[:repeated] > 2 }.each { puts "\n#{it[:name]} : ×#{it[:repeated]} #{it[:repeated_sql]}" }
    results.select { it[:db] > SLOW_DB_MS }.each do |row|
      puts "\n#{row[:name]} — requêtes les plus lentes :"
      row[:slowest].each { |ms, sql| puts "  #{ms} ms  #{sql}" }
    end
  end
end

PerfScreens.run
