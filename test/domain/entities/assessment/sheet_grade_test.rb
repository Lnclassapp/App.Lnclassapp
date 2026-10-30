require "test_helper"

module Entities
  module Assessment
    # ADR-XXXX sujets-de-devoir §4 : la note de la feuille « Prépare interros », sur 10 au demi-point, avec la mention de la maquette.
    class SheetGradeTest < ActiveSupport::TestCase
      test "4 justes sur 5 : 8 sur 10, Très bien" do
        grade = SheetGrade.new(correct: 4, total: 5)

        assert_equal 8.0, grade.score
        assert_equal :very_good, grade.mention
        assert_equal 4, grade.correct
        assert_equal 5, grade.total
      end

      test "5 justes sur 5 : 10 sur 10, Excellent" do
        grade = SheetGrade.new(correct: 5, total: 5)

        assert_equal 10.0, grade.score
        assert_equal :excellent, grade.mention
      end

      test "0 juste sur 4 : 0 sur 10, À retravailler" do
        grade = SheetGrade.new(correct: 0, total: 4)

        assert_equal 0.0, grade.score
        assert_equal :needs_work, grade.mention
      end

      test "la note est arrondie au demi-point" do
        assert_equal 6.5, SheetGrade.new(correct: 13, total: 20).score
        assert_equal 3.5, SheetGrade.new(correct: 1, total: 3).score
        assert_equal 6.5, SheetGrade.new(correct: 2, total: 3).score
        assert_equal 1.5, SheetGrade.new(correct: 3, total: 20).score
      end

      test "les seuils de mention : 9, 7 et 5 sur 10" do
        assert_equal :excellent, SheetGrade.new(correct: 9, total: 10).mention
        assert_equal :very_good, SheetGrade.new(correct: 8, total: 10).mention
        assert_equal :very_good, SheetGrade.new(correct: 7, total: 10).mention
        assert_equal :fair, SheetGrade.new(correct: 6, total: 10).mention
        assert_equal :fair, SheetGrade.new(correct: 5, total: 10).mention
        assert_equal :needs_work, SheetGrade.new(correct: 4, total: 10).mention
      end

      test "un exercice sans question n'a pas de note" do
        grade = SheetGrade.new(correct: 0, total: 0)

        assert_equal 0.0, grade.score
        assert_equal :needs_work, grade.mention
      end

      test "le détail rend le nombre pour le libellé « x bonne(s) réponse(s) sur n »" do
        assert_equal({ count: 1, total: 5 }, SheetGrade.new(correct: 1, total: 5).detail)
        assert_equal({ count: 4, total: 5 }, SheetGrade.new(correct: 4, total: 5).detail)
      end

      test "un nombre de justes hors de 0..total est refusé" do
        assert_raises(ArgumentError) { SheetGrade.new(correct: 6, total: 5) }
        assert_raises(ArgumentError) { SheetGrade.new(correct: -1, total: 5) }
      end
    end
  end
end
