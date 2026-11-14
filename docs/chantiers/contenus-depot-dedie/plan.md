# Plan d'exécution — Les leçons vivent dans leur propre dépôt

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
Lot A — outil de synchronisation + skills (cette PR, sans attendre)
  ↓ attend : PR de validation pédagogique fusionnée dans Develop (agent validateur-pedagogique présent)
Lot B — migration vers Lnclassapp/App.Lnclassapp-contenus (historique filtré, CI du dépôt de contenus)
  ↓
Lot C — branchement de l'application (VERSION, --verifier en CI, fixtures de progressions, docs/contenus allégé)
```

Séquentiel : B et C touchent les mêmes fichiers de contenu.

---

## Lot A — Synchroniser et outiller

- **Couche**       : outillage (hors `app/`)
- **Fichiers**     : `script/contenus/synchroniser.rb` · `test/script/contenus/synchroniser_test.rb`
                     `.claude/skills/lecon/SKILL.md` · `.claude/skills/publier-prod/SKILL.md` · `.claude/skills/annonce/SKILL.md`
                     `docs/chantiers/contenus-depot-dedie/*` · `docs/decisions/adr/0134-contenus-dans-un-depot-dedie-copie-figee.md`
- **Dépend de**    : —
- **Test associé** : `test/script/contenus/synchroniser_test.rb` (CA-1 à CA-5) ; répétition à l'échelle : 463 leçons copiées, `diff -r` identique
- **Done quand**   : synchronisation testée, skills écrits, PR prête avec la preuve `bin/ci-quiet`

---

## Lot B — Migrer les contenus

- **Couche**       : dépôt de contenus
- **Fichiers**     : dépôt `Lnclassapp/App.Lnclassapp-contenus` : `lecons/`, `a-reprendre/`, `progressions/`, `prompts/`, `README.md`, `CLAUDE.md`, `.github/workflows/valider.yml`
- **Dépend de**    : Lot A ; PR de validation pédagogique fusionnée (vérifier `git ls-tree origin/Develop .claude/agents/validateur-pedagogique.md`)
- **Test associé** : `git log --follow` sur 3 leçons garde leurs commits d'origine ; `diff -r` entre `lecons/` et `docs/contenus/lecons-traitees/` d'origine/Develop vide ; `valider.yml` vert sur une PR d'essai
- **Done quand**   : `main` du dépôt de contenus contient tout `docs/contenus/` avec son historique, réorganisé (`git filter-repo --path docs/contenus --path-rename docs/contenus/lecons-traitees/:lecons/ …`)

Recette de migration (répétée avant le vrai passage) :

```bash
git clone --no-local --single-branch -b Develop <app> migration && cd migration   # historique complet, pas de clone superficiel
git filter-repo --path docs/contenus/ \
  --path-rename docs/contenus/lecons-traitees/:lecons/ \
  --path-rename docs/contenus/progressions-2026-2027/:progressions/ \
  --path-rename docs/contenus/prompt-redaction.md:prompts/prompt-redaction.md \
  --path-rename docs/contenus/prompt-redaction-lot.md:prompts/prompt-redaction-lot.md \
  --path-rename docs/contenus/:
# main du dépôt de contenus a déjà un commit README (porteur) : on fusionne les deux historiques, sans réécrire main.
git remote add origin https://github.com/Lnclassapp/App.Lnclassapp-contenus && git fetch origin main
git merge --allow-unrelated-histories origin/main -m "Migration des contenus depuis l'application (historique conservé)"   # conflit README.md : garder celui des contenus
git push -u origin HEAD:main                                                                                                 # avance rapide, jamais --force
```

---

## Lot C — Brancher l'application

- **Couche**       : outillage + tests + docs (aucun fichier de `app/`)
- **Fichiers**     : `docs/contenus/VERSION` (écrit par l'outil) · `docs/contenus/README.md` (page courte) · suppression de `docs/contenus/a-reprendre/`, `progressions-2026-2027/`, `prompt-redaction*.md`
                     `test/fixtures/files/contenus/progressions-2026-2027-{physique-chimie,svt}.json` · `test/integration/catalog/pc_lessons_test.rb` · `test/integration/catalog/svt_lessons_test.rb` · `test/integration/catalog/automatic_lesson_load_test.rb` (commentaire)
                     `.github/workflows/ci.yml` (étape `--verifier`) · `script/contenus/valider.rb` (commentaire d'en-tête) · liens dans `CLAUDE.md` et `docs/` qui pointent vers `docs/contenus/prompt-*`
- **Dépend de**    : Lot B
- **Test associé** : `ruby script/contenus/synchroniser.rb --verifier` ; `test/db/seeds/standard_manifest_test.rb`, `test/integration/contenus/`, `test/integration/catalog/` verts sans assouplissement ; `bin/ci-quiet`
- **Done quand**   : la copie est identique à l'avant-migration (CA-6), `VERSION` présent et écrit dans le même commit que l'étape CI `--verifier` (sans `VERSION`, `--verifier` refuse la copie actuelle), la CI refuse une leçon modifiée à la main, PR prête

---

## Décisions ouvertes

- [x] Dépôt de contenus privé ou public — tranché par le porteur le 2026-11-14 : public (ADR §4.4)
- [ ] Qui ouvre la PR de synchronisation — options : à la demande d'une session, automatique à chaque fusion sur `main` des contenus ; recommandé : à la demande (pas de jeton d'écriture croisé)

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `script/contenus/synchroniser.rb` | Lot A |
| `.claude/skills/*` (lecon, publier-prod, annonce) | Lot A |
| `docs/contenus/**` | Lot C (lecture seule au Lot B) |
| `.github/workflows/ci.yml` | Lot C |
| `test/integration/catalog/*_lessons_test.rb` | Lot C |

## Portes de sortie

- [x] Tous les lots sont `Done` (A #597 ; B `main` du dépôt de contenus, contenus#1 et #2 ; C #602)
- [x] Un rôle distinct de l'auteur a **exécuté** le résultat (l'orchestrateur a vérifié #602 ; `valider.yml` vert sur `main` du dépôt de contenus, 463 leçons)
- [x] Pureté du domaine, rubocop, tests, parcours système : au vert (`bin/ci-quiet` sur `0ad7a085`)
- [x] ADR et UDR à jour et indexés (ADR-0134, aucun UDR)
- [x] `journal.md` complété
