require "application_system_test_case"
require "base64"

# standard-de-test, Lot G (ADR standard-de-test §4 point 8) : les captures de bin/preuve-vague. Une leçon par matière est importée,
# publiée et lue par un élève de la bonne classe, comme dans le test d'affichage (même chaîne, LessonRendering::Verifier), puis
# photographiée en pleine page à 390 px et à 1280 px dans CAPTURES_DIR (tmp/preuves/<vague>, ignoré par git).
# Sans CAPTURES_DIR le fichier ne définit aucun test (la CI le charge à vide, 0 s) : il ne sert qu'à la preuve d'une vague.
# Il se lance par `-i /captures/` : charger le test d'affichage définit aussi ses tests, qu'on n'y rejoue pas.
return unless ENV["CAPTURES_DIR"].present?

require_relative "lesson_rendering_test"

class Catalog::LessonCaptureTest < ApplicationSystemTestCase
  include LessonRendering::Verifier

  DESKTOP_WIDTH = 1280
  MAX_HEIGHT = 12_000

  # Un test par leçon : defects_for prépare le référentiel, une seule fois par test.
  ENV.fetch("CAPTURE_FILES").split(",").zip(ENV.fetch("CAPTURE_SUBJECTS").split(",")).each do |file, subject|
    test "captures de la leçon de #{subject} à 390 px et à 1280 px" do
      @capture = { directory: ENV.fetch("CAPTURES_DIR"), subject: }
      FileUtils.mkdir_p(@capture[:directory])
      defects = defects_for(file)
      # Les défauts sont le travail du test d'affichage ; ici seul compte que la page ait été photographiée.
      assert File.exist?(File.join(@capture[:directory], "#{subject}-390.png")) &&
             File.exist?(File.join(@capture[:directory], "#{subject}-#{DESKTOP_WIDTH}.png")),
             "captures de #{file} non produites : #{defects.map(&:to_s).join(' ; ')}"
    end
  end

  private

  # Prend la place de la mesure du test d'affichage : la page est attendue finie (formules, figures), puis photographiée.
  def inspect_page(_file, course, lesson, width)
    visit course_path(course.slug)
    assert_selector "h1", text: course.name, wait: 20
    reveal_revision_sheet
    measure_page(lesson)
    if width == LessonRendering::PHONE
      photograph("390")
    else
      page.current_window.resize_to(DESKTOP_WIDTH, 900)
      photograph(DESKTOP_WIDTH.to_s)
    end
    []
  end

  # Pleine page (jusqu'à MAX_HEIGHT) : la capture sort de la fenêtre par le protocole de Chrome.
  def photograph(label)
    height = [ page.evaluate_script("document.documentElement.scrollHeight"), MAX_HEIGHT ].min
    width = page.evaluate_script("window.innerWidth")
    data = page.driver.browser.execute_cdp("Page.captureScreenshot", format: "png", captureBeyondViewport: true,
                                                                    clip: { x: 0, y: 0, width:, height:, scale: 1 })
    File.binwrite(File.join(@capture[:directory], "#{@capture[:subject]}-#{label}.png"), Base64.decode64(data.fetch("data")))
  end
end
