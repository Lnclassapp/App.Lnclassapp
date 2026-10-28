require "test_helper"

module Repositories
  module Catalog
    class ImportSchemaValidatorTest < ActiveSupport::TestCase
      ROOT = Rails.root.join("test/fixtures/files/import_schemas")

      setup { @validator = ImportSchemaValidator.new(root: ROOT) }

      def document(schools) = { "format" => "lnclass.schools", "version" => 1, "schools" => schools }

      test "un document conforme ne donne aucune erreur" do
        assert_empty @validator.validate(format: "fake", version: 1, document: document([ { "name" => "Lycée A" } ]))
      end

      test "convertit chaque erreur en ImportError au chemin JSON du rapport" do
        errors = @validator.validate(format: "fake", version: 1, document: document([ { "name" => "A" }, {}, { "name" => 12 } ]))

        assert_equal [ [ "schools[1].name", "schema", { keyword: "required" } ], [ "schools[2].name", "schema", { keyword: "string" } ] ],
                     errors.map { [ it.path, it.code, it.params ] }
      end

      test "une clé manquante de l'enveloppe est notée à sa place" do
        errors = @validator.validate(format: "fake", version: 1, document: { "format" => "lnclass.schools", "version" => 1 })

        assert_equal [ "schools" ], errors.map(&:path)
      end

      test "une enveloppe qui n'est pas un objet est notée à la racine" do
        assert_equal [ "$" ], @validator.validate(format: "fake", version: 1, document: []).map(&:path)
      end

      test "traduit un pointeur JSON en chemin du rapport" do
        assert_equal "$", ImportSchemaValidator.json_path("")
        assert_equal "schools[12].type", ImportSchemaValidator.json_path("/schools/12/type")
        assert_equal "courses[0].essentials[3].a/b~c", ImportSchemaValidator.json_path("/courses/0/essentials/3/a~1b~0c")
      end

      # ADR-0105 §4.6 : l'image d'une question est un ajout compatible de la version 1.
      test "course-tree : les leçons rédigées du dépôt restent valides, chacune dans sa version, l'image d'une question n'admet que sa description" do
        validator = ImportSchemaValidator.new
        lessons = Rails.root.glob("docs/contenus/lecons-traitees/**/*.json")

        assert_operator lessons.size, :>=, 18
        lessons.each do |lesson|
          document = JSON.parse(lesson.read)
          assert_includes [ 1, 2 ], document["version"], lesson.to_s
          assert_empty validator.validate(format: "lnclass.course-tree", version: document["version"], document:), lesson.to_s
        end

        document = course_tree_document(courses: 1, essentials: 1, exercises: 1, questions: 1, answers: 2)
        question = document["courses"][0]["essentials"][0]["exercises"][0]["questions"][0]
        path = "courses[0].essentials[0].exercises[0].questions[0].image"
        check = lambda do |image|
          question["image"] = image
          validator.validate(format: "lnclass.course-tree", version: 1, document:)
        end

        assert_empty check.({ "description" => "une pile" })
        assert_equal [ "#{path}.description" ], check.({ "description" => "" }).map(&:path)
        assert_equal [ "#{path}.url" ], check.({ "description" => "une pile", "url" => "x" }).map(&:path)
        assert_equal [ path ], check.("une pile").map(&:path)
      end

      # ADR-0113 §4.4 : le format 2 a son sujet (statement) et les exercices de toute la leçon ; l'ancienne consigne n'y est plus admise.
      test "course-tree v2 : statement et exercises de la leçon sont admis, description et name d'un exercice ne le sont plus" do
        validator = ImportSchemaValidator.new
        check = ->(document) { validator.validate(format: "lnclass.course-tree", version: 2, document:).map(&:path) }
        document = course_tree_v2_document(courses: 1, essentials: 1)

        assert_empty check.(document)
        document["courses"][0]["exercises"][0].merge!("description" => "Consigne", "name" => "Titre")
        assert_equal [ "courses[0].exercises[0].description", "courses[0].exercises[0].name" ], check.(document).sort
        assert_includes check.(course_tree_document(courses: 1)), "version"
      end

      test "lit config/schemas par défaut" do
        assert_equal Rails.root.join("config/schemas"), ImportSchemaValidator.new.root
      end
    end
  end
end
