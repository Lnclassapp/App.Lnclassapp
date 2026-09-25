require "test_helper"

# ADR-0049 : no script, style, font or frame from another origin.
class NoThirdPartyResourcesTest < ActiveSupport::TestCase
  # Tags that load a resource from another origin, and known tracking hosts.
  THIRD_PARTY = %r{<(script|link|iframe|img|source|video|audio)\b[^>]*\b(src|href)=["']?(https?:)?//|googletagmanager|clarity\.ms|cdn\.jsdelivr|unpkg\.com|cdnjs}i

  test "no view or layout loads a script, style, font or frame from another origin" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].select { |f| File.read(f).match?(THIRD_PARTY) }
    assert_empty offenders, "ADR-0049 : ressource tierce interdite dans #{offenders.join(', ')}"
  end

  test "the expression tells an outbound link from a third-party resource" do
    assert_no_match THIRD_PARTY, %(<a href="https://example.org">site</a>)
    assert_no_match THIRD_PARTY, %(<script src="/assets/application.js"></script>)
    assert_match THIRD_PARTY, %(<script src="https://cdn.example.org/lib.js"></script>)
    assert_match THIRD_PARTY, %(<link href="https://fonts.googleapis.com/css2" rel="stylesheet">)
    assert_match THIRD_PARTY, %(<iframe src="//evil.example.org"></iframe>)
  end
end
