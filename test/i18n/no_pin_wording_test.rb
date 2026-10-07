require "test_helper"

# IE-24 (memo Q25, UDR-0078 §3.11, ADR-0082 §4.4 ter): the 4-digit secret is called « code secret » in every text shown.
# Every French translation loaded by the application is read, flat; none may say « PIN ». The code keeps `pin`.
class NoPinWordingTest < ActiveSupport::TestCase
  WORD = /\bPINs?\b/

  test "IE-24: no French translation says « PIN »" do
    I18n.backend.eager_load!
    offences = flatten(I18n.backend.send(:translations).fetch(:fr)).select { |_, value| value.to_s.match?(WORD) }

    assert_empty offences.map { |key, value| "#{key} : #{value}" }
  end

  test "the pattern catches the word, alone or plural, never inside another word" do
    [ "Votre PIN", "Les deux PIN ne sont pas identiques.", "PINs", "PIN oublié ?" ].each { assert_match WORD, it }
    [ "Code secret", "PINCEAU", "épingle", "pin_hint" ].each { assert_no_match WORD, it }
  end

  private

  def flatten(hash, prefix = nil)
    hash.flat_map do |key, value|
      path = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flatten(value, path) : [ [ path, Array(value).join(" ") ] ]
    end
  end
end
