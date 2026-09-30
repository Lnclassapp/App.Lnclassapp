# Générateurs de documents d'import (plan boucle-pedagogique, 0e.e2), enveloppés comme l'ADR-0039 les décrit.
# Les clés des éléments sont celles de l'ancienne application ; `mixed` rend un document invalide et doublonné par endroits.
module ImportDocuments
  ActiveSupport::TestCase.include(self)

  ROOT_KEYS = { "lnclass.schools" => "schools", "lnclass.course-tree" => "courses", "lnclass.essentials" => "essentials",
                "lnclass.exercises" => "exercises" }.freeze
  # Clé du nom de chaque élément racine : c'est elle que `mixed` vide pour rendre l'élément invalide.
  NAME_KEYS = { "schools" => "name", "courses" => "name", "essentials" => "name", "exercises" => "title" }.freeze
  SCHOOL_TYPES = { "public" => "public", "private" => "privée", "mixed" => "mixte" }.freeze

  def schools_document(count:, drena:, college_ratio: 0.44, types: %w[public private mixed])
    colleges = (count * college_ratio).round
    schools = Array.new(count) do |index|
      prefix = index < colleges ? "Collège" : "Lycée"
      { "name" => "#{prefix} Moderne #{index + 1}", "schoolsigle" => "LM#{index + 1}", "schoolstatus" => "active",
        "schooltype" => SCHOOL_TYPES.fetch(types[index % types.size]) }
    end
    envelope("lnclass.schools", "drena" => drena, "schools" => schools)
  end

  def course_tree_document(courses:, essentials: 8, exercises: 2, questions: 10, answers: 4, level_name: "Tle",
                           material_name: "SVT", series_name: "D")
    roots = Array.new(courses) do |index|
      { "name" => "Cours #{index + 1}", "subtitle" => "Sous-titre #{index + 1}", "content" => "<p>Cours #{index + 1}</p>",
        "level_name" => level_name, "material_name" => material_name, "series_name" => series_name,
        "essentials" => essential_nodes(essentials, exercises:, questions:, answers:) }
    end
    envelope("lnclass.course-tree", "courses" => roots)
  end

  def essentials_document(course:, essentials:, exercises: 2, questions: 10, answers: 4)
    envelope("lnclass.essentials", "course" => course, "essentials" => essential_nodes(essentials, exercises:, questions:, answers:))
  end

  def exercises_document(essential:, exercises:, questions: 10, answers: 4)
    envelope("lnclass.exercises", "essential" => essential, "exercises" => exercise_nodes(exercises, questions:, answers:))
  end

  # invalid_at : index des éléments dont le nom est vidé ; duplicate_of : { index => index copié }.
  def mixed(document, invalid_at: [ 3, 7 ], duplicate_of: { 5 => 1 })
    document = document.deep_dup
    roots_key = ROOT_KEYS.fetch(document["format"])
    roots = document.fetch(roots_key)
    invalid_at.each { |index| roots[index][NAME_KEYS.fetch(roots_key)] = "" }
    duplicate_of.each { |index, source| roots[index] = roots[source].deep_dup }
    document
  end

  # Un fichier d'envoi tel que le stockage l'attend (ADR-0068) : un io et son nom.
  ImportUpload = Data.define(:io, :filename)

  def import_upload(io:, filename:) = ImportUpload.new(io:, filename:)

  # Exemples réels de l'ancienne application, enveloppés (test/fixtures/files/imports/).
  def import_sample(name)
    JSON.parse(file_fixture("imports/#{name}.json").read)
  end

  private

  def envelope(format, content)
    { "format" => format, "version" => Entities::Catalog::ImportKind::VERSION }.merge(content)
  end

  def essential_nodes(count, exercises:, questions:, answers:)
    Array.new(count) do |index|
      { "name" => "Fiche #{index + 1}", "subtitle" => "Résumé #{index + 1}", "content" => "<p>Fiche #{index + 1}</p>",
        "exercises" => exercise_nodes(exercises, questions:, answers:) }
    end
  end

  def exercise_nodes(count, questions:, answers:)
    Array.new(count) do |index|
      { "title" => "Exercice #{index + 1}", "description" => "Consigne #{index + 1}", "exercise_type" => "fixation",
        "questions" => Array.new(questions) do |rank|
          { "content" => "Question #{rank + 1}", "question_type" => "single_choice",
            "answers" => Array.new(answers) { |position| { "content" => "Proposition #{position + 1}", "correct" => position.zero? } } }
        end }
    end
  end
end
