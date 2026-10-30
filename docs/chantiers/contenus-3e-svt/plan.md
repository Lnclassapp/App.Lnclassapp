# Plan d'exécution — Les 10 premières leçons de SVT de 3ème et leurs planches

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot P — dessin des planches (module commun + 8 planches)   ┐ en parallèle, avant la fusion de la vague 2
Lot SVT — rédaction des 10 leçons (6 rédacteurs au plus)    ┘
  ↓  fusion de Develop (vague 2 fusionnée)
Lot D — la sorte plate dans le domaine, la liste blanche, la consigne ; tests système
  ↓
Lot SVT (suite) — contrôle des 10 leçons → relecture IA indépendante → corrections → contrôle
```

Pas de Lot 0 : aucune table, aucun port. Les fichiers partagés avec la vague 2 (`figure_kinds.rb`, `figure.rb`, `figure_catalogs.rb`, `figure_controller.js`, `figures_structure_test.rb`, `prompt-redaction.md`) appartiennent au Lot D, qui attend sa fusion.

---

## Lot P — Le dessin des planches

- **Couche**       : UI (JS de figures)
- **Fichiers**     : `app/javascript/lib/figures/plate.js` · `app/javascript/lib/figures/plates/index.js`
                     `app/javascript/lib/figures/plates/{digestive_system,blood_smear,heart,double_circulation,female_reproductive_system,hiv_virus,soil_profile,root_hairs}.js`
                     `test/javascript/plates_structure_test.rb`
- **Dépend de**    : —
- **Test associé** : structure (aucun `innerHTML`, aucune ressource, aucune couleur en dur, sous `plate.js` et `plates/`) ; chaque fichier de `plates/` est listé par `index.js` et déclare ses parties (PRD §5) ; captures de chaque planche en `names` et `numbers`, 390 px et ordinateur.
- **Done quand**   : chaque planche se dessine, étiquettes réparties à gauche et à droite sans chevauchement, traits de rappel vers la partie, surlignage, mode numéros sans légende ; captures envoyées au porteur.

Contrat d'une planche (`plates/<id>.js`) : `export const TITLE` (nom français), `export const PARTS` (`{ id: { name, anchor: [x, y], area? } }`, dans le viewBox 640×480, zone de dessin centrale) et `export function draw(group, { highlighted, el })` (trace la planche ; une partie surlignée est remplie `primary` à 0,35). `plates/index.js` exporte `PLATES = { id: module }`. La vague 4 ajoute un fichier et une ligne d'index ; `plate.js` ne change pas.

## Lot D — La sorte plate dans le domaine

- **Couche**       : domaine + UI (liste blanche) + contenus
- **Fichiers**     : `app/domain/entities/catalog/figure_kinds.rb` · `app/domain/entities/catalog/figure_catalogs.rb` · `app/domain/entities/catalog/figure.rb`
                     `app/javascript/controllers/figure_controller.js` · `test/javascript/figures_structure_test.rb`
                     `test/domain/entities/catalog/figure_test.rb` (ou fichier de test de la sorte) · `test/script/contenus/parite_import_test.rb`
                     `test/javascript/plates_parity_test.rb` · `test/system/catalog/figure_plates_test.rb`
                     `docs/contenus/prompt-redaction.md`
- **Dépend de**    : Lot P ; PR de la vague 2 fusionnée dans `Develop`
- **Test associé** : cohérence `plate` (planche, partie, doublon, surlignage) ; parité import ↔ script ; parité domaine ↔ modules ; système : `ready` en noms et en numéros, `error` pour une planche inconnue.
- **Done quand**   : critères du PRD verts ; 100 % lignes et branches.

## Lot SVT — Les 10 leçons

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/svt/*.json` (10, dont les 3 v1 remplacés)
- **Dépend de**    : rédaction : — (formes de l'ADR) ; contrôle final : Lot D
- **Test associé** : `ruby script/contenus/valider.rb` ; relecture IA indépendante (Opus) sur l'exactitude scientifique.
- **Done quand**   : les 10 fichiers passent le contrôle sans erreur ni avertissement après relecture.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `lib/figures/plate.js`, `lib/figures/plates/*`, `test/javascript/plates_structure_test.rb` | Lot P |
| fichiers du domaine des figures, `figure_controller.js`, `figures_structure_test.rb`, `prompt-redaction.md`, tests de parité et système | Lot D |
| `docs/contenus/lecons-traitees/3eme/svt/*` | Lot SVT |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît (ADR du programme, accepté)
- [x] UDR écrite pour **chaque** vue créée ou modifiée (aucune vue ; UDR du programme pour le dessin)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle (sans objet : pas de Lot 0)
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
