# Un trimestre d'activité déterministe sur le jeu standard (chantier standard-de-test, Lot B ; ADR standard-de-test §4 point 2 et
# « Tranché » 6). Joue, après db/seeds/standard.rb, 12 semaines de classe finissant la veille du chargement : les enseignants
# assignent des exercices (un par semaine et par classe, échéance trois jours plus tard), les élèves les rendent à temps, en
# retard ou pas du tout, et s'exercent d'eux-mêmes. Tout passe par les use cases (AssignResource, StartExerciseSession,
# SubmitExerciseCopy) à une horloge simulée : notes, lacunes, remédiations, badges et échéances sont ceux que l'application
# aurait calculés. Lycée et collège : plusieurs classes actives (5 au plus, un niveau après l'autre), 10 élèves par classe ;
# grand établissement (activite: echantillon) : une classe par niveau, 8 élèves. Restent à zéro : la classe vide, la classe de
# l'élève sans activité, et toute classe sans leçon publiée pour son niveau (le collège n'a du v3 qu'en 3ème).
# Déterministe : graine fixe, plan tiré avant toute écriture, un tirage propre à chaque événement ; le calendrier est relatif
# (jour 0 = il y a 12 semaines, dernier jour = hier) : l'empreinte des totaux affichée à la fin ne dépend pas de la date.
# Idempotent : une assignation ou une séance déjà là n'est pas rejouée. L'échéance d'une assignation est posée à
# « assignation + 3 jours », non au prochain jour de séance du calendrier réel, qui rendrait l'empreinte tributaire du jour.
# ENV["STANDARD_ACTIVITY_SIZE"] = "reduite" : 3 semaines, 2 classes par établissement, 3 élèves par classe (tests).
unless Rails.env.local? || PrEnvironment.active? || DemoEnvironment.active?
  raise "db/seeds/standard/activite.rb est réservé au développement, au test, aux environnements de PR et à Demo"
end

require "digest"

$stdout.sync = true
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
log = ->(message) { puts "[standard/activite] #{message}" }
seed = 2026
srand(seed)
rng = Random.new(seed)

size = ENV.fetch("STANDARD_ACTIVITY_SIZE", "complete")
raise "STANDARD_ACTIVITY_SIZE vaut complete ou reduite, reçu : #{size.inspect}" unless %w[complete reduite].include?(size)

shape = if size == "reduite"
  { weeks: 3, classes: 2, students: 3, grand_students: 2, practice: 1..2 }
else
  { weeks: 12, classes: 5, students: 10, grand_students: 8, practice: 2..4 }
end
weeks = shape.fetch(:weeks)

standard_dir = Rails.root.join("db/seeds/standard")
set = Entities::Catalog::StandardTestSet.new(YAML.load_file(ENV.fetch("STANDARD_MANIFEST", standard_dir.join("jeu.yml").to_s)))
identity = Entities::School::FictitiousIdentity.new(YAML.load_file(standard_dir.join("noms.yml")))
levels = Orm::Level.all.index_by(&:slug)
series = Orm::Series.all.index_by(&:slug)
schools = set.schools.to_h { [ it.key, Orm::School.find_by(name: identity.school_name(it.key)) ] }
raise "le jeu standard de base n'est pas chargé (bin/rails runner db/seeds/standard.rb d'abord)" if schools.values.any?(&:nil?)

# Le calendrier : le jour 0 est celui d'il y a `weeks` semaines, le dernier est hier ; rien n'est écrit après hier 21 h 30.
last_day = Date.current - 1
first_day = last_day - ((7 * weeks) - 1)
at = ->(day, minutes) { first_day.in_time_zone + day.days + minutes.minutes }
finish = at.(7 * weeks - 1, 21 * 60 + 30)

# 1. Les classes actives : un niveau après l'autre (la meilleure série du niveau d'abord), les classes sans leçon publiée,
# la classe vide et la classe de l'élève sans activité exclues.
level_order = %w[tle 1ere 3eme 2nde 4eme 5eme 6eme]
series_order = [ "d", "c", "a1", "a2", "a", nil ]
excluded = [ set.cases.empty_classroom, set.cases.student_without_activity ]
classroom_for = lambda do |spec|
  base = [ levels.fetch(spec.level).name, spec.series && series.fetch(spec.series).name ].compact.join(" ")
  name = spec.key == [ spec.level, spec.series ].compact.join("-") ? base : "#{base} #{spec.rank}"
  Orm::Classroom.where(school_id: schools.fetch(spec.school).id, name:).order(:school_year).last
end
pool_for = lambda do |classroom|
  Orm::Exercise.where(status: "published").where(id: Orm::Question.select(:exercise_id)).joins(course: :material).left_joins(:essential)
               .where(courses: { level_id: classroom.level_id, series_id: [ classroom.series_id, nil ].uniq, status: "published" })
               .includes(course: :material)
               .order("materials.slug", "courses.name", Arel.sql("essentials.position NULLS LAST"), "exercises.position", "exercises.id").to_a
end
teacher_of = lambda do |school, material|
  Orm::TeacherSchoolMaterial.where(school_id: school.id, material_id: material.id).joins("JOIN users ON users.id = teacher_school_materials.teacher_id")
                            .order("users.contact").pick(:teacher_id)
end

active = []
set.schools.each do |school_spec|
  school = schools.fetch(school_spec.key)
  sampled = school_spec.activity == "echantillon"
  candidates = set.classrooms_of(school_spec.key).reject { excluded.include?("#{it.school}/#{it.key}") }
                  .group_by(&:level).sort_by { |level, _| level_order.index(level) || 99 }
                  .map { |_level, specs| specs.sort_by { [ series_order.index(it.series) || 99, it.rank.to_i ] } }
  # Un niveau après l'autre, puis la série suivante de chacun : on prend les premières classes qui ont des leçons.
  ranks = candidates.map(&:size).max.to_i
  picks = (0...ranks).flat_map { |rank| candidates.filter_map { it[rank] } }
  chosen = 0
  levels_done = []
  picks.each do |spec|
    break if !sampled && chosen >= shape.fetch(:classes)
    next if sampled && levels_done.include?(spec.level)

    classroom = classroom_for.(spec) or next
    roster = Orm::ClassroomStudent.where(classroom_id: classroom.id).joins(:student).order("users.contact").includes(:student)
                                  .first(shape.fetch(sampled ? :grand_students : :students)).map(&:student)
    pool = pool_for.(classroom).group_by { it.course.material }.select { |material, _| teacher_of.(school, material) }
    next if roster.empty? || pool.empty?

    levels_done << spec.level
    active << { school:, classroom:, roster:, pool:, label: "#{identity.school_name(spec.school)} / #{classroom.name}" }
    chosen += 1
  end
end
if active.empty?
  log.call("aucune classe active : le jeu standard n'a pas de leçon publiée pour ses niveaux, rien à jouer")
  return
end
log.call("classes actives : #{active.map { it.fetch(:label) }.join(', ')}")

# 2. Le plan, entièrement tiré avant la moindre écriture : les devoirs de chaque classe, puis ce que chaque élève en fait.
plan = []
sequence = 0
add = ->(time, type, **data) { plan << { at: time, type:, seq: (sequence += 1), **data } }
ability = {}
active.each_with_index do |entry, class_index|
  engagement = rng.rand(0.75..1.0)
  entry[:roster].each { ability[it.id] ||= rng.rand(0.25..0.95) }
  pools = entry.fetch(:pool).transform_values(&:dup)
  materials = pools.keys.sort_by(&:slug)
  assigned_days = Array.new(weeks - 1) { |week| (7 * week) + (class_index % 3) } + [ (7 * weeks) - 1 ]
  assigned_days.each_with_index do |day, rank|
    material = materials.rotate(class_index + rank).find { pools.fetch(it).any? } or break
    exercise = pools.fetch(material).shift
    assigned_at = at.(day, (8 * 60) + rng.rand(0..90))
    add.(assigned_at, :assign, entry:, exercise:, teacher_id: teacher_of.(entry.fetch(:school), material), day:)
    entry[:roster].each do |student|
      u = rng.rand
      on_time = [ 0.30 + (ability.fetch(student.id) * 0.65), 0.95 ].min * engagement
      delay = if u < on_time then rng.rand(0..3) elsif u < on_time + 0.12 then rng.rand(4..9) end
      next unless delay

      minutes = delay.zero? ? (8 * 60) + 90 + rng.rand(30..600) : (14 * 60) + rng.rand(0..420)
      time = at.(day + delay, minutes)
      add.(time, :session, student:, exercise:) if time <= finish
    end
  end
  # L'élève s'exerce aussi de lui-même, sur n'importe quel exercice publié de son niveau.
  everything = entry.fetch(:pool).values.flatten
  entry[:roster].each do |student|
    rng.rand(shape.fetch(:practice)).times do
      add.(at.(rng.rand(0...(7 * weeks)), (8 * 60) + rng.rand(0..780)), :session, student:, exercise: everything.fetch(rng.rand(everything.size)))
    end
  end
end
plan.sort_by! { [ it.fetch(:at), it.fetch(:type) == :assign ? 0 : 1, it.fetch(:seq) ] }
plan.each_with_index { |event, index| event[:index] = index }
log.call("plan : #{plan.count { it[:type] == :assign }} devoirs, #{plan.count { it[:type] == :session }} séances sur #{weeks} semaines, jusqu'au #{last_day}")

# 3. Les use cases, à l'horloge simulée.
clock = Struct.new(:now).new(first_day.in_time_zone)
users = Repositories::Identity::UserRepository.new
transaction = Repositories::Shared::Transaction.new
sessions = Repositories::Assessment::ExerciseSessionRepository.new
exercise_repository = Repositories::Assessment::ExerciseRepository.new
assign = UseCases::Classroom::AssignResource.new(
  classrooms: Repositories::Classroom::ClassroomRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
  session_days: Repositories::Classroom::SessionDaysRepository.new, transaction:,
  policy: Policies::Classroom::AssignPolicy.new, session_days_policy: Policies::Classroom::SetSessionDaysPolicy.new, clock:
)
start_session = UseCases::Assessment::StartExerciseSession.new(
  exercises: exercise_repository, sessions:, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
  memberships: Repositories::Classroom::MembershipRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
  policy: Policies::Assessment::StartSessionPolicy.new, transaction:, clock:
)
submit = UseCases::Assessment::SubmitExerciseCopy.new(
  sessions:, exercises: exercise_repository, policy: Policies::Assessment::SubmitAttemptPolicy.new,
  close: UseCases::Assessment::CloseExerciseSession.new(
    sessions:, exercises: exercise_repository, badges: Repositories::Assessment::BadgeRepository.new,
    gaps: Repositories::Assessment::KnowledgeGapRepository.new, policy: Policies::Assessment::SubmitAttemptPolicy.new, transaction:, clock:
  ),
  transaction:, clock:
)

# Les élèves rejoignent leur classe avant le premier jour du trimestre (le jeu de base les inscrit au chargement).
roster_ids = active.flat_map { |entry| entry.fetch(:roster).map(&:id) }
joined = first_day.in_time_zone - 7.days
Orm::ClassroomStudent.where(student_id: roster_ids).where("joined_at > ?", joined).update_all(joined_at: joined)

# La copie d'un élève : ce qu'il aurait coché, tapé ou rangé pour que la question soit juste (ou fausse), dans l'ordre mélangé
# que l'application lui a montré (AnswerShuffle, tiré de la session et de la question).
blank_kinds = [ Entities::Assessment::QuestionKinds::FillBlank, Entities::Assessment::QuestionKinds::Numeric ]
answer_for = lambda do |question, session_id, correct, draw|
  shuffled = lambda do |avoid = nil|
    Entities::Assessment::AnswerShuffle.for(session_id:, question_id: question.id, ids: question.answer_ids, avoid:)
  end
  cases = Entities::Assessment::QuestionKinds::Blanks.cases(question.answers)
  kind = question.kind
  case kind::INPUT
  when :response_text
    if kind.equal?(Entities::Assessment::QuestionKinds::Written)
      { response_text: "Je réponds en m'appuyant sur la leçon : l'idée principale, un exemple, puis une conclusion." }
    else
      texts = cases.map do |accepted|
        right = accepted.first.content
        next right if correct

        kind.equal?(Entities::Assessment::QuestionKinds::Numeric) ? (Entities::Assessment::QuestionKinds::Numeric.parse(right) + 7).to_s("F") : "pas la bonne réponse"
      end
      blank_kinds.include?(kind) && texts.size > 1 ? { blanks: texts } : { response_text: texts.first }
    end
  when :display_order
    right = question.ids_by_position
    order = shuffled.(right)
    target = correct || right.size < 2 ? right : right.rotate(1)
    { display_order: target.map { order.index(it) } }
  else
    order = shuffled.()
    pick = lambda do |options|
      right = options.select(&:correct)
      next right.map(&:id) if correct

      # Une sélection de la bonne taille, différente de la bonne : au moins une mauvaise proposition y entre.
      wrong = options.reject(&:correct).map(&:id).shuffle(random: draw).first(1)
      (wrong + right.map(&:id).shuffle(random: draw)).first(right.size)
    end
    if kind.equal?(Entities::Assessment::QuestionKinds::Select) && cases.size > 1
      { blanks: cases.map { |options| order.index(pick.(options).first).to_s } }
    else
      { display_order: pick.(question.answers).map { order.index(it) } }
    end
  end
end

entities = {}
seen = Hash.new(0)
played = 0
assigned = 0
plan.each do |event|
  clock.now = event.fetch(:at)
  if event.fetch(:type) == :assign
    entry = event.fetch(:entry)
    exercise = event.fetch(:exercise)
    classroom = entry.fetch(:classroom)
    record = Orm::ClassroomAssignment.find_by(classroom_id: classroom.id, assignable_type: "Exercise", assignable_id: exercise.id)
    unless record
      dto = Dtos::Classroom::AssignmentInput.new(classroom_public_id: classroom.public_id, assignable_type: "Exercise", assignable_key: exercise.public_id)
      dto.weekdays = %w[1 4]
      result = assign.call(actor: users.actor_for(user_id: event.fetch(:teacher_id), current_school_id: classroom.school_id), dto:)
      raise "assignation refusée (#{entry.fetch(:label)}, #{exercise.title}) : #{result.code} #{result.errors}" if result.failure?

      record = Orm::ClassroomAssignment.find_by!(classroom_id: classroom.id, assignable_type: "Exercise", assignable_id: exercise.id)
      assigned += 1
    end
    record.update_columns(due_on: record.assigned_at.in_time_zone.to_date + 3)
    next
  end

  student = event.fetch(:student)
  exercise = event.fetch(:exercise)
  key = [ student.id, exercise.id ]
  rank = seen[key]
  seen[key] += 1
  next if Orm::ExerciseSession.where(student_id: student.id, exercise_id: exercise.id, status: "completed").count > rank

  draw = Random.new((seed * 100_003) + event.fetch(:index))
  actor = users.actor_for(user_id: student.id)
  started_session = start_session.call(actor:, exercise_public_id: exercise.public_id)
  raise "séance refusée (#{student.contact}, #{exercise.title}) : #{started_session.code} #{started_session.errors}" if started_session.failure?

  session = started_session.value
  chance = (ability.fetch(student.id) + (0.05 * rank)).clamp(0.05, 0.97)
  questions = (entities[exercise.id] ||= exercise_repository.find(id: exercise.id)).questions.reject { it.kind::INPUT == :none }
  answers = questions.filter_map do |question|
    next if draw.rand < 0.03

    [ question.id, answer_for.(question, session.id, draw.rand < chance, draw) ]
  end.to_h
  answers = { questions.first.id => answer_for.(questions.first, session.id, true, draw) } if answers.empty?
  clock.now = event.fetch(:at) + draw.rand(4..14).minutes
  result = submit.call(actor:, dto: Dtos::Assessment::CopyInput.new(session_public_id: session.public_id, answers:))
  raise "copie refusée (#{student.contact}, #{exercise.title}) : #{result.code} #{result.errors}" if result.failure?

  played += 1
  log.call("#{played} séances jouées") if (played % 200).zero?
end

# 4. L'empreinte des totaux : lue dans la base (elle vaut après un passage comme après dix), sans date ni identifiant.
all_sessions = Orm::ExerciseSession.where(student_id: roster_ids)
completed = all_sessions.where(status: "completed")
completed_days = completed.where.not(classroom_assignment_id: nil)
                          .pluck(:student_id, :classroom_assignment_id, :completed_at)
                          .group_by { |student_id, assignment_id, _| [ student_id, assignment_id ] }
                          .transform_values { |rows| rows.map { it.last.in_time_zone.to_date }.min }
due_dates = Orm::ClassroomAssignment.where(classroom_id: active.map { it.fetch(:classroom).id }, status: "active").pluck(:id, :classroom_id, :due_on)
today = last_day + 1
states = Hash.new(0)
due_dates.each do |assignment_id, classroom_id, due_on|
  active.find { it.fetch(:classroom).id == classroom_id }.fetch(:roster).each do |student|
    done_on = completed_days[[ student.id, assignment_id ]]
    states[if done_on then done_on > due_on ? :rendus_en_retard : :rendus_a_temps elsif due_on < today then :non_rendus_echus else :a_faire end] += 1
  end
end
totals = {
  classes: active.size, eleves: roster_ids.size, devoirs: due_dates.size,
  seances: all_sessions.count, terminees: completed.count, remediations: all_sessions.where(kind: "remediation").count,
  notes: completed.sum(:score_percent).to_i,
  reponses: Orm::QuestionAttempt.where(exercise_session_id: all_sessions.select(:id)).count,
  lacunes: Orm::KnowledgeGap.where(student_id: roster_ids).count, badges: Orm::ExerciseBadge.where(student_id: roster_ids).count,
  **states.sort.to_h
}
fingerprint = Digest::SHA256.hexdigest(totals.map { |name, value| "#{name}=#{value}" }.join("|"))[0, 10]
log.call("totaux : #{totals.map { |name, value| "#{name} #{value}" }.join(', ')}")
log.call("empreinte des totaux : #{fingerprint}")
log.call("terminé en #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)} s (#{played} séances et #{assigned} devoirs ajoutés)")
