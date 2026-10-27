require "test_helper"

# CA-1 to CA-3, ADR-XXXX (contenu-en-blocs, #318): the course sheet adapter on the real engine and repositories. A sheet
# arrives whole on its lesson, or not at all; an existing sheet is skipped and never touched.
module UseCases
  module Catalog
    class ImportCourseSheetTest < ActiveSupport::TestCase
      setup do
        @author = create_team_member(team_role: "content", second_factor: false)
        @course = create_course(name: "La propriété de Thalès", status: "published")
      end

      def adapter = ImportCourseSheet.new(courses: Repositories::Catalog::CourseRepository.new, sheets: Repositories::Catalog::CourseSheetRepository.new)

      def run_import(document, adapter: self.adapter, transaction: Repositories::Shared::Transaction.new)
        report = create_import_report(kind: "course_sheet", imported_by: @author)
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "thales.json") ])
        UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction:, clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(course: @course.slug, theme: "blue", **document)
        { "format" => "lnclass.course-sheet", "version" => 1, "course" => course, "theme" => theme, **course_sheet_document, **document }
      end

      def first_block(doc) = doc["pages"][0]["sections"][0]["blocks"][0]

      test "CA-1: a valid file gives the lesson its sheet, counted once" do
        report = run_import(document(theme: "teal"))

        assert_equal "completed", report.status
        assert_equal [ 1, 1, 0, 0 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        sheet = Orm::CourseSheet.find_by!(course_id: @course.id)
        assert_equal [ "teal", 1, 3 ], [ sheet.theme, sheet.format_version, sheet.document["pages"].size ]
        assert_equal course_sheet_document.keys.sort, sheet.document.keys.sort
        assert_equal course_sheet_document["glossary"], sheet.document["glossary"]
      end

      test "CA-1: a draft lesson takes a sheet too, the target is by exact slug" do
        draft = create_course(name: "Brouillon", status: "draft")

        assert_equal 1, run_import(document(course: draft.slug)).imported_count
        assert_equal :not_found, adapter.resolve_target(document: { "course" => "brouillon-inconnu" }).code
        assert_equal :not_found, adapter.resolve_target(document: { "course" => "Brouillon" }).code
        assert_equal draft.id, adapter.resolve_target(document: { "course" => " #{draft.slug} " }).value.id
      end

      test "an unknown lesson rejects the whole file, nothing is written" do
        report = run_import(document(course: "inconnue"))

        assert_equal [ "rejected", 0 ], [ report.status, Orm::CourseSheet.count ]
        assert_equal [ [ "course", "unknown_target" ] ], report.import_errors.map { it.values_at("path", "code") }
      end

      test "CA-3: an existing sheet is skipped and left untouched" do
        existing = create_course_sheet(course: @course, theme: "burgundy")

        report = run_import(document(theme: "teal"))

        assert_equal [ 1, 0, 1, 0 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ "burgundy", existing.updated_at ], existing.reload.then { [ it.theme, it.updated_at ] }
        assert_equal 1, Orm::CourseSheet.count
      end

      test "CA-2: HTML in a block refuses the whole file, the report names the block by its path" do
        doc = document
        doc["pages"][1]["sections"][0]["blocks"][1] = { "type" => "paragraph", "text" => "<script>alert(1)</script>" }

        report = run_import(doc)

        assert_equal [ "rejected", 0 ], [ report.status, Orm::CourseSheet.count ]
        assert_equal [ [ "pages[1].sections[0].blocks[1].text", "schema" ] ], report.import_errors.map { it.values_at("path", "code") }.first(1)
      end

      test "CA-2: what the schema cannot say is refused by the sheet document, with page, section, position and reason" do
        doc = document
        doc["pages"][1]["sections"][0]["blocks"][1] = { "type" => "paragraph", "text" => "Voir [[absent|ici]]." }
        doc["pages"][1]["sections"][0]["blocks"][2] = { "type" => "exercise", "title" => "T", "prompt" => "P", "fields" => [
          { "id" => "a", "input" => "numeric", "label" => "A", "answer" => 1 }, { "id" => "a", "input" => "numeric", "label" => "B", "answer" => 2 }
        ] }

        report = run_import(doc)

        assert_equal [ 1, 0, 0, 1 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "pages[1].sections[0].blocks[1]", "invalid_value", [ 2, 1, 2, "unknown_glossary_key", "absent" ] ],
                       [ "pages[1].sections[0].blocks[2]", "invalid_value", [ 2, 1, 3, "duplicate_id", "a" ] ] ],
                     report.import_errors.map { [ it["path"], it["code"], it["params"].values_at("page", "section", "position", "reason", "detail") ] }
      end

      test "CA-2: an unknown kind is refused as a whole by the schema, nothing is written" do
        doc = document
        doc["pages"][2]["sections"][0]["blocks"] << { "type" => "media", "kind" => "inconnu" }

        report = run_import(doc)

        assert_equal [ "rejected", 0 ], [ report.status, Orm::CourseSheet.count ]
        assert(report.import_errors.any? { it["path"].start_with?("pages[2]") })
      end

      test "CA-2: a bad envelope (unknown theme, extra key) is refused as a whole by the schema" do
        assert_equal "rejected", run_import(document(theme: "rose")).status
        assert_equal "rejected", run_import(document("intrus" => 1)).status
        assert_equal 0, Orm::CourseSheet.count
      end

      test "a sheet the base refuses after validation fails the import loudly, nothing is written" do
        failing = Class.new(Repositories::Catalog::CourseSheetRepository) do
          def create(sheet:) = Shared::Result.failure(:conflict, errors: { course_id: [ :taken ] })
        end

        assert_raises(ImportCourseSheet::WriteFailed) do
          run_import(document, adapter: ImportCourseSheet.new(courses: Repositories::Catalog::CourseRepository.new, sheets: failing.new))
        end

        assert_equal [ "failed", 0 ], [ Orm::ImportReport.order(:id).last.status, Orm::CourseSheet.count ]
      end

      test "honours the importer contract, with the content policy, and validate_root writes nothing" do
        context = adapter.prepare(target: adapter.resolve_target(document: document).value)

        assert_importer_contract ImportCourseSheet, adapter:, root: adapter.resolve_target(document: document) && document.slice("theme", "pages", "glossary"), context: context
        assert_equal Policies::Catalog::ManageContentPolicy, ImportCourseSheet::POLICY
        assert_equal ImportCourseSheet::POLICY, Entities::Catalog::ImportKind.fetch(ImportCourseSheet::KIND).policy
      end

      test "the import kind is registered with its format, its target and a 1 MB ceiling per file" do
        kind = Entities::Catalog::ImportKind.fetch("course_sheet")

        assert_equal [ "lnclass.course-sheet", 1, "course", true, 1, 1.megabyte ],
                     [ kind.format, kind.version, kind.target_key, kind.target_required, kind.max_files, kind.max_total_bytes ]
        assert_equal "Catalog::ImportCourseSheetJob", Rails.application.config.x.import_jobs.fetch("course_sheet")
        assert Dtos::Catalog::ImportUploadInput.new(kind: "course_sheet", files: [ Dtos::Catalog::ImportUploadInput::Upload.new(io: StringIO.new("a" * 1.1.megabytes), filename: "gros.json") ]).invalid?
      end
    end
  end
end
