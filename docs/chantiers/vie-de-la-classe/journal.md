# Journal — La vie de la classe

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Le périmètre se réduit à CL-02, CL-14 et la dette des sous-pages archivées | L'inventaire du code montre livrés depuis la feuille de route : l'archivage (ADR-0088), le lien remplaçable (ADR-0085), le retrait d'un élève, le choix de classe par l'élève, la page d'une classe et ses listes | Non (memo) |
| 2026-10-16 | Recommander le préfixe du barème fixe et un suffixe libre | La cascade de l'élève et le « + » restent vrais ; un nom libre les casse | ADR-0098 (proposé) |
| 2026-10-16 | Recommander l'équipe et la direction, pas l'enseignant | Même policy que « + », « − » et l'archivage ; l'enseignant se déclare sans validation (ADR-0085 §5) | ADR-0098 (proposé) |
| 2026-10-16 | Ne pas renommer `shared/_classroom_archive_menu` en y ajoutant « Modifier » | Le renommage toucherait locales et appelants sans rien changer pour l'utilisateur | Non (UDR-0111) |
| 2026-10-16 | Réponses du porteur : recommandations acceptées sauf Q6 ; Lot B retiré, Lot C en correctif séparé | « pas de moyenne de classe » ; la dette des sous-pages archivées part tout de suite sur `fix/classe-archivee-sous-pages` | ADR-0098, UDR-0110, UDR-0111 acceptés ; UDR-0112 abandonnée |
| 2026-10-16 | Lot 0 : le DTO ne porte que `suffix` et `max_students` | L'établissement et la classe sont des arguments du use case, comme `ArchiveClassroom` ; les répéter dans le DTO ferait deux sources | Non |
| 2026-10-16 | Lot 0 : la longueur du nom complet n'est pas validée par le DTO | Elle dépend du préfixe, que seul le use case connaît (niveau et série de la classe lue) | Non (ADR-0098 §4) |
| 2026-10-16 | Lot A : une query `ClassroomSettingsQuery` pour la modale (préfixe, suffixe, effectif), absente du plan | La modale doit montrer le préfixe et l'effectif avant tout envoi ; le use case ne sert pas la lecture | Non |
| 2026-10-16 | Lot A : un concern `ClassroomSettingsActions` porte `edit` et `update` des deux espaces | Les deux contrôleurs ne diffèrent que par l'établissement et le retour sans JavaScript ; la policy des gestes de structure garde aussi la lecture de la modale | Non |
| 2026-10-16 | Lot A : le succès re-demande la page par morphing au lieu de remplacer la carte | Comme « Ajouter une classe » : la carte peut changer de place (« 6ème A » passe avant « 6ème 1 ») | UDR-0110 précisée |
| 2026-10-16 | Lot A : le champ du suffixe est écrit à la main, pas par `ui_field` | Le préfixe doit se glisser entre le libellé et le champ, sur la même ligne ; mêmes classes, même aide, même erreur reliée | Non |
| 2026-10-16 | Lot A : un refus « classe archivée » répond 422 en Turbo Stream (toast neutre, page rafraîchie) | Comme les autres conflits de l'archivage (UDR-0083) | Non |
