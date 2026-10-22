# Trois établissements de test, développement et environnements de PR seulement (chantiers tester-pr-en-local et
# environnements-de-pr, ADR-0108) : bin/tester-pr <PR> --demo, ou
# bin/rails runner db/seeds/demo/trois_etablissements.rb. Chacun a 3 classes par niveau de la 6ème à la Tle, de 35 à 45
# élèves par classe, un chef d'établissement, et les 6 enseignants de chaque classe, un par matière : l'EDHC au collège,
# la philosophie au lycée (décision du porteur du 2026-10-21) ; l'EDHC est ajoutée aux matières de la base si elle manque.
# Deux enseignants par établissement sont bivalents ; trois enseignants servent dans plusieurs établissements, l'un dans
# les trois. Aucune activité : les classes sont prêtes, rien n'y est encore joué (pour cela, db/seeds/demo/saint_michel.rb).
# Insertions groupées, en une transaction : quelques secondes. Rejoué, il ne crée rien de plus. PIN 2468 partout (ADR-0034).
# Contacts : direction 073S000001, enseignants 053S0000TT, élèves 013S00CCEE (S établissement, T enseignant, C classe,
# E élève dans la classe).
raise "db/seeds/demo/trois_etablissements.rb est réservé au développement et aux environnements de PR" unless Rails.env.development? || PrEnvironment.active?

SCHOOLS = [ [ "Test — Lycée Moderne Les Cocotiers", "LMC" ], [ "Test — Collège Le Baobab", "CLB" ],
            [ "Test — Lycée Mixte La Lagune", "LML" ] ].freeze
# 3 classes par niveau : sans série au collège, par série au lycée.
CLASSROOMS = [ *%w[6eme 5eme 4eme 3eme].product([ nil ], [ 1, 2, 3 ]),
               [ "2nde", "a", 1 ], [ "2nde", "a", 2 ], [ "2nde", "c", 1 ],
               *%w[1ere tle].product(%w[a1 c d], [ 1 ]) ].freeze
# Les parts d'une matière : les classes (rangs dans CLASSROOMS) de chacun de ses enseignants. Une matière commune à tous
# les niveaux a 4 enseignants pour les 21 classes ; l'EDHC (12 classes du collège) et la philosophie (9 du lycée), 2.
SHARES = Hash.new([ 0...6, 6...11, 11...16, 16...21 ].freeze).merge("edhc" => [ 0...6, 6...12 ], "philosophie" => [ 12...17, 17...21 ]).freeze
EDHC = { slug: "edhc", name: "EDHC", shortname: "EDHC", category: "other", position: 7 }.freeze
# Une même personne tient deux postes : [établissement, matière, part] => le poste qu'elle tient déjà. Les parts réunies
# sont disjointes dans un établissement : chaque classe garde 6 enseignants distincts.
SAME_PERSON = (1..3).each_with_object({}) do |school_rank, same|
  # Deux bivalents par établissement.
  same[[ school_rank, "svt", 0 ]] = [ school_rank, "physique-chimie", 3 ]
  same[[ school_rank, "histoire-geographie", 0 ]] = [ school_rank, "francais", 3 ]
end.merge(
  # Dans plusieurs établissements : un professeur de maths dans les trois, un de philosophie dans deux.
  [ 2, "mathematiques", 3 ] => [ 1, "mathematiques", 3 ],
  [ 3, "mathematiques", 0 ] => [ 1, "mathematiques", 3 ],
  [ 3, "philosophie", 1 ] => [ 2, "philosophie", 1 ]
).freeze
LAST_NAMES = %w[Koné Traoré Kouassi Yao Bamba Coulibaly Ouattara Diabaté Touré Koffi N'Guessan Kouamé Konan Diallo Cissé
                Gnamien Kacou Aka Assi Brou Dosso Fofana Sanogo Soro Tanoh Zadi Méité Amani Ehui Kra].freeze
FIRST_NAMES = { "male" => %w[Ibrahim Serge Paul Jean Moussa Yves Arsène Hervé Didier Franck Karim Lamine Cédric Junior
                             Christian Ange Fabrice Rodrigue Ismaël Abdoulaye],
                "female" => %w[Awa Mariam Adjoua Aminata Fatou Aya Brigitte Grâce Mireille Nadège Clarisse Salimata Prisca
                               Estelle Bintou Rokia Inès Josiane Raïssa Christelle] }.freeze
PIN = "2468"

log = ->(message) { puts "[trois-etablissements] #{message}" }
# Avant tout retour : les leçons d'EDHC (db/seeds/demo/lecons_completes.rb) en ont besoin, même établissements déjà là.
Orm::Material.find_or_create_by!(slug: EDHC[:slug]) { it.assign_attributes(EDHC.except(:slug)) }
existing = Orm::School.where(name: SCHOOLS.map(&:first)).count
if existing == SCHOOLS.size
  log.call("déjà en place, rien à faire (contenu non vérifié : bin/tester-pr <PR> --reset --demo pour repartir de zéro)")
  return
end
raise "trois établissements de test partiellement présents : recréez la base (bin/tester-pr <PR> --reset --demo)" if existing.positive?

random = Random.new(2026)
now = Time.current
pin_digest = Orm::User.new(pin: PIN).pin_digest
person = lambda do |contact, role|
  gender = %w[male female][random.rand(2)]
  { public_id: SecureRandom.base58(14), contact:, role:, gender:, pin_digest:, last_name: LAST_NAMES.sample(random:),
    first_name: FIRST_NAMES.fetch(gender).sample(random:) }
end
insert = ->(model, rows) { model.insert_all!(rows, returning: %w[id]).map { it["id"] } }
levels = Orm::Level.all.index_by(&:slug)
series = Orm::Series.all.index_by(&:slug)
drenas = Orm::Drena.order(:name).limit(SCHOOLS.size).to_a
school_year = Entities::Classroom::SchoolYear.current(now.to_date)

Orm::School.transaction do
  materials = Orm::Material.order(:id).to_a

  # 1. Les établissements, leurs classes et leur chef d'établissement.
  school_repository = Repositories::School::SchoolRepository.new
  codes = Entities::School::SchoolCode.generate_unique(count: SCHOOLS.size, taken: school_repository.taken_school_codes)
  schools = school_repository.insert_many(at: now, rows: SCHOOLS.each_with_index.map do |(name, sigle), index|
    { public_id: SecureRandom.base58(14), drena_id: drenas.fetch(index).id, name:, sigle:, school_type: "private", cycle: "both",
      status: "active", school_code: codes.fetch(index) }
  end).map { Orm::School.find(it.id) }

  classrooms = schools.map do |school|
    insert.(Orm::Classroom, CLASSROOMS.map do |level_slug, series_slug, rank|
      { public_id: SecureRandom.base58(14), school_id: school.id, level_id: levels.fetch(level_slug).id,
        series_id: series_slug && series.fetch(series_slug).id,
        name: [ levels.fetch(level_slug).name, series_slug && series.fetch(series_slug).name, rank ].compact.join(" "),
        school_year: }
    end)
  end

  head_ids = insert.(Orm::User, schools.each_index.map { person.call(format("073%d000001", it + 1), "school_admin") })
  Orm::SchoolStaff.insert_all!(schools.zip(head_ids).map do |school, user_id|
    { school_id: school.id, user_id:, position: "head", joined_via: "invitation" }
  end)

  # 2. Les enseignants : un poste par établissement, matière et part ; SAME_PERSON réunit deux postes sur une personne.
  posts = (1..SCHOOLS.size).to_a.product(materials.map(&:slug)).flat_map do |school_rank, slug|
    SHARES[slug].each_index.map { [ school_rank, slug, it ] }
  end
  owner = ->(post) { SAME_PERSON.key?(post) ? owner.(SAME_PERSON.fetch(post)) : post }
  owners = posts.map(&owner).uniq
  contacts = owners.group_by(&:first).flat_map do |school_rank, owned|
    owned.each_with_index.map { |post, index| [ post, format("053%d%06d", school_rank, index + 1) ] }
  end.to_h
  teacher_ids = owners.zip(insert.(Orm::User, owners.map { person.call(contacts.fetch(it), "teacher") })).to_h
  Orm::TeacherProfile.insert_all!(teacher_ids.values.map { { user_id: it, joined_via: "standard", onboarding_completed_at: now } })

  # [enseignant, établissement (rang), matière, part], un par poste.
  links = posts.map { |post| [ teacher_ids.fetch(owner.(post)), *post ] }
  first_school = links.group_by(&:first).transform_values { |owned| owned.map { it[1] }.min }
  by_slug = materials.index_by(&:slug)
  Orm::TeacherSchool.insert_all!(links.map { it.first(2) }.uniq.map do |teacher_id, school_rank|
    { teacher_id:, school_id: schools.fetch(school_rank - 1).id, primary: school_rank == first_school.fetch(teacher_id), created_at: now }
  end)
  Orm::TeacherSchoolMaterial.insert_all!(links.map { it.first(3) }.uniq.map do |teacher_id, school_rank, slug|
    { teacher_id:, school_id: schools.fetch(school_rank - 1).id, material_id: by_slug.fetch(slug).id, created_at: now }
  end)
  Orm::TeacherClassroom.insert_all!(links.flat_map do |teacher_id, school_rank, slug, share|
    classrooms.fetch(school_rank - 1).values_at(*SHARES[slug].fetch(share)).map { { teacher_id:, classroom_id: it, created_at: now } }
  end.uniq)

  # 3. Les élèves : de 35 à 45 par classe, dans leur classe principale.
  classrooms.each_with_index do |classroom_ids, school_index|
    classroom_ids.each_with_index do |classroom_id, classroom_index|
      rows = (1..random.rand(35..45)).map { person.call(format("013%d00%02d%02d", school_index + 1, classroom_index + 1, it), "student") }
      Orm::ClassroomStudent.insert_all!(insert.(Orm::User, rows).map do |student_id|
        { classroom_id:, student_id:, primary: true, joined_at: now, joined_via: "standard" }
      end)
    end
  end

  students = Orm::ClassroomStudent.where(classroom_id: classrooms.flatten).count
  log.call("#{schools.size} établissements, #{classrooms.sum(&:size)} classes, #{teacher_ids.size} enseignants, #{students} élèves")
end
log.call("connexion, PIN #{PIN} : direction 0731000001, 0732000001, 0733000001 ; enseignants 0531000001…, 0532000001…, " \
         "0533000001… ; élèves 013S00CCEE, par exemple 0131000101 (établissement 1, 1re classe, 1er élève)")
