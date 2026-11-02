# Mesure des pages par rôle (chantier standard-de-test, Lot C) : se connecte comme chaque rôle d'un établissement, visite ses pages
# principales par de vraies requêtes (ActionDispatch::Integration::Session, sans navigateur), relève le temps serveur et le nombre
# de requêtes SQL. Lecture seule : aucune page n'est corrigée ici. Utilisé par `bin/rails pages:lentes` (bin/pages-lentes).
require "rotp"

module PagesLentes
  ROLES = %w[eleve enseignant direction equipe].freeze
  Visit = Struct.new(:role, :page, :milliseconds, :queries, :status, keyword_init: true)

  # Une session par rôle ; chaque rôle a sa propre adresse pour ne pas partager la limite de connexions.
  class Runner
    attr_reader :visits, :notes

    def initialize(school:, roles: ROLES, warmup: 1)
      @school = school
      @roles = roles
      @warmup = warmup
      @visits = []
      @notes = []
    end

    def call
      @roles.each_with_index do |role, index|
        user = account(role)
        next @notes << "#{role} : aucun compte dans cet établissement, rôle ignoré" if user.nil?

        session = sign_in(user, index)
        next @notes << "#{role} : connexion refusée, rôle ignoré" if session.nil?

        pages(role, user).each { |page, path, headers| visit(role, session, page, path, headers || {}) }
      end
      @visits.sort_by! { -it.milliseconds }
      self
    end

    private

    def classrooms = Orm::Classroom.where(school_id: @school.id)

    # La classe la plus active : celle qui a reçu le plus de devoirs, à défaut la plus peuplée.
    def busiest_classroom
      @busiest_classroom ||= begin
        counts = Orm::ClassroomAssignment.where(classroom_id: classrooms.select(:id)).group(:classroom_id).count
        classrooms.order(:id).max_by { [ counts.fetch(it.id, 0), Orm::ClassroomStudent.where(classroom_id: it.id).count ] }
      end
    end

    def account(role)
      case role
      when "eleve" then busiest_student
      when "enseignant" then busiest_teacher
      when "direction"
        Orm::User.where(id: Orm::SchoolStaff.where(school_id: @school.id, archived_at: nil).select(:user_id)).order(:id).first
      else Orm::User.where(role: "team", team_role: "admin").order(:id).first
      end
    end

    def busiest_student
      ids = Orm::ClassroomStudent.where(classroom_id: busiest_classroom.id).select(:student_id)
      busy = Orm::ExerciseSession.where(student_id: ids).group(:student_id).order(Arel.sql("COUNT(*) DESC"), :student_id).pick(:student_id)
      Orm::User.find_by(id: busy) || Orm::User.where(id: ids).order(:id).first
    end

    def busiest_teacher
      busy = Orm::ClassroomAssignment.where(classroom_id: busiest_classroom.id).group(:assigned_by_id)
                                     .order(Arel.sql("COUNT(*) DESC"), :assigned_by_id).pick(:assigned_by_id)
      Orm::User.find_by(id: busy, role: "teacher") ||
        Orm::User.where(id: Orm::TeacherClassroom.where(classroom_id: busiest_classroom.id).select(:teacher_id)).order(:id).first
    end

    def csrf(session) = session.response.body[/name="authenticity_token" value="([^"]+)"/, 1]

    def sign_in(user, index)
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! "localhost"
      session.remote_addr = "10.9.0.#{index + 1}"
      session.get "/login"
      session.post "/session", params: { authenticity_token: csrf(session), session: { contact: user.contact, pin: "2468" } }
      return unless session.response.redirect?

      if user.role == "team"
        session.get session.response.location
        code = ROTP::TOTP.new(Orm::TotpCredential.find_by!(user_id: user.id).secret).now
        session.post "/identity/second-factor", params: { authenticity_token: csrf(session), second_factor: { code: } }
      end
      session
    end

    def visit(role, session, page, path, headers)
      @warmup.times { session.get path, headers: }
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { session.get path, headers: }
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      @visits << Visit.new(role:, page:, milliseconds: elapsed.round(1), queries:, status: session.response.status)
    end

    def pages(role, user) = send(:"#{role}_pages", user)

    def first_course(level_id) = Orm::Course.where(status: "published", level_id:).order(:id).first

    def first_student(classroom)
      Orm::User.find_by(id: Orm::ClassroomStudent.where(classroom_id: classroom.id).order(:id).pick(:student_id))
    end

    def eleve_pages(user)
      classroom = Orm::Classroom.joins(:classroom_students).find_by(classroom_students: { student_id: user.id })
      course = first_course(classroom.level_id)
      assignment = Orm::ClassroomAssignment.where(classroom_id: classroom.id, assignable_type: "Exercise").order(:id).last
      exercise = Orm::Exercise.find_by(id: assignment&.assignable_id)
      [ [ "accueil", "/students" ],
        [ "accueil (historique différé)", "/students", { "Turbo-Frame" => "student_home_recent_activity" } ],
        [ "ma classe", "/students/classroom" ], [ "archive", "/students/archive" ], [ "menu", "/students/menu" ],
        [ "annonces", "/announcements" ], [ "catalogue", "/courses" ], [ "profil", "/profile" ],
        (course && [ "leçon", "/courses/#{course.slug}" ]), (exercise && [ "exercice", "/exercises/#{exercise.public_id}" ]) ].compact
    end

    def enseignant_pages(_user)
      classroom = busiest_classroom
      student = first_student(classroom)
      course = first_course(classroom.level_id)
      assignment = Orm::ClassroomAssignment.where(classroom_id: classroom.id).order(:id).last
      exercise = Orm::Exercise.find_by(id: assignment&.assignable_id)
      base = "/classrooms/#{classroom.public_id}"
      [ [ "accueil", "/teachers" ], [ "mes classes", "/teachers/classrooms" ], [ "menu", "/teachers/menu" ], [ "classe", base ],
        [ "jours de séance", "#{base}/session_days/edit" ], [ "annonces", "/announcements" ], [ "catalogue", "/courses" ], [ "profil", "/profile" ],
        (exercise && [ "assigner (modale)", "#{base}/assignments/new?assignable_key=#{exercise.public_id}" ]),
        (student && [ "élève de la classe", "#{base}/students/#{student.public_id}" ]),
        (course && [ "leçon de la classe", "#{base}/courses/#{course.slug}" ]),
        (assignment && [ "suivi d'un devoir", "#{base}/assignments/#{assignment.public_id}" ]) ].compact
    end

    def direction_pages(_user)
      classroom = busiest_classroom
      search = first_student(classroom)&.last_name.to_s.first(4)
      [ [ "activité", "/school-admin/activity" ], [ "classes", "/school-admin/classrooms" ],
        [ "classe", "/school-admin/classrooms/#{classroom.public_id}" ], [ "niveau", "/school-admin/levels/#{classroom.level.slug}" ],
        [ "enseignants", "/school-admin/teachers" ], [ "chercher un élève", "/school-admin/students/search?q=#{CGI.escape(search)}" ],
        [ "élèves partis", "/school-admin/students/departed" ], [ "enseignants partis", "/school-admin/teachers/departed" ],
        [ "établissement", "/school-admin/school" ], [ "annonces", "/announcements" ] ]
    end

    def equipe_pages(_user)
      [ [ "accueil", "/teams" ], [ "tableau de bord", "/teams/dashboard" ], [ "référentiel", "/teams/referential" ],
        [ "croissance", "/teams/growth" ], [ "plan des classes", "/teams/classroom-plan" ], [ "établissements", "/teams/schools" ],
        [ "établissement", "/teams/schools/#{@school.public_id}" ], [ "imports", "/teams/imports" ], [ "DRENA", "/teams/drenas" ],
        [ "recherche de compte", "/teams/accounts?q=#{CGI.escape(@school.name.first(5))}" ],
        [ "demandes de suppression", "/teams/deletion-requests" ], [ "catalogue", "/courses" ] ]
    end
  end

  # Le tableau, trié du plus lent au plus rapide, et les pages signalées (au-dessus du seuil ou de la limite de requêtes).
  def self.report(runner, threshold:, max_queries:)
    flags = lambda do |visit|
      [ ("LENTE" if visit.milliseconds > threshold), ("REQUÊTES" if visit.queries > max_queries) ].compact.join(" + ")
    end
    lines = runner.visits.map do |visit|
      format("%-11s  %-30s  %9s  %6d  %s  %s", visit.role, visit.page, "#{visit.milliseconds} ms", visit.queries, visit.status, flags.(visit)).rstrip
    end
    flagged = runner.visits.count { flags.(it).present? }
    summary = flagged.zero? ? "Aucune page lente." : "#{flagged} page(s) lente(s) (au-dessus de #{threshold} ms ou de #{max_queries} requêtes SQL)."
    [ format("%-11s  %-30s  %9s  %6s  %s  %s", "rôle", "page", "durée", "SQL", "http", "signal"), *lines, *runner.notes, summary,
      "Seuil : #{threshold.to_s.delete_suffix(".0")} ms, #{max_queries} requêtes SQL." ].join("\n")
  end
end
