# Plan d'exécution — Classe sans exercice : « ci-dessous » ne montre rien

## Lot A — L'état vide mène aux cours

- **Couche**       : ui (vue ERB, i18n)
- **Fichiers**     : `app/views/classroom/classrooms/_assigned_exercises.html.erb` · `config/locales/classroom/classrooms.fr.yml`
                     `test/controllers/classroom/classrooms_controller_test.rb` (test de l'état vide, vers la ligne 290)
                     `docs/decisions/udr/0062-echeances.md` (bloc « Exercices assignés », ligne « Vide »)
- **Done quand**   : l'état vide dit « … dans « Cours » … » ; l'enseignant y voit « Voir les cours » vers `courses_path` ; un autre rôle qui voit la page (équipe, chef d'établissement, s'il y en a un) n'a pas le bouton.

### Contrat d'exécution (ordre strict)

1. Tests : adapter le test de l'état vide (texte et bouton pour l'enseignant) ; ajouter l'absence du bouton pour un autre rôle qui voit la page, s'il en existe un (sinon le noter au journal). Rouges pour la bonne raison.
2. Vue : `ui_empty_state … action: ({ label: t(".empty_action"), href: courses_path, variant: :secondary, icon: "book-open" } if <le lecteur est enseignant>)`, en réutilisant ce que la vue ou le contrôleur sait déjà du rôle (ne rien recalculer en vue si une variable existe). Locale : `empty_description` et `empty_action: "Voir les cours"`. En-tête HITL à jour.
3. UDR-0062 : la ligne « Vide » du bloc « Exercices assignés » suit le memo, datée 2026-10-29.
4. Tests verts ; tests système de la page de classe ; rubocop et lint ERB des fichiers touchés.
5. Journal ; un commit `fix(classroom): point an empty class to its courses`, pied `Chantier: docs/chantiers/classe-vide-lien-cours`.
