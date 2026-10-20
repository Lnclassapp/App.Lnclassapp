# Journal — ci-par-train

## 2026-10-20

- Le porteur retient les trois leviers ensemble et demande de les appliquer sans attendre le relevé complet des CI jouées par PR.
- **Protocole de la mesure après**, rejouable : pour chaque fusion de `git log --first-parent --merges origin/Develop -40`, appliquer `CiScope.level(branch: "x", changed: git diff --name-only <fusion>^1 <fusion>)`.
- **Levier abandonné : les migrations, fixtures, `config/` et `test/support/` au train.** Première version : 13 PR sur 28 en train, presque rien de gagné. Ils jouent maintenant les tests qui les nomment (constante, méthodes d'aide, jeu de fixture, nom ou dossier du fichier).
- **Levier abandonné : un hook `pre-push` vers `Staging`.** La promotion est une PR GitHub (#267) : aucun push local à intercepter.
- Une fabrique partagée sélectionne jusqu'à 600 des 758 tests unitaires : accepté, la suite système (la plus longue) reste au train.
- **Le porteur fixe 5 minutes au plus pour la preuve d'une PR.** La PR #270 devait le train (elle touche la CI) : interrompu après 20 minutes. Corrections : la CI n'est plus large (ses gardes et ses tests la prouvent), les niveaux doc et pr ne jouent plus `bin/setup` (2 min 10 s) et Rubocop n'inspecte que les fichiers changés (41 s pour tout l'arbre).
- **Le porteur étend le plafond : aucune tâche de CI ne dépasse 5 minutes, la suite complète comprise.** En local c'est impossible : les tests système cumulent 16,7 min de navigateur, et le poste n'a que 4 cœurs. Le dépôt étant public, le train passe sur GitHub (`CI_ENABLED` recréée par le porteur), seulement pour les PR vers `Staging` et `main`, avec `unit` en 3 parts et `system` en 6 parts (≈ 167 s enregistrées chacune), et `timeout-minutes: 5` sur chaque tâche, vérifié par la garde.
