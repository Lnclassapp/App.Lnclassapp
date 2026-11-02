require "application_system_test_case"
require "open3"
require "tmpdir"

# standard-de-test, Lot D (ADR standard-de-test §4 point 4) : une leçon v3 se rend ou le test dit pourquoi.
# Chaque fichier choisi est importé par la vraie chaîne (StartImport → RunImport, comme db/seeds/demo/lecons_completes.rb) dans la
# base de test, publié, puis lu par un élève de la bonne classe à 390 px puis sur ordinateur. Échecs, avec fichier, largeur et défaut :
# import refusé (code du refus), page plus large que l'écran, « ** » dans le texte rendu, figure du fichier absente de la page.
#
# Quels fichiers : LECONS=<chemins séparés par des virgules> ; sinon LECONS=tout (LECONS_PART=i/n pour découper, tâche `lecons`
# du train) ; sinon les fichiers v3 de docs/contenus/lecons-traitees changés depuis origin/Develop (hors CI, où le train a sa tâche).
# Aucun fichier : aucun test de leçon, et pas d'échec. Dérogation au budget système : script/ci/system_budget.rb.
module LessonRendering
  DIRECTORY = "docs/contenus/lecons-traitees".freeze
  TRAPS = "test/fixtures/files/lecons_piegees".freeze
  PHONE = 390
  DESKTOP = 1400

  Defect = Data.define(:file, :width, :kind) do
    def to_s = "#{file} — #{width.is_a?(Integer) ? "#{width} px" : width} — #{kind}"
  end

  # Le choix des fichiers, sans navigateur ni base.
  module Selection
    module_function

    # Un fichier illisible compte : il est choisi, et la vérification le signale comme un import refusé (jamais écarté en silence).
    def v3?(path)
      document = JSON.parse(File.read(path))
      !document.is_a?(Hash) || document["version"] == Entities::Catalog::ImportKind::COURSE_TREE_VERSION
    rescue JSON::ParserError
      true
    rescue Errno::ENOENT
      false
    end

    def all(root = Rails.root) = Dir[root.join(DIRECTORY, "*/*/*.json")].sort.select { v3?(it) }.map { Pathname(it).relative_path_from(root).to_s }

    # Les i-ièmes d'un partage glouton par taille (le plus gros d'abord dans la part la plus légère) : même découpage partout.
    def part(files, label, root = Rails.root)
      return files if label.blank?

      index, count = label.split("/").map { Integer(it) }
      raise ArgumentError, "LECONS_PART doit valoir i/n avec 1 <= i <= n : #{label}" unless count&.positive? && index&.between?(1, count)

      loads = Array.new(count) { [ 0, [] ] }
      files.sort_by { [ -File.size(root.join(it)), it ] }.each do |file|
        lightest = loads.min_by.with_index { |(size, _), position| [ size, position ] }
        lightest[0] += File.size(root.join(file))
        lightest[1] << file
      end
      loads.fetch(index - 1).last.sort
    end

    def named(list, root = Rails.root)
      list.split(",").map(&:strip).reject(&:empty?).map do |name|
        path = [ name, File.join(DIRECTORY, name) ].find { root.join(it).file? }
        raise ArgumentError, "LECONS : fichier introuvable : #{name}" unless path

        path
      end
    end

    # Les fichiers de leçon que la branche touche depuis la base : validés, modifiés, ajoutés, ou pas encore ajoutés.
    def changed(base: ENV.fetch("BASE", "origin/Develop"), root: Rails.root)
      merge_base, found = Open3.capture2("git", "merge-base", base, "HEAD", chdir: root.to_s, err: File::NULL)
      unless found.success?
        warn "LECONS : #{base} introuvable (le dépôt n'a pas cette branche de comparaison) : aucune leçon changée ne peut être choisie, aucune ne sera rendue."
        return []
      end

      diff, = Open3.capture2("git", "diff", "--name-only", merge_base.strip, chdir: root.to_s, err: File::NULL)
      untracked, = Open3.capture2("git", "ls-files", "--others", "--exclude-standard", chdir: root.to_s, err: File::NULL)
      (diff.lines + untracked.lines).map(&:strip).uniq.grep(%r{\A#{Regexp.escape(DIRECTORY)}/[^/]+/[^/]+/[^/]+\.json\z})
                                    .select { root.join(it).file? && v3?(root.join(it)) }.sort
    end

    def call(env = ENV)
      chosen = env["LECONS"].to_s.strip
      return part(all, env["LECONS_PART"]) if chosen == "tout"
      return named(chosen) unless chosen.empty?

      env["CI"].present? ? [] : changed
    end
  end

  # La vérification d'un fichier : défauts trouvés, liste vide si la leçon se rend. Mêlé aux tests système.
  module Verifier
    FIGURE_WAIT = 10

    # path : relatif à la racine du dépôt.
    def defects_for(path)
      begin
        document = JSON.parse(Rails.root.join(path).read)
        lesson = document.fetch("courses").first
        raise KeyError, "pas de leçon" unless lesson.is_a?(Hash)
      rescue JSON::ParserError, KeyError, NoMethodError, TypeError => error
        return [ LessonRendering::Defect.new(path, "import", "import refusé : JSON illisible (#{error.class}: #{error.message.lines.first.to_s.strip[0, 80]})") ]
      end
      seed_referential
      # L'EDHC est dans le référentiel réel (db/seeds/demo/trois_etablissements.rb) mais pas dans la fabrique de tests.
      create_material(name: "EDHC", shortname: "EDHC", category: "other", position: 7)
      team = create_team_member(team_role: "admin", second_factor: false)
      actor = Repositories::Identity::UserRepository.new.actor_for(user_id: team.id)
      refusal = import(document, actor:, filename: File.basename(path))
      return [ LessonRendering::Defect.new(path, "import", refusal) ] if refusal

      course = Orm::Course.joins(:level, :material).left_joins(:series)
                          .find_by(name: lesson["name"], levels: { name: lesson["level_name"] },
                                   materials: { name: lesson["material_name"] }, series: { name: lesson["series_name"] })
      return [ LessonRendering::Defect.new(path, "import", "import refusé : aucun cours créé") ] unless course

      publish(course, actor:)
      sign_in_as create_student_for(course)
      with_mobile_viewport(LessonRendering::PHONE.then { [ it, 844 ] }) { inspect_page(path, course, lesson, LessonRendering::PHONE) } +
        inspect_page(path, course, lesson, LessonRendering::DESKTOP)
    end

    private

    # nil si la chaîne d'import a écrit la leçon, sinon « import refusé : » et les codes de refus du rapport.
    def import(document, actor:, filename:)
      transaction = Repositories::Shared::Transaction.new
      reports = Repositories::Catalog::ImportReportRepository.new
      files = Repositories::Catalog::ImportFileStore.new
      queue = Object.new.tap { |q| q.define_singleton_method(:enqueue) { |**| nil } }
      upload = Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new(JSON.generate(document)), filename:)
      started = UseCases::Catalog::StartImport.new(reports:, files:, queue:, transaction:, clock: Time.zone)
                                              .call(actor:, dto: Dtos::Catalog::ImportUploadInput.new(kind: "course_tree", files: [ upload ]))
      return "import refusé : #{started.errors}" if started.failure?

      UseCases::Catalog::RunImport.new(
        adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), schema: Repositories::Catalog::ImportSchemaValidator.new, reports:, files:,
        users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
      ).call(report_id: started.value.id)
      report = Orm::ImportReport.find(started.value.id)
      return if report.status == "completed" && report.error_count.zero?

      codes = report.import_errors.map { "#{it['code']} (#{it['path']})" }.uniq
      "import refusé : #{codes.presence&.join(', ') || report.status}"
    end

    def publish(course, actor:)
      dependencies = { audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
                       policy: Policies::Catalog::ManageContentPolicy.new, clock: Time.zone }
      essentials = Repositories::Catalog::EssentialRepository.new
      exercises = Repositories::Assessment::ExerciseRepository.new
      courses = Repositories::Catalog::CourseRepository.new
      result = UseCases::Catalog::PublishCascade.new(
        courses:, essentials:, exercises:, transaction: dependencies[:transaction], policy: dependencies[:policy],
        publish_course: UseCases::Catalog::PublishCourse.new(courses:, **dependencies),
        publish_essential: UseCases::Catalog::PublishEssential.new(essentials:, **dependencies),
        publish_exercise: UseCases::Assessment::PublishExercise.new(exercises:, **dependencies)
      ).call(actor:, root: :course, slug: course.slug)
      raise "publication refusée pour #{course.name} : #{result.errors}" if result.failure?
    end

    # La page de la leçon, lue à la largeur courante de la fenêtre.
    def inspect_page(file, course, lesson, width)
      visit course_path(course.slug)
      assert_selector "h1", text: course.name, wait: 20
      reveal_revision_sheet
      seen = measure_page(lesson)
      defects = []
      defects << "page plus large que l'écran : scrollWidth #{seen['scroll']} > innerWidth #{seen['inner']}" if seen["scroll"] > seen["inner"]
      defects << "** dans le texte rendu : « #{seen['stars']} »" if seen["stars"]
      missing_figures(lesson, seen["figures"]).each { defects << "figure « #{it} » absente de la page ou vide" }
      defects.map { LessonRendering::Defect.new(file, width, it) }
    end

    # La fiche de révision est coupée après 50 mots : « Voir plus » montre les notions suivantes, et leurs figures.
    def reveal_revision_sheet
      return unless page.has_css?("[data-controller~='catalog--revision-more']", wait: 0)

      find("[data-controller~='catalog--revision-more'] button", text: I18n.t("catalog.courses.show.revision_more"),
                                                                  wait: LessonRendering::Verifier::FIGURE_WAIT).click
    end

    MEASURE = <<~JS.freeze
      (() => {
        const shown = (el) => el.getClientRects().length > 0 && el.offsetWidth > 0 && el.offsetHeight > 0
        const figures = [...document.querySelectorAll("figure[data-controller~=figure]")].map((figure) => {
          const canvas = figure.querySelector("[data-figure-target=canvas]")
          return { params: figure.dataset.figureParamsValue, shown: shown(figure) && !!canvas && shown(canvas) && canvas.children.length > 0 }
        })
        const body = document.body.cloneNode(true)
        body.querySelectorAll(".katex, script, style, noscript, template").forEach((node) => node.remove())
        const text = body.textContent
        const at = text.indexOf("**")
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
        let formulas = 0, bare = 0
        for (let node = walker.nextNode(); node; node = walker.nextNode()) {
          const parent = node.parentElement
          if (!parent || parent.closest("script, style, noscript, template")) continue
          if (parent.closest(".katex-html")) formulas += 1
          else if (!parent.closest(".katex, option, textarea, pre, code") && parent.closest("[data-controller~=math]") && /\\$[^$\\n]+\\$/.test(node.textContent)) bare += 1
        }
        return { scroll: document.documentElement.scrollWidth, inner: window.innerWidth, figures, formulas, bare,
                 stars: at < 0 ? null : text.slice(Math.max(0, at - 30), at + 30).replace(/\\s+/g, " ") }
      })()
    JS

    # Les formules sont rendues par KaTeX, chargé à la demande (app/javascript/controllers/math_controller.js, asynchrone) : tant
    # qu'un « $…$ » reste en texte brut hors d'un .katex, la page n'est pas finie. Le texte des formules (.katex, avec son
    # .katex-mathml caché) ne compte pas pour « ** » : c'est du code TeX. Les styles de la page : course_sheet.css, prepare_sheet.css.
    # Attend que la page soit finie : formules rendues et stables (leur nombre ne bouge plus d'une mesure à l'autre) et chaque figure
    # du fichier dessinée au moins une fois (une figure montrée deux fois n'arrête pas l'attente). Puis rend la dernière mesure.
    def measure_page(lesson)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + LessonRendering::Verifier::FIGURE_WAIT
      previous = nil
      loop do
        seen = page.evaluate_script(MEASURE)
        done = seen["bare"].zero? && seen["formulas"] == previous && missing_figures(lesson, seen["figures"]).empty?
        return seen if done || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        previous = seen["formulas"]
        sleep 0.25
      end
    end

    # Les clés des figures du fichier dont aucun exemplaire dessiné n'a les mêmes paramètres.
    def missing_figures(lesson, rendered)
      drawn = rendered.select { it["shown"] }.map { JSON.parse(it["params"].to_s) }
      lesson.fetch("figures", []).reject { |figure| drawn.include?(figure["params"]) }.map { it["key"] }
    end
  end
end

# Une leçon par test, définie à partir de la sélection.
class Catalog::LessonRenderingTest < ApplicationSystemTestCase
  include LessonRendering::Verifier

  LessonRendering::Selection.call.each do |file|
    test "la leçon #{file.delete_prefix("#{LessonRendering::DIRECTORY}/")} se rend à 390 px et sur ordinateur" do
      defects = defects_for(file)

      assert_empty defects, "Leçon non conforme :\n#{defects.map { "  - #{it}" }.join("\n")}"
    end
  end
end

# La vérification elle-même, rouge sur chaque fichier piégé, verte sur le conforme. Absente de la tâche `lecons` du train, qui ne
# rend que les leçons (elle joue dans la tâche système, avec ce fichier).
class Catalog::LessonRenderingTrapsTest < ApplicationSystemTestCase
  include LessonRendering::Verifier

  TRAPS = {
    "debordement" => /page plus large que l'écran/,
    "asterisques" => /\*\* dans le texte rendu/,
    "figure_vide" => /figure .* absente de la page/,
    "import_refuse" => /import refusé : unknown_material/,
    "json_casse" => /import refusé : JSON illisible/
  }.freeze

  unless ENV["LECONS"].to_s.strip == "tout"
    TRAPS.each do |name, expected|
      test "le fichier piégé #{name} fait échouer la vérification" do
        defects = defects_for("#{LessonRendering::TRAPS}/#{name}.json")

        assert defects.any? { it.kind.match?(expected) }, "attendu #{expected.inspect}, trouvé : #{defects.map(&:to_s).inspect}"
      end
    end

    test "des « ** » dans une formule ne sont pas un défaut" do
      assert_empty defects_for("#{LessonRendering::TRAPS}/formule_etoiles.json").map(&:to_s)
    end

    test "le fichier conforme passe la vérification" do
      assert_empty defects_for("#{LessonRendering::TRAPS}/conforme.json").map(&:to_s)
    end
  end
end

# Le choix des fichiers, sans navigateur.
class Catalog::LessonSelectionTest < ActiveSupport::TestCase
  def lessons_root
    Pathname(Dir.mktmpdir).tap do |root|
      folder = root.join(LessonRendering::DIRECTORY, "tle-c", "svt")
      folder.mkpath
      folder.join("v3.json").write({ "format" => "lnclass.course-tree", "version" => 3, "courses" => [] }.to_json)
      folder.join("v1.json").write({ "format" => "lnclass.course-tree", "version" => 1, "courses" => [] }.to_json)
      folder.join("casse.json").write("{ pas du json")
    end
  end

  test "un fichier v3 et un fichier illisible sont choisis, un fichier d'un autre format non" do
    root = lessons_root

    assert_equal %w[tle-c/svt/casse.json tle-c/svt/v3.json], LessonRendering::Selection.all(root).map { it.delete_prefix("#{LessonRendering::DIRECTORY}/") }
  ensure
    FileUtils.rm_rf(root) if root
  end

  test "sans point de comparaison avec la base, un avertissement le dit et rien n'est choisi" do
    result = nil
    _, error = capture_io { result = LessonRendering::Selection.changed(base: "origin/branche-inconnue") }

    assert_empty result
    assert_match(%r{origin/branche-inconnue introuvable}, error)
  end
end
