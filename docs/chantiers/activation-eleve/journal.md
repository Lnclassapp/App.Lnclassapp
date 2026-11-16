# Journal — Activation de l'élève : de l'inscription au premier exercice réussi

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-16 | Pas de changement de champs à l'inscription ; le message de bienvenue reste « Bienvenue dans ta classe ! » | Le numéro reste (porteur) ; la classe, le genre et le PIN sont des règles d'identité ; un niveau sans exercice publié n'aurait pas de carte : un message « Fais ton premier exercice » mentirait | Non (UDR) |
| 2026-11-16 | Une query de lecture `classroom` pour l'activation, qui réutilise la query « Prochain exercice » matière par matière | Aucun port, aucune table (ADR-0049, ADR-0062) ; la règle de choix existe déjà | Non (PRD §6) |
| 2026-11-16 | L'exercice de la carte sort de « À faire », quelle que soit sa source | Une porte par action (UDR-0173 règle 3) : pour l'élève seul, le premier exercice du programme peut aussi être un devoir | Non (UDR) |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-16 · activation-eleve · « Premier exercice réussi » : à partir de quelle note ? — appliqué : 10/20 arrondi (seuil de la moyenne de la notation) ; autres : 14/20 (maîtrise, seuil de « Refaire » d'avant) ; recommandé : 10/20
- [ ] 2026-11-16 · activation-eleve · L'élève seul (entré par la liste) dont la classe a des devoirs : la carte propose le programme ou le devoir ? — appliqué : le programme (le devoir reste dans « À faire ») ; autres : le devoir, comme l'élève amené ; recommandé : le programme
- [ ] 2026-11-16 · activation-eleve · « Refaire » dans l'historique de l'accueil : sur toute copie terminée, ou seulement sous 14/20 comme avant ? — appliqué : toute copie terminée, hors pause (le porteur veut pouvoir refaire ce qu'on a touché) ; autres : sous 14/20 ; recommandé : toute copie

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Le message de bienvenue « Fais ton premier exercice ! » prévu au PRD a été retiré avant le code : les niveaux sans exercice publié (6e à 4e, 2nde) n'auraient pas de carte, le message aurait menti. Le CA-10 est devenu le parcours navigateur de l'inscription au premier exercice.
- Première version : l'exercice de la carte ne sortait de « À faire » que pour l'élève amené. Le test d'ordre de l'accueil l'a montré : pour l'élève seul, le premier exercice du programme peut être un devoir de la classe, deux portes vers le même exercice. La règle est devenue « l'exercice de la carte sort de « À faire », quelle que soit sa source ».
- Les revues du diff final ont trouvé deux écarts, corrigés avant la fusion : l'historique reprenait une copie dont la leçon était retirée (la carte, non) ; « Voir plus (n) » comptait des copies en cours que Mon historique ne liste pas. Le challenger (rôle distinct, navigateur, jeu standard) a rejoué le parcours nominal, l'élève amené, le retour par l'historique et le double clic sur « Commencer » : 4 sur 4.
- Environnement de la session : Ruby 3.4.9 à compiler, corepack à activer, `LANG=C.UTF-8` obligatoire sinon `script/docs/build_index` tombe sur l'encodage, chromedriver du système (147) plus vieux que Chrome (153) : `CHROMEDRIVER_PATH` vers celui que selenium-manager télécharge.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- `classroom_students.joined_via` : « standard » = l'élève a choisi sa classe dans la liste (seul) ; « link » et « code » = il est venu par ce que l'enseignant ou l'établissement a donné.
- `Grading.reaches?` compare des notes arrondies au point sur 20 : 48 % vaut 10/20. Un seuil lu en SQL (`score_percent >= 50`) aurait raté ce cas ; l'activation lit la meilleure note puis applique `reaches?`.
- `NextExerciseQuery` marche sans filtre de matière, mais l'ordre du programme y est celui des leçons toutes matières confondues : l'activation l'appelle matière par matière, dans l'ordre de la grille.
- Le parcours système `boucle_pedagogique_test` passait par « À faire » : il passe maintenant par la carte, en un tap.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Moment « aha » sur la page de résultat (« Premier exercice réussi ! ») | Hors périmètre : la page de résultat ne change pas ; la carte qui disparaît suffit à marquer le passage | à ouvrir si la mesure le demande |
| Élève sans classe active : pas de carte d'activation | Rejoindre une classe est son premier pas | — |
| La carte coûte jusqu'à 2 requêtes par matière tant que l'élève n'est pas activé (8 matières au plus) | Seulement pendant l'activation, sans index nouveau | `entonnoir-aarrr` dira si la page en souffre |
| Relances WhatsApp vers la carte | Chantier de l'équipe, à la main (porteur) | relances WhatsApp |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-11-16 |
| **PR** | |
| **ADR produits** | aucun (PRD §6) |
| **UDR produits** | UDR-0174 |
