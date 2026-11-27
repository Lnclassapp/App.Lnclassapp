# 🌐 DELIVERY · StudentEntrySession — l'entrée « numéro d'abord » gardée en session, de /login ou /student à la fin de l'inscription
# Rôle : le numéro, s'il a un compte (known), le code d'un nouvel élève une fois tapé (confirmed), et le jeton du lien de classe ; 30 minutes, jamais dans l'adresse ni dans la page
# ADR  : 0141-entree-eleve-revele-un-numero-inscrit (§4.3), XXXX-connexion-revele-un-numero-inscrit (§4.3), adresse-publique-etablissement (§6) · UDR : 0176-entree-eleve-unique, XXXX-connexion-numero-d-abord
module StudentEntrySession
  extend ActiveSupport::Concern

  KEY = :student_entry
  # Le temps d'une inscription en classe ; au-delà, l'élève repasse par l'entrée.
  TTL = 30.minutes
  # L'établissement du QR (/ecole/<id>), gardé avant l'entrée : une clé à part, car l'entrée n'existe pas encore au scan.
  SCHOOL_KEY = :student_entry_school
  # known : le numéro a un compte (étape du code) ; sinon, l'écran « pas de compte » ou « Nouveau sur Lnclass ».
  Entry = Data.define(:contact, :pin, :confirmed, :link_token, :known)

  private

  # La session Rails est un cookie chiffré et authentifié (HttpOnly) ; start_session la remet à zéro à la connexion.
  def student_entry
    data = session[KEY]
    return unless data.is_a?(Hash)
    # Expirée : effacée, et rien n'est rendu ; l'écran du numéro revient, vide.
    return session.delete(KEY) && nil if Time.current.to_i - data["at"].to_i > TTL.to_i

    Entry.new(contact: data["contact"], pin: data["pin"], confirmed: data["confirmed"] == true, link_token: data["link_token"],
              known: data["known"] == true)
  end

  # L'écran d'une entrée : :contact (rien de gardé), :pin (numéro inscrit), :new_account (numéro sans compte).
  def entry_stage(entry)
    return :contact unless entry&.contact
    return :pin if entry.known

    :new_account
  end

  # Le numéro gardé sans compte : l'inscription enseignant qui suit l'écran « pas de compte » de /login le reprend.
  def new_number_entry = student_entry&.then { it unless it.known || it.contact.blank? }

  def confirmed_student_entry = student_entry&.then { it if it.confirmed }

  def keep_student_entry(contact:, pin:, confirmed:, link_token:, known: false)
    session[KEY] = { "contact" => contact, "pin" => pin, "confirmed" => confirmed, "link_token" => link_token,
                     "known" => known, "at" => Time.current.to_i }
  end

  # Rend l'entrée effacée (ou nil) : « Corriger mon numéro » pré-remplit le numéro.
  def forget_student_entry
    data = session.delete(KEY)
    return unless data.is_a?(Hash)

    Entry.new(contact: data["contact"], pin: nil, confirmed: false, link_token: data["link_token"], known: false)
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
