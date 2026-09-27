require "test_helper"

module Dtos
  module School
    class SchoolInputTest < ActiveSupport::TestCase
      School = Entities::School::School

      def input(**overrides)
        SchoolInput.new(drena_public_id: "drena-abidjan1", name: " Lycée  Classique d'Abidjan ", sigle: " LCA ",
                        school_type: "public", status: "active", cycle: "both", **overrides)
      end

      test "une saisie complète est valide ; les espaces sont resserrés, la casse est gardée" do
        school = input

        assert school.valid?
        assert_equal "drena-abidjan1", school.drena_public_id
        assert_equal({ name: "Lycée Classique d'Abidjan", sigle: "LCA", school_type: "public", status: "active", cycle: "both" },
                     school.to_h)
      end

      test "le sigle est facultatif : vide, il vaut nil" do
        assert input(sigle: "   ").valid?
        assert_nil input(sigle: "   ").sigle
        assert_nil input(sigle: nil).to_h[:sigle]
      end

      test "le type, le statut et le cycle sont pris dans leurs listes fermées, mixte compris" do
        School::SCHOOL_TYPES.each { |school_type| assert input(school_type:).valid? }
        School::STATUSES.each { |status| assert input(status:).valid? }
        School::CYCLES.each { |cycle| assert input(cycle:).valid? }
        assert_includes School::SCHOOL_TYPES, "mixed"

        assert input(school_type: "privée").tap(&:validate).errors.of_kind?(:school_type, :inclusion)
        assert input(status: "closed").tap(&:validate).errors.of_kind?(:status, :inclusion)
        assert input(cycle: "second").tap(&:validate).errors.of_kind?(:cycle, :inclusion)
        assert input(cycle: nil).tap(&:validate).errors.of_kind?(:cycle, :inclusion)
      end

      test "la DRENA et le nom sont obligatoires ; le nom compte NAME_MAX caractères au plus, le sigle SIGLE_MAX" do
        assert input(name: "a" * School::NAME_MAX, sigle: "b" * School::SIGLE_MAX).valid?
        assert input(name: "a" * (School::NAME_MAX + 1)).tap(&:validate).errors.of_kind?(:name, :too_long)
        assert input(sigle: "b" * (School::SIGLE_MAX + 1)).tap(&:validate).errors.of_kind?(:sigle, :too_long)
        assert input(name: "  ").tap(&:validate).errors.of_kind?(:name, :blank)
        assert input(drena_public_id: "").tap(&:validate).errors.of_kind?(:drena_public_id, :blank)
      end

      test "les messages d'erreur viennent de la locale de l'écran" do
        school = input(name: "", drena_public_id: nil, cycle: "").tap(&:validate)
        scope = "activemodel.errors.models.dtos/school/school_input.attributes"

        assert_equal [ I18n.t("#{scope}.name.blank") ], school.errors[:name]
        assert_equal [ I18n.t("#{scope}.drena_public_id.blank") ], school.errors[:drena_public_id]
        assert_equal [ I18n.t("#{scope}.cycle.inclusion") ], school.errors[:cycle]
      end
    end
  end
end
