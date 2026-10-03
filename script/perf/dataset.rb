# Jeu de données de mesure du chantier cache-ecrans-lourds, à l'échelle de la feuille de route (ADR-0039 §7) : 500
# établissements et leurs ~34 000 classes, 4 000 enseignants, 40 000 élèves, 200 cours complets, leurs devoirs et
# ~300 000 sessions d'exercice sur 60 jours, sur une base qui porte le référentiel de db/seeds ; et le blog (ADR-0074) :
# 30 articles publiés de 1 500 mots, chacun avec sa couverture et cinq images dans le texte, plus deux brouillons et un
# archivé.
#
#   bin/rails runner script/perf/seed_dataset.rb
#
# Tout est inséré en masse (insert_all!, ADR-0020) : public_id, slug et codes sont donc calculés ici. Les tirages
# viennent d'un générateur à graine fixe : deux exécutions donnent les mêmes volumes et la même forme ; seuls les
# public_id (SecureRandom) et les dates, relatives au jour de l'exécution, changent.
#
# Le module est chargé par script/perf/seed_dataset.rb (base de développement) et par les tests de budget
# test/performance/school/heavy_screens_budget_test.rb (PERF=1, base de test, dans la transaction du test).

module PerfDataset
  RNG = Random.new(20_260_929)
  SCHOOLS = Integer(ENV.fetch("PERF_SCHOOLS", 500))
  ADOPTING = Integer(ENV.fetch("PERF_ADOPTING", 80))
  TEACHERS = Integer(ENV.fetch("PERF_TEACHERS", 4_000))
  STUDENTS = Integer(ENV.fetch("PERF_STUDENTS", 40_000))
  COURSES = Integer(ENV.fetch("PERF_COURSES", 200))
  ARTICLES = Integer(ENV.fetch("PERF_ARTICLES", 30))
  ARTICLE_IMAGES = 5
  FOCUS_CLASS_SIZE = 55
  BATCH = 5_000
  PIN = "2468".freeze
  # Contacts du jeu, hors de ceux de db/seeds/development.rb (…00000001).
  STUDENT_CONTACT = 20_000_000
  TEACHER_CONTACT = 20_000_000
  ADMIN_CONTACT = "0720000001".freeze

  TOWNS = %w[Bouaké Daloa Korhogo Yamoussoukro San-Pédro Gagnoa Man Divo Abengourou Soubré Bondoukou Odienné Séguéla
             Dabou Agboville Grand-Bassam Bingerville Anyama Adzopé Dimbokro Touba Ferkessédougou Katiola Sassandra
             Tiassalé Issia Sinfra Bouaflé Toumodi Duékoué].freeze
  FIRST_NAMES = %w[Awa Aya Adjoua Akissi Mariam Fatou Aminata Affoué Ahou Clarisse Koffi Kouassi Yao Konan Ibrahim Moussa
                   Seydou Jean-Marc Serge Didier Arsène Brice Emmanuel Ange Grâce Esther Salimata Rokia Hervé Josué].freeze
  LAST_NAMES = %w[Kouassi Koné Traoré Ouattara Yao Konan Coulibaly Bamba Diabaté Kouamé N'Guessan Touré Doumbia Aka Kra
                  Gbagbo Zadi Séri Tapé Gnahoré Dosso Fofana Cissé Sangaré Kamagaté Assi Brou Ehui Amani Loukou].freeze
  TOPICS = [ "Les nombres", "Les fonctions", "La cellule", "L'énergie", "La lecture", "Le récit", "Les équations",
             "La géométrie", "Les statistiques", "L'électricité", "La matière", "La civilisation", "Le climat",
             "La grammaire", "L'argumentation", "Les probabilités", "La génétique", "La mécanique" ].freeze

  module_function

  def now = @now ||= Time.current
  def pick(list) = list[RNG.rand(list.size)]
  def days_ago(max_days) = now - RNG.rand(max_days * 86_400)
  def public_id = SecureRandom.base58(14)
  def log(message) = puts("[perf-seed] #{message}")

  def insert(model, rows, returning: nil)
    rows.each_slice(BATCH).flat_map do |slice|
      result = model.insert_all!(slice, returning:)
      returning ? result.rows.map(&:first) : []
    end
  end

  def pin_digest = @pin_digest ||= BCrypt::Password.create(PIN, cost: BCrypt::Engine::MIN_COST).to_s

  def user_row(contact:, role:, created_at:, anonymized: false)
    { public_id:, contact: (contact unless anonymized), role:, gender: pick(%w[male female]), pin_digest:,
      first_name: pick(FIRST_NAMES), last_name: pick(LAST_NAMES), created_at:, updated_at: created_at,
      anonymized_at: (created_at + 86_400 if anonymized) }
  end

  def run
    raise "Jeu déjà semé : bin/rails db:reset, puis relancer" if Orm::User.exists?(contact: format("05%08d", TEACHER_CONTACT + 1))

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveRecord::Base.logger = nil
    schools = seed_schools
    classrooms = Orm::Classroom.where(school_id: schools.map(&:id)).pluck(:id, :school_id, :level_id, :series_id)
                               .group_by { it[1] }
    active = Orm::School.where(id: schools.map(&:id), status: "active").pluck(:id).to_set
    adopting = schools.select { active.include?(it.id) }.first(ADOPTING)
    teachers = seed_teachers(adopting, classrooms)
    students = seed_students(adopting, classrooms)
    catalog = seed_catalog
    assignments = seed_assignments(students.keys.uniq, teachers, catalog)
    seed_sessions(students, assignments)
    seed_growth(adopting, teachers)
    seed_admin(adopting.first)
    seed_blog
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    log format("terminé en %.0f s", elapsed)
    report
  end

  # 500 établissements (80 % de lycées publics), répartis dans les 41 DRENA, et leurs classes générées par le barème.
  def seed_schools
    drenas = Orm::Drena.order(:id).pluck(:id)
    codes = Entities::School::SchoolCode.generate_unique(count: SCHOOLS, taken: Repositories::School::SchoolRepository.new.taken_school_codes)
    rows = (1..SCHOOLS).map do |index|
      prefix, school_type, cycle = case index % 20
      when 0..15 then [ "Lycée moderne", "public", "both" ]
      when 16, 17 then [ "Lycée privé", "private", "both" ]
      when 18 then [ "Lycée mixte", "mixed", "both" ]
      else [ "Collège moderne", "public", "first" ]
      end
      status = { 7 => "draft", 13 => "inactive" }.fetch(index % 50, "active")
      { public_id:, drena_id: drenas[index % drenas.size], name: "#{prefix} de #{TOWNS[index % TOWNS.size]} #{index}",
        sigle: "L#{index}", school_type:, cycle:, status:, school_code: codes[index - 1],
        national_code: (format("%06d", 100_000 + index) if index % 5 != 0) }
    end
    schools = Repositories::School::SchoolRepository.new.insert_many(rows:, at: days_ago(200))
    generate_classrooms(schools)
    log "#{schools.size} établissements, #{Orm::Classroom.count} classes"
    schools
  end

  def generate_classrooms(schools)
    classrooms = Repositories::Classroom::ClassroomRepository.new
    lookup = Repositories::Catalog::TaxonomyRepository.new.lookup
    plan = Repositories::Classroom::ClassroomPlanRepository.new.plan
    taken = classrooms.taken_join_codes
    school_year = Entities::Classroom::SchoolYear.current(now.to_date)
    schools.each do |school|
      generated = Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup:, plan:).rows
      codes = Entities::Classroom::JoinCode.generate_unique(count: generated.size, taken:)
      taken.merge(codes)
      rows = generated.zip(codes).map { |row, join_code| row.merge(public_id:, school_id: school.id, school_year:, join_code:) }
      classrooms.insert_generated(rows:, at: now)
    end
  end

  # 4 000 enseignants dans les établissements adoptants (60 dans le premier, l'établissement « focus »), 4 classes chacun.
  # → { school_id => [ [ teacher_id, [ classroom_id… ] ]… ] }
  def seed_teachers(adopting, classrooms)
    materials = Orm::Material.pluck(:id)
    focus, *others = adopting
    placements = Array.new(60) { focus } + Array.new(TEACHERS - 60) { pick(others) }
    ids = insert(Orm::User, placements.each_with_index.map do |_, index|
      user_row(contact: format("05%08d", TEACHER_CONTACT + index + 1), role: "teacher", created_at: days_ago(150))
    end, returning: %w[id])
    insert(Orm::TeacherProfile, ids.map { |id| { user_id: id, material_id: pick(materials), onboarding_completed_at: now, created_at: now, updated_at: now } })
    insert(Orm::TeacherSchool, ids.zip(placements).map { |id, school| { teacher_id: id, school_id: school.id, primary: true, created_at: now } })
    teachers = Hash.new { |hash, key| hash[key] = [] }
    teacher_classrooms = ids.zip(placements).each_with_index.flat_map do |(id, school), index|
      taught = classrooms.fetch(school.id).map(&:first).sample(index.zero? ? 6 : 4, random: RNG)
      teachers[school.id] << [ id, taught ]
      taught.map { |classroom_id| { teacher_id: id, classroom_id:, created_at: now } }
    end
    insert(Orm::TeacherClassroom, teacher_classrooms)
    log "#{ids.size} enseignants, #{teacher_classrooms.size} déclarations de classe"
    teachers
  end

  # 40 000 élèves : 55 par classe dans l'établissement focus, le reste réparti dans les classes des autres adoptants ;
  # 1 % de comptes anonymisés (ADR-0036). → { classroom_id => [ student_id… ] }
  def seed_students(adopting, classrooms)
    focus, *others = adopting
    focus_seats = classrooms.fetch(focus.id).flat_map { |id, *| Array.new(FOCUS_CLASS_SIZE, id) }
    other_classrooms = others.flat_map { classrooms.fetch(it.id).map(&:first) }
    seats = focus_seats + Array.new(STUDENTS - focus_seats.size) { pick(other_classrooms) }
    joined = seats.map { days_ago(120) }
    ids = insert(Orm::User, seats.each_index.map do |index|
      user_row(contact: format("01%08d", STUDENT_CONTACT + index + 1), role: "student", created_at: joined[index] - 3_600,
               anonymized: index >= focus_seats.size && (index % 100).zero?)
    end, returning: %w[id])
    insert(Orm::ClassroomStudent, ids.zip(seats, joined).map do |id, classroom_id, joined_at|
      { student_id: id, classroom_id:, primary: true, joined_at: }
    end)
    log "#{ids.size} élèves dans #{seats.uniq.size} classes"
    ids.zip(seats).group_by(&:last).transform_values { it.map(&:first) }
  end

  # 200 cours publiés (et 10 brouillons), 6 fiches, 3 exercices de 5 questions chacun, contenus riches avec formules.
  def seed_catalog
    author = Orm::User.find_by!(contact: "0700000000").id
    materials = Orm::Material.order(:id).pluck(:id, :name)
    pairs = Orm::Level.where.not(id: Orm::LevelSeries.select(:level_id)).pluck(:id).map { [ it, nil ] } + Orm::LevelSeries.pluck(:level_id, :series_id)
    combos = pairs.product(materials)
    courses = (0...(COURSES + 10)).map do |index|
      (level_id, series_id), (material_id, material_name) = combos[index % combos.size]
      name = "#{TOPICS[index % TOPICS.size]} #{index / combos.size + 1} (#{material_name})"
      status = index < COURSES ? "published" : "draft"
      { name:, subtitle: "Chapitre #{index + 1}", slug: "#{name.parameterize}-#{index + 1}", level_id:, series_id:, material_id:,
        author_id: author, status:, published_at: (now - 90.days if status == "published"), created_at: now, updated_at: now }
    end
    course_ids = insert(Orm::Course, courses, returning: %w[id])
    essentials = course_ids.each_with_index.flat_map do |course_id, index|
      (1..6).map do |position|
        name = "Fiche #{position} — #{courses[index][:name]}"
        { course_id:, name:, position:, slug: "#{name.parameterize}-#{course_id}-#{position}", author_id: author,
          status: courses[index][:status], published_at: courses[index][:published_at], created_at: now, updated_at: now }
      end
    end
    essential_ids = insert(Orm::Essential, essentials, returning: %w[id])
    rich_texts(course_ids, "Orm::Course") + rich_texts(essential_ids, "Orm::Essential")
    exercises = essential_ids.each_with_index.flat_map do |essential_id, index|
      (1..3).map do |position|
        { essential_id:, public_id:, position:, title: "Exercice #{position} de #{essentials[index][:name]}".first(200), author_id: author,
          status: essentials[index][:status], published_at: essentials[index][:published_at],
          exercise_type: position == 3 ? "evaluation" : "fixation", created_at: now, updated_at: now }
      end
    end
    exercise_ids = insert(Orm::Exercise, exercises, returning: %w[id])
    seed_questions(exercise_ids)
    log "#{course_ids.size} cours, #{essential_ids.size} fiches, #{exercise_ids.size} exercices"
    catalog_index(course_ids.first(COURSES))
  end

  def rich_texts(record_ids, record_type)
    body = "<h2>Rappel</h2><p>#{'Une phrase de cours, avec un exemple et une formule $a^2 + b^2 = c^2$. ' * 12}</p>" \
           "<ul>#{'<li>Point essentiel : $\\frac{1}{2}mv^2$</li>' * 8}</ul><p>#{'Un paragraphe explicatif. ' * 30}</p>"
    insert(ActionText::RichText, record_ids.map { { record_type:, record_id: it, name: "content", body:, created_at: now, updated_at: now } })
  end

  def seed_questions(exercise_ids)
    question_ids = insert(Orm::Question, exercise_ids.flat_map do |exercise_id|
      (1..5).map do |position|
        { exercise_id:, position:, question_type: position == 1 ? "true_false" : "single_choice", created_at: now, updated_at: now,
          content: "<p>Question #{position} : que vaut $x$ si $2x + 3 = 7$ ?</p>", explanation: "<p>On isole $x$.</p>" }
      end
    end, returning: %w[id])
    insert(Orm::Answer, answers_for(question_ids))
  end

  # Une question sur cinq en vrai/faux, les autres à choix unique parmi quatre.
  def answers_for(question_ids)
    question_ids.each_with_index.flat_map do |question_id, index|
      choices = (index % 5).zero? ? [ [ "Vrai", true ], [ "Faux", false ] ] : [ [ "2", true ], [ "3", false ], [ "4", false ], [ "5", false ] ]
      choices.each_with_index.map { |(content, correct), rank| { question_id:, position: rank + 1, content:, correct:, created_at: now, updated_at: now } }
    end
  end

  # { [ level_id, series_id ] => [ { course:, essentials: { essential_id => [ exercise_id… ] } }… ] }
  def catalog_index(course_ids)
    tree = Orm::Exercise.joins(:essential).where(essentials: { course_id: course_ids }).order(:id)
                        .pluck("essentials.course_id", :essential_id, :id)
    courses = Orm::Course.where(id: course_ids).pluck(:id, :level_id, :series_id)
    courses.group_by { [ it[1], it[2] ] }.transform_values do |rows|
      rows.map do |course_id, *|
        { course: course_id, essentials: tree.select { it.first == course_id }.group_by { it[1] }.transform_values { it.map(&:last) } }
      end
    end
  end

  # 10 devoirs par classe peuplée (7 exercices, 2 fiches, 1 cours), 10 % archivés, sur 60 jours.
  # → { classroom_id => [ [ assignment_id, [ exercise_id… ] ]… ] }
  def seed_assignments(classroom_ids, teachers, catalog)
    team = Orm::User.find_by!(contact: "0700000000").id
    by_classroom = teachers.values.flatten(1).each_with_object({}) { |(id, taught), map| taught.each { map[it] ||= id } }
    classrooms = Orm::Classroom.where(id: classroom_ids).pluck(:id, :level_id, :series_id)
    plans = classrooms.filter_map do |id, level_id, series_id|
      courses = catalog[[ level_id, series_id ]]
      next if courses.blank?

      essentials = courses.flat_map { |course| course[:essentials].to_a }
      targets = Array.new(7) { [ "Exercise", pick(pick(essentials).last) ] }.uniq +
                essentials.sample(2, random: RNG).map { |essential_id, exercise_ids| [ "Essential", essential_id, exercise_ids ] } +
                [ pick(courses).then { [ "Course", it[:course], it[:essentials].values.flatten ] } ]
      [ id, targets.uniq { it.first(2) } ]
    end
    rows = plans.flat_map do |classroom_id, targets|
      targets.map do |type, assignable_id, *|
        assigned_at = days_ago(60)
        archived = RNG.rand < 0.1
        { public_id:, classroom_id:, assignable_type: type, assignable_id:, assigned_at:, assigned_by_id: by_classroom.fetch(classroom_id, team),
          status: archived ? "archived" : "active", archived_at: (now if archived), archived_by_id: (team if archived),
          created_at: assigned_at, updated_at: assigned_at }
      end
    end
    ids = insert(Orm::ClassroomAssignment, rows, returning: %w[id]).each
    log "#{rows.size} devoirs dans #{plans.size} classes"
    plans.to_h do |classroom_id, targets|
      [ classroom_id, targets.map { |type, assignable_id, exercise_ids| [ ids.next, type == "Exercise" ? [ assignable_id ] : exercise_ids ] } ]
    end
  end

  # Chaque élève fait 6 exercices de ses devoirs, 1 ou 2 fois : 85 % terminés, 10 % en cours, 5 % abandonnés.
  def seed_sessions(students, assignments)
    rows = students.flat_map do |classroom_id, student_ids|
      given = assignments.fetch(classroom_id, [])
      next [] if given.empty?

      student_ids.flat_map { |student_id| sessions_for(student_id, given) }
    end
    insert(Orm::ExerciseSession, rows)
    log "#{rows.size} sessions d'exercice"
    derive_badges_and_gaps
  end

  def sessions_for(student_id, given)
    choices = given.flat_map { |assignment_id, exercise_ids| exercise_ids.map { [ assignment_id, it ] } }.uniq(&:last)
    choices.sample(6, random: RNG).flat_map do |assignment_id, exercise_id|
      attempts = RNG.rand < 0.3 ? 2 : 1
      (1..attempts).map do |attempt|
        started_at = days_ago(60)
        status = attempt < attempts ? "completed" : final_status(RNG.rand(100))
        score = status == "completed" ? [ [ (RNG.rand * 60 + 40 + RNG.rand(-40..20)).round, 0 ].max, 100 ].min : nil
        answered = status == "completed" ? 5 : 2
        { public_id:, student_id:, exercise_id:, classroom_assignment_id: assignment_id, status:, kind: "standard", started_at:,
          completed_at: (started_at + RNG.rand(120..1_200) if status == "completed"), question_count: 5, answered_count: answered,
          correct_count: score ? (score * 5 / 100) : 1, progress_percent: answered * 20, score_percent: score,
          created_at: started_at, updated_at: started_at }
      end
    end
  end

  def final_status(roll)
    return "completed" if roll < 85

    roll < 95 ? "started" : "abandoned"
  end

  # Un badge par (élève, exercice) sur la meilleure session ≥ 60 %, une lacune en attente par fiche sous 50 %.
  def derive_badges_and_gaps
    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL.squish)
      INSERT INTO exercise_badges (student_id, exercise_id, exercise_session_id, level, awarded_at, created_at, updated_at)
      SELECT DISTINCT ON (student_id, exercise_id) student_id, exercise_id, id,
             CASE WHEN score_percent = 100 THEN 'diamond' WHEN score_percent >= 90 THEN 'gold'
                  WHEN score_percent >= 75 THEN 'silver' ELSE 'bronze' END, completed_at, completed_at, completed_at
        FROM exercise_sessions WHERE status = 'completed' AND score_percent >= 60
       ORDER BY student_id, exercise_id, score_percent DESC, id
    SQL
    connection.execute(<<~SQL.squish)
      INSERT INTO knowledge_gaps (public_id, student_id, essential_id, source_session_id, status, created_at, updated_at)
      SELECT DISTINCT ON (s.student_id, e.essential_id) left(replace(gen_random_uuid()::text, '-', ''), 14), s.student_id,
             e.essential_id, s.id, 'pending', s.completed_at, s.completed_at
        FROM exercise_sessions s JOIN exercises e ON e.id = s.exercise_id
       WHERE s.status = 'completed' AND s.score_percent < 50
       ORDER BY s.student_id, e.essential_id, s.completed_at DESC
    SQL
    log "#{Orm::ExerciseBadge.count} badges, #{Orm::KnowledgeGap.count} lacunes"
  end

  # Croissance (ADR-0063) : 150 enseignants en attente, 1 200 parrainages, 6 000 partages sur 90 jours.
  def seed_growth(adopting, teachers)
    materials = Orm::Material.pluck(:id)
    pending = insert(Orm::User, (1..150).map do |index|
      user_row(contact: format("05%08d", TEACHER_CONTACT + TEACHERS + index), role: "teacher", created_at: days_ago(30))
    end, returning: %w[id])
    insert(Orm::TeacherProfile, pending.map { { user_id: it, material_id: pick(materials), created_at: now, updated_at: now } })
    insert(Orm::SchoolJoinRequest, pending.map do |id|
      created_at = days_ago(30)
      { public_id:, teacher_id: id, school_id: pick(adopting).id, status: "pending", created_at:, updated_at: created_at }
    end)
    pairs = teachers.flat_map { |school_id, list| list.map(&:first).each_cons(2).map { |referrer, referee| [ school_id, referrer, referee ] } }
    insert(Orm::Referral, pairs.sample(1_200, random: RNG).map do |school_id, referrer_id, referee_id|
      { school_id:, referrer_id:, referee_id:, source: RNG.rand < 0.8 ? "link" : "sponsor", created_at: days_ago(90) }
    end)
    all_teachers = teachers.values.flatten(1).map(&:first)
    insert(Orm::ReferralShare, Array.new(6_000) { { user_id: pick(all_teachers), channel: pick(%w[whatsapp sms copy native]), created_at: days_ago(90) } })
    log "150 demandes en attente, #{Orm::Referral.count} parrainages, #{Orm::ReferralShare.count} partages"
  end

  # Le blog public (ADR-0074, UDR-0066) : ARTICLES publiés, puis deux brouillons et un archivé, signés par l'auteur des
  # cours. Les lignes d'article_images n'ont pas de fichier : la page d'un article ne lit que leurs colonnes, seule la
  # route des images (hors mesure) lirait le bucket. Le texte cite ses cinq images par sgid, comme Action Text l'enregistre.
  def seed_blog
    author = Orm::User.find_by!(contact: "0700000000").id
    statuses = Array.new(ARTICLES, "published") + %w[draft draft archived]
    image_ids = insert(Orm::ArticleImage, Array.new(statuses.size * (ARTICLE_IMAGES + 1)) do |index|
      { public_id:, alt: "Illustration #{index + 1}", content_type: "image/webp", byte_size: 180_000, width: 1600, height: 1067,
        created_at: now, updated_at: now }
    end, returning: %w[id])
    images = Orm::ArticleImage.where(id: image_ids).order(:id).each_slice(ARTICLE_IMAGES + 1).to_a
    rows = statuses.each_with_index.map do |status, index|
      title = "Réviser le BEPC, conseil #{index + 1}"
      published_at = (now - (index + 1).days unless status == "draft")
      { public_id:, slug: title.parameterize, title:, excerpt: "Une méthode simple pour réviser, semaine après semaine.",
        cover_image_id: images[index].first.id, cover_alt: "Une élève qui révise", signature: index.even? ? "team" : "author",
        status:, published_at:, archived_at: (now if status == "archived"), author_id: author, created_at: now, updated_at: now }
    end
    article_ids = insert(Orm::Article, rows, returning: %w[id])
    insert(ActionText::RichText, article_ids.each_with_index.map do |id, index|
      Orm::ArticleImage.where(id: images[index].map(&:id)).update_all(article_id: id)
      { record_type: "Orm::Article", record_id: id, name: "body", body: article_body(images[index].drop(1)), created_at: now,
        updated_at: now }
    end)
    log "#{ARTICLES} articles publiés, 2 brouillons, 1 archivé, #{image_ids.size} images"
  end

  # 1 500 mots en quinze paragraphes, un intertitre, et une image tous les trois paragraphes.
  def article_body(images)
    paragraphs = Array.new(15) { "<div>#{(%w[Révisez chaque jour un chapitre court puis refaites les exercices corrigés] * 10).join(' ')}.</div>" }
    attachments = images.map do |image|
      %(<action-text-attachment sgid="#{image.attachable_sgid}" content-type="image/webp" width="1600" height="1067">) +
        "</action-text-attachment>"
    end
    "<h2>Le plan</h2>" + paragraphs.each_slice(3).zip(attachments).flatten.compact.join
  end

  # La direction de l'établissement focus (ADR-0065).
  def seed_admin(focus)
    id = insert(Orm::User, [ user_row(contact: ADMIN_CONTACT, role: "school_admin", created_at: days_ago(30)) ], returning: %w[id]).first
    insert(Orm::SchoolStaff, [ { user_id: id, school_id: focus.id, created_at: now } ])
    log "direction #{ADMIN_CONTACT} de « #{focus.name} »"
  end

  def report
    %w[schools classrooms users classroom_students teacher_classrooms courses essentials exercises questions answers
       classroom_assignments exercise_sessions exercise_badges knowledge_gaps referrals referral_shares articles
       article_images].each do |table|
      log format("%-22s %9d", table, ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table}"))
    end
  end
end
