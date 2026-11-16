# UDR-0174 : Activation de l'élève — la carte « Ton premier exercice » de l'accueil, et l'historique qui reprend et refait
<!-- index
titre: Carte « Ton premier exercice » et historique de reprise
statut: Accepté
adr-lie: —
problematique: l'élève qui vient de s'inscrire n'a aucun exercice sous les yeux, et celui qui revient ne retrouve pas ce qu'il a commencé
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-16 |
| **Chantier** | `docs/chantiers/activation-eleve` |
| **ADR lié** | — (ADR-0049, ADR-0062, ADR-0115 respectés) |
| **Amende** | UDR-0173 §3 (accueil : la carte revient, pendant l'activation seulement) · UDR-0132 §3.5 (historique) |
| **Remplacé par** | — |

---

## 1. Contexte

Activation à 0 (porteur, 2026-11-16). L'élève qui vient de s'inscrire voit sa classe et huit matières ; atteindre un exercice lui coûte 3 à 5 taps et autant de choix. La carte « Prochain exercice », retirée des écrans par UDR-0173, a été gardée pour ce cas (issue #624). L'élève qui a commencé un exercice sans le finir ne le retrouve pas sur l'accueil : l'historique ne liste que les copies terminées et ne propose « Refaire » que sous 14/20.

## 2. Décision

1. **Tant que l'élève n'a réussi aucun exercice** (aucune copie terminée à 10/20 arrondi ou plus), la chose de valeur de l'accueil est **son premier exercice**. La carte « Prochain exercice » revient, sous le libellé « Ton premier exercice », juste sous la carte de la classe, avant « Mes matières ». Un tap démarre (ou reprend) l'exercice. Dès la première copie réussie, elle disparaît pour de bon : l'accueil redevient celui d'UDR-0173.
2. **Quel exercice** : la copie en cours d'abord (« Reprendre à la question N ») ; sinon, pour l'élève **amené par sa classe** (lien ou code), le premier devoir de « À faire » ; sinon (l'élève **seul**, ou sans devoir), le premier exercice de sa première matière dans l'ordre du programme, par la règle « Prochain exercice » existante.
3. **Une porte par action** (UDR-0173 règle 3) : le devoir mis en carte sort de « À faire » ; la copie en cours mise en carte sort de l'historique.
4. **L'historique est la porte du retour** : il liste aussi les copies **en cours** (la ligne mène à la copie, « En cours » et « 2/5 » à droite), et « Refaire » s'offre sur toute copie terminée, quelle que soit la note, hors pause (ADR-0115).

Pourquoi une carte plutôt qu'une redirection vers l'exercice après l'inscription : l'élève découvre d'abord sa classe (repère qu'il retrouvera), et la carte sert aussi au retour d'un élève non activé ; une redirection ne servirait qu'une fois. Pourquoi pas de pop-up ni de tutoriel : un écran, une chose de valeur.

## 3. Règles d'implémentation

**Structure — accueil (`classroom/student_homes/show`)**, branche « avec classe », dans le bloc blanc qui suit le bandeau :
1. `_class_card` (inchangé) ;
2. si `@first_exercise` : `<div class="px-5 pt-6 lg:px-0 lg:pt-8">` qui rend `catalog/courses/_next_exercise` avec `next_exercise: @first_exercise, scope: :home, id: "student_first_exercise"` ;
3. `_subjects` (inchangé) ; puis le reste (avis, annonces, « À faire » qui reçoit `@to_do`, historique, invitation).
Sans `@first_exercise` : rien n'est rendu à la place, ni titre ni phrase.

**La carte (`catalog/courses/_next_exercise`, `scope: :home`)** : la même carte que pour la matière et la leçon (`ui_card padding: :md` dans une `section aria-labelledby`), avec :
- surtitre `text-xs font-medium tracking-wide text-mute uppercase` : `catalog.courses.next_exercise.first` « Ton premier exercice » ;
- titre `h2#student_first_exercise_title` (inchangé, `line-clamp-2 font-display text-base font-medium`) ;
- détail `mt-1 text-sm text-mute` : « matière · leçon », ou « matière · Donné par ta classe » (`catalog.courses.next_exercise.assigned`) quand l'exercice est un devoir ;
- le bouton `classroom/student_homes/next_step/_start` (inchangé) : « Commencer l'exercice » (POST `exercise_sessions_path`) ou « Reprendre à la question N » (lien vers la copie) ;
- la section n'a pas de marge basse (`mb-6` reste pour `:material` et `:lesson` seulement) ; le lien « Tous les exercices » reste réservé à `:lesson`.

**Historique (`classroom/student_homes/_history`)** : lignes triées par dernière activité (fin de la copie, ou début pour une copie en cours), groupées par jour de cette activité, 3 lignes puis « Voir plus (n) ».
- **Copie en cours** : toute la ligne est un lien vers `exercise_session_path(public_id)`, `aria-label` « Reprendre l'exercice « titre » » ; à droite, `data-progress` `text-sm text-mute` « En cours · 2/5 » (`history.in_progress`). Pas de second bouton.
- **Copie terminée** : la ligne mène au résultat, médaille à droite (inchangé) ; bouton secondaire `sm` « Refaire » (POST, `aria-label` `history.redo_label`) **dès que l'exercice n'est pas en pause**, quelle que soit la note.

**Tokens** : ceux des partials existantes, aucun nouveau ; pas de hex, de `style=`, de `dark:`, de valeur arbitraire, graisse ≤ 500.

**Comportement**
- La carte est rendue par la page (pas de frame) : elle est visible sans attendre. Le bouton « Commencer » est un `button_to` (Turbo, POST, redirection vers la copie) ; `data-turbo-prefetch="false"` sur la section.
- L'historique reste dans le cadre différé `student_home_recent_activity` (`loading: lazy`, `target: _top`).
- Après l'inscription : redirection vers l'accueil, message de bienvenue inchangé (un niveau sans exercice publié n'a pas de carte : le message ne promet rien).

**États obligatoires**
- Vide : pas de carte (élève activé, ou rien à proposer) ; historique absent sans copie terminée ni en cours.
- Chargement : la carte n'en a pas (rendue avec la page) ; l'historique garde le cadre différé de 1 px.
- Erreur : un démarrage refusé (pause, abonnement) suit les messages existants du démarrage.
- Succès : la copie s'ouvre.

**Accessibilité**
- Cibles ≥ 48 px (`min-h-tap`) ; le bouton porte un `aria-label` avec le titre ; la section est nommée par son `h2`.
- « En cours » est écrit, jamais porté par la couleur seule.

## 4. Conséquences

- UDR-0173 §3 « plus de carte du prochain exercice sur l'accueil » devient : « sauf la carte « Ton premier exercice », tant que l'élève n'a réussi aucun exercice ». La skill `ecrans-wave` et la copie de `lnclass-design-system` du dépôt le disent.
- Toute autre réapparition de « Prochain exercice » sur un écran de l'élève demande une nouvelle décision.
- L'historique de l'accueil n'est plus « les copies terminées » mais « ce que l'élève a touché ».
