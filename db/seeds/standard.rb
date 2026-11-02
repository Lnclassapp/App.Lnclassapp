# Le jeu de test standard, base (chantier standard-de-test, ADR standard-de-test §4) : trois établissements, leurs classes,
# les comptes de chaque rôle, les affectations et les cas difficiles du manifeste db/seeds/standard/jeu.yml, puis les
# leçons du manifeste importées par la vraie chaîne (StartImport, RunImport) et publiées en cascade. L'activité est le Lot B.
# Développement, test et environnements de PR seulement (les autres stades l'ouvriront par leur propre garde).
# Idempotent : tout est retrouvé par son nom ou son contact, rien n'est créé deux fois. Contacts et noms : FictitiousIdentity.
# PIN 2468 ; les comptes équipe prennent ENV["STANDARD_TEAM_PIN"], ou 2468 en développement, test et PR, sinon n'existent pas.
# ENV["STANDARD_LESSONS_LIMIT"] ne charge que les N premières leçons (boucles courtes, tests) ; ENV["STANDARD_MANIFEST"] change de manifeste.
unless Rails.env.local? || PrEnvironment.active?
  raise "db/seeds/standard.rb est réservé au développement, au test et aux environnements de PR"
end

standard_dir = Rails.root.join("db/seeds/standard")
lessons_dir = Rails.root.join("docs/contenus/lecons-traitees")
pin = "2468"
log = ->(message) { puts "[standard] #{message}" }
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

lessons_limit = if ENV["STANDARD_LESSONS_LIMIT"].present?
  Integer(ENV["STANDARD_LESSONS_LIMIT"], exception: false)&.then { it if it.positive? } ||
    raise("STANDARD_LESSONS_LIMIT doit être un entier positif, reçu : #{ENV['STANDARD_LESSONS_LIMIT'].inspect}")
end

# 1. Le manifeste est contrôlé contre le dépôt avant la moindre écriture.
set = Entities::Catalog::StandardTestSet.new(YAML.load_file(ENV.fetch("STANDARD_MANIFEST", standard_dir.join("jeu.yml").to_s)))
identity = Entities::School::FictitiousIdentity.new(YAML.load_file(standard_dir.join("noms.yml")))
files = lessons_dir.glob("*/*/*.json").to_h { [ it.relative_path_from(lessons_dir).to_s, JSON.parse(it.read)["version"] ] }
problems = set.errors(files)
raise "manifeste du jeu standard invalide :\n#{problems.map(&:message).join("\n")}" if problems.any?

team_pin = ENV["STANDARD_TEAM_PIN"].presence || (pin if Rails.env.local? || PrEnvironment.active?)
now = Time.current
school_year = Entities::Classroom::SchoolYear.current(now.to_date)
pin_digest = Orm::User.new(pin:).pin_digest
team_pin_digest = team_pin == pin ? pin_digest : (Orm::User.new(pin: team_pin).pin_digest if team_pin)
levels = Orm::Level.all.index_by(&:slug)
series = Orm::Series.all.index_by(&:slug)
Orm::Material.find_or_create_by!(slug: "edhc") { it.assign_attributes(name: "EDHC", shortname: "EDHC", category: "other", position: 7) }
materials = Orm::Material.all.index_by(&:slug)
insert = ->(model, rows) { model.insert_all!(rows, returning: %w[id]).map { it["id"] } }
# Les dix premiers numéros des élèves, enseignants et directions sont ceux des comptes de db/seeds/development.rb
# (0100000001, 0500000001, 0700000000) : le jeu commence au onzième, pour ne jamais en reprendre un.
reserved = Hash.new(0).merge(student: 10, teacher: 10, direction: 10)
contact_of = ->(role_key, index) { identity.contact(role: role_key, index: index + reserved[role_key]) }
person = lambda do |role_key, index, role, digest = pin_digest, **extra|
  name = identity.name(role: role_key, index: index + reserved[role_key])
  { public_id: SecureRandom.base58(14), contact: contact_of.(role_key, index), role:, gender: name.gender, pin_digest: digest,
    first_name: name.first_name, last_name: name.last_name, **extra }
end
# Les comptes déjà là (par contact) ne sont pas recréés : on rend { contact => id } après avoir inséré les manquants.
ensure_users = lambda do |rows|
  existing = Orm::User.where(contact: rows.map { it[:contact] }).pluck(:contact, :id).to_h
  missing = rows.reject { existing.key?(it[:contact]) }
  existing.merge(missing.map { it[:contact] }.zip(insert.(Orm::User, missing)).to_h)
end

first_students = []
Orm::School.transaction do
  # 2. Les établissements.
  school_repository = Repositories::School::SchoolRepository.new
  wanted = set.schools.to_h { [ it.key, identity.school_name(it.key) ] }
  present = Orm::School.where(name: wanted.values).index_by(&:name)
  to_create = set.schools.reject { present.key?(wanted.fetch(it.key)) }
  codes = Entities::School::SchoolCode.generate_unique(count: to_create.size, taken: school_repository.taken_school_codes)
  school_repository.insert_many(at: now, rows: to_create.zip(codes).map do |school, code|
    { public_id: SecureRandom.base58(14), drena_id: Orm::Drena.find_by!(name: school.drena).id, name: wanted.fetch(school.key),
      sigle: wanted.fetch(school.key).split.map { it[0] }.join.upcase.first(20), school_type: school.type, cycle: school.cycle,
      status: "active", school_code: code }
  end)
  schools = wanted.transform_values { Orm::School.find_by!(name: it) }

  # 3. Les classes : une par entrée du manifeste ; le rang n'est écrit dans le nom que lorsqu'il y en a plusieurs par série.
  classroom_ids = {}
  set.classrooms.each do |spec|
    school = schools.fetch(spec.school)
    base = [ levels.fetch(spec.level).name, spec.series && series.fetch(spec.series).name ].compact.join(" ")
    name = spec.key == [ spec.level, spec.series ].compact.join("-") ? base : "#{base} #{spec.rank}"
    classroom = Orm::Classroom.find_by(school_id: school.id, school_year:, name:) ||
                Orm::Classroom.create!(school:, level: levels.fetch(spec.level), series: spec.series && series.fetch(spec.series), name:, school_year:)
    classroom_ids["#{spec.school}/#{spec.key}"] = classroom.id
  end

  # 4. Les élèves. Le premier de chaque classe est son compte de test ; la classe vide n'en a aucun, la classe pleine en a
  # l'effectif du manifeste, le grand établissement répartit ses 1 500 élèves sur toutes ses classes, les autres en ont 12.
  empty = set.cases.empty_classroom
  plan = set.classrooms.group_by(&:school).flat_map do |school_key, specs|
    refs = specs.map { "#{school_key}/#{it.key}" }
    total = set.school(school_key).students
    refs.each_with_index.map do |ref, position|
      size = if ref == empty then 0
      elsif ref == set.cases.full_classroom then set.cases.full_classroom_size
      elsif total then (total / refs.size) + (position < total % refs.size ? 1 : 0)
      else 12
      end
      [ ref, size ]
    end
  end
  student_index = 0
  student_rows = plan.flat_map do |ref, size|
    Array.new(size) { person.(:student, student_index, "student").tap { student_index += 1 }.merge(classroom: ref) }
  end
  first_students = student_rows.uniq { it[:classroom] }
  student_ids = ensure_users.(student_rows.map { it.except(:classroom) })
  linked = Orm::ClassroomStudent.where(student_id: student_ids.values).pluck(:student_id).to_set
  Orm::ClassroomStudent.insert_all!(student_rows.filter_map do |row|
    id = student_ids.fetch(row[:contact])
    { classroom_id: classroom_ids.fetch(row[:classroom]), student_id: id, primary: true, joined_at: now, joined_via: "standard" } unless linked.include?(id)
  end)

  # 5. Les enseignants : leurs établissements, leurs matières, et toutes les classes de ces établissements.
  teachers = set.accounts.teachers
  teacher_ids = ensure_users.(teachers.each_index.map { person.(:teacher, it, "teacher") })
  teachers.each_with_index do |account, index|
    teacher_id = teacher_ids.fetch(contact_of.(:teacher, index))
    Orm::TeacherProfile.find_or_create_by!(user_id: teacher_id) { it.assign_attributes(joined_via: "standard", onboarding_completed_at: now) }
    account.schools.each_with_index do |school_key, rank|
      school = schools.fetch(school_key)
      Orm::TeacherSchool.find_or_create_by!(teacher_id:, school_id: school.id) { it.primary = rank.zero? }
      Orm::TeacherSchoolMaterial.find_or_create_by!(teacher_id:, school_id: school.id, material_id: materials.fetch(account.subject).id) { it.created_at = now }
      set.classrooms_of(school_key).each do |spec|
        Orm::TeacherClassroom.find_or_create_by!(teacher_id:, classroom_id: classroom_ids.fetch("#{school_key}/#{spec.key}")) { it.created_at = now }
      end
    end
  end

  # 6. Les directions.
  directions = set.accounts.directions
  head_ids = ensure_users.(directions.each_index.map { person.(:direction, it, "school_admin") })
  directions.each_with_index do |account, index|
    user_id = head_ids.fetch(contact_of.(:direction, index))
    Orm::SchoolStaff.find_or_create_by!(school_id: schools.fetch(account.school).id, user_id:) { it.position = "head"; it.joined_via = "invitation" }
  end

  # 7. L'équipe : seulement si un PIN est connu (développement, test, PR, ou STANDARD_TEAM_PIN). Le rôle « terrain » est filtré par DRENA
  # par l'écran, pas par une table : le compte du jeu n'a rien d'autre que son rôle.
  if team_pin_digest
    team_ids = ensure_users.(set.accounts.team.map { person.(it.role.to_sym, 0, "team", team_pin_digest, team_role: it.role) })
    team_ids.each_value { |user_id| Orm::TotpCredential.find_or_create_by!(user_id:) { it.secret = ROTP::Base32.random; it.confirmed_at = now } }
  end

  log.call("#{schools.size} établissements, #{classroom_ids.size} classes, #{student_rows.size} élèves, #{teachers.size} enseignants")
end

# 8. Les leçons du manifeste, importées par la vraie chaîne puis publiées en cascade par l'administrateur de l'équipe fictive.
paths = set.expected_paths
paths = paths.first(lessons_limit) if lessons_limit
admin = Orm::User.find_by(contact: contact_of.(:admin, 0)) || Orm::User.find_by!(contact: "0700000000")
actor = Repositories::Identity::UserRepository.new.actor_for(user_id: admin.id)
documents = paths.map { |path| [ path, JSON.parse(lessons_dir.join(path).read) ] }
course_for = lambda do |course|
  Orm::Course.joins(:level, :material).left_joins(:series)
             .find_by(name: course["name"], levels: { name: course["level_name"] }, materials: { name: course["material_name"] },
                      series: { name: course["series_name"] })
end
missing = documents.reject { |_path, document| course_for.(document["courses"].first) }

if missing.any?
  noop_queue = Object.new.tap { |queue| queue.define_singleton_method(:enqueue) { |**| nil } }
  transaction = Repositories::Shared::Transaction.new
  missing.each_slice(50) do |batch|
    uploads = batch.map do |path, document|
      Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(JSON.generate(document)), filename: path.tr("/", "-"))
    end
    started_import = UseCases::Catalog::StartImport.new(
      reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      queue: noop_queue, transaction:, clock: Time.zone
    ).call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(kind: "course_tree", files: uploads))
    raise "import refusé : #{started_import.errors}" if started_import.failure?

    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), schema: Repositories::Catalog::ImportSchemaValidator.new,
      reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction:, clock: Time.zone
    ).call(report_id: started_import.value.id)
    report = Orm::ImportReport.find(started_import.value.id)
    raise "import en échec : #{report.attributes.slice('status', 'imported_count', 'error_count')}" unless report.status == "completed"
  end
end

courses = documents.map { |path, document| course_for.(document["courses"].first) || raise("leçon refusée par l'import : #{path}") }
dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
                 policy: Policies::Catalog::ManageContentPolicy.new, clock: Time.zone }
cascade = UseCases::Catalog::PublishCascade.new(
  courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
  exercises: Repositories::Assessment::ExerciseRepository.new, transaction: dependencies[:transaction], policy: dependencies[:policy],
  publish_course: UseCases::Catalog::PublishCourse.new(courses: Repositories::Catalog::CourseRepository.new, **dependencies),
  publish_essential: UseCases::Catalog::PublishEssential.new(essentials: Repositories::Catalog::EssentialRepository.new, **dependencies),
  publish_exercise: UseCases::Assessment::PublishExercise.new(exercises: Repositories::Assessment::ExerciseRepository.new, **dependencies)
)
published = courses.count do |course|
  next false if course.status == "published" && Orm::Exercise.where(course_id: course.id).where.not(status: "published").none?

  result = cascade.call(actor:, root: :course, slug: course.slug)
  raise "publication refusée pour #{course.name} : #{result.errors}" if result.failure?

  true
end
log.call("#{courses.size} leçons du manifeste, #{published} publiées maintenant")

# 9. Les comptes par rôle (contact, rôle, établissement) ; le premier élève de chaque classe est son compte de test.
if ENV["STANDARD_QUIET"].blank?
  log.call("comptes (PIN #{pin}#{team_pin_digest ? '' : ' ; pas de comptes équipe : STANDARD_TEAM_PIN absente'}) :")
  show = ->(contact, role, school) { log.call(format("  %-10s %-12s %s", contact, role, school)) }
  set.accounts.directions.each_with_index { |account, index| show.(contact_of.(:direction, index), "direction", identity.school_name(account.school)) }
  set.accounts.teachers.each_with_index do |account, index|
    show.(contact_of.(:teacher, index), "enseignant", "#{account.schools.map { identity.school_name(it) }.join(' + ')} (#{account.subject})")
  end
  first_students.each { |row| show.(row[:contact], "élève", "#{identity.school_name(row[:classroom].split('/').first)} / #{row[:classroom].split('/').last}") }
  set.accounts.team.each { |account| show.(contact_of.(account.role.to_sym, 0), "équipe #{account.role}", account.drena || "-") } if team_pin_digest
end
log.call("terminé en #{(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)} s")
