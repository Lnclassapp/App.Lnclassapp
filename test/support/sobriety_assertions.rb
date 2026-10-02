# UDR-0057: the sobriety rule, checked in a real browser. R1 one primary action, R2 at most 5 blocks
# before the first scroll, R3 at most 3 visible lines in a list before « Voir plus ».
module SobrietyAssertions
  ActionDispatch::SystemTestCase.include(self)

  # ComponentsHelper::BUTTON_VARIANTS: primary = bg-ink text-white, brand = bg-brand text-ink.
  PRIMARY_ACTION = "a.bg-ink.text-white, button.bg-ink.text-white, a.bg-brand.text-ink, button.bg-brand.text-ink".freeze

  # R1: visible primary or brand buttons and links inside the scope (the page's main by default).
  def assert_single_primary_action(scope: "#main")
    count = within(scope) { all(PRIMARY_ACTION, visible: true).size }
    assert_operator count, :<=, 1, "R1 : #{count} actions principales visibles dans #{scope}, une seule permise"
  end

  # R2: visible blocks matched by `selector` whose top edge lies inside the first screen.
  def assert_blocks_above_fold(selector, max: 5)
    count = page.evaluate_script(<<~JS, selector)
      (function (selector) {
        return Array.from(document.querySelectorAll(selector)).filter(function (block) {
          var box = block.getBoundingClientRect();
          return block.offsetParent !== null && box.height > 0 && box.top < window.innerHeight;
        }).length;
      })(arguments[0])
    JS
    assert_operator count, :<=, max, "R2 : #{count} blocs (#{selector}) avant le premier défilement, #{max} au plus"
  end

  # R3: visible items of a list (its rows matched by `items`) before « Voir plus ».
  def assert_list_capped(list, items: "li", max: ComponentsHelper::REVEAL_LIMIT)
    count = within(list) { all(items, visible: true).size }
    assert_operator count, :<=, max, "R3 : #{count} lignes visibles dans #{list}, #{max} au plus avant « Voir plus »"
  end
end
