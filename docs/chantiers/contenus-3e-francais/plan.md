# Plan d'exécution — Les 10 premières leçons de Français de 3ème

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — contrôle aligné sur l'import  ┐ en parallèle
Lot P — consigne par matière          ┘
  ↓
Lot FR — 10 leçons (un rédacteur par leçon, 6 en parallèle au plus) → contrôle → relecture IA indépendante → contrôle
```

Pas de Lot 0 : aucun contrat, aucune table, aucune route.

---

## Lot A — Le contrôle reprend les règles de question de l'import

- **Couche**       : script (Ruby pur)
- **Fichiers**     : `script/contenus/valider.rb`
                     `test/script/contenus/valider_test.rb` · `test/script/contenus/parite_import_test.rb`
- **Dépend de**    : —
- **Test associé** : parité import ↔ script étendue à tous les types de question (bien formés : aucune erreur ; fautes : mêmes [chemin, raison]) ; avertissement sous 50 % de questions `AUTO_GRADED`, et pas à 50 %.
- **Done quand**   : une question `written` avec `points`, `criteria`, `starter` et `answers: []` passe le script ; chaque faute de la table « Chemins alternatifs » du PRD rend les mêmes raisons qu'à l'import ; 100 % lignes et branches sur le script.

Consignes : les règles de structure viennent de `Entities::Assessment::Question.structure_errors_for` (requis en Ruby pur, comme `Entities::Catalog::Figure`), avec la correspondance règle → clé de l'import (`RULE_KEYS` de `ContentNode`) ; types de `points`, `unit`, `starter`, `criteria`, `tolerance`, `match` comme le schéma ; la part corrigée automatiquement se lit sur `AUTO_GRADED` du type. Les conseils de nombre de propositions ne visent que les 4 types à choix.

## Lot P — Consigne de rédaction pour les 5 matières

- **Couche**       : documentation
- **Fichiers**     : `docs/contenus/prompt-redaction.md` · `docs/contenus/prompt-redaction-lot.md` · `docs/contenus/README.md`
- **Dépend de**    : — (la forme JSON des types est celle du schéma v3, déjà en place)
- **Test associé** : relecture ; le Lot FR s'en sert tel quel.
- **Done quand**   : la consigne dit, par matière, ce que deviennent La méthode, l'exemple et les 4 problèmes ; donne la forme JSON de chaque type de question ; impose corrigé modèle, `points` et `criteria` aux questions rédigées et la règle des 50 % ; rappelle la fidélité à la progression, les règles de textes du Français et la neutralité de l'HG ; le prompt de lot prend la matière en entrée.

## Lot FR — Les 10 leçons de Français

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/francais/*.json` (10, dont les 3 v1 remplacés)
- **Dépend de**    : Lot A, Lot P
- **Test associé** : `ruby script/contenus/valider.rb` sur les 10 fichiers ; relecture IA indépendante (autre modèle) ; challenger.
- **Done quand**   : les 10 fichiers passent le contrôle sans erreur ni avertissement après relecture, et sont envoyés au porteur.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `script/contenus/valider.rb`, `test/script/contenus/*` | Lot A |
| `docs/contenus/prompt-redaction*.md`, `docs/contenus/README.md` | Lot P |
| `docs/contenus/lecons-traitees/3eme/francais/*` | Lot FR |

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
