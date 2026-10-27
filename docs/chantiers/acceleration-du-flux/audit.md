# Audit du flux de travail : de la conception au déploiement

| | |
|---|---|
| **Date** | 2026-10-20 |
| **Périmètre** | Le processus en 5 phases ([`docs/workflows/README.md`](../../workflows/README.md)), les chantiers, les PR, la CI, les promotions et le déploiement |
| **Données** | 1 608 commits depuis le 2026-09-20, les 120 dernières PR fusionnées, les 125 dossiers de `docs/chantiers/` |
| **Statut** | Constat. Chaque piste devient un chantier ordinaire, avec sa mesure avant et après. |

---

## 1. Diagnostic

Les garde-fous sont d'un niveau rare : un domaine pur vérifié par les outils, des policies testées et une preuve exigée avant chaque fusion. Le débit se perd ailleurs, pour deux raisons : **le processus produit plus de texte que de code**, et il **avance par grosses vagues**.

| Constat | Chiffre |
|---|---|
| Lignes modifiées : `docs/` contre `app/` | 459 000 contre 82 000 (×5,6) |
| Commits qui ne touchent que la doc | 714 sur 1 608 (44 %) |
| Documentation d'un chantier (memo, prd, plan, journal) | ≈ 9 000 mots |
| ADR et UDR | 106 ADR et 131 UDR, la plupart écrites en un mois |
| Lignes de tests contre lignes de code | 105 000 contre 34 000 (×3) |
| Fusions de `Develop` dans une branche de chantier | 110 |
| Commits de renumérotation d'un ADR après une collision | 5 |
| Commits de corrections après revue | 56 |
| PR fusionnées le 2026-10-19 | 20, puis 40 PR promues d'un coup (#267) |
| Durée entre `Staging` et `main` | 0 à 10 min, sans recette (#268) |
| Taille d'une PR vers `Develop` (p50 et p90) | 513 et 8 500 lignes |
| Ouverture → fusion d'une PR vers `Develop` (p50 et p90) | 2 h et 20 h |
| Poids de `docs/` | 40 Mo, dont `contenus` 18 Mo et `design` 13 Mo |

---

## 2. Pistes, de la plus rentable à la moins rentable

### 2.1 Doser la documentation selon le risque

Toute feature paie aujourd'hui memo, grill, PRD, ADR, UDR, plan et journal, quel que soit son risque. On propose trois poids :

| Poids | Quand | Ce qu'on écrit |
|---|---|---|
| **Léger** | Feature de moins d'un jour, sans schéma ni sécurité | Une page : le problème, les critères d'acceptation et les lots |
| **Normal** | Le cas courant | Le processus actuel |
| **Lourd** | Ce qui se défait mal (schéma, sécurité, contrat de port) | Le processus actuel, avec un ADR |

- **Un ADR ne sert qu'aux décisions difficiles à défaire.** Un choix qu'on peut défaire en un lot n'en mérite pas.
- **Des motifs à la place des UDR par vue.** Un catalogue de composants et de motifs d'écran remplace une UDR par vue. Une nouvelle UDR ne sert plus que quand un motif change.
- **Un numéro d'ADR posé à la fusion, pas à l'ouverture.** Le chantier écrit `ADR-XXXX-slug`, et `script/docs/build_index` attribue le numéro au commit de clôture. Cela met fin aux collisions entre chantiers parallèles.

### 2.2 Une PR par lot, derrière des feature flags

La règle « une PR par chantier » produit des PR de 8 500 lignes, des branches de 9 jours (`images-dans-les-cours`) et 110 synchronisations avec `Develop`.

- **Un feature flag par feature**, éteint par défaut. Chaque lot fusionne dès qu'il est vert, même si la feature n'est pas finie.
- **Le déploiement se découple de l'ouverture** : on allume le flag pour l'équipe, puis pour une école, puis pour tous.
- Effets attendus :
  - des revues sous 600 lignes, donc sous 5 minutes (mesure de [`security-reviewer`](../../../.claude/agents/security-reviewer.md)) ;
  - presque plus de conflits ;
  - une régression trouvée dans la journée.

### 2.3 Faire de `Staging` un vrai sas, ou le supprimer

`Staging → main` passe en quelques minutes, sans recette. Cette étape ajoute une PR et ne filtre rien.

- **Option A, garder `Staging`** :
  - un test de fumée automatique contre l'URL déployée : `/up`, la connexion de chaque rôle, un parcours enseignant et un parcours élève ;
  - `main` n'est accepté que s'il est vert.
- **Option B, supprimer `Staging`** : les feature flags tiennent lieu de recette en production.
- **Dans les deux cas, un train à cadence fixe** (par exemple un par jour) au lieu de vagues de 20 à 40 PR. Une promotion de 40 PR ne se relit pas sérieusement et se défait mal.

### 2.4 Chaque constat de revue récurrent devient une garde

56 commits corrigent des remarques de revue. Les remarques qui reviennent doivent devenir des tests de garde ou des règles Rubocop, comme on l'a déjà fait pour la pureté du domaine. Exemples :

- un use case sans policy ;
- un `:id` dans une route ;
- un `html_safe` ou un `raw` ;
- un fragment en cache dont la clé n'a pas le rôle.

Les sous-agents de revue se concentrent alors sur ce qu'un outil ne voit pas. Ils tournent **par lot, en parallèle de la CI**, plutôt que sur le diff final.

### 2.5 Une vraie pyramide de tests

Exiger 100 % des lignes **et des branches** partout pousse à écrire des tests de faible valeur : il y a 3 lignes de test par ligne de code.

- 100 % sur `app/domain` et les policies, environ 90 % ailleurs.
- Les 427 tests système sont le goulot de la CI (6 parts). On garde en tests système les parcours critiques, et on descend le reste en tests de requête ou de composant.

### 2.6 Sortir le contenu du dépôt de code

`docs/contenus` (18 Mo), `leçons/` (318 000 lignes modifiées) et `docs/design` (13 Mo) sont des données, pas du code. Les mettre dans un dépôt de contenu, ou dans un stockage importé, accélère :

- le clone et le checkout de la CI ;
- graphify ;
- chaque recherche d'un agent.

### 2.7 Déploiement : migrations en deux temps et retour arrière

- **Ajouter, recopier, puis supprimer seulement à la livraison suivante.** La #268 a recopié `teacher_profiles.material_id` et supprimé la colonne dans la même livraison : si la recopie avait un défaut, il n'y avait pas de retour possible.
- **Écrire un plan de retour arrière** : comment revenir à l'image précédente sur Railway, et ce qu'il faut faire des migrations.
- **Prévoir la panne du fournisseur.** La pause des déploiements Railway du 2026-10-20 montre qu'on dépend d'un seul fournisseur. Il faut au moins une procédure écrite pour ce cas.

### 2.8 Conception : confronter aux utilisateurs, mesurer après

- Le grill se fait entre le porteur et un agent. Il ne remplace pas deux ou trois enseignants devant une maquette cliquable, et `docs/design/maquettes/` existe déjà.
- **Un chiffre de succès par PRD**, relu deux semaines après l'ouverture. La mesure d'audience côté serveur (ADR-0049) le permet déjà.

---

## 3. Ordre proposé

| Étape | Pistes | Gain attendu |
|---|---|---|
| **1. Tout de suite** | Numérotation des ADR à la fusion (2.1) · règle des migrations en deux temps (2.7) · test de fumée de `Staging` (2.3) | Fin des collisions ; des livraisons qu'on peut défaire ; un sas qui filtre |
| **2. Cette semaine** | Feature flags et une PR par lot (2.2) · train quotidien (2.3) | Le gain le plus fort sur le délai de livraison |
| **3. Ensuite** | Trois poids de chantier (2.1) · gardes issues des revues (2.4) | Moins de texte et moins d'allers-retours |
| **4. Après** | Pyramide de tests (2.5) · contenu hors du dépôt (2.6) · mesure après l'ouverture (2.8) | Une CI plus courte et des features jugées sur leurs résultats |
