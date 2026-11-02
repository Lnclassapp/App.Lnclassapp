# ADR-XXXX : Un jeu de test standard, une activité déterministe, un rôle par environnement
<!-- index
titre: Standard de test : jeu standard, activité déterministe, rôle des environnements, rendu des leçons
statut: Accepté
problematique: Chaque environnement teste sur des données différentes, sans activité, et l'affichage des leçons n'est vérifié qu'à la main.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-02 |
| **Chantier** | `docs/chantiers/standard-de-test` |
| **Remplace** | — (amende ADR-0122 pour Staging et ADR-0123 pour Develop, sous réserve des décisions ouvertes du memo) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

En novembre 2026, Lnclass a trois jeux de test qui ne se recoupent pas :

- local (`bin/tester-pr --demo`) et environnement de PR (ADR-0108) : 3 établissements, 63 classes, des milliers d'élèves **sans activité**, toutes les leçons v3 importées ;
- `demo/saint_michel.rb`, local seulement : une classe de Tle D active, à dates fixes (septembre–octobre 2026), déjà hors des périodes courtes des tableaux de bord ;
- Develop (ADR-0122, ADR-0123) : ~350 leçons v3 remplacées entières à chaque déploiement ; Staging : leçons à sujets seulement ; production : imports manuels.

Les tableaux de bord (enseignant, direction, équipe filtrée par DRENA) ne se testent pas sans activité ; aucun établissement n'est assez grand pour révéler une page lente ; les cas difficiles ne sont garantis nulle part ; l'affichage des leçons n'est vérifié qu'à l'œil (30 sur 347) ; aucune PR ne dit sur quelles données elle a été prouvée.

Le porteur a validé le 2026-11-02 quatre principes (jeu standard identique partout, leçons vérifiées par la machine, un rôle par environnement, preuve de vague) et huit objectifs (activité déterministe, recette par rôle rejouée à la demande, cas difficiles, boucle courte de contenu, une commande et une remise à zéro, grand établissement, démonstration, règle de fusion).

## 2. Moteurs de décision

- Ne rien supprimer sur un environnement distant sans l'accord explicite du porteur.
- Budget CI : aucune tâche > 5 min (ADR-0107) ; tests système budgétés.
- Déterminisme : mêmes chiffres partout, un calcul qui change se voit.
- Aucune vraie donnée personnelle.
- Réutiliser les use cases et la vraie chaîne d'import : l'activité doit être celle que l'application aurait calculée.
- Pas de nouveau port ni de nouvelle table.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Choix implicite des leçons (première de chaque dossier) | Rien à maintenir | Le jeu change à chaque arrivée de fichier |
| **B — Manifeste YAML dans le dépôt** | Relisible, stable, testable | Un fichier à tenir à jour — **retenue** |
| C — Dump de base figé | Recréation exacte et rapide | Périmé à chaque migration, illisible en revue, contourne les use cases |
| D — Activité écrite directement en SQL | Rapide pour 1 500 élèves | Les notes, lacunes et badges ne seraient pas ceux que l'application calcule |
| **E — Activité par les use cases, horloge simulée, graine fixe, trimestre glissant terminé la veille ; grand établissement échantillonné** | Chiffres vrais et identiques ; tableaux « 7 jours » remplis | Plus lent ; plafonné à 5 min par l'échantillonnage — **retenue** |
| F — Dates fixes | Chiffres identiques au jour près | Périodes courtes vides quelques semaines plus tard (constaté sur Saint-Michel) |
| G — Rendre les 417 leçons à chaque PR | Couverture totale | 15 à 20 min : viole ADR-0107 |
| **H — Fichiers touchés en PR, tout au train en parts de ≤ 5 min** | Couverture totale par train | Un défaut transverse n'est vu qu'au train — **retenue** |
| I — Remettre Develop à zéro au jeu standard dès maintenant | Develop strictement identique | Supprime ~350 leçons et leurs données : décision du porteur |

## 4. Décision

> **Nous décrivons le jeu de test standard dans un manifeste du dépôt, le chargeons par les use cases avec un trimestre d'activité déterministe, en une commande, partout où l'on teste ; nous rendons chaque leçon v3 par la machine ; nous donnons un rôle à chaque environnement sans y rien supprimer ; chaque PR dit ce qu'elle a prouvé sur ce jeu.**

1. **Manifeste** `db/seeds/standard/jeu.yml` : un lycée public (classes de la 6ème à la Tle, une par niveau-série, séries A et C comprises), un collège seul privé, un grand établissement mixte (~1 500 élèves), répartis sur deux DRENA ; une classe vide, un élève sans activité, une classe pleine ; comptes élève, enseignant (dont un dans deux établissements), direction, équipe (admin, contenu, terrain) ; un fichier v3 par couple niveau-série et matière qui en a, plus la leçon v3 la plus longue. Noms tirés de `db/seeds/standard/noms.yml` (liste fictive), contacts dans une plage réservée non attribuable.
2. **Commande** `bin/jeu-standard [--reset] [--grand]` : joue `db/seeds/standard.rb` (base) puis `db/seeds/standard/activite.rb` (trimestre : séances, notes, lacunes, devoirs rendus et en retard, par les use cases, horloge simulée à la Saint-Michel, `srand` fixe, fin la veille du chargement). Affiche les comptes et une **empreinte des totaux**, testée. `--reset` refuse sur un environnement distant sans confirmation explicite. Idempotente sans `--reset`.
3. **Partout** : l'environnement de PR et `bin/tester-pr --demo` jouent le jeu standard à la place de `demo/trois_etablissements` + `demo/lecons_completes` (gardés derrière `--tout-contenu`) ; `demo/saint_michel.rb` est absorbé par l'activité standard puis retiré.
4. **Rendu des leçons** `test/system/catalog/lesson_rendering_test.rb` : import par `ImportCourseTree`, publication dans la base de test, page élève à 390 px et sur ordinateur ; échec sur import refusé, `scrollWidth > innerWidth`, `**` dans le texte rendu, figure déclarée non visible. Fichiers : `LECONS=` ; sinon fichiers v3 changés depuis `origin/Develop` ; au train `LECONS=tout LECONS_PART=i/n`, tâche `lecons` en parts de ≤ 5 min. Dérogation nommée au budget système.
5. **Rôles** : production inchangée ; Staging ajoute les leçons v3 absentes (mode `:create_only`) sans remplacer les présentes ; Develop charge le jeu standard sans supprimer les leçons déjà là, et ne charge plus les autres leçons v3 du programme (décision n° 1) ; la remise à zéro de Develop est une décision séparée du porteur.
6. **Aperçu** `bin/apercu-lecon <fichier> [--suivre]` : `valider.rb`, import seul (`replace: :lesson`), publication, adresse ; refusé hors `development`.
7. **Recette** `docs/recette/` : un parcours par rôle sur les comptes du jeu et une table écran → parcours ; rejoué seulement par le chantier qui touche ce rôle ou cet écran.
8. **Preuve de vague** `bin/preuve-vague <dossier>` : `valider.rb` + rendu des fichiers + captures d'une leçon par matière dans `tmp/preuves/`, jamais commitées.
9. **Règle de fusion** : `.github/pull_request_template.md` porte la section « Prouvé sur le jeu standard » (parcours rejoués, leçons rendues, ligne `bin/ci-quiet`) ; une garde de `bin/ci-quiet` vérifie qu'elle est remplie quand la PR change du code.
10. **Pages lentes** `bin/pages-lentes` : visite les pages de chaque rôle sur le grand établissement, chronomètre, signale celles au-dessus du seuil ; chaque page signalée ouvre un chantier `optimize`.

### Tranché par le porteur, 2026-11-02

1. **Develop** : le jeu standard y est **ajouté** ; **aucune suppression**. La remise à zéro de Develop n'est pas décidée.
2. **Staging** : ajout automatique des leçons v3 absentes, sans remplacer les présentes.
3. **Rendu des leçons** : fichiers touchés en PR, tout au train en parts de ≤ 5 min. **Dérogation au budget système** : le test `test/system/catalog/lesson_rendering_test.rb` est exclu du plafond de 15 s de croissance par PR (`script/ci/system_budget.rb`) ; son coût est borné par la liste des fichiers touchés en PR et par le découpage en parts de ≤ 5 min au train.
4. **Niveaux sans v3** (2nde, 4ème, 5ème, 6ème) : une leçon v1 si elle s'importe par la chaîne actuelle ; sinon le couple reste vide, écrit comme tel dans le manifeste.
5. **Leçons** : la leçon 1 de la progression de chaque couple niveau-série et matière (liste dans le PRD §8), plus la leçon v3 la plus longue.
6. **Activité** : étendue aux deux établissements de base, plusieurs classes, plusieurs semaines ; déterministe (graine fixe, trimestre glissant terminé la veille du chargement, empreinte des totaux testée). Le grand établissement a une activité échantillonnée. Le parcours DRENA passe par un compte équipe filtré par DRENA.
7. **Démonstration** (décision du porteur, 2026-11-02, remplace « sur Develop ») : un environnement Railway dédié **`Demo`**, servi sur **demo.lnclass.com**. L'application reconnaît le nom `Demo` (casse ignorée) comme un stade à part : il reçoit le référentiel, le jeu standard et l'activité simulée ; il n'est **jamais** un environnement de PR (même si `PR_BASE_ENVIRONMENT` y a été copiée : pas de mot de passe PR, pas de `lecons_completes`) ; aucun chargement des leçons du dépôt, aucune action de production. Base Postgres et bucket propres. Comptes équipe seulement si `DEMO_TEAM_PIN` (scellée) est posée : un PIN public sur un compte équipe d'un site ouvert donnerait l'administration à tout visiteur.
8. **Numéros fictifs — plage confirmée par le porteur le 2026-11-02** : le format de contact (`0[157]\d{8}`) n'accepte que des numéros mobiles ivoiriens ; le jeu utilise la plage `0[157]0000xxxx` (élèves 01, enseignants 05, direction et équipe 07, tranches disjointes), déjà utilisée par les seeds de développement. **Demo** (démonstration, objectif 7) : pas de remise à zéro automatique de Demo, accord de l'orchestrateur en attendant l'avis du porteur ; on la refait en recréant la base Postgres de Demo puis en redéployant.

## 5. Conséquences

### 🟢 Positives

- Local, PR et Develop parlent des mêmes comptes, des mêmes leçons et des mêmes chiffres.
- Les tableaux de bord se testent et se montrent en démonstration avec des chiffres crédibles.
- Un calcul de statistique modifié se voit à l'empreinte.
- Chaque leçon v3 est rendue par la machine au moins une fois par train.
- Boucle de rédaction : une commande, quelques secondes.

### 🔴 Coûts consentis

- Le manifeste et la liste de noms se maintiennent à la main.
- L'activité par les use cases est lente : le grand établissement n'a qu'une activité échantillonnée.
- L'empreinte change à chaque évolution légitime d'un calcul : il faut la mettre à jour sciemment.
- Une tâche CI de plus au train (~15 à 20 min de calcul en parts) et une dérogation au budget système.
- Tant que Develop n'est pas remis à zéro, il porte le jeu **et** les ~350 leçons anciennes.
- La section de preuve ajoute une étape à chaque PR.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/catalog/automatic_load_stage.rb (extension prévue)
# develop    → :lesson, fichiers restreints au manifeste
# staging    → :create_only (v3 sans sujets) ; :exercises (v3 à sujets, ADR-0122)
# production, pr, inconnu → rien
```

```yaml
# db/seeds/standard/jeu.yml (forme)
etablissements:
  - { cle: lycee, type: public, cycle: both, drena: <drena 1>, classes: tout_le_programme }
  - { cle: college, type: private, cycle: first, drena: <drena 2>, classes: [6eme, 5eme, 4eme, 3eme] }
  - { cle: grand, type: mixed, cycle: both, drena: <drena 1>, eleves: 1500, activite: echantillon }
cas: { classe_vide: college/5eme, eleve_sans_activite: lycee/tle-a1, classe_pleine: lycee/tle-d }
lecons:
  tle-d/mathematiques: <fichier>.json
longue: <fichier v3 le plus long>.json
```

## 7. Comment vérifier que la décision est respectée

- `test/db/seeds/standard_manifest_test.rb` : un v3 existant par couple qui en a ; cas difficiles présents.
- `test/db/seeds/standard_identity_test.rb` : contacts dans la plage fictive, noms de la liste.
- `test/db/seeds/standard_activity_test.rb` : empreinte des totaux égale à la valeur attendue, sur une activité réduite.
- `test/domain/entities/catalog/automatic_load_stage_test.rb` : Develop restreint au manifeste ; Staging `:create_only` ; production rien.
- `test/system/catalog/lesson_rendering_test.rb` + fichiers piégés : rouge sur chaque défaut.
- Garde de la section de preuve dans `bin/ci-quiet`.
- `.github/workflows/ci.yml` : `timeout-minutes: 5` sur chaque part de la tâche `lecons`.
