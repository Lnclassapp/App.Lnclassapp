# UDR-0054 §3.1 : Mission Control Jobs (monté sous /teams/jobs, ADR-0052) déclare dans ses helpers un lecteur
# `page_title` sans argument, qui masque PageTitleHelper#page_title(page) dans les vues rendues sous l'engine. Une page
# d'erreur de l'application y est rendue (403 d'un compte qui n'est pas de l'équipe) et appelle page_title(page) :
# l'appel avec argument revient au helper de l'application, l'appel sans argument reste celui de l'engine.
module MissionControlPageTitle
  def page_title(*page)
    page.empty? ? super() : PageTitleHelper.instance_method(:page_title).bind_call(self, *page)
  end
end

Rails.application.config.to_prepare { MissionControl::Jobs::NavigationHelper.prepend(MissionControlPageTitle) }
