require "test_helper"

module Entities
  module School
    # ADR-0044, ADR-0066 §4.3: the four positions of a school's direction and the gestures of each.
    class StaffPositionTest < ActiveSupport::TestCase
      test "quatre fonctions fermées, dont deux qui gèrent" do
        assert_equal %w[principal censor educator secretary], StaffPosition::ALL
        assert_equal %w[principal censor], StaffPosition::MANAGERS
      end

      test "les fonctions de la direction sont celles des invitations, sans dépendance d'un contexte à l'autre" do
        assert_equal StaffPosition::ALL, Entities::Identity::Invitation::POSITIONS
      end

      test "le Proviseur et le Censeur ont tous les gestes sauf inviter un Proviseur" do
        %w[principal censor].each do |position|
          (StaffPosition::ALL_GESTURES - [ :invite_principal ]).each { assert StaffPosition.allows?(position, it), "#{position} #{it}" }
          assert_not StaffPosition.allows?(position, :invite_principal), position
        end
      end

      test "l'Éducateur et la Secrétaire lisent, ajoutent une classe et changent un élève de classe, rien d'autre" do
        %w[educator secretary].each do |position|
          %i[read add_classroom place_student].each { assert StaffPosition.allows?(position, it), "#{position} #{it}" }
          %i[invite_staff invite_principal regenerate_code detach_teacher reinstate_teacher detach_staff].each do |gesture|
            assert_not StaffPosition.allows?(position, gesture), "#{position} #{gesture}"
          end
        end
      end

      test "une fonction inconnue ou absente n'a aucun geste" do
        assert_not StaffPosition.allows?(nil, :read)
        assert_not StaffPosition.allows?("director", :read)
      end

      test "un geste inconnu lève" do
        assert_raises(ArgumentError) { StaffPosition.allows?("principal", :delete_school) }
        assert_raises(ArgumentError) { StaffPosition.allows?("principal", "read") }
      end
    end
  end
end
