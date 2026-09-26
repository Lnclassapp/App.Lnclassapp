require "test_helper"

# CA-08, ADR-0039: a file of the old application, once enveloped, is imported whole and in draft; the HTML of its
# courses and essentials is sanitized before it enters their rich text.
class Catalog::ImportCourseTreeJobTest < ActiveJob::TestCase
  setup do
    seed_referential
    @author = create_team_member(team_role: "content", second_factor: false)
  end

  def import(document)
    report = create_import_report(kind: "course_tree", imported_by: @author)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, io: StringIO.new(document.to_json), filename: "svt_tle_d.json")

    Catalog::ImportCourseTreeJob.perform_now(report.id)

    report.reload
  end

  test "the real extract of the old application is written with all its descendants, in draft, and the report is completed" do
    report = import(import_sample("course_tree_tle_d_sample"))

    assert_equal [ "completed", 2, 2, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({ "essentials_created" => 6, "exercises_created" => 24, "questions_created" => 144, "answers_created" => 288 },
                 report.details)
    assert_equal [ 2, 6, 24, 144, 288 ], [ Orm::Course, Orm::Essential, Orm::Exercise, Orm::Question, Orm::Answer ].map(&:count)
    course = Orm::Course.find_by!(name: "Génétique et Évolution")
    assert_equal [ "tle", "d", "svt", "draft", @author.id ],
                 [ course.level.slug, course.series.slug, course.material.slug, course.status, course.author_id ]
    assert_equal [ "Brassage génétique par la méiose", "Mutation et diversité", "Sélection naturelle et dérive" ],
                 course.essentials.order(:position).pluck(:name)
    assert_includes course.content.to_plain_text, "Transmission des caractères héréditaires"
    question = Orm::Question.find_by!(content: "Le crossing-over a lieu pendant la prophase de la deuxième division de méiose.")
    assert_equal [ [ "Vrai", false ], [ "Faux", true ] ], question.answers.order(:position).pluck(:content, :correct)
    assert_equal [ "draft" ], [ Orm::Essential, Orm::Exercise ].flat_map { it.distinct.pluck(:status) }.uniq
  end

  test "imported HTML is sanitized: no script, no event attribute, no javascript: link; bold, lists and formulas are kept" do
    dirty = <<~HTML
      <p onclick="steal()">La loi <strong>d'Ohm</strong> : $U = R \\times I$<script>alert("x")</script></p>
      <ul><li>tension</li><li><a href="javascript:alert(1)">intensité</a></li></ul>
    HTML
    document = course_tree_document(courses: 1, essentials: 1, exercises: 1, questions: 1, answers: 2, material_name: "Physique Chimie")
    document["courses"][0]["content"] = dirty
    document["courses"][0]["essentials"][0]["content"] = dirty

    report = import(document)

    assert_equal [ "completed", 1 ], report.values_at(:status, :imported_count)
    [ Orm::Course.sole, Orm::Essential.sole ].each do |record|
      html = record.content.body.to_html
      assert_no_match(/script|alert|onclick|steal|javascript:/, html, record.class.name)
      assert_includes html, "<strong>d'Ohm</strong>"
      assert_includes html, "$U = R \\times I$"
      assert_match(%r{<ul>\s*<li>tension</li>\s*<li><a>intensité</a></li>\s*</ul>}, html)
    end
  end

  test "it runs the course tree adapter" do
    assert_instance_of UseCases::Catalog::ImportCourseTree, Catalog::ImportCourseTreeJob.new.send(:adapter)
    assert_equal "Catalog::ImportCourseTreeJob", Rails.configuration.x.import_jobs.fetch(UseCases::Catalog::ImportCourseTree::KIND)
  end
end
