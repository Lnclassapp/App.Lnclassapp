require "test_helper"

# PRD §4 : aucun gabarit ne contient de nom, de numéro, de note, de niveau de médaille ni de titre d'annonce.
module Entities
  module Communication
    class PushMessageTest < ActiveSupport::TestCase
      def candidate(motive, **variables)
        PushCandidate.new(user_id: 1, motive:, object_key: "#{motive}:k", url: "/ma-classe", variables:)
      end

      CASES = {
        "inactive" => {},
        "assignment_due" => { material: "Maths" },
        "assignment_new" => { material: "Maths", count: 3 },
        "quiz_prep" => { material: "Maths", count: 2 },
        "announcement" => {},
        "result" => { material: "Maths", kind: "copy" },
        "unfinished" => { material: "Maths" }
      }.freeze

      test "les sept gabarits existent et portent le lien et l'étiquette du motif" do
        assert_equal PushMotive::ALL.sort, CASES.keys.sort
        CASES.each do |motive, variables|
          message = PushMessage.for(candidate(motive, **variables))

          assert_equal "Lnclass", message.title
          assert_equal "/ma-classe", message.url
          assert_equal motive, message.tag
          assert message.body.present?, motive
          assert_no_match(/translation missing|%\{/, message.body, motive)
        end
      end

      test "les textes de PRD §3.1" do
        assert_equal "Un devoir de Maths est à rendre demain.", PushMessage.for(candidate("assignment_due", material: "Maths")).body
        assert_equal "Ton prof de Maths t'a donné 3 exercices.", PushMessage.for(candidate("assignment_new", material: "Maths", count: 3)).body
        assert_equal "Ton prof de Maths t'a donné 1 exercice.", PushMessage.for(candidate("assignment_new", material: "Maths", count: 1)).body
        assert_equal "Prépare ton interro de Maths de demain : 2 exercices.", PushMessage.for(candidate("quiz_prep", material: "Maths", count: 2)).body
        assert_equal "Prépare ton interro de Maths de demain : 1 exercice.", PushMessage.for(candidate("quiz_prep", material: "Maths", count: 1)).body
        assert_equal "Ta copie de Maths est corrigée.", PushMessage.for(candidate("result", material: "Maths", kind: "copy")).body
        assert_equal "Bravo ! Une nouvelle médaille en Maths.", PushMessage.for(candidate("result", material: "Maths", kind: "medal")).body
      end

      test "aucune donnée de l'élève n'entre dans le texte, même si on la lui passe" do
        extras = { name: "Awa Koné", contact: "0100000001", score: 17, level: "Platine-Z9", title: "Fermeture exceptionnelle" }
        CASES.each do |motive, variables|
          body = PushMessage.for(candidate(motive, **variables, **extras)).body

          extras.each_value { |value| assert_not_includes body, value.to_s, "#{motive} : #{value}" }
        end
      end

      test "un résultat sans sa nature est refusé" do
        assert_raises(KeyError) { PushMessage.for(candidate("result", material: "Maths")) }
      end
    end
  end
end
