# 🌐 DELIVERY · StudentEntrySession — l'entrée élève gardée en session entre l'entrée et la fin de l'inscription
# Rôle : numéro et code secret saisis à l'entrée, confirmés ou non, et le jeton du lien de classe ; 30 minutes, jamais dans l'adresse ni dans la page
# ADR  : 0141-entree-eleve-revele-un-numero-inscrit (§4.3) · UDR : 0176-entree-eleve-unique
module StudentEntrySession
  extend ActiveSupport::Concern

  KEY = :student_entry
  # Le temps d'une inscription en classe ; au-delà, l'élève repasse par l'entrée.
  TTL = 30.minutes
  Entry = Data.define(:contact, :pin, :confirmed, :link_token)

  private

  # La session Rails est un cookie chiffré et authentifié (HttpOnly) ; start_session la remet à zéro à la connexion.
  def student_entry
    data = session[KEY]
    return unless data.is_a?(Hash)
    return forget_student_entry if Time.current.to_i - data["at"].to_i > TTL.to_i

    Entry.new(contact: data["contact"], pin: data["pin"], confirmed: data["confirmed"] == true, link_token: data["link_token"])
  end

  def confirmed_student_entry = student_entry&.then { it if it.confirmed }

  def keep_student_entry(contact:, pin:, confirmed:, link_token:)
    session[KEY] = { "contact" => contact, "pin" => pin, "confirmed" => confirmed, "link_token" => link_token,
                     "at" => Time.current.to_i }
  end

  # Rend l'entrée effacée (ou nil) : « Corriger mon numéro » pré-remplit le numéro.
  def forget_student_entry
    data = session.delete(KEY)
    return unless data.is_a?(Hash)

    Entry.new(contact: data["contact"], pin: nil, confirmed: false, link_token: data["link_token"])
  end
end
