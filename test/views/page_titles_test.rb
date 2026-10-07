require "test_helper"

# UDR-0054 §3.1, §3.2, §3.3, §3.12 — the guards of the UX finishes, once every screen is migrated (Lot Z):
# every page view names its page through `page_title` (FU-06), no view sets `content_for :title` or the `autofocus`
# attribute (FU-20), no locale writes the « · Lnclass » suffix (FU-06), no back link is an `arrow-left` button and no
# breadcrumb is left (FU-11).
class PageTitlesTest < ActiveSupport::TestCase
  VIEWS = Rails.root.join("app/views")

  # Views that are not pages: served only inside a frame, or the demonstrations of /design served in one.
  NOT_PAGES = %w[design/frame.html.erb school/drena_schools/index.html.erb].freeze

  ERB_CODE = /<%(?!#)=?(.*?)-?%>/m
  RENDERED_TEMPLATE = /\A\s*render\s*\(?\s*template:\s*["']([^"']+)["']/

  def relative(path) = Pathname(path).relative_path_from(VIEWS).to_s
  def source(path) = File.read(path)

  def page_views
    Dir[VIEWS.join("**/*.html.erb")].reject do |path|
      name = relative(path)
      File.basename(path).start_with?("_") || name.start_with?("layouts/", "components/") || NOT_PAGES.include?(name)
    end
  end

  def all_views = Dir[VIEWS.join("**/*.erb")]

  # A page names itself, or renders the page view that does (`render template:`).
  def names_its_page?(path, seen = [])
    code = source(path)
    return true if code.match?(/\bpage_title[\s(]/)

    code.scan(ERB_CODE).flatten.filter_map { it[RENDERED_TEMPLATE, 1] }.any? do |template|
      target = VIEWS.join("#{template}.html.erb").to_s
      !seen.include?(target) && File.exist?(target) && names_its_page?(target, seen + [ path ])
    end
  end

  # Markup outside the ERB code, where an `autofocus` attribute would be written by hand.
  def markup(code) = code.gsub(/<%.*?%>/m, "")

  def locale_strings(node, &block)
    case node
    when Hash then node.each_value { locale_strings(it, &block) }
    when Array then node.each { locale_strings(it, &block) }
    when String then yield node
    end
  end

  test "FU-06: every page view calls page_title" do
    offenders = page_views.reject { names_its_page?(it) }.map { relative(it) }

    assert_empty offenders, "UDR-0054 §3.1 : page sans page_title — #{offenders.join(', ')}"
  end

  test "FU-06: no view sets content_for :title, and the layout composes the title" do
    offenders = all_views.select { source(it).match?(/content_for\??[\s(]*:title\b|yield[\s(]*:title\b/) }.map { relative(it) }

    assert_empty offenders, "UDR-0054 §3.1 : content_for :title interdit — #{offenders.join(', ')}"
    assert_match "<title><%= document_title %></title>", source(VIEWS.join("layouts/application.html.erb"))
  end

  test "FU-06: no locale writes the « · Lnclass » suffix" do
    offenders = Dir[Rails.root.join("config/locales/**/*.yml")].flat_map do |path|
      found = []
      locale_strings(YAML.load_file(path, aliases: true)) { found << "#{File.basename(path)} : #{it}" if it.include?("· Lnclass") }
      found
    end

    assert_empty offenders, "UDR-0054 §3.1 : le helper ajoute « · Lnclass » — #{offenders.join(' | ')}"
  end

  test "FU-20: no view carries the autofocus attribute; ui_field autofocus: names the target of the controller" do
    by_hand = all_views.select { markup(source(it)).match?(/\sautofocus(?=[\s=>\/])/) }.map { relative(it) }
    by_helper = all_views.select do |path|
      source(path).scan(ERB_CODE).flatten.any? { it.match?(/\bautofocus:/) && !it.lstrip.start_with?("ui_field") }
    end.map { relative(it) }

    assert_empty by_hand, "UDR-0054 §3.3 : attribut autofocus écrit dans #{by_hand.join(', ')}"
    assert_empty by_helper, "UDR-0054 §3.3 : autofocus: hors d'ui_field dans #{by_helper.join(', ')}"
  end

  test "FU-11: no back button with an arrow-left icon, no breadcrumb" do
    offenders = (all_views + Dir[Rails.root.join("app/helpers/**/*.rb")]).select do |path|
      source(path).match?(/arrow-left|breadcrumb|Fil d'Ariane/i)
    end.map { Pathname(it).relative_path_from(Rails.root).to_s }

    assert_empty offenders, "UDR-0054 §3.2 : un seul retour, le lien à chevron — #{offenders.join(', ')}"
  end

  test "the guards see what they forbid" do
    assert_match(/\sautofocus(?=[\s=>\/])/, markup(%(<input name="q" autofocus>)))
    assert_no_match(/\sautofocus(?=[\s=>\/])/, markup(%(<body data-controller="autofocus"><%= ui_field f, :q, autofocus: true %>)))
    assert_equal [ " ui_field f, :q, autofocus: true " ], %(<%= ui_field f, :q, autofocus: true %>).scan(ERB_CODE).flatten
    assert_equal "identity/teacher_registrations/new",
                 %( render template: "identity/teacher_registrations/new" )[RENDERED_TEMPLATE, 1]
    # A page that only renders the page view naming itself (no such view is left in app/views since ADR-0082).
    Tempfile.create([ "delegating", ".html.erb" ]) do |view|
      view.write(%(<%= render template: "identity/teacher_registrations/new" %>\n))
      view.flush
      assert names_its_page?(view.path)
    end
    Tempfile.create([ "unnamed", ".html.erb" ]) do |view|
      view.write(%(<p>Sans titre</p>\n))
      view.flush
      assert_not names_its_page?(view.path)
    end
  end
end
