require "test_helper"

# ADR-XXXX (modèles de langage, « Données envoyées ») : les notes partent masquées (numéros ivoiriens, noms des contacts).
module Entities
  module Crm
    class RedactionTest < ActiveSupport::TestCase
      test "Ivorian phone numbers are masked with or without spaces, dots or +225" do
        [ "0701020304", "07 01 02 03 04", "07.01.02.03.04", "+225 05 01 02 03 04", "225 0101020304", "+2250501020304" ].each do |number|
          assert_equal "Rappeler au [numéro] demain", Redaction.call("Rappeler au #{number} demain"), number
        end
      end

      test "other digit runs are left alone" do
        assert_equal "Classe de 120 élèves, budget 0201020304", Redaction.call("Classe de 120 élèves, budget 0201020304")
      end

      test "contact names are masked whole and by part, whatever the case" do
        assert_equal "[contact] a dit que [contact] rappellera", Redaction.call("Awa Koné a dit que KONÉ rappellera", names: [ "Awa Koné" ])
      end

      test "blank text stays nil" do
        assert_nil Redaction.call(nil)
        assert_nil Redaction.call("  ", names: [ "Awa" ])
      end
    end
  end
end
