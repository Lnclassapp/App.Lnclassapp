# Plan d'exécution — Activation de l'élève : de l'inscription au premier exercice réussi

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Lots séquentiels** : les deux lots touchent le contrôleur de l'accueil et sa locale, donc aucun parallélisme (règle 3 du workflow). Pas de Lot 0 : aucun port, aucune migration, aucune route ; les fichiers partagés sont tenus par le Lot A puis repris par le Lot B, l'un après l'autre. Un commit par lot.

## Graphe

```
Lot A « le premier exercice sur l'accueil » ──► Lot B « reprendre ou refaire depuis l'historique » ──► Lot C « clôture »
```

---

## Lot A — Le premier exercice sur l'accueil (élève seul, élève amené)

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/activation_query.rb` (nouveau)
                     `app/controllers/classroom/student_homes_controller.rb` (carte, `@to_do`, en-tête corrigé)
                     `app/views/classroom/student_homes/show.html.erb`
                     `app/views/catalog/courses/_next_exercise.html.erb` (variante `:home`)
                     `config/locales/catalog/courses.fr.yml`
                     `docs/decisions/udr/XXXX-activation-premier-exercice.md`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/classroom/activation_query_test.rb` (CA-1 à CA-7)
                     `test/controllers/classroom/student_homes_controller_test.rb` (CA-8, CA-9)
                     `test/system/identity/student_signup_steps_test.rb` (CA-10, de l'inscription au premier exercice)
- **Done quand**   : un élève qui vient de s'inscrire voit « Ton premier exercice » sous sa classe et démarre l'exercice en un tap ; amené par sa classe, c'est son devoir, qui sort de « À faire »

---

## Lot B — Reprendre ou refaire depuis l'historique

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/student_home_query.rb` (`recent_sessions` lit aussi les copies en cours)
                     `app/controllers/classroom/student_homes_controller.rb` (la copie de la carte sort de l'historique)
                     `app/views/classroom/student_homes/_history.html.erb`
                     `config/locales/classroom/student_homes.fr.yml`
- **Dépend de**    : Lot A
- **Test associé** : `test/infrastructure/queries/classroom/student_home_query_test.rb`, `test/controllers/classroom/student_homes_controller_test.rb` (CA-11 à CA-14)
- **Done quand**   : depuis l'historique de l'accueil, l'élève reprend une copie en cours en un tap et refait un exercice terminé à 16/20

---

## Lot C — Clôture

- **Couche**       : docs + skills
- **Fichiers**     : `.claude/skills/ecrans-wave/SKILL.md` (hors périmètre amendé)
                     `docs/chantiers/simplification-ecrans-eleve/lnclass-design-system-SKILL.md` (la carte, pendant l'activation)
                     `docs/chantiers/activation-eleve/journal.md`, `memo.md` (statut), `etat.md`
                     numéro de l'UDR et index (`script/docs/build_index --number`)
- **Dépend de**    : Lot B
- **Test associé** : `bin/ci-quiet` (niveau pr) ; tests système de l'accueil par `bin/system-changed`
- **Done quand**   : la ligne de preuve est dans la PR, les captures sont envoyées au porteur

---

## Décisions ouvertes

> Session autonome (contrat de session) : rien n'est posé au porteur avant le lancement ; les choix réversibles sont appliqués et écrits dans `## À trancher` du journal.

- [x] Seuil de « réussi » — options : 10/20, 14/20 ; appliqué : 10/20 (journal)
- [x] « Refaire » sur toute copie terminée — options : toutes, sous 14/20 seulement ; appliqué : toutes (journal)
- [x] Élève seul dont la classe a des devoirs — options : programme, devoir ; appliqué : programme (journal)

## Vérification de collision

Lots séquentiels : la collision est assumée et ordonnée.

| Fichier | Lot propriétaire |
|---|---|
| `app/controllers/classroom/student_homes_controller.rb` | Lot A, puis Lot B |
| `test/controllers/classroom/student_homes_controller_test.rb` | Lot A, puis Lot B |
| `config/locales/classroom/student_homes.fr.yml` | Lot B |
| `config/locales/catalog/courses.fr.yml` | Lot A |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît — sans objet (PRD §6)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé et ports gelés avant tout lot parallèle — sans objet (aucun port, lots séquentiels)
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
