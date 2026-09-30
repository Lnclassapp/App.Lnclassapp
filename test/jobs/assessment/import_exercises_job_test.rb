require "test_helper"

# AS-06 replaced, TR-28, ADR-0039: the job imports the exercises of a file into its target essential, whole and in draft,
# with the keys of the old application.
class Assessment::ImportExercisesJobTest < ActiveJob::TestCase
  setup do
    @author = create_team_member(team_role: "content", second_factor: false)
    @essential = create_essential(name: "Brassage génétique par la méiose")
  end

  def import(document)
    report = create_import_report(kind: "exercises", imported_by: @author)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(document.to_json), filename: "exercices.json") ])

    Assessment::ImportExercisesJob.perform_now(report.id)

    report.reload
  end

  test "the exercises of the file are written in their essential with their questions and answers, and the report is completed" do
    document = exercises_document(essential: @essential.slug, exercises: 3, questions: 5, answers: 4)
    document["exercises"][1]["name"] = document["exercises"][1].delete("title")
    document["exercises"][2]["status"] = "publié"

    report = import(document)

    assert_equal [ "completed", 3, 3, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({ "questions_created" => 15, "answers_created" => 60 }, report.details)
    exercises = @essential.exercises.order(:position)
    assert_equal [ [ "Exercice 1", 1 ], [ "Exercice 2", 2 ], [ "Exercice 3", 3 ] ], exercises.pluck(:title, :position)
    assert_equal [ [ "draft", @author.id ] ], exercises.distinct.reorder(nil).pluck(:status, :author_id)
    question = exercises.first.questions.find_by!(position: 1)
    assert_equal [ [ "Proposition 1", true ], [ "Proposition 2", false ], [ "Proposition 3", false ], [ "Proposition 4", false ] ],
                 question.answers.order(:position).pluck(:content, :correct)
  end

  test "it runs the exercises adapter" do
    assert_instance_of UseCases::Assessment::ImportExercises, Assessment::ImportExercisesJob.new.send(:adapter)
    assert_equal "Assessment::ImportExercisesJob", Rails.configuration.x.import_jobs.fetch(UseCases::Assessment::ImportExercises::KIND)
  end
end
