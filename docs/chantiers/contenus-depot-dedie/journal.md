# Journal — Les leçons vivent dans leur propre dépôt

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-14 | Copie figée versionnée au même chemin (`docs/contenus/lecons-traitees/` + `VERSION`), pas de sous-module ni de téléchargement | Develop et Staging chargent les leçons au pré-déploiement depuis l'image : ni jeton ni réseau en plus | Oui, ADR `contenus-dans-un-depot-dedie-copie-figee` |
| 2026-11-14 | `valider.rb` reste dans l'application | Il charge les entités du domaine et un test de parité le lie à l'import | Oui, même ADR §4.1 |
| 2026-11-14 | Dépôt : d'abord `Kamkara007/App.Lnclassapp-contenus`, puis `Lnclassapp/App.Lnclassapp-contenus` (final) ; rien n'y est poussé avant la migration | Un premier commit README obligerait à réécrire `main` pour y poser l'historique migré | Non |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [x] 2026-11-14 · contenus-depot-dedie · Le dépôt de contenus doit-il être privé ? — réponse du porteur (via l'orchestrateur) : **public**, tel quel. Écrit dans l'ADR §4.4 (corrigés visibles, jamais de secret ni de donnée d'élève). Si sa CI récupère l'application (privée), il lui faut un jeton de lecture : `APP_READ_TOKEN`, secret du dépôt de contenus, posé par le porteur.
- Info : dépôt final `Lnclassapp/App.Lnclassapp-contenus` (porteur, 2026-11-14). Il ne peut pas être attaché à la session du Lot A (même nom que `Kamkara007/App.Lnclassapp-contenus`, déjà attaché) : le Lot B part d'une **nouvelle session** avec `Lnclassapp/App.Lnclassapp-contenus` comme source. `Kamkara007/App.Lnclassapp-contenus` (vide) peut être supprimé par le porteur.
- [ ] 2026-11-14 · contenus-depot-dedie · Ne pas lancer soi-même les commandes d'initialisation du dépôt (README « first commit ») — appliqué : dépôt laissé vide, la migration (Lot B) y pose l'historique des leçons puis le README ; autres : initialiser maintenant et poser la migration par-dessus ; recommandé : laisser vide.
- [ ] 2026-11-14 · contenus-depot-dedie · La PR de synchronisation des contenus vers l'application est-elle ouverte à la demande ou automatiquement à chaque fusion sur `main` des contenus ? — appliqué : à la demande ; autres : automatique (jeton d'écriture croisé) ; recommandé : à la demande.
- [ ] 2026-11-14 · contenus-depot-dedie · Migration (Lot B) en attente de la fusion de la PR de validation pédagogique (session validation-pedagogique-agent) : au 2026-11-14 elle n'est pas ouverte et l'agent `validateur-pedagogique` n'est pas sur `Develop`. — appliqué : attendre ; autres : migrer sans attendre (conflits sur ~460 fichiers) ; recommandé : attendre.
- Info (non bloquant) : `/annonce` a besoin de `GOOGLE_TTS_API_KEY` (variable d'environnement Claude Code) ; absente aujourd'hui, la skill livre alors le texte sans audio. `/publier-prod` lit la production avec `RAILWAY_API_TOKEN`, absente de cette session.

## Retouches

> Les retouches de ce chantier après sa livraison ([`retouche.md`](../../workflows/retouche.md)) : `- AAAA-MM-JJ · #<PR> · <ce qui change>`

- …

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- Première version du script : `git` en échec rendu `nil` et lu comme « plus récente » ou « arbre propre », fichiers ignorés par git copiés, `--verifier` vert sans `VERSION`, échange de dossiers sans retour arrière, dossier à l'intérieur de l'application pris pour un dépôt. Trouvé par les revues (pannes silencieuses, tests), corrigé avant fusion avec un test par cas. Leçon : un outil qui lit git distingue les codes de sortie, il ne rabat pas tout sur `nil`.
- Le nom du dépôt a changé trois fois dans la journée (`Lnclassapp/contenus`, `Kamkara007/App.Lnclassapp-contenus`, transfert vers `Lnclassapp`) : aucun propriétaire n'est figé dans les outils, le script lit le `remote origin`.

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- Les leçons relues sont lues **en marche** (chargement automatique de Develop et Staging au pré-déploiement), pas seulement en test : l'image Railway les embarque par `COPY . .`.
- Deux tests lisent une progression (`pc_lessons_test.rb`, `svt_lessons_test.rb`) : elles devront devenir des fixtures au Lot C.
- Répétition : 463 leçons synchronisées en 6 s, copie identique octet pour octet ; `git filter-repo` produit l'arborescence `lecons/ a-reprendre/ progressions/ prompts/ README.md` voulue. Partir d'`origin/Develop` avec l'historique complet (le clone de session est superficiel).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
