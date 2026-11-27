# 🌐 DELIVERY · Identity::TeacherEntriesController
# Rôle : « Enseignant(e) » de l'accueil, numéro d'abord (/teacher) : inscrit → le code, puis connecté (tout rôle) ; inconnu → l'inscription enseignant, le numéro gardé, ouverte sur le code
# ADR  : 0050, 0148-connexion-revele-un-numero-inscrit · UDR : 0189-connexion-numero-d-abord (amendement du 2026-11-27, §3.8)
module Identity
  # La connexion de /login, mêmes compteurs et mêmes refus ; seuls changent l'adresse, le titre et l'issue d'un numéro sans compte.
  class TeacherEntriesController < SessionsController
    # La vue est celle de /login (identity/sessions/new, trouvée par héritage) ; @teacher_entry y change titre et adresses.
    before_action { @teacher_entry = true }

    private

    def entered(value)
      return super unless value.outcome == :new_number

      keep_student_entry(contact: value.contact, pin: nil, confirmed: false, link_token: nil, known: false)
      redirect_to new_teacher_registration_path(confirmed: 1), status: :see_other
    end

    def entry_path(**) = new_teacher_entry_path(**)
    def entries_path = teacher_entries_path
  end
end
