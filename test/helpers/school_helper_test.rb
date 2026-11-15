require "test_helper"

# UDR-0173 écrans minimalistes style Wave §3 : le sigle de la carte de classe, celui de la base, sinon les initiales du nom.
class SchoolHelperTest < ActionView::TestCase
  test "the sigle of the database wins" do
    assert_equal "CSMT", school_sigle(sigle: " CSMT ", name: "Collège Saint Michel de Treichville")
  end

  test "without a sigle: the initials of the words of 3 letters or more, 4 at most, accents removed" do
    assert_equal "LMT", school_sigle(sigle: nil, name: "Lycée Moderne de Treichville")
    assert_equal "GSMS", school_sigle(sigle: "", name: "Groupe Scolaire Modèle Savane")
    assert_equal "CEMA", school_sigle(sigle: nil, name: "Collège Évangélique Moderne d'Abobo Anyama")
  end

  test "a single word gives its 3 first letters, an empty name nothing" do
    assert_equal "LYC", school_sigle(sigle: nil, name: "Lycée")
    assert_equal "", school_sigle(sigle: nil, name: "")
  end
end
