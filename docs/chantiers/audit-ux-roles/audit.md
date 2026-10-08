# Audit UI/UX par rôle (état des lieux du 2026-10-07)

> Revue en **lecture seule** du code de `Develop` (commit `2da31c20`), menée avec la grille du design system Lnclass (« règles de Wave » : une tâche par écran, dire chaque chose une fois, ambre = urgence, bouton = verbe + destination). Chaque point a été vérifié dans les vues, les helpers et les locales. Rien n'est décidé ici : c'est l'entrée de la phase 1 (Cadrer). Le prompt d'exécution est dans [`prompt.md`](prompt.md).
>
> Ordre : **élève → enseignant → direction → équipe**, puis le **transverse** (shell, composants, écrans d'entrée), qui touche les quatre rôles. Le transverse se corrige en premier, parce qu'il corrige d'un coup des points répétés dans chaque rôle.

**Légende** · 🔴 bloque la tâche principale ou induit en erreur · 🟠 gêne réelle, fréquente · 🟡 finition · ⚖️ contredit une UDR existante : à trancher par le porteur avant d'agir.

---

## 0. Décisions à trancher par le porteur (avant tout code)

| # | Question | Ce que dit le code / l'UDR | Ce que dit la grille | Recommandation |
|---|---|---|---|---|
| D1 | Ordre de l'accueil élève | UDR-0076 §2.1 : classe → matières → annonces → « À faire » | Carte « Prochain exercice » en tête, sous le bandeau | Carte en tête (la tâche principale doit être visible sans défiler) |
| D2 | Barre basse sur l'accueil élève et pendant une session d'exercice | Visible partout (décision du 2026-10-06 pour la session) | Pas de barre basse sur l'accueil ; rien qui fasse quitter une session par erreur | La masquer pendant la session ; la garder ailleurs |
| D3 | Pastilles rouges du taux de rendu (direction) | UDR-0074 §2 : écart assumé | Jamais de rouge ; ambre = urgence | Gris / bleu pâle pour « faible », ambre pour « inactif depuis 7 jours » |
| D4 | Seuil du vert pour une note | Vert dès 10/20 (`PASS_THRESHOLD` 50 %) | Vert ≥ 14/20, neutre 10–13,5, « Refaire » < 10 | Aligner sur la grille (`MASTERY_THRESHOLD` 70 %) |
| D5 | Couleur des rôles dans le shell | Filet orange `bg-teacher` (#ff8a00), or pour la catégorie « Lettres » | Une seule couleur de marque ; l'orange se lit comme l'ambre d'urgence | Un filet neutre ou bleu ; le badge de rôle suffit |
| D6 | Code d'établissement partagé enseignant / direction | Le même code ouvre jusqu'à 3 comptes direction | — (risque d'usurpation : tout prof qui a le lien WhatsApp peut devenir direction) | Deux codes distincts ; à défaut, le dire dans l'écran du lien. **À traiter aussi côté sécurité** |
| D7 | Qui valide un enseignant sans code | `join_request_vouches` réservé aux enseignants | La direction est la première concernée | Ouvrir la validation à la direction |
| D8 | Bouton principal noir (`primary`) ou bleu (`brand`) | 46 envois noirs, 24 bleus, parfois sur le même geste | Une seule couleur de marque | Bleu de marque pour l'action principale, partout |

---

## 1. Rôle élève

### Les 5 problèmes les plus graves
1. 🔴 **L'accueil ne répond pas à « qu'est-ce que je fais maintenant ? »** L'exercice à faire est en 4ᵉ bloc, sous le pli à 390 px ; « À faire » garde les exercices terminés avec un bouton « Commencer » (parfois le bouton principal) ; la page exercice cache « Commencer l'exercice » derrière quatre statistiques vides.
2. 🔴 **Aucun état hors connexion ni d'erreur dans la boucle d'exercice.** « Valider » sans réseau échoue sans rien dire ; le frame d'activité reste en squelette pour toujours.
3. 🟠 **Impasses** : élève sans classe qui tourne en rond dans le shell, catalogue vide sans bouton, « Tu es déjà inscrit dans une classe » sans suite, annonce masquée introuvable, « Mon historique » inaccessible, aide seulement sur l'accueil.
4. 🟠 **Couleurs détournées** : rouge pour une réponse fausse, vert dès 10/20 sur trois écrans, ambre pour une fiche à revoir, or proche de l'ambre sur les badges de matière.
5. 🟠 **Vocabulaire instable dans la boucle d'exercice** : « Recommencer » / « Refaire » changent de sens, « Meilleur score » / « Meilleure note », seuils en % alors que l'élève voit des /20, infobulle qui promet une correction jamais montrée.

### Accueil (`/students` · `classroom/student_homes/show`)
- 🔴 ⚖️ D1 · Tâche principale sous le pli (`show.html.erb:19-52`, `navigation_helper.rb:49`) → carte « Prochain exercice » en tête, avec ses 7 états (chargement, pas de classe, abonnement terminé, en retard, à commencer, commencé, tout est fait).
- 🔴 Exercices terminés dans « À faire » avec « Commencer » (`StudentHomeQuery#urgency`, `_assigned_exercise.html.erb:19-29`) → les retirer de « À faire » (ils vivent dans l'historique).
- 🟠 Compteur « %{done} sur %{total} faits » qui compte des lignes affichées comme à faire (`show.html.erb:27`) → « 4 exercices faits sur 6 » dans la carte, une seule fois.
- 🟠 Bouton vague « Entrer » (`student_homes.fr.yml:22`) → « Voir ma classe ».
- 🟡 Code, nom, niveau et établissement répétés entre Accueil et Ma classe (`_classroom_card.html.erb:16-21`) → le code dans la case « Inviter » ou dans Ma classe, pas les deux.
- 🟡 Matières abrégées sous 640 px (« Math », « PC », « HG », « Philo », `student_homes.fr.yml:38-42`) → noms entiers, « Physique-Chimie » coupé par `<wbr>`.
- 🟡 Point de retard brun `bg-warning` #9a5200 (`components_helper.rb:137`) → token `--urgent-dot` (#f08c00) avec anneau de la couleur du fond.
- 🟡 Survol ambre sur « fiche à revoir » (`_pending_gaps.html.erb:11`) → survol neutre.
- 🟡 « Il y a 3 jours » (`_recent_activity.html.erb:19`) → « Aujourd'hui 09:14 », « Hier », « Mardi 29 sept. ».
- 🟠 ⚖️ D4 · Vert dès 10/20 (`_recent_activity.html.erb:16`) → vert ≥ 14/20, « Refaire » bleu doux < 10.
- 🟠 Frame différé sans erreur ni hors-ligne (`show.html.erb:55-58`) → `ui_error_state` « Réessayer », squelette de 3 lignes de la taille finale.

### Annonces (carrousel de l'accueil, `/announcements`)
- 🟠 Annonce masquée perdue après le toast (`student_homes/show.html.erb:45` `link: false`) → lien « Toutes les annonces », au moins quand une annonce est masquée.
- 🟠 Pas de date sur la carte (`communication/messages/_card.html.erb:9-25`) → « Hier », « Mardi 29 sept. » sur la ligne de l'émetteur.
- 🟡 Contour blanc du bouton audio invisible sur fond clair (`_card.html.erb:62`) → contour `currentColor`.

### Ma classe (`/students/classroom`)
- 🟠 Même exercice, deux formes de ligne (lien ici, bouton « Commencer » à l'accueil : `student_classrooms/_assigned_exercise.html.erb:6` vs `student_homes/_assigned_exercise.html.erb:19-29`) → une seule ligne d'exercice assigné dans toute l'app.
- 🟡 « N exercices assignés » sur la carte cours, listés juste dessous (`_course_card.html.erb:15`) → retirer le compteur.
- 🟡 « Meilleur score » en /20 (`student_classrooms.fr.yml:72,78`) → « Meilleure note » partout.
- 🟠 Vert dès 10/20 (`_treated_exercise.html.erb:5`) → D4.

### Mon historique (`/students/archive`)
- 🟠 Seul accès : l'écran « compte en attente » (`pending_accounts/show.html.erb:46`) → « Tout l'historique » sous l'historique de l'accueil, et une ligne dans le profil.
- 🟠 Trois listes pour la même chose, trois noms (« Mes activités récentes », « Exercices traités », « Mes exercices terminés ») → une liste « Historique », un nom.
- 🟡 Date longue « 7 octobre 2026 » (`student_archives/show.html.erb:42`) et vert dès 10/20 (`:46`) → formats de la grille, D4.

### Rejoindre une classe (`/join`, `/c/:code`)
- 🟡 « Se connecter » sans zone tactile de 44 px (`join_codes/new.html.erb:33`, `joins/new.html.erb:64`) → `inline-flex min-h-tap`.
- 🟡 Infobulle inutile sur le format du code, déjà dit par l'exemple, l'aide et l'erreur (`join_codes/new.html.erb:25`) → la supprimer.
- 🟡 Code non groupé (`join_code.rb:34-36`) → afficher et accepter les groupes séparés par une espace.
- 🟠 Trois libellés pour le même geste (« Rejoindre une classe », « Rejoindre ma classe », « Rejoins ta classe ») → « Rejoindre ma classe ».
- 🟡 Titre et bouton identiques « Rejoindre cette classe » (`joins.fr.yml:143,145`) → titre « Ta nouvelle classe ».
- 🟠 Impasse « Tu es déjà inscrit dans une classe. » (`joins.fr.yml:98`) → dire quoi faire + lien vers l'aide.
- 🟡 Section « Ton contact » pour un seul champ (`_signup_form.html.erb:39-42`) → « Ton numéro ».

### Compte en attente (élève sans classe)
- 🟠 Titre « Compte en attente » et icône horloge, alors qu'on attend un geste de l'élève (`pending_accounts.fr.yml:6`, `show.html.erb:39`) → titre « Rejoindre ma classe », icône classe.
- 🔴 Navigation en boucle : Accueil et Ma classe renvoient ici, Cours est vide (`student_homes_controller.rb:15`, `student_classrooms_controller.rb:10`) → shell sans barre de navigation pour un compte en attente.

### Catalogue, page cours, fiche essentielle
- 🟠 Catalogue vide sans bouton (`catalog/courses/index.html.erb:100-101`) → « Rejoindre ma classe ».
- 🟡 Badge matière répété sur chaque carte quand le filtre matière est actif (`_course_card.html.erb:11`) → le masquer.
- 🟡 Badge « Lettres » couleur or (`components_helper.rb:116`) → la teinte de la matière (`tint-*`).
- 🟠 Page cours : le contenu riche passe avant la liste des fiches (`courses/show.html.erb:31-44`) → fiches d'abord.
- 🟡 Badge de niveau inutile pour l'élève (`courses/show.html.erb:22`, `essentials/show.html.erb:22`, `exercises/show.html.erb:19`) → le masquer.
- 🟡 « Essentielles de la leçon » (`courses.fr.yml:55`) → « Fiches essentielles ».
- 🟡 Encart « Fiche à revoir » en ambre (`essentials/show.html.erb:54-55`) → bleu doux.
- 🟡 « Depuis le 7 octobre 2026 » (`essentials/show.html.erb:62`) → « Depuis mardi 29 sept. ».
- 🟠 « Refaire un exercice » mène à un exercice peut-être jamais fait (`essentials.fr.yml:82`) → « Faire un exercice de la fiche ».
- 🟡 « Assigné par ton enseignant » sans date limite (`_exercise_progress.html.erb:14-16`) → `due_badge`.

### Page exercice (`/exercises/:id`)
- 🔴 « Commencer l'exercice » sous le pli derrière 4 statistiques vides (`exercises/show.html.erb:10-38`, `_student_progress.html.erb:9-41`) → sans session terminée, masquer les statistiques.
- 🟠 Infobulle mensongère « La correction de chaque question s'affiche… » (`exercises.fr.yml:92`) → « Après chaque réponse, tu sais si elle est juste, avec une explication. »
- 🟡 Infobulles « Badge » et « Maîtrise » en %, seuils en dur (`shared/layouts.fr.yml:27-28`) → seuils en /20 lus depuis le domaine.
- 🟡 Aperçu des questions avec leurs propositions, qui double la session → nombre de questions seulement.

### Session d'exercice (`/sessions/:id`)
- 🔴 Pas de hors-ligne ni d'erreur réseau (`_question_card.html.erb:10-41`) → réponse gardée, « Hors connexion · ta réponse partira dès le retour du réseau », « Réessayer ».
- 🟠 Rouge et « Mauvaise réponse » (`_feedback_card.html.erb:4,11-15`) → bandeau neutre « Pas tout à fait », vert seulement pour juste.
- 🟠 ⚖️ D2 · Barre basse visible : un doigt qui glisse fait quitter la session (`_feedback_card.html.erb:43-46`).

### Résultat de session
- 🟠 « Recommencer » ici = nouvelle session ; ailleurs = abandonner (`session_results.fr.yml:37`, `exercises.fr.yml:85-88`) → « Refaire l'exercice ».
- 🟠 Rouge dans la correction (`_question_review.html.erb:4,9-10,28-29`) → « Pas tout à fait », neutre.
- 🟠 Pas d'étape suivante ; le retour mène à la fiche même depuis l'accueil (`show.html.erb:8,58-66`) → « Exercice suivant » (le prochain de « À faire ») ou « Retour à l'accueil ».

### Aide, profil, connexion (vus par l'élève)
- 🟠 Aide seulement sur l'accueil (`student_homes/show.html.erb:9-14`) → icône d'aide 44 px dans l'en-tête de toutes les pages élève.
- 🟡 Profil sans « Mon historique » ni aide (`identity/profiles/show.html.erb`) → deux lignes.
- 🟠 Vouvoiement servi à l'élève : « Heureux de vous revoir », « Vérifiez votre connexion » (`sessions.fr.yml:8`, `pin_resets.fr.yml:9,11,16`, `shared/components.fr.yml:17`) → formules neutres ou `tone_t`.
- 🟠 PIN oublié sans code : aucune issue (`pin_resets/new.html.erb:14-36`) → « Je n'ai pas de code » vers la carte d'aide.
- 🟡 Échéance « À rendre mercredi » un mercredi, ambiguë à 7 jours (`due_date_helper.rb:7`) → `WEEK = (2..6)`.

---

## 2. Rôle enseignant

### Les 5 problèmes les plus graves
1. 🔴 **L'onglet « Classes » n'ouvre aucune classe** (`navigation_helper.rb:24`, `teachings/_toggle.html.erb:4`) : il mène à l'éditeur de déclaration, chaque classe est une bascule, et un tap la retire sans confirmation.
2. 🔴 **Assigner un exercice prend 5 à 6 gestes, à l'aveugle** : pas de bouton « Assigner un exercice » sur la classe, exercice non consultable depuis la fiche dans la classe, modale des jours en plein geste avec un « Plus tard » ambigu, deux chemins parallèles (classe / catalogue) avec des écrans en double.
3. 🟠 **Le suivi quotidien est relégué et sans action** : « Activités » en 4ᵉ section de l'accueil ; sur le suivi, les élèves en retard sont en bas, sans bouton de relance.
4. 🟠 **Le premier usage n'est pas guidé** : classes vides sans code ni partage, états vides sans action, pas d'aide, invitation répétée trois fois.
5. 🟠 **Retours incohérents et impasses** : la classe revient à « Accueil » alors que l'onglet actif est « Classes » ; résultat et exercice reviennent au catalogue ; le résultat d'un élève accueille l'enseignant par « Courage ! » ; pas d'écran pour les classes archivées ni les élèves partis.

### Shell enseignant
- 🔴 « Classes » → l'éditeur de déclaration (`navigation_helper.rb:24`) → une liste des classes ; la déclaration dans un ⋮ « Modifier mes classes ».
- 🟠 ⚖️ D5 · Filet orange `bg-teacher` (`navigation_helper.rb:57`, `_header.html.erb:5`).
- 🟠 Aucune entrée « Aide » (`_header.html.erb:15-27`) → « Besoin d'aide ? » dans le menu du compte.

### Inscription (`/teacher-signup`, sans code)
- 🟡 Deux titres empilés sur téléphone (`teacher_registrations/new.html.erb:24-25,46-47`) → un titre, une phrase.
- 🟡 Infobulle qui redit l'aide du champ (`_form.html.erb:65-68`) → la supprimer.
- 🟡 Quatre légendes en capitales pour huit champs, dont « Contact » pour un seul numéro (`_form.html.erb:22,48,54,76`) → alléger.
- 🟡 Code « K7M-4QZ » avec tiret, code de classe sans séparateur, deux typographies de code (`teacher_registrations.fr.yml:39,72`, `join_code.rb:35`, `pending_accounts/show.html.erb:25`) → un format, une typo.

### Compte en attente
- 🟠 Seule action « Se déconnecter » (`pending_accounts/show.html.erb:42-50`) → « Écrire à l'équipe sur WhatsApp » ; « Partager ma demande à un collègue ».
- 🟡 « Votre compte attend son école » (`pending_accounts.fr.yml:71`) → « Votre établissement n'est pas encore confirmé ».

### Déclaration des classes (`/teachers/classrooms`)
- 🔴 Bascules sans confirmation ni toast (`teachings/_toggle.html.erb:4-16`, `teachings/destroy.turbo_stream.erb`) → bascules seulement pendant l'onboarding.
- 🟡 « Inviter un collègue » en en-tête pendant l'onboarding (`teaching_selections/index.html.erb:6`) → après la configuration.
- 🟠 État vide « Revenez un peu plus tard » (`teaching_selections.fr.yml:60`) → « Prévenir ma direction » / « Contacter l'équipe ».
- 🟡 Titre d'onboarding resté titre permanent (`teaching_selections.fr.yml:57`) → « Mes classes ».
- 🟠 « Terminer la configuration » en bas de toutes les cartes (`index.html.erb:16-31`) → barre d'action collante avec le compteur.

### Accueil (`/teachers`)
- 🟠 « Activités » (les exercices à suivre) en 4ᵉ section (`teacher_homes/show.html.erb:12-57`) → juste après les classes, et renommé « Exercices à suivre » (`teacher_homes.fr.yml:20`).
- 🟠 États vides sans action (`show.html.erb:23`, `_course_levels.html.erb:5-6`) → « Déclarer mes classes ».
- 🟡 Invitation présente deux fois (`_course_levels.html.erb:20-25`, `show.html.erb:61-64`, carte latérale) → retirer la bulle « Inviter » des cours.
- 🟡 Bulles de niveau toutes illustrées pareil (`_course_levels.html.erb:13-17`) → le niveau en gros, sans illustration répétée.
- 🔴 Classe vide sans code ni partage (`_classroom_card.html.erb:5-31`) → code + « Partager sur WhatsApp » tant que la classe a 0 élève.
- 🟡 « Score moyen » sans période, « Aucune session terminée » (`_classroom_card.html.erb:21-25`, `teacher_homes.fr.yml:42-43`) → « Moyenne de la classe : 62 % » + infobulle période ; « Aucun exercice rendu ».
- 🟡 Carrousel d'annonces sans titre visible, qui disparaît sans annonce (`show.html.erb:51-53`) → carte « Annonces » toujours là, avec « Écrire une annonce ».
- 🟡 Échéance relative ici, absolue sur la classe (`_follow_ups.html.erb:17` vs `_assigned_exercises.html.erb:27`) → un format.
- 🟡 « 7 octobre 2026 » et « Je confirme » (`_pending_colleagues.html.erb:17,21`) → « Hier », « Confirmer Aya K. ».

### Page d'une classe (`/classrooms/:id`)
- 🔴 Aucun bouton « Assigner un exercice » (`classrooms/show.html.erb:8-16`) → bouton principal en tête des exercices assignés.
- 🟡 « Ouvrez un cours ci-dessous » alors que les cours sont au-dessus (`classrooms.fr.yml:59`) → un bouton dans l'état vide.
- 🟠 Bloc code plein écran même quand la classe est pleine (`_header.html.erb:47-61`) → complet à 0 élève, ensuite une ligne compacte + ⋮.
- 🟠 Message WhatsApp aux élèves au vouvoiement (`classrooms.fr.yml:25`) → « Rejoins la classe… ».
- 🟡 « Classe archivée » en ambre (`_header.html.erb:20`) → neutre.
- 🟠 « Aucun code pour cette classe » sans action (`_header.html.erb:64`) → qui contacter, ou « Générer un code ».
- 🟡 Retour toujours « Accueil » (`_header.html.erb:8`) → vers « Classes ».
- 🟡 Infobulle « 35 est le nombre maximum » (`_header.html.erb:37-39`) → « 12 élèves · 35 max », sans infobulle.
- 🟡 Effectif dit trois fois, « Dernier score » répété dans chaque ligne (`_roster.html.erb:6,33,36,61`) → une fois.
- 🟡 Phrase sur le code de récupération toujours affichée (`_roster.html.erb:13`) → dans la modale du code.
- 🟠 « Voir le résultat » en `text-xs` sans zone de 44 px (`_roster.html.erb:65-66`) → le score cliquable en `min-h-tap`.
- 🟡 « Aucune session terminée », état vide sans « Partager » (`_roster.html.erb:9,68`) → « Pas encore d'exercice », bouton WhatsApp.
- 🟡 Bouton « Renseigner » (`_session_days.html.erb:25`) → « Indiquer mes jours ».
- 🟡 Ligne d'exercice trop dense à 390 px (`_assigned_exercises.html.erb:34-40`) → « 18/25 faits » + cercle ; le détail au suivi.

### Assigner (modales des jours, fiche dans la classe, cours dans la classe)
- 🟠 « Plus tard » assigne sans date limite (`assignments.fr.yml:49`) → « Assigner sans date ».
- 🟠 Question de configuration en plein geste (`assignments/new.html.erb:8`) → demander les jours à la déclaration ou à la première visite.
- 🟡 Toast « ajouté à » pour le bouton « Assigner » (`assignments.fr.yml:66-70`) → « … assigné à 6ᵉ 1 ».
- 🟠 Titre de l'exercice non cliquable dans la fiche de la classe (`classroom_essentials/show.html.erb:38`) → lien vers l'exercice.
- 🟠 Deux écrans pour la même fiche (classe / catalogue, `classroom_essentials/show.html.erb:11-22`) → un écran, la classe en contexte.
- 🟡 Surtitres et badges redondants, avis archivé en ambre (`classroom_courses/show.html.erb:12,18-19,23`, `classroom_essentials/show.html.erb:13,20`) → les retirer, neutre.
- 🟡 Seul le titre est cliquable dans la liste des fiches (`classroom_courses/show.html.erb:35`, `catalog/courses/_essential_row.html.erb:22`) → ligne entière + chevron.
- 🟡 « Essentielles de la leçon » (`classroom_courses.fr.yml:8`) → « Fiches essentielles ».
- 🟡 Phrase de réussite longue, « (1 sur 1) » (`classroom_essentials.fr.yml:24-25`) → « 60 % ont réussi · 3/5 ».

### Suivi d'un exercice (`/classrooms/:id/assignments/:id`)
- 🟠 Élèves en retard tout en bas, après « Compréhension » (`assignment_follow_ups/show.html.erb:46-72`) → juste après les chiffres.
- 🟠 « Pas encore faits » sans action (`show.html.erb:62-72`) → « Relancer la classe sur WhatsApp » (message sans nom d'élève).
- 🟡 « Faits : 18 » puis « Acquis · 18/25 » (`show.html.erb:25-41`) → un seul endroit.
- 🟡 « Assigné le 5 oct. » (`assignment_follow_ups.fr.yml:84`) → « Lun. 5 oct. » / « Hier » ; surtitre redondant (`show.html.erb:13`).
- 🟡 Palier à 0 en `text-line`, quasi invisible (`comprehension/_badge_counts.html.erb:10`) → `text-mute`.
- 🟠 « En difficulté » en rouge, « Fragile » en jaune proche de l'ambre (`comprehension/_section.html.erb:81`, `application.tailwind.css:73-76`) → gris / bleu pâle, jaune distinct.
- 🟡 « Pas encore lisible », « 1 session » (`comprehension.fr.yml:10,16,28`) → « Trop peu de rendus », « 1 essai ».

### Résultat d'un élève vu par l'enseignant
- 🟠 Titre « Félicitations ! » / « Courage ! » adressé à l'élève (`session_results/show.html.erb:16`) → « Résultat de Aya K. ».
- 🟠 Retour vers le catalogue (`show.html.erb:8`, et `exercises/show.html.erb:11`) → vers la provenance.
- 🟡 « Note 12/20 » et « Score 60 % » (`show.html.erb:29-38`) → l'un ou l'autre ; « Session de X » → « Copie de X ».

### Catalogue et fiche (côté enseignant)
- 🟡 Badge de matière sur chaque carte pour un prof d'une seule matière (`_course_card.html.erb:11`) → masqué.
- 🟠 Bascules « Assigner » sous toute la leçon (`essentials/show.html.erb:41-47,74`) → ancre en haut ou contenu replié.
- 🟠 Une rangée par classe sous chaque exercice, jusqu'à 30 rangées (`_exercise_progress.html.erb:54-64`) → un bouton « Assigner… » qui ouvre une feuille de classes à cocher.

### Annonces
- 🟠 Pas de « Nouvelle annonce » sur l'onglet d'arrivée (`inboxes/show.html.erb:8-10`) → bouton dans l'en-tête.
- 🟡 Ligne destinataires / dates tronquée à 390 px (`authored_messages/_row.html.erb:29`) → deux lignes.
- 🟠 Tutoiement d'un adulte (`authored_messages.fr.yml:47,118-119`) → vouvoiement.
- 🟠 Formulaire de plusieurs écrans (10 thèmes, 8 illustrations, image, audio, date) avant « Publier » (`_form.html.erb:51-125`) → titre, texte, classes ; le reste sous « Personnaliser ».

### Inviter un collègue
- 🟠 Tutoiement d'un adulte (`referrals.fr.yml:23`) → « Inscrivez-vous… ».
- 🟡 Titre dit deux fois, URL brute avec jeton affichée (`referrals/show.html.erb:6`, `_invite.html.erb:7,24`) → une fois ; URL derrière « Copier le lien ».
- 🟡 « WhatsApp », « SMS », « Plus d'options », « Parrainage » vs « Inviter un collègue » (`referrals.fr.yml:24-25,31-33`) → « Envoyer par WhatsApp », un seul nom, « Voir mes invitations ».

### Profil
- 🟡 Nom affiché deux fois, ligne « Photo : présente » (`profiles/_information.html.erb:12,26-33,42`) → une fois.
- 🟡 « Changer mon PIN » seul bouton principal (`profiles/show.html.erb:32-33`) → secondaire.
- 🟡 Établissement et matière sans moyen de signaler une erreur (`_information.html.erb:62-69`) → « Signaler une erreur ».

### Écrans manquants
- 🟠 Ni classes des années passées ni élèves partis (`classroom_overview_query.rb:43`, `teacher_home_query.rb:35`) → dans la future liste « Classes » et en pied du roster.

---

## 3. Rôle direction

### Les 5 problèmes les plus graves
1. 🔴 **L'accueil ne dit pas si l'établissement travaille.** Effectifs en tête, taux en pastilles de 14 px sans chiffre, fil d'activité sans les devoirs rendus, et un établissement vide affiche en vert « Rien à signaler » (`direction_alerts.rb:15-22`, `_school_card.html.erb:24-27`).
2. 🔴 **Pas de parcours de démarrage, création des classes laborieuse** : pas de premiers pas, un « + » par classe (24 appuis pour 24 classes), codes visibles seulement dans un toast éphémère, pas de bouton « Inviter » sur Enseignants.
3. 🔴 ⚖️ D6 · **Le même code ouvre les comptes enseignant et direction** (`schools.fr.yml:10,18,23`), et l'inscription demande à la direction de récupérer ce code… auprès de ses enseignants.
4. 🟠 ⚖️ D7 · **La direction ne peut pas valider ses enseignants en attente** (`join_request_vouches_controller.rb:6`) ; une direction sans établissement tombe sur un écran générique sans contact.
5. 🟠 **Textes et gestes copiés de l'équipe** (« référentiel », « fiche », « activez-le »), tutoiement d'un adulte, codes et dates hors format, ambre hors urgence, tableaux qui défilent à 390 px, pas d'annulation après le retrait d'un enseignant.

### Inscription de la direction (`/school-staff-signup`)
- 🔴 Le code est à demander « à vos enseignants » (`school_staff_registrations.fr.yml`) → dire où le trouver (courrier / WhatsApp de Lnclass, DRENA) + « Je n'ai pas de code ».
- 🟡 Quatre lignes de titre avant le premier champ (`new.html.erb:24-25,34-35`) → un titre, une phrase.
- 🟡 « Bienvenue, direction », « Genre » pour écrire M./Mme, pas de champ « Fonction » (`shared/common.fr.yml:77`) → « Civilité », champ « Fonction ».
- 🟡 Code en `font-display` ici, `font-mono` ailleurs, tiret au lieu d'espace (`_form.html.erb:49`) → un style.
- 🟡 Limite de tentatives en état d'erreur rouge sans bouton (`new.html.erb:30`) → « Réessayez dans une minute » + « Réessayer ».

### Compte en attente (direction sans établissement)
- 🟠 Message générique sans contact (`pending_accounts.fr.yml:29-31`, `show.html.erb:42-50`) → texte direction + « Écrire à l'équipe sur WhatsApp ».

### Accueil (`/school-admin/classrooms`)
- 🔴 Chiffres d'inventaire en tête, taux invisible (`_school_card.html.erb:14-21`, `_levels.html.erb:19`) → « Devoirs rendus cette semaine : 62 % » + devoirs donnés sur 7 jours, puis les niveaux avec leur taux écrit.
- 🔴 Faux « Rien à signaler » (`direction_alerts.rb:15-22`) → alertes « Aucune classe créée », « Aucun enseignant inscrit », « N classes sans devoir depuis 7 jours ».
- 🟠 ⚖️ D3 · Toutes les alertes en triangle ambre, alerte ambre pour une pastille rouge (`_school_card.html.erb:34`) → icône neutre pour les constats, ambre pour l'inactivité.
- 🟠 Alertes sans lien (`_school_card.html.erb:8-10`) → chaque classe cliquable ; « classe sans élève » → voir le code.
- 🟡 « Voir l'établissement » en double, « Anciens élèves » rangé dans la carte Établissement (`:53-54`) → supprimer le doublon, déplacer.
- 🟡 État vide des niveaux « Voir l'établissement » (`_levels.html.erb:8`) → « Créer vos classes ».
- 🟡 Bandeau d'arrivée avec date longue et parenthèse (`index.html.erb:10-13`) → « Mme X a rejoint la direction mardi ».
- 🟡 Carrousel d'annonces sans titre visible ni « Publier » (`communication/messages/_carousel.html.erb:13-16`) → carte « Annonces » + « Publier une annonce ».
- 🔴 Pas de premiers pas après l'inscription (`school_staff_registrations_controller.rb:22`) → carte « Pour démarrer » : inviter vos enseignants, créer vos classes, publier une première annonce.

### Activité récente (frame)
- 🟡 État vide-impasse (`activities/_activity.html.erb:12`) → « Inviter vos enseignants ».
- 🟡 « Réessayer » recharge tout l'accueil (`:10`) → recharger le frame seul.
- 🟠 Pas de devoirs rendus, pas de « Voir plus » → « 12 élèves de 3ᵉ 2 ont rendu « X » », page complète.

### Page d'un niveau, page d'une classe
- 🟠 Classes triées par nom (`levels/show.html.erb:13-16`) → par taux croissant.
- 🟡 4 lignes de chiffres, sans l'enseignant (`_classroom_card.html.erb:24-37`) → « Enseignant : M. X ».
- 🟠 Page classe sans enseignant ni code (`student_work_query.rb:10-11`) → les deux, code copiable.
- 🟡 « Aucun élève ne correspond » deux fois (`classrooms/show.html.erb:49,51`) ; « Moyenne » vs « Score moyen » (`:18`, `classrooms.fr.yml:92`) → une fois, un terme.
- 🟠 Tuiles qui cassent à 390 px, tableau `min-w-xl` de 3 colonnes (`show.html.erb:16-28,57`) → tuiles compactes, liste empilée.
- 🟡 Infobulles en formule (« ÷ (élèves × devoirs donnés) »), « — : » lu « tiret » (`classrooms.fr.yml:11,14`) → phrase simple.

### Anciens élèves, Enseignants, Enseignants retirés
- 🟡 Sous-titre qui répète le seul établissement (`departed_students/index.html.erb:11`, `teachers/index.html.erb:6`, `departed_teachers/index.html.erb:8`) → le supprimer.
- 🟡 « Devoirs rendus » en nombre seul vs « 3 / 8 » (`departed_students/index.html.erb:61`) → un format.
- 🟠 Tableaux `min-w-xl` qui défilent (`departed_students:40`, `teachers:16`) → une ligne par personne au téléphone.
- 🔴 Pas de bouton « Inviter des enseignants » ; « Enseignants retirés » mis en avant (`teachers/index.html.erb:7,61`, `destroy.turbo_stream.erb:8`) → bouton principal « Inviter », lien discret pour les retirés.
- 🟡 ⋮ qui disparaît sans explication sur un établissement inactif (`teachers/index.html.erb:46`, `departed_teachers/index.html.erb:28`) → notice « consultation seule ».
- 🟡 « non calculé » pour une matière absente (`teachers.fr.yml:21`) → « matière non renseignée ».
- 🟡 « retiré(e) » alors que le genre est connu, « Retiré le 4 octobre 2026 » (`teachers.fr.yml:36-38`, `departed_teachers/index.html.erb:26`) → accord, date courte.
- 🟡 Lien retour maison « ← Enseignants » (`removal.html.erb:9`, `departed_teachers/index.html.erb:6`) → `ui_page_header back:`.
- 🟠 Retrait sans « Annuler » (`teachers/destroy.turbo_stream.erb:4`) → toast avec « Annuler » (la réintégration existe).

### Établissement (`/school-admin/school`)
- 🔴 ⚖️ D6 · Le lien « pour les enseignants » ouvre aussi la direction (`schools.fr.yml:10,18,23`).
- 🟠 URL brute sur 2-3 lignes, « Changer le lien » au même niveau que « Copier » (`_link.html.erb:8-9,13,21`) → code en grand, WhatsApp d'abord, « Changer le lien » discret.
- 🟡 « Établissement pas actif » en ambre (`show.html.erb:8`, `shared/_level_classrooms.html.erb:13`) → notice neutre + cadenas.
- 🔴 Un « + » par classe, codes nulle part (`shared/_level_classrooms.html.erb:25,44-50`, `level_classrooms_controller.rb:16`) → « Nombre de classes : [−] 4 [+] », liste des classes avec code copiable.
- 🟠 Textes écrits pour l'équipe (« Créez les niveaux… », « rechargez la fiche », « activez-le », « cours assignés », `teams/level_classrooms.fr.yml:12-25`) → clés propres à la direction.
- 🟡 Titre en `h3` au milieu de `h2`, « − » désactivé sans raison (`shared/_level_classrooms.html.erb:10,40`) → niveau de titre paramétré, infobulle « Cette classe a déjà servi ».
- 🟡 « 2 / 3 comptes créés avec le code », pas de fonction sous les noms (`shared/school_staff.fr.yml:6`) → « 2 places sur 3 utilisées », fonction.

### Annonces (Reçues, Mes annonces, Enseignants)
- 🟠 « Reçues » sans « Nouvelle annonce » (`inboxes/show.html.erb:8`) → bouton dans chaque onglet.
- 🟡 « …et de votre direction » dit à la direction (`inboxes.fr.yml:20`) ; onglet de modération nommé « Enseignants » (`messages.fr.yml:53`) → textes propres, « Annonces des enseignants ».
- 🟡 « Nouvelle annonce » deux fois à vide (`authored_messages/index.html.erb:7,20`) ; ligne trop chargée à 390 px (`_row.html.erb:14-36`).
- 🟡 « Annuler » en `ghost` et « Retirer » recopié à la main (`_row.html.erb:39`, `moderations/_moderated_message.html.erb:18-22`) → `ui_button`, `secondary`.
- 🟠 Tutoiement, texte inexact pour un public enseignant (`authored_messages.fr.yml:97,118-119`).
- 🟡 Un seul public, pas de « Tous » ni de ciblage par niveau, « Directions » ; « Pour <établissement> » redondant (`_form.html.erb:43-44`).

### Profil
- 🟡 « — » brut, pas de fonction (`profiles.fr.yml:43`) → « Non renseigné », ligne « Fonction ».

---

## 4. Rôle équipe

### Les 5 problèmes les plus graves
1. 🔴 **Publier le contenu est un geste caché et sans garde-fou** : pas de filtre « brouillons » ; « Publier », « Archiver », « Tout publier » dans un ⋮, sans confirmation, alors qu'ils changent ce que voient des milliers d'élèves (`catalog/courses/_role_actions.html.erb:13-15`).
2. 🔴 **Les imports ne guident pas** : slug à recopier depuis l'URL, aucun modèle téléchargeable, erreurs en chemin JSON sans la valeur fautive, plafonnées à 1 000 (`kinds/_essentials`, `_import_errors.html.erb:13`).
3. 🟠 **Parcours sans issue et accueil sans file d'action** : comptes et établissements du Pilotage non cliquables, recherche de compte au numéro exact, enseignants en attente enterrés dans Croissance ; Croissance, Blog, Comptes, Demandes de suppression hors navigation.
4. 🟠 **Inutilisable à 390 px** : tableaux de 672 à 896 px dont la 1ʳᵉ colonne défile, 5 filtres avant la liste, éditeurs longs dans des feuilles basses, 7-8 raccourcis équivalents.
5. 🟠 **Gestes destructifs mal protégés, ambre galvaudé** : supprimer un compte élève = bouton secondaire sans revérification du second facteur ; « Régénérer le code » = bouton principal bleu ; annonce nationale sans récapitulatif ; ambre sur les brouillons, si bien que les vraies urgences ne ressortent plus.

### Transverse équipe
- 🟠 Ambre hors urgence : « Brouillon » (`content_status_helper.rb:6`, `article_status_helper.rb:7`), « Hors barème » (`levels/_level_row.html.erb:12`), « Non défini » (`classroom_plans/_line_row.html.erb:19`), 2FA « Non activé » (`account_lookups/_result.html.erb:36`), cible non atteinte (`growth/show.html.erb:38`), établissement inactif (`schools/_header.html.erb:105`), questions verrouillées, « À compléter », lien montré une fois, demande de suppression ambre dès J-5 (`deletion_requests/_due.html.erb:9`) → ton neutre, ambre aux échéances < 24 h.
- 🟠 Tableaux `min-w-2xl/3xl/4xl` (`schools/index:45`, `levels/index:18`, `imports/index:26`, `articles/index:13`, `series/index:12`, `materials/index:13`, `drenas/index:19`, `dashboards/_drenas:20`, `_schools:32`) → cartes sous `sm`, ou 1ʳᵉ colonne collante.
- 🟠 Jargon : « Slug », « Code » qui affiche le slug, « menu ⋮ » écrit dans les textes (`drenas/index:24`, `levels/_level_row:18`, `teams.articles.*`) → « Identifiant d'import » + Copier, seulement où un import le demande.
- 🟡 Trois formats de date (`l(:long)`, `l(:short)`, `time_ago_in_words`) → un helper de date relative.
- 🟠 Pages orphelines (Croissance, Comptes, Demandes de suppression, Blog) sans `nav_key` ni entrée (`navigation_helper.rb:24-35`) → dans « Plus » ou sous « Comptes » / « Contenu ».
- 🟠 Pas d'état d'erreur sur les frames et recherches (`homes/show:28`, `account_lookups/_result:52`, `account_lookups/show:7-21`, `dashboards/_search`, `import_status_controller.js`) → `ui_error_state` « Réessayer ».
- 🟠 CRUD du référentiel incohérents (confirmations, icônes, toasts avec / sans nom, titres, état vide non rétabli après la dernière suppression, `<caption>` absentes) → un gabarit de CRUD partagé.
- 🟠 Pas de revérification du second facteur avant suppression de compte, réinitialisation 2FA ou invitation « Administration » (`Teams::BaseController`).

### Accueil
- 🟠 7-8 raccourcis de même poids (`homes/_shortcuts.html.erb:6-16`) → 2-3, le reste dans la navigation.
- 🟡 « Voir les établissements » en triple (`homes/show.html.erb:23`) → supprimer.
- 🔴 Pas de carte « À traiter » (`homes/show.html.erb:11-33`) → enseignants en attente, imports en échec, brouillons, demandes de suppression proches, avec compteur et lien.
- 🟡 Badge « Brouillon — visible uniquement par l'équipe » (`_recent_content.html.erb:24`) → « Brouillon ».

### Pilotage
- 🟠 Recherche de compte tout en bas (`dashboards/show.html.erb:25`) → sous les filtres.
- 🟠 Comptes et établissements non cliquables (`_search_results:18-33`, `_recent_signups:11-24`, `_schools:50`) → liens vers la fiche.
- 🟡 État vide « établissements » sans action (`_schools:9`) → « Importer les établissements ».
- 🟡 Quatre libellés pour « effacer les filtres » → « Effacer les filtres ».

### Croissance
- 🟠 « k enseignant », « Cohorte », « Cycle viral médian », note de 4 phrases (`growth.fr.yml`) → titres en clair, explications en infobulle.
- 🟠 File « Demandes en attente » dans une page d'analyse (`growth/show.html.erb:98`) → « Enseignants en attente de validation » sur l'accueil.

### Référentiel (DRENA, niveaux, séries, matières, barème, illustrations)
- 🟡 « Gérer » ×6 (`referentials/_summary.html.erb:18`) → « Gérer les niveaux »… ou tuiles-liens.
- 🟡 Structure scolaire redite trois fois (`_summary.html.erb:26-45`) → la matrice seule.
- 🟡 DRENA sans recherche (`drenas/index.html.erb:6-14`) → `table-filter`.
- 🟡 Position de niveau saisie à la main (`levels/_form.html.erb:13`) → « Monter » / « Descendre ».
- 🟡 Matrice : `title=`, case « utilisée » cliquable mais refusée (`level_series/_cell.html.erb:10-17`) → `aria-disabled` + raison.
- 🟡 Barème : retour figé, ⋮ pour une seule action, aide répétée (`classroom_plans/show.html.erb:7`, `_line_row:27-33`, `edit:12-15`).
- 🟡 Illustrations : « Renommer » en page entière (`_illustration.html.erb:27`) → modale ; lien croisé depuis le formulaire d'annonce.

### Établissements et fiche
- 🟠 Import en bouton principal (`schools/index.html.erb:10`) → secondaire ; la recherche est la tâche.
- 🟠 5 filtres empilés à 390 px (`schools/_filters.html.erb:14-37`) → recherche + « Filtres (n) » en feuille.
- 🟡 Pagination précédent / suivant sur une liste nationale (`schools/index.html.erb:80`).
- 🟠 Classes montrées deux fois, « Ajouter une classe » double le « + » (`schools/show.html.erb:20-26`, `_header:44`) → une liste par niveau.
- 🟠 Enseignants en attente après « Direction » (`schools/show.html.erb:40-42`) → en tête.
- 🟡 Pas de « Réactiver » ni de « Supprimer » sur la fiche (`_header.html.erb:47-59`) → aligner sur la liste.
- 🟠 « Régénérer le code » bouton principal bleu (`_header.html.erb:63`) → `danger`.
- 🟡 « Valider » 40 px vs « Refuser » 48 px (`_join_requests.html.erb:27-30`) ; « Supprimé le » pour une date future ; « rattaché(e) ».

### Invitations
- 🟡 Icône avion en papier alors que rien n'est envoyé (`invitations/new.html.erb:9`, `staff_invitations/new.html.erb:8`) → icône lien, « Créer le lien ».
- 🟠 Les rôles « Contenu » / « Terrain » promettent des périmètres que les policies n'appliquent pas (`teams.invitations.team_role_hints`) → décrire les droits réels, ou les appliquer (**sécurité**).

### Cours, fiches, exercices
- 🟠 Pas de filtre « Statut » (`catalog/courses/index.html.erb:43-47`).
- 🔴 Publier / Archiver / Tout publier sans confirmation, dans un ⋮ (`_role_actions.html.erb:13-15`, `essentials/show.html.erb:34-36`) → bouton « Publier » visible, confirmation avec décompte.
- 🟠 Éditeur riche dans une modale `lg` / feuille basse (`courses/new`, `essentials/new`, `exercises/new`) → page plein écran.
- 🟡 Règles de structure d'exercice en paragraphe, vérifiées seulement au serveur (`exercises/_form.html.erb:57`) → formulaire qui s'adapte au type.
- 🟠 « Retirer » une question sans annulation (`_question_fields.html.erb:8-9`, `_answer_fields.html.erb:17-18`) → toast « Question retirée · Annuler ».

### Imports
- 🟠 Pas de modèle téléchargeable, exemple sans « Copier » (`imports/new.html.erb:68-70`, `kinds/*`).
- 🔴 Slug à recopier depuis l'URL (`kinds/_essentials`, `kinds/_exercises`) → sélecteur de cours / fiche, ou retirer ces types du menu général.
- 🔴 Erreurs en chemin JSON sans la valeur fautive (`_import_errors.html.erb:13`) → « Établissement n° 4 · niveau inconnu « Tle C » », avec les valeurs acceptées.
- 🟠 Erreurs perdues au-delà de 1 000 (`_import_errors.html.erb:19-23`) → regroupement par motif + export.
- 🟡 `aria-live` bavard, `<progress>` sans total (`_status.html.erb:7,19`) ; rapport sans lien vers les objets créés (`:22-46`) ; pastilles de filtre 40 px (`imports/index.html.erb:20`) ; 50 imports sans pagination ; `title=` (`_files.html.erb:9`).

### Comptes et suppressions
- 🟡 Titre « Débloquer un compte » trop étroit → « Comptes ».
- 🟠 Recherche au numéro exact (`account_lookups/show.html.erb:14`) → nom aussi, ou cible des liens du Pilotage.
- 🟠 « Supprimer le compte » en secondaire au même poids que « Générer un code » (`_result.html.erb:76`) → `danger`, zone séparée ; dire ce qui est conservé (`account_deletions.new.kept`).
- 🟠 Numéro de téléphone dans l'URL (`deletion_requests/index.html.erb:17`, `?contact=`) → lien par `public_id` (**donnée personnelle**).

### Blog, annonces, modération
- 🟡 `text-2xs` (`articles/index.html.erb:23`), titre non cliquable (`_article_row.html.erb:10`), pas de filtre d'état (`index.html.erb:9`), « Publier » / « Archiver » sans confirmation (`article_status_helper.rb:28-32`).
- 🟠 Portée nationale implicite (`authored_messages/_form.html.erb:36-38`) → récapitulatif « Tout le pays · N destinataires » avant publication.
- 🟡 « Annuler » en `ghost` (`moderations/_moderated_message.html.erb:18`) ; retrait sans motif transmis à l'auteur.

---

## 5. Transverse (shell, composants, écrans d'entrée) — à corriger en premier

### Les 5 problèmes transverses les plus graves
1. 🔴 **L'infobulle ne marche pas au toucher** : `<details>` qui s'ouvre dans le flux et fait sauter tableaux et titres, ne se ferme ni au toucher extérieur ni par Échap, HTML invalide dans `<p>` / `<h2>` / `<th>`, et des formats indispensables (PIN, code de 8 chiffres valable 15 min) cachés dedans.
2. 🔴 **Focus et tailles hors seuils** : contour de focus #00a0ff à 2,8:1, invisible sur le héros bleu ; libellés de la barre basse à 11 px sur tous les écrans mobiles ; cases à cocher de 24 px.
3. 🔴 **Rien pour le hors-ligne et les erreurs réseau** : pas de service worker, manifest d'échafaudage (« AppLnclassapp », `theme_color: red`), frames qui affichent « Content missing » en anglais ou un squelette sans fin.
4. 🟠 **L'orientation se perd** : compte en attente qui tourne en rond, onglet actif seulement si la vue le déclare, 403/404 hors shell, connexion sans lien d'inscription, aide accessible depuis l'accueil élève seulement.
5. 🟠 **Composants et textes incohérents** : deux couleurs de bouton principal, « Se déconnecter » en rouge, orange et or proches de l'ambre, 24 bandeaux d'erreur et 3 groupes radio recopiés, vouvoiement servi aux élèves, doublons de libellés.

### Navigation et orientation
- 🔴 Compte en attente avec une navigation en boucle (`authenticated_controller.rb:11,22`) → shell sans navigation.
- 🟠 Onglet actif seulement par `nav_key` ou chemin exact (`navigation_helper.rb:105`) → détection par préfixe, `nav_key` pour les exceptions.
- 🟡 403/404 hors shell (`renders_result.rb:37`) → dans le shell si connecté.
- 🟠 Connexion sans « Pas encore de compte ? Rejoindre ma classe » (`sessions/new.html.erb:41-44`).
- 🟡 Déconnexion vers la landing marketing (`sessions_controller.rb:30`) → vers la connexion (téléphone partagé).

### Infobulles et aide contextuelle
- 🔴 `ui_info_tip` au toucher (`_info_tip.html.erb:4-9`, `info_tip_controller.js:23-24`) → bulle flottante, fermeture au toucher extérieur et Échap, zone tactile 44 px.
- 🟠 WCAG 1.4.13 : Échap ne ferme pas, trou de 4 px qui ferme la bulle au survol (`info_tip_controller.js:7,35-40`).
- 🟠 HTML invalide (`classroom/classrooms/_roster.html.erb:36`, `_questions_preview.html.erb:7`, `session_results/_badge.html.erb:14`) → à côté du titre, jamais dedans.
- 🟠 Formats cachés en infobulle (PIN : `sessions/new.html.erb:38`, `pin_resets/new.html.erb:26,31`, `joins/_signup_form.html.erb:51`) → `hint:` relié par `aria-describedby`.
- 🟡 Même info en infobulle pour l'élève, en texte pour l'adulte (`profiles/show.html.erb:21-29`, `catalog/courses/index.html.erb:25`) → une règle unique.
- 🟠 FAQ inaccessible hors de l'accueil élève, et rédigée pour l'élève (`help_controller.rb:22`, `help.fr.yml`) → « Besoin d'aide ? » dans `ACCOUNT_LINKS` de tous les rôles et en pied des écrans d'entrée ; variante adulte.

### Onboarding
- 🟠 « Contactez l'équipe Lnclass » sans lien (`pending_accounts.fr.yml`) → les `support_contacts` de la carte d'aide.
- 🟡 Limite de tentatives en rouge `role=alert` (`pending_accounts/show.html.erb:18`, `teacher_registrations/new.html.erb:30`, `school_staff_registrations/new.html.erb:30`) → état d'attente neutre avec compte à rebours.

### États
- 🔴 Pas de PWA ni de hors-ligne (`pwa/manifest.json.erb`, `application.html.erb:27`, `service-worker.js` vide) → bandeau « Hors connexion » global, page de repli, manifest Lnclass.
- 🔴 Frames sans erreur : « Content missing » (`_sidebar.html.erb:36-38`, frame `modal`) → écouteur global `turbo:frame-missing` / `fetch-request-error`.
- 🟡 Pages statiques `public/*.html` sans mode sombre, libellés différents des pages Rails.

### Accessibilité
- 🔴 `text-2xs` (11 px) dans la barre basse (`navigation_helper.rb:62`, token `application.tailwind.css:40-41`) → `text-xs`, supprimer le token.
- 🔴 Focus #00a0ff à 2,8:1 et invisible sur fond de marque (`application.tailwind.css:338,344,380`) → `outline-ink` / `brand-strong` avec décalage.
- 🟠 Focus des champs pâle (`components_helper.rb:66-71`) → bordure `brand-strong`, anneau ≥ 3:1.
- 🟠 Cases à cocher de 24 px (`_field.html.erb:6-10`) → `min-h-tap` sur l'étiquette.
- 🟡 Menu compte annoncé « Mon compte » alors qu'il affiche le nom (`_dropdown.html.erb:10`, WCAG 2.5.3).
- 🟡 `aria-current` sur un `<p>` (`_pagination.html.erb:7`), repère « nav Retour » sur chaque retour (`_back_link.html.erb:4`), `role=alert` dans une région `aria-live` (`_toasts.html.erb:4`).
- 🟡 Animations sans `motion-safe:` (`_loading_state.html.erb:12-14`, `_spinner.html.erb:4`).

### Mode sombre
- 🔴 QR code de la 2FA illisible (`second_factor_enrollments/new.html.erb:12-13`) → modules clairs ou conteneur blanc fixe.
- 🟡 Bandeau « navigateur ancien » resté clair (`application.tailwind.css:503-508`).

### Performance perçue (data chère)
- 🟠 Logo JPEG 1080×1080 (25 Ko) affiché en 36-64 px partout (`_header.html.erb:9` + 16 `image_tag`) → `lnclass/icon.svg` (1,8 Ko).
- 🟡 Bricolage Grotesque non préchargée (`application.html.erb:34`) → la précharger, ou police système sous 3G.
- 🟡 KaTeX (25 Ko) chargé sur toutes les pages (`application.tailwind.css:7`) → avec `math_controller` seulement.
- 🟡 `backdrop-blur` sur deux barres fixes (`_header.html.erb:4`, `_bottom_bar.html.erb:6`) → fond opaque.

### Cohérence des composants
- 🟠 ⚖️ D8 · Deux styles de bouton principal (`components_helper.rb:49`), « Se connecter » noir dans la modale, bleu sur la page.
- 🟡 « Se déconnecter » en rouge (`navigation_helper.rb:129`) → ton neutre.
- 🟡 24 bandeaux d'erreur recopiés → composant `ui_alert` / `ui_form_errors`.
- 🟡 3 groupes radio « genre » recopiés (`teacher_registrations/_form:26`, `invitations/show:59`, `school_staff_registrations/_form:18`) → `ui_radio_group`.
- 🟡 Bloc logo des écrans d'entrée recopié 16 fois en 36 / 56 / 64 px → `ui_entry_logo`.
- 🟡 Poignée de feuille basse non interactive (`_modal.html.erb:17`) → glisser pour fermer, ou retirer la poignée.

### Microcopie
- 🟠 Vouvoiement servi aux élèves : `components.fr.yml:17`, `common.fr.yml:10-18`, `layouts.fr.yml:4`, `sessions.fr.yml:8,17`, `pin_resets.fr.yml:9`, `errors/pages.fr.yml`, `public_pages.fr.yml` → infinitif neutre ou `tone_t`.
- 🟠 Doublons de libellés : « Active / Inactive » vs « Actif / Désactivé » ; « Rejoindre une / ma classe » ; « Créer un compte » vs « Créer mon compte enseignant » ; « Retour / Revenir à l'accueil » ; « PIN » / « Code secret » / « Afficher le code » ; « Modifier » vs « Changer mon… » → un terme par objet (glossaire).
- 🟡 « Non acquis » (pas de badge) vs « Acquis » (maîtrise ≥ 70 %) → « Pas encore de badge ».
- 🟡 Toast « C'est fait » + « Connexion réussie » ; erreur « Une erreur est survenue » → pas de toast après connexion ; une erreur qui dit quoi.
- 🟡 « Continuer » (`second_factors.fr.yml:46`, `joins.fr.yml:50`), « Chatter avec le support » (`help_sheet.fr.yml:12`) → verbe + destination, « Écrire sur WhatsApp ».
- 🟡 Codes « K7M-4QZ » avec tiret (`school_code.rb`) → espace.
- 🟡 Titres d'erreur avec un point final ; accords masculins par défaut (« Vous serez prévenu », « Inscrit le »).
