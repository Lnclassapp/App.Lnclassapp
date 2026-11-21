# 🌐 DELIVERY · StudentEntrySession — l'entrée élève gardée en session entre l'entrée et la fin de l'inscription
# Rôle : numéro et code secret saisis à l'entrée, confirmés ou non, et le jeton du lien de classe ; 30 minutes, jamais dans l'adresse ni dans la page
# ADR  : 0141-entree-eleve-revele-un-numero-inscrit (§4.3), adresse-publique-etablissement (§6) · UDR : 0176-entree-eleve-unique
module StudentEntrySession
  extend ActiveSupport::Concern

  KEY = :student_entry
  # Le temps d'une inscription en classe ; au-delà, l'élève repasse par l'entrée.
  TTL = 30.minutes
  # L'établissement du QR (/e/<id>), gardé avant l'entrée : une clé à part, car l'entrée n'existe pas encore au scan.
  SCHOOL_KEY = :student_entry_school
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

  # Seul un établissement actif est gardé (le contrôleur de l'adresse l'a vérifié) ; l'inscription le rejuge à l'envoi.
  def keep_entry_school(public_id)
    session[SCHOOL_KEY] = { "public_id" => public_id, "at" => Time.current.to_i }
  end

  # → l'identifiant public gardé, nil s'il manque ou si les 30 minutes sont passées.
  def entry_school_public_id
    data = session[SCHOOL_KEY]
    return unless data.is_a?(Hash)
    return session.delete(SCHOOL_KEY) && nil if Time.current.to_i - data["at"].to_i > TTL.to_i

    data["public_id"].presence
  end
end
