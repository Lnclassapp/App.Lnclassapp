# Plan d'exécution — « Choisis ta classe » aux couleurs Wave et Djamo

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [UDR-0091](../../decisions/udr/0091-choix-de-classe-eleve-trois-etapes-pastilles-et-cases.md). Pas d'ADR.
> **Prérequis** : la PR `accueil-eleve` est fusionnée. À coder **avant** `connexion-inscription-eleve` si possible : l'inscription reprend cette cascade. Une PR, 2 commits ; peut partager une session avec `profil-eleve` et `historique-eleve`, en PR distinctes.

## Graphe

```
Lot A — CASCADE ET PAGE ──► Lot B — PREUVE ET CLÔTURE
```

Pas de Lot 0 : aucun contrat ni donnée nouvelle.

---

## Lot A — Cascade partagée et page (CA-1 à CA-7)

- **Couche**       : UI + config
- **Fichiers**     : `app/views/classroom/student_registrations/_class_picker.html.erb`
                     `app/views/school/{drena_schools,school_levels,level_classrooms}/index.html.erb` *(branche `picker` seulement)*
                     `app/javascript/controllers/classroom/class_picker_controller.js` *(action `change`)*
                     `app/views/classroom/student_classroom_choices/new.html.erb`
                     `config/locales/classroom/{student_classroom_choices,student_registrations}.fr.yml`
                     `test/system/classroom/class_choice_test.rb` *(nouveau)* · `test/controllers/classroom/student_classroom_choices_controller_test.rb` · `test/controllers/school/*_controller_test.rb`
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/system/classroom/class_choice_test.rb` (CA-1 à CA-4, CA-7 à 390 et 820 px) · `student_classroom_choices_controller_test.rb` (CA-5, repli sans JS) · `test/system/classroom/join_test.rb` (CA-6)
- **Done quand**   : un élève sans classe en rejoint une au doigt, au clavier et sans JS ; l'inscription montre la même cascade

---

## Lot B — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `journal.md` · `docs/chantiers/README.md` · index UDR *(par `script/docs/build_index`)* · statut d'UDR-0091
- **Dépend de**    : Lot A
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR
- **Done quand**   : captures envoyées (390 px et ordinateur : établissement connu, après « Changer », classe complète, refus, sombre), PR ouverte prête

---

## Vérification de collision

Un seul lot de code : pas de collision. `_class_picker.html.erb` est aussi lu par `connexion-inscription-eleve`, qui ne le modifie pas.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît *(aucun)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0091 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord *(CA-1 à CA-4, CA-7 : `class_choice_test.rb` ; CA-5 : contrôleur ; CA-6 : `join_test.rb` et contrôleur)*
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + UDR
- [x] `journal.md` clos (dérapages, dette, chantiers de suivi)
