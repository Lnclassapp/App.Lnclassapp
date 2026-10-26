# Maquettes du chantier mvp-teacher-student

Branche à part, **jamais fusionnée** (porteur, 2026-10-26) : elle sert seulement à donner les maquettes à Touré et Konan. Les captures ne sont jamais commitées dans `Develop` (CLAUDE.md). On supprime la branche après le pilote.

- `lnclass-ecrans-v12-2026-10-26-mon-compte-jaune.zip` : 140 écrans retenus, chacun en gris (mise en page) et en couleur (jetons).
  - `eleve/{gris,couleur}/{telephone,ordinateur}/` : 18 écrans par dossier.
  - `enseignant/{gris,couleur}/{telephone,ordinateur}/` : 17 écrans par dossier.
  - Chaque écran : un `.html` (à ouvrir dans le navigateur) et son `.png`. `index.html` à la racine les montre tous ; `HISTORIQUE.txt` liste les versions.
- Chaque issue de lot (#286 à #313) dit quels écrans suivre.

Télécharger : `git fetch origin maquettes/mvp-teacher-student && git show origin/maquettes/mvp-teacher-student:lnclass-ecrans-v12-2026-10-26-mon-compte-jaune.zip > maquettes.zip`, ou le bouton « Download » de GitHub sur le fichier.
