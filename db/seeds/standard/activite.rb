# Un trimestre d'activité déterministe sur le jeu standard (chantier standard-de-test, Lot B ; ADR standard-de-test §4 point 2 et
# « Tranché » 6). Joue, après db/seeds/standard.rb, jusqu'à 12 semaines de classe finissant la veille du chargement : les enseignants
# assignent des exercices (un par semaine et par classe, échéance trois jours plus tard), les élèves les rendent à temps, en
# retard ou pas du tout, et s'exercent d'eux-mêmes. Tout passe par les use cases (AssignResource, StartExerciseSession,
# SubmitExerciseCopy) à une horloge simulée : notes, lacunes, badges et échéances sont ceux que l'application aurait calculés
# (des remédiations s'y ajoutent quand un élève reprend une notion en lacune). Lycée et collège : plusieurs classes actives
# (5 au plus, un niveau après l'autre), toute la classe ; grand établissement (activite: echantillon) : une classe par
# niveau, un échantillon d'élèves. Les arrivées (enseignants, élèves) sont datées de la rentrée, sauf 2 ou 3 élèves récents. Restent à zéro : la classe vide, la classe de
# l'élève sans activité, et toute classe sans leçon publiée pour son niveau (le collège n'a du v3 qu'en 3ème).
# Déterministe : graine fixe, plan tiré avant toute écriture, un tirage propre à chaque événement ; le calendrier est relatif
# (jour 0 = il y a `weeks` semaines, dernier jour = hier) : l'empreinte des totaux affichée à la fin ne dépend pas de la date
# une fois la fenêtre pleine (12 semaines après la rentrée) ; avant, elle dépend du nombre de semaines, que la commande affiche.
# Idempotent : une assignation ou une séance déjà là n'est pas rejouée. L'échéance est calculée par AssignResource : le jour de
# séance de l'enseignant est posé à chaque devoir sur le jour d'échéance voulu (assignation + 3 jours), si bien que rendus à
# temps (0 à 2 jours) et en retard (5 jours et plus) ne dépendent pas du jour de la semaine du chargement.
# Le trimestre ne commence jamais avant la rentrée (1er septembre) : il est plus court que 12 semaines jusqu'au 24 novembre,
# et l'empreinte complète ne vaut d'une date à l'autre qu'à partir de là (l'empreinte réduite, de 3 semaines, dès le 22 septembre).
# ENV["STANDARD_ACTIVITY_SIZE"] = "reduite" : 3 semaines, 2 classes par établissement, 3 élèves par classe (tests).
# Develop (Lot I) aussi : l'activité n'y touche que les comptes du jeu (élèves inscrits par le jeu, enseignants arrivés par lui),
# jamais un vrai testeur qui aurait rejoint une classe ou un établissement du jeu.
develop = Entities::Catalog::AutomaticLoadStage.for(name: ENV["RAILWAY_ENVIRONMENT_NAME"], pr_environment: PrEnvironment.active?).whole_lessons? &&
          !DemoEnvironment.active?
unless Rails.env.local? || PrEnvironment.active? || DemoEnvironment.active? || develop
  raise "db/seeds/standard/activite.rb est réservé au développement, au test, aux environnements de PR, à Demo et à Develop"
end

require "digest"

$stdout.sync = true
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
log = ->(message) { puts "[standard/activite] #{message}" }
seed = 2026
rng = Random.new(seed)

size = ENV.fetch("STANDARD_ACTIVITY_SIZE", "complete")
raise "STANDARD_ACTIVITY_SIZE vaut complete ou reduite, reçu : #{size.inspect}" unless %w[complete reduite].include?(size)

shape = if size == "reduite"
  { weeks: 3, classes: 2, students: 3, grand_students: 2, practice: 1..2 }
else
  { weeks: 12, classes: 4, students: 25, grand_students: 8, practice: 1..3 }
end

standard_dir = Rails.root.join("db/seeds/standard")
set = Entities::Catalog::StandardTestSet.new(YAML.load_file(ENV.fetch("STANDARD_MANIFEST", standard_dir.join("jeu.yml").to_s)))
identity = Entities::School::FictitiousIdentity.new(YAML.load_file(standard_dir.join("noms.yml")))
levels = Orm::Level.all.index_by(&:slug)
series = Orm::Series.all.index_by(&:slug)
schools = set.schools.to_h { [ it.key, Orm::School.find_by(name: identity.school_name(it.key)) ] }
raise "le jeu standard de base n'est pas chargé (bin/rails runner db/seeds/standard.rb d'abord)" if schools.values.any?(&:nil?)

# Le calendrier : le dernier jour est hier, le premier est celui d'il y a `weeks` semaines, jamais avant la rentrée de l'année
# scolaire en cours (1er septembre) : tant que la rentrée est récente, le trimestre est plus court (moins de 12 semaines avant
# le 24 novembre) ; rien n'est écrit après hier 21 h 30.
last_day = Date.current - 1
rentree = Date.new(Entities::Classroom::SchoolYear.current(last_day).to_i, Entities::Classroom::SchoolYear::START_MONTH, 1)
weeks = [ shape.fetch(:weeks), (last_day - rentree + 1).to_i / 7 ].min
if weeks < 2
  log.call("la rentrée du #{rentree} est trop récente : moins de deux semaines de classe, rien à jouer")
  return
end
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
# Les comptes du jeu seuls : élèves inscrits par lui (joined_via « standard »), enseignants arrivés par lui.
jeu_teachers = Orm::TeacherProfile.where(joined_via: "standard").select(:user_id)
jeu_links = Orm::ClassroomStudent.where(joined_via: "standard")
teacher_of = lambda do |school, material|
  Orm::TeacherSchoolMaterial.where(school_id: school.id, material_id: material.id, teacher_id: jeu_teachers).joins("JOIN users ON users.id = teacher_school_materials.teacher_id")
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
    break if !sampled && chosen >= shape.fetch(:classes) # assez de classes actives pour cet établissement
    next if sampled && levels_done.include?(spec.level) # échantillon : une seule classe par niveau

    classroom = classroom_for.(spec) or next # classe absente de la base (manifeste ou base d'un autre jeu)
    roster = jeu_links.where(classroom_id: classroom.id).joins(:student).order("users.contact").includes(:student)
                                  .first(shape.fetch(sampled ? :grand_students : :students)).map(&:student)
    pool = pool_for.(classroom).group_by { it.course.material }.select { |material, _| teacher_of.(school, material) }
    # Sans élève (la classe vide), ou sans exercice publié d'une matière que l'établissement enseigne (le v3 manque à ce
    # niveau, par exemple 4ème à 6ème) : la classe reste à zéro.
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
profile = {}
active.each_with_index do |entry, class_index|
  engagement = rng.rand(0.75..1.0)
  # Une classe réaliste : ~60 % de réguliers, ~25 % d'irréguliers, ~15 % de décrochés (qui s'arrêtent après 1 à 3 semaines).
  entry[:roster].each do |student|
    ability[student.id] ||= rng.rand(0.25..0.95)
    draw = rng.rand
    profile[student.id] ||= if draw < 0.60 then { kind: :regular, on_time: rng.rand(0.80..0.95), late: 0.08, practice: 1.0 }
    elsif draw < 0.85 then { kind: :irregular, on_time: rng.rand(0.35..0.55), late: 0.20, practice: 0.5 }
    else { kind: :dropped, on_time: 0.6, late: 0.1, practice: 0.0, stops_after: rng.rand(1..3) }
    end
  end
  pools = entry.fetch(:pool).transform_values(&:dup)
  materials = pools.keys.sort_by(&:slug)
  # Un devoir par semaine, puis deux tout récents (avant-hier et hier) : leur échéance est à venir.
  assigned_days = Array.new(weeks - 1) { |week| (7 * week) + (class_index % 3) } + [ (7 * weeks) - 3, (7 * weeks) - 1 ]
  assigned_days.each_with_index do |day, rank|
    material = materials.rotate(class_index + rank).find { pools.fetch(it).any? } or break
    exercise = pools.fetch(material).shift
    assigned_at = at.(day, (8 * 60) + rng.rand(0..90))
    add.(assigned_at, :assign, entry:, exercise:, teacher_id: teacher_of.(entry.fetch(:school), material), day:)
    entry[:roster].each do |student|
      u = rng.rand
      habit = profile.fetch(student.id)
      on_time = habit.fetch(:on_time) * engagement
      # Rendu à temps : 0 à 2 jours après l'assignation ; en retard : 5 jours ou plus. L'échéance est à 3 jours (4 si le
      # troisième jour est un dimanche) : ni l'un ni l'autre ne dépend du jour de la semaine du chargement.
      delay = if u < on_time then rng.rand(0..2) elsif u < on_time + habit.fetch(:late) then rng.rand(5..9) end
      next if delay.nil? || (habit[:stops_after] && day >= 7 * habit[:stops_after])

      minutes = delay.zero? ? (8 * 60) + 90 + rng.rand(30..600) : (14 * 60) + rng.rand(0..420)
      time = at.(day + delay, minutes)
      add.(time, :session, student:, exercise:) if time <= finish
    end
  end
  # L'élève s'exerce aussi de lui-même, sur un exercice que la classe n'a pas reçu en devoir (« Fait seul ») ; la moitié de ces
  # séances tombent dans les 7 derniers jours, pour que les tableaux « 7 jours » soient remplis.
  free = pools.values.flatten
  free = entry.fetch(:pool).values.flatten if free.empty?
  entry[:roster].each do |student|
    (rng.rand(shape.fetch(:practice)) * profile.fetch(student.id).fetch(:practice)).round.times do |count|
      day = count.even? ? (7 * weeks) - 7 + rng.rand(0..6) : rng.rand(0...(7 * weeks))
      add.(at.(day, (8 * 60) + rng.rand(0..780)), :session, student:, exercise: free.fetch(rng.rand(free.size)))
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

roster_ids = active.flat_map { |entry| entry.fetch(:roster).map(&:id) }

# Les arrivées : le jeu de base inscrit tout le monde au chargement ; ici enseignants et élèves des trois établissements
# arrivent à la rentrée moins 2 à 5 jours (écart tiré de l'id), sauf 2 ou 3 élèves par établissement, arrivés ces derniers
# jours (jamais un élève qui a déjà travaillé). Rejoué, le résultat est le même.
rentree_at = rentree.in_time_zone + 8.hours
school_ids = schools.values.map(&:id)
school_classrooms = Orm::Classroom.where(school_id: school_ids).select(:id)
recent = school_ids.flat_map do |school_id|
  jeu_links.joins(:classroom).where(classrooms: { school_id: }).where.not(student_id: roster_ids).order(id: :desc)
                       .limit(2 + (school_id % 2)).pluck(:id).each_with_index.map { |id, rank| [ id, at.((7 * weeks) - 1 - (2 * rank), 10 * 60) ] }
end
arrivals = [ [ Orm::TeacherSchool.where(school_id: school_ids, teacher_id: jeu_teachers), "created_at" ],
             [ Orm::TeacherSchoolMaterial.where(school_id: school_ids, teacher_id: jeu_teachers), "created_at" ],
             [ Orm::TeacherClassroom.where(classroom_id: school_classrooms, teacher_id: jeu_teachers), "created_at" ],
             [ jeu_links.where(classroom_id: school_classrooms).where.not(id: recent.map(&:first)), "joined_at" ] ]
arrivals.each do |rows, column|
  rows.update_all([ "#{column} = ?::timestamp - ((2 + (id % 4)) * interval '1 day')", rentree_at ])
end
recent.each { |id, time| Orm::ClassroomStudent.where(id:).update_all(joined_at: time) }

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
# Les séances déjà terminées (un rejeu ne les refait pas), lues une fois ; les acteurs des élèves, construits une fois.
done_before = Orm::ExerciseSession.where(student_id: roster_ids, status: "completed").group(:student_id, :exercise_id).count
actors = {}
played = 0
assigned = 0
plan.each do |event|
  clock.now = event.fetch(:at)
  if event.fetch(:type) == :assign
    entry = event.fetch(:entry)
    exercise = event.fetch(:exercise)
    classroom = entry.fetch(:classroom)
    unless Orm::ClassroomAssignment.exists?(classroom_id: classroom.id, assignable_type: "Exercise", assignable_id: exercise.id)
      dto = Dtos::Classroom::AssignmentInput.new(classroom_public_id: classroom.public_id, assignable_type: "Exercise", assignable_key: exercise.public_id)
      # Un seul jour de séance, celui de l'échéance voulue : trois jours après l'assignation (le lundi si c'est un dimanche).
      due = event.fetch(:at).to_date + 3
      dto.weekdays = [ (due.sunday? ? due + 1 : due).cwday.to_s ]
      result = assign.call(actor: users.actor_for(user_id: event.fetch(:teacher_id), current_school_id: classroom.school_id), dto:)
      raise "assignation refusée (#{entry.fetch(:label)}, #{exercise.title}) : #{result.code} #{result.errors}" if result.failure?

      assigned += 1
    end
    next
  end

  student = event.fetch(:student)
  exercise = event.fetch(:exercise)
  key = [ student.id, exercise.id ]
  rank = seen[key]
  seen[key] += 1
  next if done_before.fetch(key, 0) > rank

  draw = Random.new((seed * 100_003) + event.fetch(:index))
  actor = (actors[student.id] ||= users.actor_for(user_id: student.id))
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
  semaines: weeks, classes: active.size, eleves: roster_ids.size, devoirs: due_dates.size,
  seances: all_sessions.count, terminees: completed.count, remediations: all_sessions.where(kind: "remediation").count,
  notes: completed.sum(:score_percent).to_i,
  reponses: Orm::QuestionAttempt.where(exercise_session_id: all_sessions.select(:id)).count,
  lacunes: Orm::KnowledgeGap.where(student_id: roster_ids).count, badges: Orm::ExerciseBadge.where(student_id: roster_ids).count,
  **states.sort.to_h
}
fingerprint = Digest::SHA256.hexdigest(totals.map { |name, value| "#{name}=#{value}" }.join("|"))[0, 10]
log.call("totaux : #{totals.map { |name, value| "#{name} #{value}" }.join(', ')}")
log.call("empreinte des totaux : #{fingerprint} (#{weeks} semaines ; stable d'une date à l'autre une fois la fenêtre pleine, à #{shape.fetch(:weeks)} semaines)")
log.call("terminé en #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)} s (#{played} séances et #{assigned} devoirs ajoutés)")
