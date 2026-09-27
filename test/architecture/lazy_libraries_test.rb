require "test_helper"

# ADR-0051: Trix, Action Text, KaTeX and the confetti are chunks loaded on demand. No file of app/javascript
# imports them statically: only `import("…")` is allowed.
class LazyLibrariesTest < ActiveSupport::TestCase
  LAZY = %r{\A\s*import\s+(?:[^"'()]+\s+from\s+)?["'](?:trix|@rails/actiontext|katex|canvas-confetti)(?:/[^"']*)?["']}

  def static_imports(source) = source.each_line.grep(LAZY)

  test "no static import of a lazy library in app/javascript" do
    offenders = Rails.root.glob("app/javascript/**/*.js").select { static_imports(it.read).any? }

    assert_empty offenders.map { it.relative_path_from(Rails.root).to_s }
  end

  test "the pattern catches static imports and lets dynamic ones through" do
    [ 'import "trix"', 'import Trix from "trix"', "import renderMathInElement from 'katex/contrib/auto-render'",
      'import "@rails/actiontext"', 'import confetti from "canvas-confetti"' ].each do |line|
      assert_equal 1, static_imports(line).size, line
    end
    assert_empty static_imports('await Promise.all([import("trix"), import("@rails/actiontext")])')
    assert_empty static_imports('const { default: render } = await import("katex/contrib/auto-render")')
  end
end
