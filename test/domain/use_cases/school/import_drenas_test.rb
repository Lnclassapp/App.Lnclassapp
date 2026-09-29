require "test_helper"

# DR-03, DR-04, DR-05, ADR-0066: the DRENA adapter on the real engine and repository. Each line carries only its name;
# the slug drena-… is drawn from it, and is the duplicate key against the base and the lines above.
module UseCases
  module School
    class ImportDrenasTest < ActiveSupport::TestCase
      setup do
        @author = create_team_member(second_factor: false)
      end

      def adapter = ImportDrenas.new(drenas: Repositories::School::DrenaRepository.new)

      # The real engine, on a report in base and its file.
      def run_import(document)
        report = create_import_report(kind: "drenas", imported_by: @author)
        Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, io: StringIO.new(document.to_json),
                                                          filename: "drenas.json")
        UseCases::Catalog::RunImport.new(
          adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
          schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new,
          clock: Time.zone
        ).call(report_id: report.id)
        report.reload
      end

      def document(*names) = { "format" => "lnclass.drenas", "version" => 1, "drenas" => names.map { { "name" => it } } }

      def validate(root)
        subject = adapter
        subject.validate_root(root:, path: "drenas[0]", context: subject.prepare(target: nil))
      end

      def error_pairs(item) = item.errors.map { [ it.path, it.code ] }

      test "honours the importer contract, and validate_root writes nothing" do
        subject = adapter
        assert_importer_contract ImportDrenas, adapter: subject, root: { "name" => "Abidjan 1" }, context: subject.prepare(target: nil)
        assert_equal "drenas", ImportDrenas::KIND
        assert_equal ImportDrenas::POLICY, Entities::Catalog::ImportKind.fetch(ImportDrenas::KIND).policy
        assert_equal Policies::School::ManageSchoolPolicy, ImportDrenas::POLICY
      end

      test "there is no target; the context holds the slugs and the names in base" do
        Orm::Drena.create!(name: "Bouake 1", slug: "drena-bouake-1")
        subject = adapter

        target = subject.resolve_target(document: document("Man"))
        assert target.success?
        assert_nil target.value

        context = subject.prepare(target: nil)
        assert_nil context.target
        assert_equal [ "drena-bouake-1" ], context.existing_keys.to_a
        assert_equal Set["Bouake 1"], context.data.fetch(:taken_names)
      end

      test "a valid line is keyed by its slug, and plans its public_id, squished name and slug" do
        item = validate({ "name" => "  San-Pédro  " })

        assert item.valid?
        assert_equal "drena-san-pedro", item.key
        assert_equal [ "San-Pédro", "drena-san-pedro" ], item.plan.values_at(:name, :slug)
        assert_equal 14, item.plan.fetch(:public_id).length
        assert_equal %i[public_id name slug], item.plan.keys
        assert_not_equal item.plan[:public_id], validate({ "name" => "San-Pédro" }).plan[:public_id]
      end

      test "DR-05 an empty, blank, missing, too long or letterless name is an error at drenas[i].name" do
        assert_equal [ [ "drenas[0].name", "blank" ] ], error_pairs(validate({ "name" => "" }))
        assert_equal [ [ "drenas[0].name", "blank" ] ], error_pairs(validate({ "name" => "   " }))
        assert_equal [ [ "drenas[0].name", "blank" ] ], error_pairs(validate({}))

        too_long = validate({ "name" => "M" * 81 })
        assert_equal [ [ "drenas[0].name", "too_long" ] ], error_pairs(too_long)
        assert_equal({ max: 80 }, too_long.errors.first.params)
        assert validate({ "name" => "M" * 80 }).valid?

        letterless = validate({ "name" => "???" })
        assert_equal [ [ "drenas[0].name", "no_latin_character" ] ], error_pairs(letterless)
        assert_equal({ value: "???" }, letterless.errors.first.params)
        assert_nil letterless.plan
        assert_nil letterless.key
      end

      test "DR-05 on the engine: every invalid line is in error at its path, the unknown key by the schema, and nothing is created" do
        report = run_import({ "format" => "lnclass.drenas", "version" => 1,
                              "drenas" => [ { "name" => "" }, { "name" => "M" * 81 }, { "name" => "???" },
                                            { "name" => "Man", "code" => "M1" } ] })

        assert_equal [ "completed", 4, 0, 0, 4 ],
                     report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ [ "drenas[0].name", "blank" ], [ "drenas[1].name", "too_long" ], [ "drenas[2].name", "no_latin_character" ] ],
                     report.import_errors.first(3).map { it.values_at("path", "code") }
        assert_equal "schema", report.import_errors.last["code"]
        assert_match(/\Adrenas\[3\]/, report.import_errors.last["path"])
        assert_equal 0, Orm::Drena.count
      end

      test "DR-03 a line whose slug exists, in base or above in the file, is skipped and counted; the existing DRENA is kept" do
        existing = Orm::Drena.create!(name: "Bouake 1", slug: "drena-bouake-1")
        before = existing.reload.attributes

        report = run_import(document("Bouaké 1", "Grand-Bassam", "Grand Bassam"))

        assert_equal [ "completed", 3, 1, 2, 0 ],
                     report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [], report.import_errors
        assert_equal before, existing.reload.attributes
        assert_equal [ [ "Bouake 1", "drena-bouake-1" ], [ "Grand-Bassam", "drena-grand-bassam" ] ],
                     Orm::Drena.order(:name).pluck(:name, :slug)
      end

      test "DR-04 a name taken in base under another slug is in error taken; the other lines are imported" do
        Orm::Drena.create!(name: "Abidjan Plateau", slug: "drena-abidjan-1")

        report = run_import(document("Abidjan Plateau", "Man"))

        assert_equal [ "completed", 2, 1, 0, 1 ],
                     report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
        assert_equal [ { "path" => "drenas[0].name", "code" => "taken", "params" => { "value" => "Abidjan Plateau" } } ],
                     report.import_errors
        assert_equal [ [ "Abidjan Plateau", "drena-abidjan-1" ], [ "Man", "drena-man" ] ], Orm::Drena.order(:name).pluck(:name, :slug)
      end

      test "a name in base whose slug is the one of the line is a duplicate, never taken" do
        Orm::Drena.create!(name: "Abidjan 1", slug: "drena-abidjan-1")

        item = validate({ "name" => "Abidjan 1" })

        assert item.valid?
        assert_equal "drena-abidjan-1", item.key
      end

      test "write inserts the planned rows and counts them, with no details" do
        items = [ validate({ "name" => "Korhogo" }), validate({ "name" => "Odienné" }) ]
        at = Time.zone.local(2026, 9, 29, 10)

        written = adapter.write(items:, author_id: @author.id, at:)

        assert_equal({ imported: 2, details: {} }, written)
        korhogo = Orm::Drena.find_by!(slug: "drena-korhogo")
        assert_equal [ "Korhogo", items.first.plan[:public_id], at ], korhogo.values_at(:name, :public_id, :created_at)
        assert Orm::Drena.exists?(name: "Odienné", slug: "drena-odienne")
      end
    end
  end
end
