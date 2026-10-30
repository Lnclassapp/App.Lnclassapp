# Plan d'exécution — Liste de la classe : le badge dit qu'il vient de la moyenne

## Lot A — Pastille « Moyenne x/20 · badge » dans la liste

- **Couche**       : ui (vue ERB, i18n)
- **Fichiers**     : `app/views/classroom/classrooms/_roster.html.erb` · `config/locales/classroom/classrooms.fr.yml` (et la locale anglaise si la clé y existe)
                     tests de la liste de la classe (contrôleur ou système existants qui lisent `#badge_<public_id>`)
                     `docs/decisions/udr/0134-ecrans-enseignant-sans-repetition.md` (§3.5, ligne `_roster`)
- **Dépend de**    : —
- **Done quand**   : `#badge_<id>` affiche « Moyenne 15/20 · Or » avec badge, « Moyenne 7/20 · Pas encore » avec une note sans badge, « Pas encore » sans exercice fait ; tient sur une ligne à 390 px.

### Contrat d'exécution (ordre strict)

1. Adapter/écrire les tests des trois cas ; les lancer : rouges pour la bonne raison.
2. Vue : `badge_grade` → « Moyenne %{grade}/20 · %{badge} » ; branche `else` : si `student.grade` présent, « Moyenne %{grade}/20 · Pas encore » (`comprehension_box_label(:none)`), sinon « Pas encore ». Commentaire de la vue à jour.
3. UDR-0134 §3.5 : remplacer « pastille du badge à droite « Or · 15/20 » (§3.1) ou « Pas encore » `text-mute` » par la règle du memo, avec la date de l'amendement.
4. Tests verts ; `test/system` qui touchent la page de classe ; rubocop / erb lint des fichiers touchés.
5. Journal ; un commit `fix(classroom): say the roster badge comes from the class average` avec le pied `Chantier: docs/chantiers/badge-liste-moyenne`.
