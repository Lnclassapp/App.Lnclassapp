# Données de démonstration réalistes, développement seulement : bin/rails runner db/seeds/demo/saint_michel.rb
# Le Collège Saint Michel de Tiassalé, sa direction (2 comptes), 4 classes par niveau et par série de la 6ème à la Tle,
# 4 enseignants par matière déclarés chacun dans 5 classes, la Tle D 1 et ses 20 élèves. Les 6 enseignants de la Tle D 1
# y assignent chacun 3 exercices. 18 leçons complètes de lecons-traitees/tle-d (3 par matière) importées par la vraie
# chaîne d'import. Chaque élève traite 6 fois chaque exercice de la leçon 1 de sciences ; ceux de Français,
# d'Histoire-Géographie et de Philosophie, assignés la veille, restent à faire. Tout passe par les use cases, à une horloge
# qui avance de la rentrée à hier : notes, badges, lacunes et échéances sont ceux que l'application aurait calculés.
# Idempotent : rejoué, il ne crée que ce qui manque. PIN 2468 pour tous les comptes (ADR-0034).
raise "db/seeds/demo/saint_michel.rb est réservé au développement" unless Rails.env.development?

$stdout.sync = true
PIN = "2468"
# Jouées 6 fois par chaque élève, puis seulement assignées (le travail « À faire » de la classe).
PLAYED_LESSONS = %w[limites-et-continuite cinematique-du-point le-devenir-des-cellules-sexuelles-chez-les-mammiferes].freeze
ASSIGNED_LESSONS = %w[histoire-l-onu geographie-les-fondements-du-developpement-economique-de-la-cote-d-ivoire
                      histoire-l-ere-de-la-bipolarisation-de-1947-a-1991 la-dissertation-philosophique
                      le-commentaire-de-texte-philosophique la-connaissance-de-l-homme oeuvre-narrative
                      la-dissertation-litteraire preparation-a-l-oral-du-baccalaureat].freeze
# Les leçons 2 et 3 de sciences, seulement publiées : ni jouées, ni assignées.
PUBLISHED_LESSONS = %w[probabilite-conditionnelle-et-variable-aleatoire derivabilite-et-etude-de-fonctions les-alcools
                       mouvement-du-centre-d-inertie-d-un-solide le-fonctionnement-des-organes-sexuels-chez-l-homme
                       la-reproduction-chez-les-spermaphytes].freeze
LESSONS = (PLAYED_LESSONS + ASSIGNED_LESSONS + PUBLISHED_LESSONS).freeze
# Les leçons sont rangées par matière (lecons-traitees/tle-d/<matière>/<leçon>.json) : on les trouve par leur nom.
LESSON_FILES = Rails.root.glob("docs/contenus/lecons-traitees/tle-d/*/*.json").to_h { [ it.basename(".json").to_s, it ] }.freeze
RUNS = 6
START = Time.zone.local(2026, 9, 14, 8)
FINISH = Time.zone.local(2026, 10, 5, 21)
srand(2026)

# Les use cases lisent l'heure ici : la démo date chaque écriture dans le passé.
class DemoClock
  attr_accessor :now

  def initialize(now) = @now = now
end
clock = DemoClock.new(START - 7.days)
log = ->(message) { puts "[saint-michel] #{message}" }

account = lambda do |contact, **attributes|
  Orm::User.find_by(contact:) || Orm::User.create!(contact:, pin: PIN, **attributes)
end

# 1. L'établissement et ses classes, générées par le barème comme le fait l'import (ADR-0058).
drena = Orm::Drena.find_by!(slug: "tiassale")
school = Orm::School.find_by(name: "Collège Saint Michel de Tiassalé")
unless school
  school_code = Entities::School::SchoolCode.generate_unique(count: 1, taken: Repositories::School::SchoolRepository.new.taken_school_codes).first
  rows = [ { public_id: SecureRandom.base58(14), drena_id: drena.id, name: "Collège Saint Michel de Tiassalé", sigle: "CSMT",
             school_type: "private", cycle: "both", status: "active", school_code: } ]
  classrooms = Repositories::Classroom::ClassroomRepository.new
  Orm::School.transaction do
    created = Repositories::School::SchoolRepository.new.insert_many(rows:, at: clock.now).first
    generated = Entities::Classroom::DefaultClassroomPlan.rows_for(
      school: created, lookup: Repositories::Catalog::TaxonomyRepository.new.lookup, plan: Repositories::Classroom::ClassroomPlanRepository.new.plan
    ).rows
    codes = Entities::Classroom::JoinCode.generate_unique(count: generated.size, taken: classrooms.taken_join_codes)
    classrooms.insert_generated(rows: generated.zip(codes).map { |row, join_code|
      row.merge(public_id: SecureRandom.base58(14), school_id: created.id,
                school_year: Entities::Classroom::SchoolYear.current(clock.now.to_date), join_code:)
    }, at: clock.now)
  end
  school = Orm::School.find_by!(name: "Collège Saint Michel de Tiassalé")
  log.call("établissement créé, code #{school.school_code}")
end
tle = Orm::Level.find_by!(slug: "tle")
series_d = Orm::Series.find_by!(slug: "d")
classroom = Orm::Classroom.find_by!(school:, level: tle, series: series_d, name: "Tle D 1")

# 2. La direction : le directeur et un second compte de direction (3 au plus par établissement, ADR-0077).
[ [ "0710000001", "Kouamé", "Jean-Baptiste", "male" ], [ "0710000002", "Diabaté", "Aminata", "female" ] ].each do |contact, last_name, first_name, gender|
  user = account.call(contact, role: "school_admin", last_name:, first_name:, gender:)
  Orm::SchoolStaff.create!(user:, school:, joined_via: "invitation", created_at: clock.now) unless Orm::SchoolStaff.exists?(user:)
end
users = Repositories::Identity::UserRepository.new

# 2 bis. 4 classes par niveau et par série, de la 6ème à la Tle : le directeur complète le barème au « + » de « Classes par
#        niveau », qui nomme la classe suivante (« Tle C 2 »).
add_classroom = UseCases::Classroom::AddLevelClassroom.new(
  classrooms: Repositories::Classroom::ClassroomRepository.new, schools: Repositories::School::SchoolRepository.new,
  taxonomy: Repositories::Catalog::TaxonomyRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
  policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: Repositories::Shared::Transaction.new, clock:
)
director = users.actor_for(user_id: Orm::User.find_by!(contact: "0710000001").id)
Orm::Classroom.where(school:).includes(:level, :series).group_by { [ it.level, it.series ] }.each do |(level, series), existing|
  (4 - existing.size).times do
    result = add_classroom.call(actor: director, school_public_id: school.public_id, level_slug: level.slug, series_slug: series&.slug)
    raise "classe refusée (#{level.name} #{series&.name}) : #{result.code} #{result.errors}" if result.failure?
  end
end
log.call("classes : #{Orm::Classroom.where(school:).count}")

# 3. Les leçons complètes, importées par la chaîne réelle (Imports → Cours complets), puis publiées en cascade.
team = Orm::User.find_by!(contact: "0700000000")
team_actor = Repositories::Identity::UserRepository.new.actor_for(user_id: team.id)
names = LESSONS.map { |slug| JSON.parse(LESSON_FILES.fetch(slug).read)["courses"].first["name"] }
missing = LESSONS.zip(names).reject { |_slug, name| Orm::Course.exists?(name:, level: tle, series: series_d) }
if missing.any?
  noop_queue = Object.new.tap { |queue| queue.define_singleton_method(:enqueue) { |**| nil } }
  uploads = missing.map do |slug, _name|
    path = LESSON_FILES.fetch(slug)
    Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(path.read), filename: "#{slug}.json")
  end
  transaction = Repositories::Shared::Transaction.new
  started = UseCases::Catalog::StartImport.new(
    reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
    queue: noop_queue, transaction:, clock:
  ).call(actor: team_actor, dto: Dtos::Catalog::ImportUploadInput.new(kind: "course_tree", files: uploads))
  raise "import refusé : #{started.errors}" if started.failure?

  UseCases::Catalog::RunImport.new(
    adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), schema: Repositories::Catalog::ImportSchemaValidator.new,
    reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
    users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
    transaction:, clock:
  ).call(report_id: started.value.id)
  log.call("import : #{Orm::ImportReport.find(started.value.id).attributes.slice("status", "imported_count", "error_count").compact}")
end
courses = names.map { |name| Orm::Course.find_by!(name:, level: tle, series: series_d) }
cascade_dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
                         policy: Policies::Catalog::ManageContentPolicy.new, clock: }
cascade = UseCases::Catalog::PublishCascade.new(
  courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
  exercises: Repositories::Assessment::ExerciseRepository.new, transaction: cascade_dependencies[:transaction], policy: cascade_dependencies[:policy],
  publish_course: UseCases::Catalog::PublishCourse.new(courses: Repositories::Catalog::CourseRepository.new, **cascade_dependencies),
  publish_essential: UseCases::Catalog::PublishEssential.new(essentials: Repositories::Catalog::EssentialRepository.new, **cascade_dependencies),
  publish_exercise: UseCases::Assessment::PublishExercise.new(exercises: Repositories::Assessment::ExerciseRepository.new, **cascade_dependencies)
)
courses.each do |course|
  next if course.status == "published" && Orm::Exercise.joins(:essential).where(essentials: { course_id: course.id }).where.not(status: "published").none?

  result = cascade.call(actor: team_actor, root: :course, slug: course.slug)
  raise "publication refusée pour #{course.name} : #{result.errors}" if result.failure?
end
exercises_by_course = courses.to_h do |course|
  [ course, Orm::Exercise.joins(:essential).where(essentials: { course_id: course.id }, status: "published")
                         .order("essentials.position", :position).to_a ]
end
log.call("leçons : #{courses.map { |course| "#{course.name} (#{exercises_by_course[course].size} exercices)" }.join(", ")}")

# 4. Les enseignants de la Tle D 1, et d'elle seule : un par matière, avec les leçons de sa matière.
teachers = [ [ "0510000001", "Koné", "Ibrahim", "male", "mathematiques" ], [ "0510000002", "Bamba", "Mariam", "female", "physique-chimie" ],
             [ "0510000003", "N'Guessan", "Serge", "male", "svt" ], [ "0510000004", "Touré", "Awa", "female", "histoire-geographie" ],
             [ "0510000005", "Gnamien", "Paul", "male", "philosophie" ], [ "0510000006", "Kacou", "Adjoua", "female", "francais" ] ]
           .map do |contact, last_name, first_name, gender, material_slug|
  material = Orm::Material.find_by!(slug: material_slug)
  teacher = account.call(contact, role: "teacher", last_name:, first_name:, gender:)
  Orm::TeacherProfile.create!(user: teacher, material:, onboarding_completed_at: clock.now) unless teacher.teacher_profile
  Orm::TeacherSchool.create!(teacher_id: teacher.id, school_id: school.id, primary: true) unless Orm::TeacherSchool.exists?(teacher_id: teacher.id)
  Orm::TeacherClassroom.create!(teacher_id: teacher.id, classroom:) unless Orm::TeacherClassroom.exists?(teacher_id: teacher.id, classroom:)
  [ teacher, courses.select { it.material_id == material.id } ]
end

# 4 bis. 4 enseignants par matière, chacun dans 5 classes, déclarées par l'enseignant lui-même (« Mes classes »). Le premier
#        de chaque matière garde la Tle D 1 : les classes vont de la Tle D vers la 6ème, par paquets de 5. La philosophie
#        ne s'enseigne qu'en 1ère et en Tle, la physique-chimie à partir de la 4ème.
colleagues = {
  "mathematiques" => [ %w[Yao Didier male], %w[Kouakou Estelle female], %w[Soro Lassina male] ],
  "physique-chimie" => [ %w[Adjé Romain male], %w[Koffi Pélagie female], %w[Silué Drissa male] ],
  "svt" => [ %w[Ahui Florence female], %w[Djè Marius male], %w[Traoré Kadiatou female] ],
  "histoire-geographie" => [ %w[Boni Augustin male], %w[Kra Odile female], %w[Fofana Brahima male] ],
  "philosophie" => [ %w[Amani Gisèle female], %w[Zadi Roland male], %w[Lago Sylvie female] ],
  "francais" => [ %w[Dosso Ismaël male], %w[Gnaoré Hortense female], %w[Kanga Eugène male] ]
}
series_order = %w[d c a1 a2 a].freeze
classrooms_by_rank = Orm::Classroom.where(school:).includes(:level, :series)
                                   .sort_by { [ -it.level.position, series_order.index(it.series&.slug) || 9, it.name ] }
declare = UseCases::Classroom::DeclareTeaching.new(
  classrooms: Repositories::Classroom::ClassroomRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
  policy: Policies::Classroom::DeclareTeachingPolicy.new, clock:
)
colleagues.each.with_index(1) do |(material_slug, people), material_rank|
  material = Orm::Material.find_by!(slug: material_slug)
  staff = teachers.map(&:first).select { it.teacher_profile.material_id == material.id }
  staff += people.each.with_index(1).map do |(last_name, first_name, gender), rank|
    teacher = account.call(format("0511%d%05d", material_rank, rank), role: "teacher", last_name:, first_name:, gender:)
    Orm::TeacherProfile.create!(user: teacher, material:, onboarding_completed_at: clock.now) unless teacher.teacher_profile
    Orm::TeacherSchool.create!(teacher_id: teacher.id, school_id: school.id, primary: true) unless Orm::TeacherSchool.exists?(teacher_id: teacher.id)
    teacher
  end
  eligible = classrooms_by_rank.select do |room|
    case material_slug
    when "philosophie" then %w[1ere tle].include?(room.level.slug)
    when "physique-chimie" then %w[6eme 5eme].exclude?(room.level.slug)
    else true
    end
  end
  staff.zip(eligible.each_slice(5)).each do |teacher, rooms|
    actor = users.actor_for(user_id: teacher.id)
    rooms.each do |room|
      result = declare.call(actor:, classroom_public_id: room.public_id)
      raise "déclaration refusée (#{teacher.last_name}, #{room.name}) : #{result.code} #{result.errors}" if result.failure?
    end
  end
end
log.call("enseignants : #{Orm::TeacherSchool.where(school_id: school.id).count}, " \
         "#{Orm::TeacherClassroom.joins(:classroom).where(classrooms: { school_id: school.id }).count} classes déclarées")

# 5. Les 20 élèves de la Tle D 1, inscrits à la rentrée.
students = [ %w[Ahoua Kouadio male], %w[Aka Bénédicte female], %w[Assi Franck male], %w[Bakayoko Salimata female],
             %w[Brou Yannick male], %w[Coulibaly Fatoumata female], %w[Dago Hervé male], %w[Diallo Aïcha female],
             %w[Doumbia Moussa male], %w[Ehui Prisca female], %w[Gbagbo Junior male], %w[Kassi Grâce female],
             %w[Konan Arsène male], %w[Kouassi Larissa female], %w[Méité Abdoulaye male], %w[N'Dri Esther female],
             %w[Ouattara Seydou male], %w[Sangaré Mariétou female], %w[Tano Christian male], %w[Yapi Rebecca female] ]
           .each_with_index.map do |(last_name, first_name, gender), index|
  student = account.call(format("0110000%03d", index + 1), role: "student", last_name:, first_name:, gender:)
  unless Orm::ClassroomStudent.exists?(student_id: student.id)
    Orm::ClassroomStudent.create!(student_id: student.id, classroom:, primary: true, joined_at: START - rand(1..5).days)
  end
  student
end

# 6. Chaque enseignant assigne 3 exercices ; son premier geste donne ses jours de séance (lundi, jeudi). En sciences, un
#    par semaine depuis la rentrée (le premier de chaque fiche) ; dans les autres matières, la veille, le premier de chaque
#    leçon : leur échéance est à venir.
played = courses.first(PLAYED_LESSONS.size)
assign = UseCases::Classroom::AssignResource.new(
  classrooms: Repositories::Classroom::ClassroomRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
  session_days: Repositories::Classroom::SessionDaysRepository.new, transaction: Repositories::Shared::Transaction.new,
  policy: Policies::Classroom::AssignPolicy.new, session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new, clock:
)
teachers.each_with_index do |(teacher, taught), offset|
  actor = users.actor_for(user_id: teacher.id)
  taught &= courses.first(PLAYED_LESSONS.size + ASSIGNED_LESSONS.size)
  recent = (taught & played).empty?
  picks = recent ? taught.map { exercises_by_course[it].first } : exercises_by_course[taught.first].each_slice(3).first(3).map(&:first)
  picks.each_with_index do |exercise, week|
    next if Orm::ClassroomAssignment.exists?(classroom:, assignable_type: "Exercise", assignable_id: exercise.id)

    clock.now = recent ? FINISH - 12.hours + (offset * 20).minutes + week.minutes : START + week.weeks + offset.days + 10.hours
    dto = Dtos::Classroom::AssignmentInput.new(classroom_public_id: classroom.public_id, assignable_type: "Exercise",
                                               assignable_key: exercise.public_id)
    dto.weekdays = %w[1 4] if week.zero?
    result = assign.call(actor:, dto:)
    log.call("assignation refusée (#{teacher.last_name}, #{exercise.title}) : #{result.code} #{result.errors}") if result.failure?
  end
end

# 6 bis. Les annonces de la semaine : deux de la direction aux élèves, une de l'enseignant de Maths à ses classes.
create_message = UseCases::Communication::CreateMessage.new(
  messages: Repositories::Communication::MessageRepository.new, attachments: Repositories::Communication::AttachmentStore.new,
  schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
  teachings: Repositories::Classroom::TeachingRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
  transaction: Repositories::Shared::Transaction.new, policy: Policies::Communication::PublishPolicy.new, clock:
)
math_teacher = teachers.first.first
[ [ "0710000001", "students", "meeting", "Réunion parents-professeurs", "Samedi 10 octobre à 9 h, salle polyvalente. Les bulletins du mois y seront remis aux parents." ],
  [ "0710000002", "students", "exam", "Devoirs de niveau de la Tle", "Du 19 au 23 octobre, toutes les matières. Le planning est affiché au tableau de la vie scolaire." ],
  [ math_teacher.contact, "classrooms", "homework", "Limites : revoir les fiches 1 et 2", "Avant jeudi, refaites les exercices « Appliquer » des fiches 1 et 2. On corrige en classe." ] ]
  .each_with_index do |(contact, audience, illustration, title, body), rank|
  next if Orm::Message.exists?(title:)

  author = Orm::User.find_by!(contact:)
  clock.now = FINISH - (rank * 5).hours
  rooms = audience == "classrooms" ? Orm::TeacherClassroom.where(teacher_id: author.id).includes(:classroom).map { it.classroom.public_id } : []
  dto = Dtos::Communication::MessageInput.new(title:, body:, audience:, illustration:, classroom_public_ids: rooms, commit: "publish",
                                              visible_until: (FINISH + 30.days).to_date.iso8601)
  result = create_message.call(actor: users.actor_for(user_id: author.id), dto:)
  raise "annonce refusée (#{title}) : #{result.code} #{result.errors}" if result.failure?
end

# 7. Chaque élève traite chaque exercice 6 fois. Un niveau propre à chacun, qui progresse d'un passage à l'autre ;
#    les passages suivent l'ordre du temps, pour que lacunes et remédiations s'enchaînent comme en classe.
sessions = Repositories::Assessment::ExerciseSessionRepository.new
transaction = Repositories::Shared::Transaction.new
start_session = UseCases::Assessment::StartExerciseSession.new(
  exercises: Repositories::Assessment::ExerciseRepository.new, sessions:, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
  memberships: Repositories::Classroom::MembershipRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
  policy: Policies::Assessment::StartSessionPolicy.new, transaction:, clock:
)
submit = UseCases::Assessment::SubmitQuestionAttempt.new(
  sessions:, exercises: Repositories::Assessment::ExerciseRepository.new, policy: Policies::Assessment::SubmitAttemptPolicy.new,
  close: UseCases::Assessment::CloseExerciseSession.new(
    sessions:, badges: Repositories::Assessment::BadgeRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
    policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction:, clock:
  ),
  transaction:, clock:
)
exercises = played.flat_map { exercises_by_course[it] }
questions = Orm::Question.where(exercise: exercises).includes(:answers).order(:position).group_by(&:exercise_id)
ability = students.to_h { |student| [ student.id, rand(0.35..0.85) ] }
# DEMO_SLICE=« i/n » : ce processus ne joue que les élèves de rang i modulo n. Les élèves sont indépendants (lacunes et
# badges sont par élève) : n processus en parallèle divisent la durée par n.
slice, slices = ENV.fetch("DEMO_SLICE", "0/1").split("/").map(&:to_i)
students = students.select.with_index { |_student, index| index % slices == slice }
events = students.flat_map do |student|
  exercises.flat_map do |exercise|
    runs = Orm::ExerciseSession.where(student_id: student.id, exercise_id: exercise.id, status: "completed")
    done = runs.count
    # Une reprise place les passages restants après le dernier joué : l'ordre du temps reste celui des passages.
    from = [ runs.maximum(:completed_at), START ].compact.max
    Array.new(RUNS - done) { from + (rand * (FINISH - from)) }.sort.each_with_index.map { |at, rank| [ at, student, exercise, done + rank ] }
  end
end.sort_by(&:first)
log.call("#{events.size} sessions à jouer")

choose = lambda do |question, correct|
  right = question.answers.select(&:correct).map(&:id).sort
  next right if correct

  count = Entities::Assessment::Question::EXPECTED.fetch(question.question_type.to_sym)
  ids = question.answers.map(&:id)
  loop do
    pick = ids.sample(count).sort
    break pick unless pick == right
  end
end

events.each_with_index do |(at, student, exercise, run), index|
  actor = users.actor_for(user_id: student.id)
  clock.now = at
  started = start_session.call(actor:, exercise_public_id: exercise.public_id)
  raise "session refusée (#{student.first_name}, #{exercise.title}) : #{started.code} #{started.errors}" if started.failure?

  chance = [ ability.fetch(student.id) + (0.07 * run), 0.97 ].min
  # Une session interrompue (processus arrêté) reprend à sa première question sans réponse.
  answered = Orm::QuestionAttempt.joins("JOIN exercise_sessions ON exercise_sessions.id = question_attempts.exercise_session_id")
                                 .where(exercise_sessions: { public_id: started.value.public_id }).pluck(:question_id)
  questions.fetch(exercise.id).reject { answered.include?(it.id) }.each do |question|
    clock.now += rand(20..90).seconds
    dto = Dtos::Assessment::AttemptInput.new(session_public_id: started.value.public_id, question_id: question.id,
                                             answer_ids: choose.call(question, rand < chance))
    result = submit.call(actor:, dto:)
    raise "réponse refusée : #{result.code} #{result.errors}" if result.failure?
  end
  log.call("#{index + 1}/#{events.size}") if ((index + 1) % 250).zero?
end

completed = Orm::ExerciseSession.where(student_id: students.map(&:id), status: "completed")
log.call("terminé : #{completed.count} sessions terminées, moyenne #{completed.average(:score_percent)&.round(1)} %, " \
         "#{Orm::ExerciseBadge.where(student_id: students.map(&:id)).count} badges, " \
         "#{Orm::ClassroomAssignment.where(classroom:).count} assignations")
log.call("connexion : élèves 0110000001 à 0110000020, enseignants de la Tle D 1 0510000001 à 6, autres enseignants 05111… à 05116…, direction 0710000001 et 2 ; PIN #{PIN}")
