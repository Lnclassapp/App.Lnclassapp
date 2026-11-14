# PRD — Les leçons vivent dans leur propre dépôt

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Les leçons, progressions, leçons à reprendre et prompts quittent le dépôt de l'application pour `Kamkara007/App.Lnclassapp-contenus`, historique conservé. L'application garde une copie figée des seules leçons relues, au même chemin, écrite par un outil de synchronisation dans une PR ; Develop, Staging, le jeu standard et la CI continuent de lire cette copie. Rédaction (`/lecon`), publication en production (`/publier-prod`, création seule) et annonces audio (`/annonce`) deviennent des skills de projet.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Session de rédaction (`/lecon`) | Écrire une leçon dans le dépôt de contenus, la faire relire et valider, ouvrir une PR de contenus | Toucher la copie figée de l'application ; fusionner sa propre PR |
| Session de synchronisation | Ouvrir une PR applicative qui copie une version du dépôt de contenus | Copier une version dont une leçon échoue au contrôle ; revenir en arrière sans `--forcer` |
| Session `/publier-prod` | Préparer la liste des leçons à créer en production et les fichiers à importer | Importer elle-même ; remplacer ou supprimer une leçon en production sans confirmation écrite du porteur |
| Membre de l'équipe (Team) | Importer en production depuis l'écran Imports (règles en place, `ManageContentPolicy`) | — (inchangé) |
| Élève, enseignant, parent, direction | — (inchangé) | — |

## 3. Parcours

### Chemin nominal

1. `/lecon` rédige une leçon dans le dépôt de contenus (rédacteur), la fait relire par un agent indépendant, puis valider par `validateur-pedagogique`, puis passe `valider.rb` (de l'application). PR de contenus vers `main`.
2. La PR de contenus fusionnée, une session lance `ruby script/contenus/synchroniser.rb <clone>` dans l'application et ouvre la PR « contenus : synchronisation à `<SHA>` ». La CI de l'application contrôle et rend les leçons ; fusion vers `Develop`.
3. Develop charge les leçons au déploiement (inchangé), Staging par le train.
4. `/publier-prod` liste les leçons de la version qui n'existent pas encore en production, prépare les fichiers et la marche à suivre ; un membre de l'équipe importe dans Imports.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Une leçon de la version échoue au contrôle | Synchronisation refusée, rien n'est copié, la liste des leçons fautives est affichée |
| Clone du dépôt de contenus avec des changements non commités | Refusé : la copie nomme une version exacte |
| Version plus ancienne que la copie en place | Refusé sauf `--forcer` |
| Leçon de la copie modifiée à la main dans l'application | La CI refuse (`--verifier`) et dit de corriger dans le dépôt de contenus |
| Aucune version encore synchronisée | `--verifier` ne refuse rien (avant migration) |
| Leçon de même titre déjà en production (publiée ou brouillon) | `/publier-prod` l'écarte et la liste ; elle ne part qu'avec la confirmation écrite du porteur |
| Clé de synthèse vocale absente | `/annonce` nomme `GOOGLE_TTS_API_KEY` et s'arrête à l'étape audio ; le texte de l'annonce reste livré |

## 4. Critères d'acceptation

```gherkin
Scénario: CA-1 synchroniser une version valide
  Étant donné un clone du dépôt de contenus propre, dont toutes les leçons passent valider.rb
  Quand on lance la synchronisation
  Alors les leçons sont copiées au chemin lu par l'application
  Et les leçons absentes de la version sont retirées de la copie
  Et VERSION nomme le dépôt, le SHA, le nombre de fichiers et l'empreinte

Scénario: CA-2 une leçon invalide bloque tout
  Étant donné une version dont une leçon échoue au contrôle ou n'est pas un JSON lisible
  Quand on lance la synchronisation
  Alors elle est refusée en nommant le fichier
  Et la copie en place et VERSION ne changent pas

Scénario: CA-3 source douteuse refusée
  Étant donné une source qui n'est pas un dépôt git, ou qui a des changements non commités
  Quand on lance la synchronisation
  Alors elle est refusée

Scénario: CA-4 pas de retour en arrière silencieux
  Étant donné une copie à la version v2
  Quand on synchronise la version v1, ancêtre de v2
  Alors c'est refusé, sauf avec --forcer

Scénario: CA-5 la copie est en lecture seule
  Étant donné une copie synchronisée
  Quand une leçon y est modifiée, ajoutée ou retirée à la main
  Alors la vérification échoue et renvoie vers la synchronisation
  Et sans VERSION, la vérification passe

Scénario: CA-6 l'application ne perd aucune leçon à la migration
  Étant donné la migration faite
  Alors la copie est identique, octet pour octet, à docs/contenus/lecons-traitees/ d'avant la migration
  Et le jeu standard, les tests de contenus et le rendu ciblé passent sans être assouplis

Scénario: CA-7 la production n'est jamais écrasée
  Étant donné une leçon dont le titre existe en production
  Quand /publier-prod prépare la publication
  Alors elle est écartée et listée
  Et rien ne part sans la confirmation écrite du porteur
```

CA-1 à CA-5 : `test/script/contenus/synchroniser_test.rb`. CA-6 : `diff -r` à la migration et CI de la PR de branchement. CA-7 : skill `/publier-prod`, vérifié par le challenger sur une liste réelle.

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | aucun |
| Infrastructure | aucune ; outil hors application `script/contenus/synchroniser.rb` |
| Delivery | aucune |
| UI | aucune |
| Outillage | `.claude/skills/lecon`, `.claude/skills/publier-prod`, `.claude/skills/annonce` ; étape CI `--verifier` ; CI du dépôt de contenus |

## 6. Décisions rattachées

- ADR-XXXX-contenus-dans-un-depot-dedie-copie-figee — leçons dans un dépôt dédié, copie figée versionnée dans l'application.
- Pas d'UDR : aucune vue ne change.
- S'appuie sur ADR-0122 et ADR-0123 (chargement automatique hors production), ADR-0131 (rendu ciblé), inchangés.
