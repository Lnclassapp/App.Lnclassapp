require "test_helper"

# CA-1, CA-2, ADR-0039, ADR-0116: a v3 lesson, once enveloped, is imported whole and in draft by the job; the retired formats are refused.
class Catalog::ImportCourseTreeJobTest < ActiveJob::TestCase
  setup do
    seed_referential
    @author = create_team_member(team_role: "content", second_factor: false)
  end

  def import(document)
    report = create_import_report(kind: "course_tree", imported_by: @author)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "maths_3eme.json") ])

    Catalog::ImportCourseTreeJob.perform_now(report.id)

    report.reload
  end

  test "a v3 lesson is written with its notions, exercises and figures, in draft, and the report is completed" do
    report = import(revision_sheet_document)

    assert_equal [ "completed", 1, 1, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({ "essentials_created" => 2, "exercises_created" => 6, "questions_created" => 30, "answers_created" => 60 }, report.details)
    course = Orm::Course.find_by!(name: "Racines carrées")
    assert_equal [ "3eme", "mathematiques", "draft", @author.id, "blue" ],
                 [ course.level.slug, course.material.slug, course.status, course.author_id, course.sheet_theme ]
    assert_equal [ "Simplifier une racine carrée", "Calculer avec des racines" ], course.essentials.order(:position).pluck(:name)
    assert_equal [ "draft" ], Orm::Essential.distinct.pluck(:status)
  end

  test "the real extract of the old application (format 1) is refused whole as retired" do
    report = import(import_sample("course_tree_tle_d_sample"))

    assert_equal "rejected", report.status
    assert_equal [ [ "version", "format_retired" ] ], report.import_errors.map { it.values_at("path", "code") }
    assert_equal 0, Orm::Course.count
  end

  test "it runs the course tree adapter" do
    assert_instance_of UseCases::Catalog::ImportCourseTree, Catalog::ImportCourseTreeJob.new.send(:adapter)
    assert_equal "Catalog::ImportCourseTreeJob", Rails.configuration.x.import_jobs.fetch(UseCases::Catalog::ImportCourseTree::KIND)
  end
end
