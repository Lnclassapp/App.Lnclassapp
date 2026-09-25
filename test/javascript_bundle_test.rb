require "test_helper"
require "zlib"

# ADR-0051 and TR-41 : Stimulus controllers are registered by file pattern (esbuild-rails),
# KaTeX, Trix and Action Text ship in our own on-demand chunks, never from a CDN nor in the
# common entry point, which stays in budget.
class JavascriptBundleTest < ActiveSupport::TestCase
  BUILDS = Rails.root.join("app/assets/builds")
  BUDGET_KB = 60

  test "the bundle registers the math controller found by file pattern" do
    assert_includes BUILDS.join("application.js").read, 'name:"math"'
  end

  test "the rich text editor is registered, while Trix and Action Text stay out of the common entry point" do
    application = BUILDS.join("application.js").read

    assert_includes application, 'name:"rich-text-editor"'
    assert_not_includes application, "trix-editor"
    assert_not_includes application, "trix-attachment-add"
    assert(Dir[BUILDS.join("*.digested.js")].any? { |chunk| File.read(chunk).include?("trix-attachment-add") })
    assert BUILDS.join("trix.css").exist?
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
