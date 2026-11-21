# Plan d'exécution — Entrée et accueil de l'élève allégés

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Chaque lot : test rouge d'abord ; en-tête HITL à jour sur chaque fichier de `app/` touché ; clés I18n fr seulement ; `bin/rails test <fichiers>`, `bin/rubocop <fichiers>`, `bin/system-changed`. Écrans élève : skill `ecrans-wave`.

## Graphe

```
Lot 0 — SOCLE (orchestrateur du chantier, fait) : routes /ecole/:school_public_id et /students/first-exercise, clé qr_label
  ↓
  ├─► Lot A  entrée : textes retirés + pavé numérique          ┐
  ├─► Lot B  inscription : sans code de classe ni bloc numéro   ├─ en parallèle, worktrees isolés
  ├─► Lot C  QR de l'établissement : adresse publique → entrée  │
  └─► Lot D  fenêtre « Ton premier exercice » + tuile Inviter   ┘
```

---

## Lot 0 — Socle

- **Couche**       : delivery (routes) + locale
- **Fichiers**     : `config/routes/classroom.rb` · `config/locales/classroom/student_homes.fr.yml` (clé `class_card.qr_label`)
- **Dépend de**    : —
- **Test associé** : aucun (les routes sont testées par les lots C et D)
- **Done quand**   : les deux routes et la clé existent sur la branche du chantier

---

## Lot A — Entrée : sans phrases, pavé numérique de « Nouveau sur Lnclass »

- **Couche**       : ui + locale (serveur inchangé hors message)
- **Fichiers**     : `app/views/identity/student_entries/new.html.erb` · `app/views/identity/student_entries/_base_errors.html.erb` (si le message d'écart y passe) · `app/views/shared/_auth_welcome.html.erb` (rendre `text:` optionnel, si nécessaire) · `app/javascript/controllers/identity/pin_pad_controller.js` (nouveau) · `app/javascript/controllers/index.js` (seulement si l'enregistrement n'est pas automatique) · `config/locales/identity/student_entries.fr.yml` · `test/controllers/identity/student_entries_controller_test.rb` · `test/system/` : le(s) fichier(s) système existant(s) de l'entrée élève + nouveau `test/system/student_entry_pin_pad_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : CA-1, CA-2, CA-3, CA-4, CA-5 ; UDR-XXXX-pave-numerique-confirmation-code §3.1, §3.2
- **Done quand**   : sur `/student`, plus de phrase ; un numéro inconnu montre 4 cases et le pavé, bouton gris ; 2468 deux fois → coche et inscription ; 1111 → « Les deux codes sont différents. », cases vides ; sans JavaScript, le formulaire actuel marche

---

## Lot B — Inscription : sans « J'ai le code de ma classe », sans bloc « Ton numéro »

- **Couche**       : ui + locale
- **Fichiers**     : `app/views/classroom/student_registrations/_form.html.erb` · `app/views/classroom/student_registrations/new.html.erb` · `app/views/classroom/student_registrations/_class_picker.html.erb` (seulement pour rendre `after_school:` optionnel) · `app/javascript/controllers/classroom/signup_steps_controller.js` · `config/locales/classroom/student_registrations.fr.yml` · tests existants de l'inscription élève (`test/system/*signup*`, `*student_registration*`, `test/controllers/classroom/student_registrations_controller_test.rb`) et ceux qui cliquent « J'ai le code de ma classe »
- **Dépend de**    : Lot 0
- **Test associé** : CA-6, CA-7, CA-8 ; UDR-XXXX-pave-numerique-confirmation-code §3.3 (sauf le préchoix de l'établissement, Lot C)
- **Done quand**   : ni lien ni champ de code de classe à l'inscription ; après l'entrée, l'étape « Toi » n'a plus « Ton numéro » sauf en erreur ; `/c/<jeton>` et la cascade marchent ; les tests qui passaient par le code de classe à l'inscription sont réécrits sur la cascade ou retirés s'ils ne prouvent plus qu'un parcours supprimé

---

## Lot C — QR de l'établissement : adresse publique, établissement préchoisi

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/controllers/classroom/school_signup_links_controller.rb` (nouveau) · `app/controllers/concerns/student_entry_session.rb` · `app/controllers/classroom/student_registrations_controller.rb` (préchoix en mode entrée seulement) · requête d'établissement actif par identifiant public (une requête `Queries::School::…` existante ; sinon une méthode bornée ajoutée à `school_preview_query.rb` ou équivalent) · `app/infrastructure/queries/classroom/student_home_query.rb` (colonne `school_public_id` de la ligne, rien d'autre) · `app/helpers/classroom/join_qr_helper.rb` (helper `school_signup_qr_svg`) · `app/views/classroom/student_homes/_class_card.html.erb` · nouveaux tests : `test/controllers/classroom/school_signup_links_controller_test.rb`, `test/system/school_signup_link_test.rb` ; test existant de la carte de classe / de la requête d'accueil si l'un vérifie le sigle
- **Dépend de**    : Lot 0
- **Test associé** : CA-9, CA-10, CA-11 ; ADR-XXXX-adresse-publique-etablissement §1 (menaces M1 à M5), §7
- **Done quand**   : `/ecole/<id>` actif garde l'établissement 30 min et mène à `/student` ; inactif, brouillon, inconnu → même réponse, rien gardé ; connecté → accueil ; 61e appel/min → 429 ; après l'entrée, l'inscription s'ouvre établissement choisi ; la carte de classe montre le QR de cette adresse, plus le sigle

---

## Lot D — Fenêtre « Ton premier exercice » sur les écrans de l'élève, tuile « Inviter »

- **Couche**       : infrastructure (lecture bornée) + delivery + ui
- **Fichiers**     : `app/controllers/classroom/student_first_exercises_controller.rb` (nouveau) · `app/views/classroom/student_first_exercises/show.html.erb` (nouveau) · un helper de contrôleur `first_exercise_prompt?` (concern nouveau `app/controllers/concerns/first_exercise_prompt.rb`, inclus par `AuthenticatedController`) · `app/controllers/authenticated_controller.rb` · `app/views/layouts/shell.html.erb` · `app/controllers/classroom/student_homes_controller.rb` · `app/views/classroom/student_homes/show.html.erb` · `app/views/classroom/student_homes/_invite_tile.html.erb` (nouveau) · `app/views/classroom/student_homes/_invite_classmates.html.erb` (supprimé) · `app/views/shared/navigation/_install_banner.html.erb` (ou son appel dans `show`) · lecture « a rendu une copie » : méthode bornée dans `app/infrastructure/queries/classroom/activation_query.rb` · `config/locales/classroom/student_homes.fr.yml` (hors `class_card`) · `config/locales/classroom/student_first_exercises.fr.yml` (nouveau) · `.claude/skills/ecrans-wave/SKILL.md` (§ Hors périmètre) · tests : `test/controllers/classroom/student_first_exercises_controller_test.rb` (nouveau), `test/system/student_first_exercise_prompt_test.rb` (nouveau), tests existants de l'accueil élève et de l'activation qui vérifient la carte `#student_first_exercise` ou la bannière d'invitation
- **Dépend de**    : Lot 0
- **Test associé** : CA-12 à CA-16 ; UDR-XXXX-accueil-eleve-qr-fenetre-inviter §3.2, §3.3
- **Done quand**   : un élève qui vient de s'inscrire voit la fenêtre sur l'accueil, la ferme, la revoit sur l'écran suivant, jamais sur un exercice ; après une copie rendue, plus de cadre ; la carte n'est plus sur l'accueil ; la tuile « Inviter » ouvre le partage ; plus de bannière d'invitation des camarades

---

## Décisions ouvertes

Aucune posée au porteur : les sept points sont tranchés (lancement de l'orchestrateur) ; les réversibles appliquées par défaut sont dans `journal.md` § À trancher.

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `config/routes/classroom.rb` | Lot 0 |
| `config/locales/classroom/student_homes.fr.yml` | Lot 0 (`class_card.qr_label`), puis Lot D seul |
| `app/views/identity/student_entries/*`, `config/locales/identity/student_entries.fr.yml`, `pin_pad_controller.js` | Lot A |
| `app/views/classroom/student_registrations/*`, `signup_steps_controller.js`, `config/locales/classroom/student_registrations.fr.yml` | Lot B |
| `app/controllers/classroom/student_registrations_controller.rb`, `student_entry_session.rb`, `student_home_query.rb`, `join_qr_helper.rb`, `_class_card.html.erb` | Lot C |
| `layouts/shell.html.erb`, `authenticated_controller.rb`, `student_homes_controller.rb`, `student_homes/show.html.erb`, `activation_query.rb`, `_install_banner.html.erb` | Lot D |
| Tests système de l'inscription élève existants | Lot B (le Lot C n'écrit que de nouveaux fichiers) |
| Tests de l'accueil élève existants | Lot D (le Lot C ne touche que ce qui vérifie le sigle, dans un fichier de la carte ou de la requête ; s'il est partagé, il le laisse au Lot D et le signale) |

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)
