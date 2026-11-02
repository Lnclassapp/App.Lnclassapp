# Memo — Un standard de test pour Lnclass

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | décision |
| **Ouvert le** | 2026-11-02 |
| **Branche** | `feature/standard-de-test` |
| **Programme** | — |

---

## Le problème

Lnclass n'a pas de standard de test. Chaque endroit a son propre jeu de données :

- en local et dans une PR, le jeu démo crée 3 établissements, 63 classes, des milliers d'élèves et importe **toutes** les leçons v3 ;
- Develop charge à chaque déploiement toutes les leçons v3 du programme (~350 publiées), en les remplaçant entières ;
- Staging ne reçoit automatiquement que les leçons à sujets ; le reste passe par l'écran Imports, à la main ;
- la production ne reçoit que des imports manuels.

Personne ne sait donc « sur quoi » une PR a été testée. Les leçons, elles, ne sont vérifiées à l'écran que par un humain : le plan de test des contenus v3 en a choisi 30 sur 347 et laisse les autres sans contrôle d'affichage (défilement horizontal à 390 px, `**` affichés en clair, figure manquante). Enfin, corriger une leçon prend une boucle longue : modifier le JSON, réimporter, publier, aller voir — sans aperçu d'un seul fichier.

## Pour qui

- **Le porteur et les testeurs** (équipe) : savoir sur quelles données une PR, Develop ou une vague a été testée, et retrouver les mêmes comptes partout.
- **Les rédacteurs de contenus** (équipe) : voir tout de suite une leçon qu'ils viennent de modifier, puis l'améliorer en boucle courte.
- **Les enseignants relecteurs** : relire tout le contenu sur Staging, et seulement là.
- Indirectement les **élèves** : aucune leçon cassée à l'écran n'arrive en production.

## Pourquoi maintenant

Les vagues de contenus v3 (347+ leçons, 9 PR de chargement #439 à #447) arrivent plus vite que la relecture humaine. Le porteur a validé le 2026-11-02 quatre principes : un jeu de test standard identique partout, des leçons vérifiées par la machine, un rôle par environnement, une preuve de vague ; plus une boucle courte de mise à jour locale.

## Hors périmètre

- **Aucune donnée supprimée** sur Develop, Staging ou production sans accord écrit du porteur. Le passage de Develop au jeu standard est soumis au porteur (question ouverte n° 1).
- La production ne change pas : import manuel du seul contenu validé, comme aujourd'hui.
- Pas de nouvel écran ni de nouvelle vue : l'aperçu local réutilise les pages de leçon existantes (donc pas d'UDR).
- Pas de compte **Parent** ni de compte **personnel d'établissement** (SchoolStaff) dans le jeu standard : les 4 rôles demandés sont direction, enseignant, élève, équipe. À ajouter plus tard si un parcours parent est testé.
- Pas de correction des leçons elles-mêmes : le test signale, les chantiers de contenus corrigent.
- Pas de réécriture de `valider.rb` : il reste la première porte, le test d'affichage vient après.
- Le jeu « activité » (Saint-Michel, élèves ayant déjà travaillé) reste tel quel, optionnel.
- Pas de relecture enseignante outillée sur Staging (circuit de validation) : ce chantier pose seulement le contenu complet sur Staging.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| « Une leçon par matière et par niveau » : le niveau compte-t-il la série (Tle C ≠ Tle D en maths) ? | Oui : les fichiers sont rangés par niveau-série ; deux séries n'ont pas la même leçon de maths. | Le jeu standard prend **une leçon par dossier niveau-série et par matière** : 46 couples ont du v3 aujourd'hui. |
| La 2nde, la 4ème, la 5ème et la 6ème n'ont que des fichiers v1 : qu'y met-on ? | Le chargement automatique ignore les v1 ; le jeu démo aussi. | Le jeu standard ne prend que des v3 ; un couple sans v3 reste vide et le manifeste le dit. Couvert dès qu'une vague v3 arrive. Décision ouverte n° 4. |
| Qui choisit la leçon d'une matière, et que se passe-t-il si elle est renommée ou supprimée ? | Un choix implicite (« la première par ordre alphabétique ») change dès qu'un fichier arrive. | Le jeu est un **manifeste écrit** qui nomme chaque fichier ; un test refuse un fichier du manifeste absent ou non v3. |
| « Identique partout » : Develop doit-il être recréé à l'identique, donc vidé ? | Develop porte ~350 leçons publiées, des tentatives et des devoirs ; le recréer, c'est supprimer. | Interdit sans le porteur. Le chantier livre d'abord local + PR ; Develop est un lot à part, bloqué sur la décision ouverte n° 1. |
| Le test d'affichage sur 347+ fichiers tient-il dans 5 min par tâche ? | Un rendu de leçon à deux largeurs coûte ~2 à 3 s (le test des formules longues : 6,5 s avec connexion) : 417 fichiers ≈ 15 à 20 min. | Une PR ne rend **que les fichiers qu'elle touche** ; le passage complet se fait au train, découpé en parts de ≤ 5 min. Il ne compte pas dans le budget de 15 s des tests système : dérogation à demander (décision ouverte n° 3). |
| « Sans les publier » : où la leçon est-elle rendue ? | Le test tourne sur la base de test, effacée à chaque test ; rien ne part vers un environnement. | Le test importe par la vraie chaîne (même refus que l'écran Imports) et publie **dans la base de test** seulement, pour voir la page élève. |
| Que veut dire « figure absente » à vérifier par la machine ? | Une figure déclarée dans le JSON qui ne s'affiche pas (image vide, SVG non rendu). | Le test compte les figures du fichier et les figures visibles de la page ; il compare. |
| Staging = « tout le contenu, relu par les enseignants » : le chargement doit-il remplacer une leçon déjà relue ? | Non : remplacer une leçon relue efface la relecture. | Sur Staging, le chargement **ajoute les leçons absentes** sans toucher les présentes (sauf exercices des leçons à sujets, comme aujourd'hui). Décision ouverte n° 2. |
| L'aperçu local d'un fichier risque-t-il d'atteindre un environnement partagé ? | Il réutilise le remplacement de leçon entière, qui efface tentatives et devoirs. | L'aperçu refuse de tourner hors développement local. |
| Un enseignant dans deux établissements, un élève dans deux classes : le jeu standard les couvre-t-il ? | Le jeu démo actuel couvre l'enseignant multi-établissements ; c'est un cas qui a déjà cassé. | Le jeu standard garde **un enseignant affecté aux deux établissements**. L'élève multi-classes n'existe pas dans le métier (une classe par élève) : rien à ajouter. |
| Que perd-on en remplaçant le jeu démo de 63 classes ? | Le volume (35 à 45 élèves par classe) servait à voir les listes longues. | Le jeu standard garde **une classe pleine** (40 élèves) pour les listes longues ; le reste en a 3. Le jeu volumineux reste disponible derrière une option. |

## Cas limites identifiés

- Un fichier du manifeste disparaît ou repasse en v1 : le test du manifeste échoue, le chargement ne part pas à moitié.
- Une PR touche 60 fichiers de contenus : le rendu des fichiers touchés dépasse 5 min → il se découpe comme au train.
- Une PR supprime un fichier de contenu : rien à rendre, pas d'échec.
- Un JSON refusé à l'import : le test échoue avec le code de refus de l'import, sans aller jusqu'à l'écran.
- Le jeu standard est rejoué : il ne crée rien de plus (idempotent par contact, par nom d'établissement et par titre de leçon).
- L'aperçu local d'un fichier modifié pendant que le serveur tourne : le fichier est rechargé, la page rafraîchie montre la nouvelle version.

## Questions encore ouvertes

1. **Develop au jeu standard** : (a) on garde les ~350 leçons et on arrête seulement d'en charger d'autres que le jeu standard — rien n'est supprimé ; (b) on vide Develop et on le recrée au jeu standard — suppression de ~350 leçons publiées, de leurs tentatives, séances, devoirs et lectures, et des 3 établissements de test. **Recommandation : (a) maintenant, (b) plus tard si le porteur le demande.**
2. **Staging = tout le contenu** : le chargement automatique y ajoute toutes les leçons v3 absentes (sans remplacer les présentes) — d'accord ?
3. **Budget CI** : une dérogation au budget de 15 s pour le test d'affichage des leçons, qui tourne au train en tâches séparées de ≤ 5 min (et sur les seuls fichiers touchés dans une PR) — d'accord ?
4. **Niveaux sans v3** (2nde, 4ème, 5ème, 6ème) : on les laisse vides dans le jeu standard jusqu'à leur vague v3, ou on y met une leçon v1 ?
5. **Le choix des leçons** : on prend la première leçon du programme de chaque matière (proposition), ou le porteur en désigne d'autres ?
