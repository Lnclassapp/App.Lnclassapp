# Plan d'exécution — Refonte de la page d'accueil publique

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot 0 — SOCLE (séquentiel) : options du déclencheur de ui_modal · photo WebP · locale
  ↓
Lot A — La page : tests rouges, puis homepage/index et _role_modal
  ↓
Lot B — Preuve : captures, mesures, journal
```

Une seule page, une seule chaîne : les trois lots sont séquentiels. Un seul agent suffit.

---

## Lot 0 — Socle

- **Couche**       : ui (composant partagé, locale, asset)
- **Fichiers**     : `app/helpers/components_helper.rb` *(`ui_modal` : `trigger_size:`, `trigger_full:`)*
                     `app/views/components/_modal.html.erb`
                     `app/views/design/index.html.erb` · `config/locales/design/index.fr.yml` *(exemple du déclencheur large)*
                     `test/helpers/components_helper_test.rb`
                     `config/locales/homepage/index.fr.yml` *(fichier partagé : réécrit en entier)*
                     `app/assets/images/homepage/student.webp` *(créé)* · `app/assets/images/homepage/student.png` *(supprimé)*
- **Dépend de**    : —
- **Test associé** : `test/helpers/components_helper_test.rb` (RH-13) · `test/design/design_tokens_test.rb`
- **Done quand**   : `ui_modal(trigger:, trigger_size: :lg, trigger_full: true)` rend un bouton de 56 px pleine largeur, les options absentes rendent le bouton d'aujourd'hui, la photo pèse moins de 100 Ko, et les clés de la nouvelle locale existent.

---

## Lot A — La page

- **Couche**       : delivery (vues) + ui
- **Fichiers**     : `app/views/homepage/index.html.erb`
                     `app/views/homepage/_role_modal.html.erb`
                     `test/controllers/homepage_controller_test.rb`
                     `test/system/homepage_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/homepage_controller_test.rb` (RH-01, RH-02, RH-04 à RH-10) · `test/system/homepage_test.rb` (RH-02, RH-03) · `test/system/finitions/narrow_screens_test.rb` (RH-11, existant) · `test/views/page_titles_test.rb` (RH-12, existant)
- **Done quand**   : les critères RH-01 à RH-12 sont verts, écrits avant la vue et rouges d'abord ; la page tient à 390 px sans défilement horizontal ; les deux entrées sont visibles sans défiler à 360 × 640.

---

## Lot B — Preuve

- **Couche**       : —
- **Fichiers**     : `docs/design/captures/landing/accueil--desktop.png` · `docs/design/captures/landing/accueil--mobile.png`
                     `docs/chantiers/refonte-homepage/prd.md` *(§7, mesures « après »)* · `docs/chantiers/refonte-homepage/journal.md`
- **Dépend de**    : Lot A
- **Test associé** : `bin/rubocop` · `test/design/design_tokens_test.rb` · `bin/rails test test/controllers/homepage_controller_test.rb test/controllers/homepage_redirection_test.rb test/helpers/components_helper_test.rb test/views/page_titles_test.rb` · `bin/rails test test/system/homepage_test.rb test/system/finitions/narrow_screens_test.rb test/system/design_system_test.rb`
- **Done quand**   : un rôle distinct de l'auteur a rejoué le parcours élève (héros → modale → `/join`) et un chemin d'erreur (360 px, JavaScript coupé) ; les captures sont dans le dépôt ; le journal est clos.

---

## Vérification de collision

> Deux lots ne listent jamais le même fichier.

| Fichier | Lot propriétaire |
|---|---|
| `app/helpers/components_helper.rb` | Lot 0 |
| `app/views/components/_modal.html.erb` | Lot 0 |
| `app/views/design/index.html.erb` · `config/locales/design/index.fr.yml` | Lot 0 |
| `config/locales/homepage/index.fr.yml` | Lot 0 |
| `app/assets/images/homepage/*` | Lot 0 |
| `test/helpers/components_helper_test.rb` | Lot 0 |
| `app/views/homepage/index.html.erb` · `app/views/homepage/_role_modal.html.erb` | Lot A |
| `test/controllers/homepage_controller_test.rb` · `test/system/homepage_test.rb` | Lot A |
| `docs/design/captures/landing/*` · `journal.md` · `prd.md` §7 | Lot B |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé` *(mené sans le porteur : hypothèses marquées)*
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md` *(sans objet : aucun)*
- [x] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0064 ; amendements UDR-0012 et UDR-0005)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle *(aucun port ; lots séquentiels sur la même branche)*
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord *(RH-01 à RH-13 ; voir le journal pour la nature du premier rouge)*
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [x] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur *(challenger du 2026-10-02 : huit critères rejoués, tous PASS, deux chemins d'erreur ; rapport dans le journal)*
- [x] Pureté domaine · rubocop · tests · brakeman : au vert *(lancés en local le 2026-10-02, tous verts, relancés après les corrections du challenger puis après la fusion avec `Develop` : 3 075 tests unitaires, 49 tests système, rubocop, brakeman ; la CI de la PR fait foi)*
- [x] PR unique vers `Develop`, référençant chantier + ADR + UDR *([#145](https://github.com/Lnclassapp/App.Lnclassapp/pull/145))*
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
