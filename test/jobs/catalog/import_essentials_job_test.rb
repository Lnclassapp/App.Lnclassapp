require "test_helper"

# CA-15, ADR-0039: the essentials of a file land in their course, in draft; the HTML of each essential is sanitized
# before it enters its rich text.
class Catalog::ImportEssentialsJobTest < ActiveJob::TestCase
  setup do
    @author = create_team_member(team_role: "content", second_factor: false)
    @course = create_course(name: "Électricité")
  end

  def import(document)
    report = create_import_report(kind: "essentials", imported_by: @author)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "fiches.json") ])

    Catalog::ImportEssentialsJob.perform_now(report.id)

    report.reload
  end

  test "the essentials are written in their course with their exercises, in draft, and the report is completed" do
    report = import(essentials_document(course: @course.slug, essentials: 2, exercises: 2, questions: 3, answers: 4))

    assert_equal [ "completed", 2, 2, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({ "exercises_created" => 4, "questions_created" => 12, "answers_created" => 48 }, report.details)
    assert_equal [ [ "Fiche 1", 1, "draft", @author.id ], [ "Fiche 2", 2, "draft", @author.id ] ],
                 @course.essentials.order(:position).pluck(:name, :position, :status, :author_id)
    assert_equal [ "draft" ], Orm::Exercise.distinct.pluck(:status)
  end

  test "imported HTML is sanitized: no script, no event attribute; bold, lists and formulas are kept" do
    document = essentials_document(course: @course.slug, essentials: 1, exercises: 1, questions: 1, answers: 2)
    document["essentials"][0]["content"] = <<~HTML
      <p>La loi <strong>d'Ohm</strong> : $U = R \\times I$<script>alert("x")</script></p>
      <ul><li>tension</li><li>intensité<img src="x" onerror="steal()"></li></ul>
    HTML

    report = import(document)

    assert_equal [ "completed", 1 ], report.values_at(:status, :imported_count)
    html = Orm::Essential.sole.content.body.to_html
    assert_no_match(/script|alert|onerror|steal/, html)
    assert_includes html, "<strong>d'Ohm</strong>"
    assert_includes html, "$U = R \\times I$"
    assert_match(%r{<ul>\s*<li>tension</li>\s*<li>intensité}, html)
  end

  test "it runs the essentials adapter" do
    assert_instance_of UseCases::Catalog::ImportEssentials, Catalog::ImportEssentialsJob.new.send(:adapter)
    assert_equal "Catalog::ImportEssentialsJob", Rails.configuration.x.import_jobs.fetch(UseCases::Catalog::ImportEssentials::KIND)
  end
end
