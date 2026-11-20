require "test_helper"

module Queries
  module School
    class SchoolSearchQueryTest < ActiveSupport::TestCase
      setup do
        @query = SchoolSearchQuery.new
        @tiassale = create_drena(name: "Tiassalé")
        @notre_dame = create_school(drena: @tiassale, name: "Collège Notre-Dame de la Paix", sigle: "CNDP")
      end

      def found(term) = @query.call(term:)&.rows&.map(&:public_id)

      test "CA-1 : accents, casse, ordre des mots, sigle, DRENA et initiales trouvent l'établissement, avec sa DRENA" do
        [ "ND paix tiassale", "notre dame", "NOTRE-DAME", "paix collège", "cndp", "TIASSALÉ", "  notre   dame  " ].each do |term|
          assert_includes found(term), @notre_dame.public_id, term
        end
        row = @query.call(term: "notre dame").rows.first
        assert_equal SchoolSearchQuery::Row.new(public_id: @notre_dame.public_id, name: "Collège Notre-Dame de la Paix",
                                                drena_public_id: @tiassale.public_id, drena_name: "Tiassalé"), row
      end

      test "CA-1 : chaque mot doit se trouver ; les initiales ne valent que pour un mot court" do
        create_school(drena: create_drena(name: "Dabou"), name: "Lycée de la Paix")

        assert_equal [ @notre_dame.public_id ], found("paix tiassale")
        assert_empty found("paix korhogo")
        assert_empty found("cnddlpx"), "un mot long ne cherche pas dans les initiales"
      end

      test "CA-2 : jamais un établissement inactif ni en brouillon" do
        create_school(drena: @tiassale, name: "Lycée Fermé", status: "inactive")
        create_school(drena: @tiassale, name: "Lycée Fermé Bis", status: "draft")

        assert_empty found("fermé")
        assert_nil @query.find(public_id: Orm::School.find_by!(name: "Lycée Fermé").public_id)
      end

      test "CA-3 : 20 résultats au plus, l'indication qu'il y en a d'autres ; le nom qui commence par le mot d'abord" do
        drena = create_drena(name: "Bouaké 1")
        25.times { |i| create_school(drena:, name: format("Collège du Lycée %02d", i)) }
        lycee = create_school(drena:, name: "Lycée Moderne")

        result = @query.call(term: "lycee")
        assert_equal SchoolSearchQuery::LIMIT, result.rows.size
        assert result.more
        assert_equal lycee.public_id, result.rows.first.public_id

        exact = @query.call(term: "lycee moderne")
        assert_equal [ lycee.public_id ], exact.rows.map(&:public_id)
        assert_not exact.more
      end

      test "CA-4 : une saisie trop courte ne fait aucune requête ; une saisie démesurée est coupée sans erreur" do
        assert_no_queries do
          assert_nil @query.call(term: "a")
          assert_nil @query.call(term: "   ")
          assert_nil @query.call(term: nil)
        end
        assert_equal [], @query.call(term: "x" * 500).rows
        assert_equal %w[ab cd ef gh ij kl], SchoolSearchQuery.words("ab cd ef gh ij kl mn")
        assert_kind_of SchoolSearchQuery::Result, @query.call(term: "ab cd ef gh ij kl mn")
      end

      test "les jokers de LIKE tapés sont cherchés tels quels" do
        assert_nil @query.call(term: "%%")
        assert_empty found("100%")
      end

      test "find : l'établissement actif et sa DRENA, nil pour un identifiant inconnu ou vide" do
        assert_equal "Tiassalé", @query.find(public_id: @notre_dame.public_id).drena_name
        assert_nil @query.find(public_id: "inconnu")
        assert_nil @query.find(public_id: nil)
      end
    end
  end
end
