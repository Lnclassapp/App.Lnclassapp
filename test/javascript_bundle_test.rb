require "test_helper"
require "zlib"

# ADR-0051 and TR-41 : Stimulus controllers are registered by file pattern (esbuild-rails),
# KaTeX and Trix ship in our own on-demand chunks, never from a CDN nor in the common entry
# point, which stays in budget. The editor refuses every attachment (ADR-0047, ADR-0049).
class JavascriptBundleTest < ActiveSupport::TestCase
  BUILDS = Rails.root.join("app/assets/builds")
  BUDGET_KB = 60

  test "the bundle registers the math controller found by file pattern" do
    assert_includes BUILDS.join("application.js").read, 'name:"math"'
  end

  test "the rich text editor is registered and refuses files, while Trix stays out of the common entry point" do
    application = BUILDS.join("application.js").read

    assert_includes application, 'name:"rich-text-editor"'
    assert_includes application, "trix-file-accept"
    assert_not_includes application, "trix-toolbar"
    assert(Dir[BUILDS.join("*.digested.js")].any? { |chunk| File.read(chunk).include?("trix-toolbar") })
    assert_includes BUILDS.join("trix.css").read, "trix-toolbar"
  end

  test "no Direct Upload code ships: the editor never sends a file" do
    assert(Dir[BUILDS.join("*.js")].none? { |chunk| File.read(chunk).include?("direct-upload") })
  end

  test "no compiled chunk loads anything from a CDN" do
    offenders = Dir[BUILDS.join("*.js")].select { |chunk| File.read(chunk).include?("cdn.") }

    assert_empty offenders
  end

  test "the common entry point stays within its gzip budget" do
    size_kb = Zlib.gzip(BUILDS.join("application.js").binread, level: Zlib::BEST_COMPRESSION).bytesize / 1024.0

    assert_operator size_kb, :<=, BUDGET_KB
  end
end
