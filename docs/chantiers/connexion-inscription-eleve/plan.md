# Plan d'exécution — Connexion et inscription de l'élève aux couleurs Wave et Djamo

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md) · [UDR-0088](../../decisions/udr/0088-connexion-et-inscription-eleve-carte-bleue-et-rubriques-numerotees.md). Pas d'ADR.
> **Prérequis** : la PR `accueil-eleve` est fusionnée (icône du casque, `ui_icon` maison). La cascade redessinée vient de `choix-classe-eleve` ; si sa PR n'est pas fusionnée, la rubrique 1 garde la cascade actuelle. Une seule PR, un commit par lot (4 commits).

## Graphe

```
Lot 0 — SOCLE
  ↓
  ├─► Lot A  Connexion    ┐ en parallèle
  └─► Lot B  Inscription  ┘
  ↓
Lot C — PREUVE ET CLÔTURE
```

---

## Lot 0 — Socle

- **Couche**       : UI (partials partagés) + config
- **Fichiers**     : `app/views/shared/_auth_welcome.html.erb` *(nouveau)* · `app/views/shared/_auth_help.html.erb` *(nouveau)*
                     `config/locales/identity/sessions.fr.yml` · `config/locales/classroom/student_registrations.fr.yml` *(toutes les clés du chantier)*
- **Dépend de**    : PR `accueil-eleve` fusionnée
- **Test associé** : `test/views/shared/auth_welcome_test.rb` (rendu carte et panneau)
- **Done quand**   : les deux partials se rendent seuls, en clair et en sombre

---

## Lot A — Connexion (CA-1 à CA-3, CA-8, CA-9)

- **Couche**       : UI
- **Fichiers**     : `app/views/identity/sessions/new.html.erb`
                     `test/system/identity/sign_in_test.rb` · `test/controllers/identity/sessions_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/identity/sign_in_test.rb` (CA-1, CA-2 à 390 et 1 280 px, CA-8) · `test/controllers/identity/sessions_controller_test.rb` (CA-3, CA-9)
- **Done quand**   : la connexion suit les maquettes pour les quatre rôles, et tous les tests de connexion passent

---

## Lot B — Inscription (CA-4 à CA-7, CA-9)

- **Couche**       : UI
- **Fichiers**     : `app/views/classroom/student_registrations/new.html.erb` · `_form.html.erb`
                     `test/system/classroom/join_test.rb` · `test/controllers/classroom/student_registrations_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/classroom/join_test.rb` (CA-4 à CA-7)
- **Done quand**   : l'inscription suit les maquettes, par la cascade et par le lien de la classe, avec et sans erreurs

---

## Lot C — Preuve et clôture

- **Couche**       : docs + preuve
- **Fichiers**     : `journal.md` · `docs/chantiers/README.md` · index UDR *(par `script/docs/build_index`)* · statut d'UDR-0088
- **Dépend de**    : Lots A, B
- **Test associé** : `bin/ci-quiet` vert, verdict copié dans la PR ; `test/system/finitions/{public_pages,narrow_screens}_test.rb` relancés
- **Done quand**   : captures envoyées (390 px et ordinateur : connexion vierge et en erreur, inscription vierge, par lien, en erreur, aide ouverte, sombre), PR ouverte prête

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/views/shared/_auth_welcome.html.erb` · `_auth_help.html.erb` · `config/locales/**` | Lot 0 |
| `app/views/identity/sessions/**` · tests de connexion | Lot A |
| `app/views/classroom/student_registrations/new.html.erb` · `_form.html.erb` · tests d'inscription | Lot B |
| `app/views/classroom/student_registrations/_class_picker.html.erb` | **aucun** (chantier `choix-classe-eleve`) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît *(aucun)*
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md` *(UDR-0088 écrite ; index à la clôture)*
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [x] Lot 0 mergé avant les lots parallèles
- [x] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord *(le test système de CA-6/CA-7 lancé après la vue : journal)*
- [x] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [x] Pureté domaine · rubocop · tests · brakeman : au vert *(hors échecs déjà présents sur la base : journal, clôture)*
- [ ] PR unique vers `Develop`, référençant chantier + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
