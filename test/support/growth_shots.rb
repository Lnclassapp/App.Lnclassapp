# Screenshots of the croissance-parrainage journeys for the review, only when GROWTH_SHOTS=<dir> is set (ADR-0063).
# A desktop shot is taken at 1280 px wide; a phone shot inside with_mobile_viewport keeps its 390 px.
module GrowthShots
  ActionDispatch::SystemTestCase.include(self)

  DESKTOP = [ 1280, 1000 ].freeze

  def growth_shot(name, scroll_to: nil, desktop: true)
    return unless ENV["GROWTH_SHOTS"]

    window = page.current_window
    original = window.size
    window.resize_to(*DESKTOP) if desktop
    page.execute_script("document.querySelector(arguments[0]).scrollIntoView({ block: 'center' })", scroll_to) if scroll_to
    page.save_screenshot(File.join(ENV["GROWTH_SHOTS"], "#{name}.png"))
  ensure
    window.resize_to(*original) if desktop && original
  end
end
