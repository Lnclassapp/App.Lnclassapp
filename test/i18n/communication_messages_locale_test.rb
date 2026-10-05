require "test_helper"

# UDR-0071 §3 : les libellés partagés des annonces (Lot 0), que les lots A, B et C lisent tels quels, et l'entrée
# « Annonces » de la navigation et de l'accueil élève.
class CommunicationMessagesLocaleTest < ActiveSupport::TestCase
  def t(key, **) = I18n.t(key, locale: :fr, raise: true, **)

  test "les statuts, « Terminée » compris, et les destinataires" do
    assert_equal({ draft: "Brouillon", scheduled: "Programmée", published: "Publiée", archived: "Archivée", withdrawn: "Retirée",
                   ended: "Terminée" }, t("communication.statuses"))
    assert_equal({ all: "Tous", students: "Élèves", teachers: "Enseignants", school_admins: "Directions", classrooms: "Classes" },
                 t("communication.audiences"))
    assert_equal "Tout le pays", t("communication.scopes.national")
    assert_equal Entities::Communication::Message::STATUSES + [ "ended" ], t("communication.statuses").keys.map(&:to_s)
    assert_equal Entities::Communication::Message::AUDIENCES, t("communication.audiences").keys.map(&:to_s)
  end

  # UDR-0075 §3.1 : les libellés des dix thèmes, dans l'ordre de Entities::Communication::Message::THEMES (Lot 0 de
  # annonces-v2, lus par les lots A et B).
  test "AV-07 — les dix thèmes ont chacun leur libellé, dans l'ordre de l'ADR-0081" do
    assert_equal({ ciel: "Ciel", lagune: "Lagune", menthe: "Menthe", citron: "Citron", mangue: "Mangue", corail: "Corail",
                   hibiscus: "Hibiscus", lavande: "Lavande", indigo: "Indigo", nuit: "Nuit" }, t("communication.themes"))
    assert_equal Entities::Communication::Message::THEMES, t("communication.themes").keys.map(&:to_s)
  end

  test "la signature et les onglets" do
    assert_equal({ team: "Lnclass", school_admin: "Direction", male: "M.", female: "Mme" }, t("communication.signature"))
    assert_equal({ label: "Annonces", received: "Reçues", mine: "Mes annonces", school: "Enseignants", all: "Toutes" },
                 t("communication.tabs"))
  end

  test "la carte, l'audio et le masquage, mot pour mot" do
    assert_equal ", annonce officielle", t("communication.card.official")
    assert_equal [ "Modifiée", "Masquée", "Réafficher" ], %w[edited dismissed restore].map { t("communication.card.#{it}") }
    assert_equal "Masquer l'annonce « Nouvelles fiches »", t("communication.card.dismiss", title: "Nouvelles fiches")
    assert_equal({ new: "Écouter le message", playing: "Arrêter la lecture", played: "Réécouter le message" },
                 t("communication.audio.labels"))
    assert_equal [ "Audio indisponible sur ce téléphone.", "Écouter" ], %w[unavailable fallback].map { t("communication.audio.#{it}") }
    assert_equal [ "Annonce masquée", "Elle reste dans « Toutes les annonces ».", "Annuler", "Cette annonce ne peut pas être masquée." ],
                 %w[title message undo refused].map { t("communication.dismissal.#{it}") }
  end

  test "« Annonces » dans la navigation et dans les sections de l'accueil" do
    assert_equal "Annonces", t("shared.navigation.announcements")
    assert_equal({ title: "Annonces", subtitle: "Ce que t'annoncent tes enseignants, ta direction et Lnclass",
                   empty: "Aucune annonce pour le moment" }, t("shared.home.sections.announcements"))
  end
end
