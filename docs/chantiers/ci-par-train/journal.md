# Journal — ci-par-train

## 2026-10-20

- Le porteur retient les trois leviers ensemble et demande de les appliquer sans attendre le relevé complet des CI jouées par PR.
- **Protocole de la mesure après**, rejouable : pour chaque fusion de `git log --first-parent --merges origin/Develop -40`, appliquer `CiScope.level(branch: "x", changed: git diff --name-only <fusion>^1 <fusion>)`.
- **Levier abandonné : les migrations, fixtures, `config/` et `test/support/` au train.** Première version : 13 PR sur 28 en train, presque rien de gagné. Ils jouent maintenant les tests qui les nomment (constante, méthodes d'aide, jeu de fixture, nom ou dossier du fichier).
- **Levier abandonné : un hook `pre-push` vers `Staging`.** La promotion est une PR GitHub (#267) : aucun push local à intercepter.
- Une fabrique partagée sélectionne jusqu'à 600 des 758 tests unitaires : accepté, la suite système (la plus longue) reste au train.
