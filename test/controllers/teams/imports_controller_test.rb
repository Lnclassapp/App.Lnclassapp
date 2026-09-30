require "test_helper"

# ADR-0039, UDR-0006: the imports screen of the team — list, upload in the modal frame, tracking frame.
class Teams::ImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @member = create_team_member
  end

  def upload(content = schools_document(count: 2, drena: "drena-abidjan-2").to_json, filename: "ecoles.json")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/json", original_filename: filename)
  end

  # files : un fichier ou une liste (import[files][]), ADR-0068.
  def post_import(files: upload, kind: "schools", as: :turbo_stream)
    post teams_imports_path, params: { import: { kind:, files: Array.wrap(files) } }, as:
  end

  test "a teacher receives 403 on every action" do
    sign_in_as create_teacher

    get teams_imports_path
    assert_response :forbidden
    get new_teams_import_path(kind: "schools")
    assert_response :forbidden
    post_import(as: nil)
    assert_response :forbidden
  end

  test "the list shows recent reports, and filters them by kind" do
    create_import_report(kind: "schools", status: "completed", imported_count: 12, total_count: 12)
    create_import_report(kind: "exercises", status: "rejected")
    sign_in_as @member

    get teams_imports_path

    assert_response :success
    assert_select "nav a[href='#{teams_imports_path}'][aria-current=page]", text: "Imports"
    assert_select "#imports tr", 2
    assert_select "#imports", text: /Terminé/
    assert_select "#imports", text: /Rejeté/
    assert_select "a[data-turbo-frame=modal][href='#{new_teams_import_path(kind: 'course_tree')}']"

    get teams_imports_path(kind: "exercises")

    assert_select "#imports tr", 1
    assert_select "#imports", text: /Exercices/
    assert_select "nav a[aria-current=page]", text: "Exercices"
  end

  test "an empty list says so" do
    sign_in_as @member

    get teams_imports_path(kind: "unknown")

    assert_select "#imports tr", 0
    assert_select "#imports_empty", text: /Aucun import/
  end

  test "the upload form opens in the modal frame, with the limits of its kind" do
    sign_in_as @member

    get new_teams_import_path(kind: "schools"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal", 1
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#import-upload-modal"
    assert_select "input[type=file][name='import[files][]'][accept='.json,application/json']:not([multiple])"
    assert_select "#import_files_summary", 0
    assert_select "input[type=hidden][name='import[kind]'][value=schools]"
    assert_select "#import_io_hint", text: /20 Mo au plus, avec 5 000 éléments au plus/
  end

  # ADR-0066, UDR-0053 §3: the schools help cites the DRENA by their prefixed slug.
  test "the schools help gives an example and a list of DRENA slugs, all prefixed drena-" do
    create_drena(name: "Abidjan 2")
    sign_in_as @member

    get new_teams_import_path(kind: "schools"), headers: { "Turbo-Frame" => "modal" }

    assert_select "#import-help-schools pre code", text: /"drena": "drena-abidjan-1",.*"drena": "drena-abidjan-2"/m
    assert_select "#import-help-schools pre code", text: /"drena": "abidjan-/, count: 0
    assert_select "#import-help-drenas li code", "drena-abidjan-2"
  end

  test "an unknown kind has no upload form" do
    sign_in_as @member

    get new_teams_import_path(kind: "unknown")
    assert_response :not_found
    post_import(kind: "unknown", as: nil)
    assert_response :not_found
  end

  test "a file over 20 MB is refused in the modal, and nothing is created" do
    sign_in_as @member

    assert_no_difference -> { Orm::ImportReport.count } do
      post_import(files: upload("x" * (Entities::Catalog::ImportKind::MAX_BYTES + 1)), as: nil)
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal #import_io_error", text: "« ecoles.json » dépasse 20 Mo."
    assert_select "input[type=file][aria-invalid=true]"
  end

  test "a file that is not JSON, or no file at all, is refused" do
    sign_in_as @member

    post_import(files: upload(filename: "ecoles.csv"), as: nil)
    assert_response :unprocessable_entity
    assert_select "#import_io_error", text: "« ecoles.csv » n'est pas un fichier .json."

    post_import(files: "pas un fichier", as: nil)
    assert_response :unprocessable_entity
    assert_select "#import_io_error", text: "Choisissez au moins un fichier .json."
  end

  # IM-09 : les autres types n'acceptent qu'un fichier, même par une requête forgée.
  test "IM-09 two files for a single-file kind are refused, and nothing is created" do
    sign_in_as @member

    assert_no_difference -> { Orm::ImportReport.count } do
      post_import(files: [ upload, upload(filename: "autres.json") ], as: nil)
    end

    assert_response :unprocessable_entity
    assert_select "#import_io_error", text: "Vous avez choisi 2 fichiers : 1 au plus."
  end

  # IM-07 : les limites d'un envoi de cours complets, vérifiées par le serveur.
  test "IM-07 51 course files, or 50 MB and a byte in total, are refused without a report" do
    sign_in_as @member
    small = ->(index) { upload("{}", filename: "cours-#{index}.json") }

    assert_no_difference -> { Orm::ImportReport.count } do
      post_import(files: Array.new(51) { small.(it) }, kind: "course_tree", as: nil)
      assert_select "#import_io_error", text: "Vous avez choisi 51 fichiers : 50 au plus."

      full = [ 20, 20, 10 ].each_with_index.map { |megabytes, index| upload("x" * (megabytes * 1024 * 1024), filename: "#{index}.json") }
      post_import(files: [ *full, upload("x", filename: "un-octet.json") ], kind: "course_tree", as: nil)
      assert_select "#import_io_error", text: "Les fichiers font 50,0 Mo au total : 50 Mo au plus."
    end
    assert_response :unprocessable_entity
  end

  # IM-10 : l'autorisation ne change pas avec plusieurs fichiers.
  test "IM-10 a teacher posting two course files is refused, and nothing is created" do
    sign_in_as create_teacher

    assert_no_difference -> { Orm::ImportReport.count } do
      post_import(files: [ upload("{}", filename: "a.json"), upload("{}", filename: "b.json") ], kind: "course_tree", as: nil)
    end
    assert_response :forbidden
  end

  # IM-01 (envoi) : plusieurs fichiers de cours, un rapport, les noms dans l'ordre d'envoi, deux noms identiques distingués.
  test "IM-01 several course files make one report, their names kept in upload order" do
    sign_in_as @member

    assert_enqueued_with(job: Catalog::ImportCourseTreeJob) do
      post_import(files: [ upload("{}", filename: "cours.json"), upload("[]", filename: "a.json"), upload("{ }", filename: "cours.json") ],
                  kind: "course_tree")
    end

    report = Orm::ImportReport.sole
    assert_equal [ "cours.json", "a.json", "cours.json (2)" ], report.files.map { it["name"] }
    assert_equal [ "{}", "[]", "{ }" ], report.sources.map(&:download)
    assert_select "turbo-stream[action=prepend][target=imports] tr#import_#{report.public_id}", text: /cours\.json et 2 autres fichiers/
  end

  # UDR-0055 §3.1 : la modale des cours complets accepte plusieurs fichiers et prépare le résumé de la sélection.
  test "the course upload form takes several files, with the limits of the kind and the selection summary" do
    sign_in_as @member

    get new_teams_import_path(kind: "course_tree"), headers: { "Turbo-Frame" => "modal" }

    assert_select "form#import-upload-form[data-controller='teams--import-files'][data-teams--import-files-max-files-value='50']"
    assert_select "form[data-teams--import-files-max-total-bytes-value='#{50 * 1024 * 1024}'][data-teams--import-files-one-text-value='1 fichier · %{size}']"
    assert_select "input[type=file][multiple][name='import[files][]'][aria-describedby='import_io_hint import_files_summary']"
    assert_select "#import_io_hint", text: "Jusqu'à 50 fichiers .json, 50 Mo au total, 20 Mo au plus par fichier, 500 cours au plus en tout."
    assert_select "#import_files_summary[aria-live=polite] #import_files_error[role=alert][hidden]"
    assert_select "#import-help-multiple", text: /jusqu'à 50 fichiers/
  end

  test "a second import of the same kind while one runs is refused with its reason" do
    create_import_report(kind: "schools", status: "queued")
    sign_in_as @member

    with_fake_import_job { post_import(as: nil) }

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal [role=alert]", text: "Un import de ce type est déjà en cours."
  end

  test "an accepted file answers in Turbo Stream: toast, tracking in the modal, row on top of the list" do
    sign_in_as @member

    with_fake_import_job do
      assert_enqueued_with(job: FakeImportJob) { post_import }
    end

    report = Orm::ImportReport.sole
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: /Import lancé/
    assert_select "turbo-stream[action=update][target=modal] turbo-frame#import_status[data-controller='teams--import-status']"
    assert_select "turbo-stream[action=update][target=modal] [data-status=queued]"
    # UDR-0054 §3.1: the tracking modal names the tab like the page of the report.
    tab = "Import d'établissements · Équipe · Lnclass"
    assert_select "turbo-stream[action=update][target=modal] #import-tracking-modal", 1
    assert_select "turbo-stream[action=update][target=modal] [data-modal-document-title-value=\"#{tab}\"]"
    assert_select "turbo-stream[action=prepend][target=imports] tr#import_#{report.public_id}", text: /ecoles\.json/
    assert_equal @member.id, report.imported_by_id
  end

  test "without Turbo, an accepted file leads to its tracking page" do
    sign_in_as @member

    with_fake_import_job { post_import(as: nil) }

    assert_redirected_to teams_import_path(Orm::ImportReport.sole.public_id)
  end

  test "the tracking page shows a finished report, its counts, details and errors" do
    report = create_import_report(status: "completed", total_count: 4, imported_count: 1, skipped_count: 1, error_count: 2,
                                  details: { "classrooms" => 77, "levels_skipped" => 2 }, finished_at: Time.current,
                                  import_errors: [ { "path" => "schools[3].name", "code" => "blank", "params" => {} },
                                                   { "path" => "schools[4]", "code" => "schema", "params" => { "keyword" => "required" } } ])
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_response :success
    assert_select "h1", "Import : Établissements"
    assert_select "nav a[href='#{teams_imports_path}'][aria-current=page]", text: "Imports"
    assert_select "#import_counter_imported", "1"
    assert_select "#import_counter_total", "4"
    assert_select "li", text: /Classes générées : 77/
    assert_select "li", text: /Levels skipped : 2/
    assert_select "#import_errors li", 2
    assert_select "#import_errors li", text: /schools\[4\]\s*Clé obligatoire manquante\./
  end

  # IM-08, IM-12 (UDR-0055 §3.2, §3.3, §3.4) : le bilan par fichier, l'erreur qui nomme son fichier, le nom de l'import.
  test "the tracking page of several files lists each file, and each error names its file" do
    report = create_import_report(
      kind: "course_tree", status: "completed", total_count: 3, imported_count: 2, error_count: 1, finished_at: Time.current,
      import_errors: [ { "path" => "courses[0].essentials[1].name", "code" => "blank", "params" => {}, "file" => "b.json" } ],
      files: [ { "name" => "a.json", "byte_size" => 9, "status" => "read", "imported" => 2, "skipped" => 0, "errors" => 0 },
               { "name" => "b.json", "byte_size" => 9, "status" => "read", "imported" => 0, "skipped" => 0, "errors" => 1 },
               { "name" => "c.json", "byte_size" => 9, "status" => "rejected", "reason" => { "code" => "json_invalid", "params" => {} },
                 "imported" => 0, "skipped" => 0, "errors" => 0 } ]
    )
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_select "p", text: /a\.json et 2 autres fichiers/
    assert_select "#import_files_title", "Fichiers (3)"
    assert_select "#import_files li", 3
    assert_select "#import_files li:nth-child(1)", text: /a\.json\s*2 importés · 0 ignoré · 0 en erreur/
    assert_select "#import_files li:nth-child(3)", text: /c\.json\s*Refusé\s*Le fichier n'est pas un JSON lisible\./
    assert_select "#import_errors li", text: /b\.json\s*courses\[0\]\.essentials\[1\]\.name\s*Valeur obligatoire manquante\./
  end

  test "a report whose files were all refused says so, and lists each file" do
    report = create_import_report(
      kind: "course_tree", status: "rejected", finished_at: Time.current,
      import_errors: [ { "path" => "$", "code" => "json_invalid", "params" => {}, "file" => "a.json" },
                       { "path" => "$", "code" => "json_invalid", "params" => {}, "file" => "b.json" } ],
      files: %w[a.json b.json].map { { "name" => it, "byte_size" => 1, "status" => "rejected", "reason" => { "code" => "json_invalid", "params" => {} } } }
    )
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_select "[role=alert]", text: /Aucun fichier n'a pu être lu/
    assert_select "#import_files li", 2
  end

  test "the tracking frame alone answers a request coming from the frame" do
    report = create_import_report(status: "importing", processed_count: 200)
    sign_in_as @member

    get teams_import_path(report.public_id), headers: { "Turbo-Frame" => "import_status" }

    assert_response :success
    assert_no_match "<html", response.body
    assert_select "turbo-frame#import_status[data-teams--import-status-url-value='#{teams_import_path(report.public_id)}'] [data-status=importing]"
    assert_select "progress"
    assert_match "200 éléments vérifiés", response.body
  end

  test "a rejected report shows its reason; a failed one says it stopped" do
    rejected = create_import_report(status: "rejected", finished_at: Time.current,
                                    import_errors: [ { "path" => "format", "code" => "format_mismatch",
                                                       "params" => { "expected" => "lnclass.schools" } } ])
    failed = create_import_report(kind: "exercises", status: "failed", finished_at: Time.current)
    sign_in_as @member

    get teams_import_path(rejected.public_id)
    assert_select "[role=alert]", text: /rejeté en bloc/
    assert_select "#import_errors li", text: /attendu : lnclass\.schools/

    get teams_import_path(failed.public_id)
    assert_select "[role=alert]", text: /erreur imprévue/
  end

  # UDR-0053 (amendment): a file of schools uploaded to the DRENA import names the right import.
  test "a file of another import kind names that kind in the report" do
    report = create_import_report(kind: "drenas", status: "rejected", finished_at: Time.current,
                                  import_errors: [ { "path" => "format", "code" => "format_mismatch",
                                                     "params" => { "expected" => "lnclass.drenas", "received" => "lnclass.schools" } } ])
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_select "#import_errors li",
                  text: /Ce fichier est un import « Établissements » \(format lnclass\.schools\), pas un import « DRENA »/
  end

  test "a generation of the classrooms: listed and filtered, its report without a file and with its own words (ADR-0056)" do
    author = create_team_member(first_name: "Awa", last_name: "Koné", second_factor: false)
    report = create_import_report(kind: "classrooms", checksum_sha256: nil, imported_by: author, status: "completed",
                                  total_count: 5, imported_count: 3, skipped_count: 1, error_count: 1, finished_at: Time.current,
                                  details: { "classrooms_created" => 150, "skipped_levels" => 2 },
                                  import_errors: [ { "path" => "Lycée Moderne", "code" => "write_failed", "params" => {} } ])
    create_import_report(kind: "schools")
    sign_in_as @member

    get teams_imports_path(kind: "classrooms")

    assert_select "#imports tr", 1
    assert_select "nav a[aria-current=page]", text: "Génération des classes"
    assert_select "#import_#{report.public_id} a[href='#{teams_import_path(report.public_id)}']", text: "Voir le rapport"
    assert_select "a[href=?]", new_teams_import_path(kind: "classrooms"), 0
    assert_select "a[href=?]", new_teams_import_path(kind: "schools"), 1

    get teams_import_path(report.public_id)

    assert_response :success
    assert_select "h1", "Génération des classes"
    assert_select "p", text: /\A\s*Awa Koné · /
    assert_select "dt", text: "Établissements dotés"
    assert_select "dt", text: "Sans classe à générer"
    assert_select "dt", text: "Établissements examinés"
    assert_select "#import_counter_imported", "3"
    assert_select "li", text: /Classes générées : 150/
    assert_select "li", text: /Niveaux sautés .* : 2/
    assert_select "#import_errors li", text: /Lycée Moderne\s*L'enregistrement de cet élément n'a pas abouti\./
  end

  test "a generation running or failed speaks of schools, not of a file" do
    running = create_import_report(kind: "classrooms", checksum_sha256: nil, status: "importing", processed_count: 400)
    sign_in_as @member

    get teams_import_path(running.public_id), headers: { "Turbo-Frame" => "import_status" }
    assert_match "400 établissements traités", response.body
    assert_match "Génération des classes en cours…", response.body

    running.update!(status: "failed", finished_at: Time.current)
    get teams_import_path(running.public_id)
    assert_select "[role=alert]", text: /La génération s'est arrêtée sur une erreur imprévue/
  end

  # finitions-generation-menu: the status badge follows the kind too — a generation is never « Import en cours ».
  test "the status badge of a generation speaks of a generation, in the list as in its report" do
    running = create_import_report(kind: "classrooms", checksum_sha256: nil, status: "importing")
    checking = create_import_report(kind: "schools", status: "validating")
    sign_in_as @member

    get teams_imports_path

    assert_select "#import_#{running.public_id}", text: /Génération en cours/
    assert_select "#import_#{running.public_id}", text: /Import en cours/, count: 0
    assert_select "#import_#{checking.public_id}", text: /Vérification/

    get teams_import_path(running.public_id)

    assert_select "#import_status [data-status=importing] > div:first-child", text: /Génération en cours/
    assert_select "#import_status", text: /Import en cours/, count: 0

    running.update!(status: "validating")
    get teams_import_path(running.public_id), headers: { "Turbo-Frame" => "import_status" }

    assert_select "[data-status=validating] > div:first-child", text: /Recherche des établissements/
  end

  test "a teacher may not read the report of a generation" do
    report = create_import_report(kind: "classrooms", checksum_sha256: nil)
    sign_in_as create_teacher

    get teams_import_path(report.public_id)

    assert_response :forbidden
  end

  test "beyond 1 000 errors, the rest is announced" do
    errors = Array.new(Entities::Catalog::ImportKind::MAX_ERRORS) { { "path" => "schools[#{it}].name", "code" => "blank", "params" => {} } }
    report = create_import_report(status: "completed", error_count: 1_001, total_count: 1_001, import_errors: errors,
                                  finished_at: Time.current)
    sign_in_as @member

    get teams_import_path(report.public_id)

    assert_select "#import_errors li", 1_000
    assert_match "Et 1 autre élément en erreur, non détaillé.", response.body
  end

  test "an unknown report is not found" do
    sign_in_as @member

    get teams_import_path("inconnu")

    assert_response :not_found
  end
end
