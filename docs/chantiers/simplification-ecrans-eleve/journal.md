# Journal — simplification-ecrans-eleve

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Graisse des titres : `font-medium` (500), pas le 700 des maquettes | Le garde `design_tokens_test` interdit plus de 500 hors page d'accueil publique (UDR palette froide §3.2) | non |
| 2026-11-14 | La flèche retour des écrans intérieurs amende le garde FU-11 (UDR-0054 §3.2) | Le porteur demande une flèche retour ; seul `shared/screens/_inner_header` est exempté | UDR XXXX |
| 2026-11-14 | Valeur à droite de « À faire » : l'échéance (« À rendre demain »), pas « 0/4 » | L'exercice assigné n'a pas de total de questions dans `StudentHomeQuery` ; on n'invente pas de donnée | non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-14 · simplification-ecrans-eleve · Sigle de l'établissement absent de la base : dérivé des initiales du nom (mots de 3 lettres et plus, hors articles, 4 lettres au plus ; « Lycée Moderne de Treichville » → « LMT ») — appliqué : dérivation à l'affichage, rien écrit en base ; autres : saisir le sigle à l'import, ou afficher le nom en entier ; recommandé : dérivation
- [ ] 2026-11-14 · simplification-ecrans-eleve · « Leçon n » s'écrit « Leçon » à l'écran alors que le vocabulaire (UDR-0007, 0130) dit « fiche de cours » — appliqué : « Leçon n » comme dans les maquettes validées, ajouté aux exceptions de `test/i18n/locale_files_test.rb` ; autres : « Fiche n » ; recommandé : garder « Leçon n »
- [ ] 2026-11-14 · simplification-ecrans-eleve · La charte `lnclass-design-system` (skill hors dépôt) impose encore la carte « Prochain exercice » (§6 à §8) et l'« Exercice du jour » — appliqué : l'UDR du chantier prime (README de design, `test-ecrans`) ; à faire : mettre la skill à jour hors dépôt ; recommandé : mise à jour par le porteur
- [ ] 2026-11-14 · simplification-ecrans-eleve · « Voir plus (n) » sans JavaScript : les lignes en trop restent cachées — appliqué : même comportement que l'UDR-0057 R3 ; autres : tout afficher sans JS (`<noscript>`) ; recommandé : garder

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Environnement de la session : Ruby 3.4.9 absent (installé avec rbenv), `LANG=C.UTF-8` nécessaire au hook pre-commit (`build_index`), ChromeDriver du PATH (147) refuse Chrome 153 : retirer `/opt/node22/bin` du PATH laisse selenium-manager choisir.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| `StudentHomeQuery#next_step` et `DailyExerciseQuery` ne sont plus lus par l'accueil (calcul mort) ; `next_step/_start` et `NextExerciseQuery` après le lot C | Les retirer touche la query et ses ~40 tests ; hors du périmètre « écrans » | nettoyage `next-step-mort` |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
