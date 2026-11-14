# ADR-XXXX : Les leçons vivent dans le dépôt public `App.Lnclassapp-contenus` ; l'application en garde une copie figée versionnée
<!-- index
titre: Leçons dans un dépôt dédié, copie figée dans l'application
statut: Accepté
problematique: Comment sortir les leçons du dépôt applicatif sans priver Develop, Staging, le jeu standard et la CI des leçons qu'ils lisent
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-14 |
| **Chantier** | `docs/chantiers/contenus-depot-dedie` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

`docs/contenus/` (environ 106 Mo, plus de 600 fichiers) mélange quatre choses : les leçons relues (`lecons-traitees/`), lues **en marche** par l'application ; les leçons à reprendre ; les progressions DPFC ; les prompts et le mode d'emploi de rédaction. Les leçons relues sont lues par :

- le chargement automatique de Develop et Staging au pré-déploiement (`bin/rails contenus:charger`, ADR-0122, ADR-0123), depuis l'image construite avec le dépôt de l'application (`COPY . .`) ;
- le jeu standard (`db/seeds/standard.rb`, `db/seeds/standard/jeu.yml`) et la démo (`db/seeds/demo/lecons_completes.rb`) ;
- la CI : rendu ciblé des leçons modifiées (`.github/workflows/ci.yml`, ADR-0131), tests d'intégration `test/integration/contenus/` et `test/integration/catalog/` ;
- l'aperçu local (`bin/apercu-lecon`).

Le contrôle `script/contenus/valider.rb` charge des entités du domaine (`app/domain/entities/assessment/question_kinds/*`, `catalog/figure*`) et un test de parité le lie à l'import : il ne peut pas quitter l'application sans dupliquer les règles.

## 2. Moteurs de décision

1. Develop et Staging doivent toujours trouver toutes les leçons relues au déploiement, sans secret supplémentaire dans l'hébergeur.
2. Une seule source des règles de contrôle (parité avec l'import).
3. Le porteur décide, par une PR, de ce qui entre dans l'application ; la production n'est jamais alimentée automatiquement.
4. Le moins de code applicatif touché : chemins, chargement, CI ciblée et aperçu inchangés.
5. Rédaction et correction des leçons hors du dépôt de code.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Copie figée versionnée : `script/contenus/synchroniser` copie les leçons relues d'une version du dépôt de contenus dans `docs/contenus/lecons-traitees/` et écrit la version dans `docs/contenus/VERSION` | Aucun secret ni réseau au déploiement ; chemins inchangés ; chaque entrée de contenu est une PR relue et testée ; retour arrière = revert | **Retenue** |
| B — Sous-module git | Version épinglée par SHA, pas de copie | Dépôt privé : l'hébergeur et la CI ont besoin d'un jeton pour le cloner ; les sessions Claude et `bin/setup` doivent l'initialiser ; un sous-module oublié = Develop sans leçons, en silence |
| C — Téléchargement au setup ou au déploiement | Application légère | Jeton dans l'hébergeur ; déploiement qui dépend du réseau et d'un second dépôt ; pas de trace dans l'application de la version chargée |
| D — Tout laisser dans l'application | Rien à faire | Le problème du memo reste entier |

## 4. Décision

> **Nous déplaçons les leçons, les progressions, les leçons à reprendre, les prompts et le mode d'emploi dans `Lnclassapp/App.Lnclassapp-contenus`, historique conservé. L'application garde une copie figée des seules leçons relues, au même chemin, avec un fichier `docs/contenus/VERSION` qui nomme la version copiée ; cette copie ne s'écrit que par `script/contenus/synchroniser`, dans une PR. Le contrôle `valider.rb` reste dans l'application.**

### 4.1 Ce qui part, ce qui reste

| Contenu | Après migration |
|---|---|
| `lecons-traitees/` | Source : `contenus/lecons/` · copie figée : `docs/contenus/lecons-traitees/` (application) |
| `a-reprendre/`, `progressions-2026-2027/`, `prompt-redaction*.md`, `README.md` | `contenus/` seulement |
| Les 2 progressions lues par des tests (Physique-Chimie, SVT) | Copiées dans `test/fixtures/files/contenus/` ; les tests y pointent |
| `script/contenus/valider.rb`, `fonds_de_carte.rb`, `bin/apercu-lecon` | Application |
| `docs/contenus/README.md` | Remplacé par une page courte : d'où vient la copie, comment synchroniser |

### 4.2 Arborescence de `Lnclassapp/App.Lnclassapp-contenus`

```
lecons/<niveau>-<série>/<matière>/*.json   ← ce que l'application copie
a-reprendre/ · progressions/ · prompts/ · README.md
.github/workflows/valider.yml              ← récupère l'application à Develop et lance valider.rb sur les fichiers modifiés
```

Une version = un SHA de `main` du dépôt de contenus (une étiquette `AAAA.MM.JJ` est conseillée, pas exigée).

### 4.3 Passage d'une leçon jusqu'à la production

| Étape | Qui | Garde |
|---|---|---|
| Rédaction, relecture, validation pédagogique | `/lecon` dans le dépôt de contenus, PR vers `main` | `valider.rb` vert, relecteur et validateur distincts du rédacteur |
| Entrée dans Develop | PR applicative « contenus : synchronisation à `<SHA>` » produite par `script/contenus/synchroniser` | CI de l'application (contrôle de chaque fichier, rendu ciblé, tests) ; fusion comme toute PR |
| Develop puis Staging | Chargement automatique (ADR-0122, ADR-0123) ; Staging par le train | Règles en place, inchangées |
| Production | `/publier-prod` prépare ; un membre de l'équipe importe dans Imports | Création seule ; toute leçon de même titre déjà présente, brouillon compris, est écartée sauf confirmation écrite du porteur ; jamais de suppression |

### 4.4 Dépôt public

Décision du porteur (2026-11-14) : le dépôt de contenus est **public**. Tout ce qu'il contient est donc lisible par tous, y compris par les élèves :

- les leçons, leurs exercices **et leurs corrigés** (réponses attendues, explications, barèmes), les sujets de devoir et leurs corrections ;
- les leçons à reprendre, les progressions, les prompts de rédaction et leur historique git.

Il n'y entre **jamais** : de secret (jeton, clé, PIN, mot de passe), de donnée d'élève, d'enseignant ou d'établissement réel (nom, contact, résultat), ni de nom de personne réelle hors auteurs. Un secret poussé par erreur est révoqué, pas seulement effacé : l'historique public l'a déjà exposé.

Nom : `Lnclassapp/App.Lnclassapp-contenus` (confirmé par le porteur le 2026-11-14, après un premier dépôt `Kamkara007/App.Lnclassapp-contenus`, supprimé). Le script ne fige aucun nom : il lit le `remote origin` du clone.

### 4.5 Lecture seule

Après migration, une leçon de `docs/contenus/lecons-traitees/` modifiée sans que `docs/contenus/VERSION` change dans le même commit est refusée par la CI (empreinte de l'arbre écrite dans `VERSION`).

## 5. Conséquences

### 🟢 Positives

- Déploiement inchangé, sans secret ni réseau en plus ; chemins, chargement, CI ciblée et aperçu intacts.
- Chaque entrée de contenu dans l'application est une PR testée et réversible ; `VERSION` dit ce que Develop charge.
- Les brouillons, progressions et prompts ne pèsent plus sur le dépôt de code.

### 🔴 Coûts consentis

- Les leçons relues restent dupliquées (environ 95 Mo) dans l'application, et l'historique passé de l'application garde tout : le clone n'allège que pour l'avenir.
- Une correction de leçon fait deux PR (contenus, puis synchronisation).
- La CI du dépôt de contenus dépend de l'application (à Develop) pour le contrôle : un changement de règle côté application peut rendre rouge une PR de contenu.
- Dépôt public : les corrigés sont lisibles par les élèves avant un devoir ; c'est accepté par le porteur (les leçons sont faites pour réviser).
- La CI du dépôt de contenus, s'il récupère l'application privée pour lancer `valider.rb`, a besoin d'un jeton de lecture sur l'application (secret du dépôt de contenus).

## 6. Notes d'implémentation

```bash
# Dans l'application : copier la version <SHA> d'un clone local du dépôt de contenus
ruby script/contenus/synchroniser.rb ../contenus            # copie lecons/ → docs/contenus/lecons-traitees/, valide, écrit VERSION
ruby script/contenus/synchroniser.rb ../contenus --verifier  # CI : l'empreinte de l'arbre correspond à VERSION
```

`docs/contenus/VERSION` (YAML) : `depot`, `sha`, `date`, `fichiers`, `empreinte` (SHA-256 des chemins et contenus triés).

## 7. Comment vérifier que la décision est respectée

- `test/script/contenus/synchroniser_test.rb` : copie, suppression des fichiers retirés, refus d'une leçon invalide (rien n'est copié), empreinte.
- Après migration : étape CI `ruby script/contenus/synchroniser.rb --verifier` ; rouge si une leçon change sans `VERSION`.
- `test/db/seeds/standard_manifest_test.rb` et `test/integration/contenus/` restent stricts : ils échouent si une leçon du jeu standard manque dans la copie.
