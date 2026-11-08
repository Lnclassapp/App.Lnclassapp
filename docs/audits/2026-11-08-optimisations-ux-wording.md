# Audit 2/3 — Optimisations, UI/UX, wording, concepts (2026-11-08)

> Lecture seule : aucun fichier de `app/`, `config/`, `db/` ni de test n'a été modifié ; rien n'a été lancé (ni app, ni CI, ni production). Les constats viennent de la lecture du code, des vues et des locales ; ce qui n'a pas été vérifié sur l'écran réel (rendu 390 px, contraste, EXPLAIN) est marqué « à confirmer ».
> Grille : Lnclass vise la **maîtrise par médaille/badge** plutôt que la note.

## Résumé

**248 constats** : P0 = 0 · P1 = 24 · P2 = 77 · P3 = 147.

Légende des IDs : lettre = type (O optimisation, U UI/UX, W wording, C concept), suffixe = part auditée (E élève, T enseignant, S école/direction, A équipe A, B équipe B, C catalogue/communication, X transverse). Exemple : `U-T03` = UI/UX, enseignant.

### Top 10

1. **C-X01** — « Médaille » et « Trophée » sont interdits par UDR-0007 et par la regex `FORBIDDEN` de `test/i18n/locale_files_test.rb:6` : il faut une nouvelle UDR, le glossaire et le test avant tout renommage.
2. **C-E01 / C-E02** — L'élève lit une note /20 partout ; la médaille n'apparaît que sur l'écran de résultat, qui empile 5 jugements (badge, appréciation, note, maîtrise, score %).
3. **C-X08 / W-X01** — Le pourcentage brut survit sur 3 écrans alors que l'élève lit /20 ; « niveau » désigne trois choses (scolaire, palier, maîtrise).
4. **C-T01 / U-T01** — Deux règles de « badge » coexistent (par exercice, et par classe sur la moyenne avec Diamant dès un seul exercice parfait).
5. **C-S01 / C-S02 / C-S03** — Direction : « Moyenne » en % par classe, tuile « Moyenne », colonne « Score moyen », anciens élèves ; UDR-0007 déconseille « Moyenne ».
6. **C-C01 / C-C02** — La FAQ `/aide` enseigne la note sur 20 ; « Réussi » = 100 % de bonnes réponses, sans lien avec la médaille.
7. **C-X05** — La doc cite Bronze 50 / Argent 70 / Or 80 %, les seuils réels sont 48/68/78 % (ADR-0106) ; `REMEDIATION_THRESHOLD` (15/20) ne coïncide avec aucun palier.
8. **O-C01 / O-C02** — Liste des cours élève : requête exécutée deux fois (blocs téléphone et ordinateur) ; sur ordinateur 24 leçons max sans pagination alors que le total affiche le vrai nombre.
9. **O-X01 / O-X02** — Pool DB de 3 à 5 connexions face à Puma 3 threads + Solid Queue dans le même process ; verrou `limits_concurrency` des imports à 3 min par défaut contre des imports de 10 min.
10. **O-X05** — Index manquant sur `classroom_students.student_id` (seul un index partiel existe) ; touche aussi l'accueil direction.

Autres faits marquants : pas de N+1 net (agrégats groupés, listes paginées, imports en jobs par lots de 100) ; aucun rôle ni écran parent dans l'UI (seulement des mentions légales) ; les pages d'erreur vouvoient alors que l'app tutoie ; l'accueil équipe fait ~12 requêtes pour 3 compteurs.

## Passage aux médailles/badges

**Conclusion.** Les 4 paliers existants (Bronze, Argent, Or, Diamant) plus l'état « Pas encore » suffisent pour l'élève ; « Pas encore » existe déjà (`comprehension.fr.yml:24`, « Pas encore de badge » sur le résultat). La médaille se déduit de `score_percent` par `Grading.badge_for` : aucune migration de colonne. À faire d'abord : unifier les trois libellés concurrents (« Pas encore » / « Non acquis » / « En difficulté »), trancher la règle unique (par exercice ou par classe), et lever l'interdit « Médaille » (UDR-0007 §2 + regex du test i18n). Risque : décalage entre `exercise_badges.level` (stocké) et le palier recalculé depuis ADR-0106 (C-X15). Aucun classement d'élèves ni export de notes n'existe ; le rapport de compréhension enseignant classe pourtant les élèves par score.

**Principaux écrans à convertir** (détail ligne à ligne dans les tableaux ci-dessous) :

| Écran | Aujourd'hui | Deviendrait |
|---|---|---|
| Accueil, historique, Ma classe, page exercice (élève) | note /20, moyenne | médaille du meilleur résultat par exercice |
| Résultat de session (élève) | badge + appréciation + note + maîtrise + score % | médaille seule, avec une phrase |
| Liste de classe, fiche élève (enseignant) | « Moyenne 15/20 · Or », « Dernier score » % | médaille de maîtrise la plus haute, sans chiffre |
| Rapport d'exercice, « Copies rendues » (enseignant) | classement par meilleure note | répartition par médaille, sans classement |
| Pilotage, « Réussite moyenne » (équipe) | `AVG(score_percent)` | répartition Bronze/Argent/Or/Diamant sur la période |
| Carte classe, tuile « Moyenne », « Score moyen », anciens élèves (direction) | % moyens, taux de rendu 70/40 % | répartition de médailles par classe |
| Corrigé (équipe) | « Question N · X pt » | à retirer |
| FAQ `/aide`, fiches de révision (catalogue) | échelle /20, « Réussi » = 100 % | texte médailles ; « Réussi » = médaille obtenue |

### Inventaire détaillé par part


### Élève

| Écran | Donnée chiffrée actuelle (fichier:ligne) | Médaille/badge proposé |
|---|---|---|
| Résultat de la copie (élève) | Tuile Note « 14/20 » `session_results/show.html.erb:63` ; tuile Maîtrise `:72-75` ; titre d'appréciation `session_results.fr.yml:headline` | Une grande médaille (Bronze→Diamant ou « Pas encore ») + prochaine médaille à viser |
| Résultat (enseignant/équipe) | Score « 68 % » `show.html.erb:67-70`, « x sur y » `:79` | Médaille de la copie + « x/y justes » uniquement en détail |
| Résultat — phrase de progrès | « 8/20 … 14/20 » `session_results.fr.yml:94-96` | « Tu passes de Bronze à Argent » |
| Résultat — objectif de remédiation | « vise au moins 15/20 » `session_results.fr.yml:107-110` | « Vise l'Argent » (palier, plus de chiffre) |
| Accueil — carte « À revoir » | « Tu as eu 8/20 » `student_homes.fr.yml:35` + `next_step/_review.html.erb:9` | « Tu n'as pas encore de médaille sur … » |
| Accueil — historique | `grade_label` vert dès 14/20 `_history.html.erb:31-32` ; bouton Refaire `< 10` `:35` | Trophée du palier ; « Refaire » si sous Argent |
| Accueil — avancement du devoir | « 4 exercices faits sur 6 » + barre `next_step/_progress.html.erb:5-8` | Garder (avancement, pas une note) ; option : barre de médailles obtenues |
| Ma classe — exercices traités | « 16/20 · Acquis » `exercise_cards_helper.rb:15-16` | Médaille détenue de l'exercice (une par exercice) |
| Ma classe — vide traités | « ton meilleur score » `student_classrooms.fr.yml:19` | « ta meilleure médaille » |
| Mon historique | pastille « 14/20 » `student_archives/_result_row.html.erb:102-105` (+ sr-only « 14 sur 20 » `:104`) | Pastille trophée + nom du palier |
| Page exercice (élève) | « Meilleure note : 16/20 » `exercises/show.html.erb:119-122` ; `ExerciseProgressQuery.badge_level` inutilisé | « Ta médaille : Or » |
| Copie en cours | « 3/10 répondues » `exercise_sessions/show.html.erb:32` ; « barème : N points » `:30` ; « (2 points) » par question | Garder le compteur ; retirer barème/points côté élève |
| Compréhension (enseignant) | « 20 / 27 faits » `_section.html.erb:18-19` ; barres % par question `:60-63` ; pastille « 🏆 16/20 » `comprehension_helper.rb:87` ; tri par `-row.best` `comprehension_detail_query.rb:93` | Cinq cases médailles (déjà là) ; pastille trophée seul ; tri par palier sans classement |
| Cercle catégorie dominante | « 18/25 » `_circle.html.erb:5-9` | « 18 élèves en Argent ou mieux » |

### Enseignant

Proposition générale : une seule pastille `médaille` (trophée coloré + libellé Bronze/Argent/Or/Diamant, « À consolider » sous le Bronze) ; les chiffres /20 et % passent en infobulle ou disparaissent.

| Écran | Donnée chiffrée actuelle (fichier:ligne) | Médaille/badge proposé |
|---|---|---|
| Liste de classe, pastille élève | « Moyenne 15/20 · Or » (`classroom/classrooms/_roster.html.erb:104,107`) | Médaille seule (règle de classe à trancher, C-T01) ; « À consolider » sans chiffre |
| Liste de classe, colonne « Dernier score » | `84 %` (`_roster.html.erb:124`) | Médaille de la dernière session + « Voir le résultat » |
| Fiche élève, résumé | « Moyenne 14/20 · Or » (`classroom_students/_summary.html.erb:14-18`) | Répartition « Or ×1 · Argent ×2 » uniquement |
| Fiche élève, ligne d'exercice | « 14/20 » (`_assignments.html.erb:32`) | Médaille de l'exercice + flèche de tendance |
| Fiche élève, fait seul | `78 %` (`_self_practice.html.erb:26`) | Médaille de la session |
| Rapport d'exercice, liste « Élèves » | « 🏆 16/20 » + tri par meilleur score (`comprehension_helper.rb:87`, `comprehension_detail_query.rb:93`) | Médaille seule, groupée par case, tri alphabétique |
| Rapport d'exercice, « Copies rendues » | « 1re copie 8/20 · meilleure note 15/20 » (`assignment_follow_ups/show.html.erb:54`, locale l.12) | Supprimé ; « Bronze → Or » dans la ligne élève |
| Accueil, « Historique » | « 17/20 » moyenne de classe verte (`teacher_homes/_history.html.erb:35-38`) | Répartition de médailles de la classe ou médaille dominante |
| Accueil, carte de classe | pastilles Or 3 / Argent 5 (déjà médailles) (`_classroom_card.html.erb:12-19`) | Conserver ; aligner la règle sur C-T01 |
| Page classe, « Exercices assignés » | « 20 / 27 faits » (progression, pas une note) | Conserver ; ajouter la médaille dominante de l'exercice |
| Infobulles Badge / Maîtrise | « Bronze dès 10/20, Argent dès 14/20, Or dès 16/20 » (`shared/layouts.fr.yml:27`) | Critères en mots (« plus de la moitié juste », « sans faute ») |

### École / direction (et parent)

| Écran | Donnée chiffrée actuelle (fichier:ligne) | Médaille/badge proposé |
|---|---|---|
| Carte classe d'un niveau | « Moyenne : 62 % » — levels/_classroom_card.html.erb:40 ; `average_percent` student_work_query.rb:177 | Médaille dominante de la classe (la plus fréquente parmi les `exercise_badges` des élèves présents) + répartition « 8 bronze · 6 argent · 3 or » ; rien si < 5 élèves |
| Carte classe d'un niveau | « Taux de rendu : 71 % » + pastille verte/jaune/rouge — _classroom_card.html.erb:15,37 ; work_signal.rb:5-6 | Indicateur de participation en mots (« régulière / à relancer »), sans couleur de médaille |
| Tuile « Moyenne » page classe | `percent.call(classroom.average_percent)` — classrooms/show.html.erb:29 | Barre empilée de médailles de la classe (bronze/argent/or/diamant) |
| Tuile « Taux de rendu » page classe | `percent.call(classroom.submission_rate)` — show.html.erb:28 | « 24 devoirs rendus sur 30 » en nombres entiers, sans % |
| Colonne « Score moyen » par élève | `percent.call(student.work.average_percent)` — show.html.erb:110 | Meilleure médaille de l'élève + nombre de médailles (icône + nom accessible) |
| Colonne « Devoirs rendus » | `t(".submitted", count:, total:)` « 4 / 6 » — show.html.erb:107 | Conserver (entiers) |
| Anciens élèves | `percent.call(student.average_percent)` — departed_students/index.html.erb:126 | Meilleure médaille obtenue dans l'établissement |
| Accueil : bulles « Niveaux » | pastille de taux + `sr_rate` « taux de rendu 71 % » — _levels.html.erb:47-51 | Médaille dominante du niveau (forme + nom), ou aucune pastille |
| Accueil : alerte « red_signal » | « moins de 40 % des devoirs » — classrooms.fr.yml:53-55 | « classes avec peu d'activité » (sans pourcentage) |
| Fiches à revoir (classe) | « moins de 10/20 » — classroom/classrooms/_gaps.html.erb:7 | « pas encore de médaille de bronze » |
| Infobulles | `tips.average` / `student_average` / `average_tip` (classrooms.fr.yml:12-13 ; departed_students.fr.yml:12) | Expliquer les 4 médailles (ADR-0033) au lieu de « Moyenne des scores » |

### Équipe A (imports, établissements, pilotage, croissance)

| Écran | Donnée chiffrée actuelle | Médaille proposée |
|---|---|---|
| Pilotage `/teams/dashboard` · « Sur la période » · tuile « exercices terminés » | « Réussite moyenne : 72 % » (moyenne de `score_percent`, `team_dashboard_query.rb:137`) | Répartition des **médailles décernées** sur la période : « 120 Bronze · 85 Argent · 40 Or · 12 Diamant » (barres ou pastilles bronze/argent/or/diamant, nombre d'élèves médaillés), sans moyenne. « — » devient « Aucune médaille décernée ». |
| Pilotage · « Élèves par niveau » | « 12 élèves · 18 % » par niveau scolaire | Inchangé (effectif et part de répartition, pas une note). Éventuel ajout : « dont N avec au moins une médaille Or ». |
| Pilotage · « Par DRENA » / « Par établissement » | Colonnes Classes, Enseignants, Élèves, Élèves actifs (comptes) | Inchangé. Option : colonne « Élèves médaillés » (nombre, pas %). |
| Pilotage · inscrits récents, recherche de compte | Aucun chiffre de note | Aucune. |
| Croissance `/teams/growth` | k, conversion (%), cycle viral (jours), élèves par enseignant | Aucune (indicateurs de croissance, pas de maîtrise). |
| Imports, établissements, accueil, déblocage, suppressions | Compteurs d'import, de classes, de demandes | Aucune. |

### Équipe B (contenu, référentiels, invitations)

| Écran | Donnée chiffrée actuelle | Médaille proposée |
|---|---|---|
| Corrigé d'une fiche de cours (teams/answer_keys/show) | « Question N · X pt » (points par question) | Retirer les points ; « Question N » seul. Pas de médaille côté équipe (lecture du corrigé) |
| Corrigé, entraînement (teams/answer_keys/_practice) | « Je m'entraîne (non noté) » | « Je m'entraîne (sans médaille) » |
| Corrigé, réponse numérique | « à X près » (tolérance) | Inchangé : paramètre de correction, pas une note |
| Référentiel / Niveaux / Barème des classes | « Barème des classes », « Hors barème », nombre de classes 0 à 30 | Renommer (« Plan des classes ») pour libérer « barème » aux seuils de médaille ; chiffres inchangés (comptages, pas des notes) |
| Articles (lectures) | « N lectures sans dédoublonnage » | Inchangé : métrique d'audience, hors maîtrise |
| Séries, DRENA, matières, invitations, codes | compteurs d'objets uniquement | Sans objet |

### Catalogue et communication

| Écran | Donnée chiffrée / statut actuel | Médaille proposée |
|---|---|---|
| Liste des cours (élève) `/cours` | Pastille « En cours » / coche « Terminée » (fiches lues), compteur « N fiches de cours » | Garder « Lue »/« Fiches lues » ; ajouter à côté la meilleure médaille de la leçon (agrégat des badges de ses exercices) ou rien si aucun exercice tenté |
| Carte de leçon (ordinateur) | « En cours » + lignes de fiches avec « À revoir » | Médaille de la leçon + « À revoir » conservé pour les lacunes |
| Carte feuille « Prépare interros n°N » | « n / N exercices réussis » (réussi = 100 % juste) | Pastilles Bronze/Argent/Or/Diamant par exercice, ou « n médailles sur N exercices » |
| Exercice dans une feuille | Statut « Réussi » / « À revoir », verdict « ✓ Juste / ✗ Faux » par question, lien « Voir ma correction » vers la page résultat en /20 | Médaille de l'exercice à la place de Réussi/À revoir ; verdicts de question conservés |
| Vue enseignant d'une feuille | « n / N élèves ont réussi » | Répartition par médaille de la classe (4 compteurs + « sans médaille ») |
| « Je m'entraîne » (fiche de révision) | Verdicts Juste/À revoir par case, aucun chiffre | Aucune médaille (sans trace) ; harmoniser le mot « À revoir » en « Faux » |
| Page d'épreuve (`paper`) | « (3 points) » par exercice | Retirer ou rester décoratif (à trancher) |
| FAQ `/aide` | Note /20, %, seuils Bronze/Argent/Or en /20, « Maîtrise » Acquis/Fragile/En difficulté, « Meilleure note » | FAQ en médailles uniquement ; supprimer « note sur 20 » et « Maîtrise » |
| Carte « Prochain exercice » | Aucun chiffre (titre + bouton) | Optionnel : médaille actuelle de l'exercice pour inciter à monter d'un palier |
| Annonces / communication | Aucun chiffre de score | Aucune |

### Concepts et vocabulaire transverses

Légende : médaille = Bronze/Argent/Or/Diamant (existants) ; « Pas encore » = absence de médaille (terme déjà en UI enseignant ; **terme à valider** côté élève, qui lit aujourd'hui « Pas encore de badge » sur le résultat). Le pourcentage et la note /20 restent calculés en base (aucune migration).

| écran | rôle | fichier:ligne | donnée actuelle | médaille proposée |
|---|---|---|---|---|
| Résultat de session (carte principale) | élève | `assessment/session_results/show.html.erb:46`, `:63` | badge (déjà), titre « Très bien/Bien… », note « 14/20 » (`grade_label`), maîtrise (Acquis/Fragile/En difficulté) `:72-75` | Garder la médaille au centre ; retirer maîtrise ; titre d'appréciation OK ou à remplacer (décision porteur) ; note /20 relégable en discret |
| Résultat de session (tuiles) | enseignant, équipe | `show.html.erb:67-68` | « Score 80 % » en plus de la note | Retirer le score %, garder médaille + note /20 (W-X14) |
| Accueil élève, historique | élève | `classroom/student_homes/_history.html.erb:32-33` | « 14/20 » vert/ink selon MASTERY | Médaille de la session (icône + nom) à la place de la note ; bouton « Refaire » reste sous « Bronze » (`grade_on_20 < 10`, `:35`) = « Pas encore » |
| Accueil élève, carte « À revoir » | élève | `student_homes/next_step/_review.html.erb:9` | « Tu as eu 7/20. Relis la fiche… » | « Pas encore de médaille sur cette fiche… » (formulation à valider) |
| Archives de l'élève (ancienne classe) | élève | `student_archives/_result_row.html.erb:7,18-19` | pastille « 14/20 » | Médaille + nom en sr-only (`grade_spoken` à remplacer) |
| Page d'un exercice (meilleur résultat) | élève | `assessment/exercises/show.html.erb:119-121` ; `exercises.fr.yml:36` | « Meilleure note : 14/20 » | « Meilleure médaille : Argent » (lecture de `exercise_badges` via `ExerciseProgressQuery:17` déjà prête) |
| Ma classe, exercices traités | élève | `exercise_cards_helper.rb:15-16` (`exercise_card_for_treated`) | « 16/20 · Acquis » | « Or · Acquis » → médaille seule (supprimer le suffixe maîtrise) |
| Ma classe, clé orpheline | élève | `student_classrooms.fr.yml:40` | « Meilleur score » (probablement inutilisée) | supprimer (C-X07) |
| Fait seul (fiche élève vue enseignant) | enseignant | `classroom_students/_self_practice.html.erb:26` | « 60 % » | médaille ou /20 (C-X08) |
| Liste de la classe | enseignant | `classrooms/_roster.html.erb:100-108` | pastille « Moyenne 15/20 · Or » ou « Pas encore » | déjà une médaille ; unifier « Pas encore » |
| Liste de la classe (colonne) | enseignant | `_roster.html.erb:124` ; `classrooms.fr.yml:56-57` | « Dernier score 80 % » | médaille de la dernière session ; renommer « Dernière médaille » |
| Fiche d'un élève (résumé) | enseignant | `classroom_students/_summary.html.erb:15-16,19-22` | « Moyenne 14/20 · Argent » + compteurs de médailles | déjà médaille |
| Fiche d'un élève (exercices assignés) | enseignant | `classroom_students/_assignments.html.erb:28-33` | pastille note /20 + trophée du palier | déjà médaille ; ajouter « Pas encore » sous Bronze |
| Suivi d'un devoir (copies) | enseignant | `assignment_follow_ups/show.html.erb:38` ; `assignment_follows_ups.fr.yml:12` | « 1re copie 8/20 · meilleure note 14/20 » | « 1re copie Bronze · meilleure Argent » (garder /20 en infobulle) |
| Compréhension d'un exercice | enseignant | `assessment/comprehension/_section.html.erb`, `comprehension.fr.yml:18-24` | cinq cases par badge, tendances | déjà médaille |
| Accueil enseignant, historique | enseignant | `classroom/teacher_homes/_history.html.erb:34-38` ; `teacher_homes.fr.yml:31-32` | moyenne « 14,5/20 » verte | médaille de classe = `class_badge_for` de la moyenne |
| Page d'une classe (direction) | direction | `school_admin/classrooms/show.html.erb:29,109-110` ; `school_admin/classrooms.fr.yml:91,96` | tuile « Moyenne 72 % » + colonne « Score moyen » par élève | /20 + médaille de classe (décision porteur : la direction lit-elle des médailles ?) |
| Carte de classe par niveau | direction | `school_admin/levels/_classroom_card.html.erb:40` ; `school_admin/levels.fr.yml:25` | « Moyenne : 72 % » | idem |
| Élèves partis | direction | `school_admin/departed_students/index.html.erb:62` ; `departed_students.fr.yml:21` | « Score moyen 65 % » | idem |
| Tableau de bord équipe | équipe | `teams/dashboards/_key_figures.html.erb:6` ; `dashboards.fr.yml:41-45` | « Réussite moyenne : 68 % » | garder en % ou /20 (agrégat plateforme, hors périmètre élève ; ADR-0106 §4.4) |
| Aide / FAQ | élève | `communication/help/show.html.erb:7-9` ; `help.fr.yml:29-43` | questions « note sur 20 », « Maîtrise », « badge » | réécrire (C-X11) |
| Infobulles badge et maîtrise | élève, enseignant | `badges_helper.rb:24-34` ; `layouts.fr.yml:27-28` | seuils /20 calculés | mettre à jour le mot (médaille) |
| Pages légales / mission | public | `pages/privacy.fr.yml:29,77` ; `pages/mission.fr.yml:27` | « notes, badges » | texte seul |
| Résultat : fiche à revoir | élève | `session_results/_gap_outcome.html.erb:7` | « vise au moins 15/20 » | « vise au moins l'Argent »/ « Bronze » (REMEDIATION_THRESHOLD = 15/20 n'est pas un palier : voir remarque) |

Remarque inventaire : `REMEDIATION_THRESHOLD` (75 %, 15/20) est entre Argent (14/20) et Or (16/20) et ne coïncide avec aucun palier (`grading.rb`). Remplacer la note par une médaille dans `_gap_outcome.html.erb` oblige soit à dire « 15/20 » (note), soit à créer un seuil de lacune = palier (ex. Argent, 14/20 : changement de règle métier, ADR-0043/0101 à amender). À trancher.

---

#### Résumé des risques de migration

- Aucune migration SQL nécessaire pour un passage « médailles » en affichage (le palier est dérivé de `score_percent`).
- Risque principal : décalage `exercise_badges.level` (stocké) vs `badge_for(score_percent)` (recalculé) après ADR-0106 ; à vérifier en base.
- Risque doc/test : UDR-0007 et `FORBIDDEN` (médaille/trophée) à changer avant tout renommage.
- Risque UX : `REMEDIATION_THRESHOLD` non aligné sur un palier.
- Aucun classement d'élèves, aucun export de notes à migrer.

## Constats — Élève

Contexte vérifié : `Entities::Assessment::Grading` (app/domain/entities/assessment/grading.rb) porte 4 seuils : PASS 50 (Bronze), MASTERY 70 (Argent, « Acquis »), GOLD 80 (Or), PERFECT 100 (Diamant), plus REMEDIATION 75 (l:10). Aujourd'hui l'élève voit une **note sur 20** partout (UDR-0023/0058), le badge seulement sur l'écran de résultat. Cinq vocabulaires coexistent : note /20, médaille, maîtrise (Acquis/Fragile/En difficulté), appréciation (Très bien…À retravailler), score %.

### Conceptuel

#### C-E01 — Le badge n'est visible que sur l'écran de résultat ; accueil, historique, Ma classe, page exercice n'affichent que la note /20
Gravité : P1 · Élève, /home, /student/archive, /student/classroom, /exercises/:id · Fichier : app/views/classroom/student_homes/_history.html.erb:31-32 ; student_archives/_result_row.html.erb:102-105 ; assessment/exercises/show.html.erb:119-122 ; helpers/assessment/exercise_cards_helper.rb:15-16
Description : la médaille (ADR-0033) existe en base (`exercise_badges`) mais n'est lue que par le résultat. Partout ailleurs l'élève lit « 14/20 ».
Preuve : `grade_label(session.score_percent)` (_history:32) ; `t(".best", grade: grading.grade_on_20(...))` (exercises/show:121) ; `ExerciseProgressQuery::Row` calcule `badge_level` et `mastery` mais la vue ne s'en sert pas.
Proposition : remplacer chaque `grade_label` élève par le trophée + nom du palier (Bronze/Argent/Or/Diamant, « Pas encore » sinon) ; retirer `data-grade`/vert à 14/20.
Effort : M

#### C-E02 — Le résultat d'une session montre 5 jugements concurrents pour une seule copie
Gravité : P1 · /exercise_sessions/:id/result · assessment/session_results/show.html.erb:46, 50, 56-63, 72-75, 67 · Description : badge (l.46), titre d'appréciation « Très bien / Bien / Assez bien / À retravailler » (headline), encouragement vert/rouge (l.9, 50), note /20 (l.63), maîtrise Acquis/Fragile/En difficulté (l.72-75), et, pour l'enseignant, Score % et « x sur y » (l.67-80).
Preuve : `<dt ...><%= t(".mastery") %>` + `ui_badge mastery_label(...)` à côté de `grade_label(result.score_percent)` et du badge.
Proposition : garder UNE médaille en grand + une phrase d'encouragement ; supprimer tuile Note, tuile Maîtrise, headline d'appréciation ; ne garder « x/y questions justes » qu'en détail de correction.
Effort : M

#### C-E03 — Le badge affiché est celui de la session, pas celui détenu par l'élève
Gravité : P2 · résultat · session_result_query.rb:98 (`badge_level: grading.badge_for(score_percent)`) ; show.html.erb:46 · Description : après un mauvais essai, la page affiche « Bronze » alors que l'élève détient Or (le badge ne monte que vers un palier supérieur, glossaire). Contradiction médaille/historique.
Preuve : le partial reçoit `result.badge_level` (palier du score de la session) et `earned_now` par `ExerciseBadge.exists?(exercise_session_id:)` (query l.~78).
Proposition : afficher « Médaille de l'exercice : Or » (détenue) + « Cet essai : Bronze » en secondaire, ou seulement la détenue ; « Nouveau badge ! » reste lié à earned_now.
Effort : M

#### C-E04 — Trois seuils différents pour « c'est bon / à refaire » (10, 14, 15 sur 20)
Gravité : P2 · accueil / résultat / Ma classe · _history.html.erb:35 (`grade_on_20(...) < 10` en dur) ; Grading::MASTERY 70 = 14/20 (vert, « Acquis ») ; REMEDIATION_THRESHOLD 75 = 15/20 (gap_outcome.hint « vise au moins 15/20 », session_results.fr.yml:107-110).
Description : un élève « Acquis » (14/20, vert) a encore sa notion « à revoir » ; « Refaire » dans l'historique apparaît à < 10/20 seulement. Le chiffre 10 est dupliqué hors du domaine.
Preuve : `if grading.grade_on_20(session.score_percent) < 10 &&` .
Proposition : décider avec les médailles : « à revoir » = pas de médaille (< Bronze) ; « Refaire » proposé sous Argent ; objectif de remédiation = « obtenir l'Argent » au lieu de « 15/20 » ; centraliser dans Grading.
Effort : M

#### C-E05 — « Maîtrise » (Acquis/Fragile/En difficulté) double la médaille avec des paliers qui ne se recoupent pas
Gravité : P2 · result show:72-75 ; exercise_cards_helper.rb:16 (« 16/20 · Acquis ») ; helpers/assessment/badges_helper.rb:19, 32 ; config/locales/assessment/badges.fr.yml:9-12 · Description : 3 niveaux de maîtrise vs 4 médailles ; Bronze = « Fragile », Argent et Or = « Acquis ». Le mot « Maîtrise » désigne un 2e système.
Preuve : `mastery_tip` « Acquis : 14/20 et plus. Fragile : de 10 à 13/20 » (shared/layouts.fr.yml:28) et `badges_tip` à côté.
Proposition : supprimer `mastery_*` côté élève ; « maîtrise » devient le nom du parcours de médailles ; les couleurs/états suivent le palier.
Effort : M

#### C-E06 — « Progression » mêle avancement (barre) et résultat (note) ; la phrase de progrès parle en notes /20
Gravité : P3 · résultat + accueil · session_results.fr.yml:94-96 (« Tu progresses : 8/20 à ta première session, 14/20 aujourd'hui ») ; student_homes/next_step/_progress.html.erb:5-8 (barre « exercices faits sur ») · Description : « progresser » = monter de note ici, = faire plus d'exercices là ; « Tu confirmes ta maîtrise : 14/20 » mélange maîtrise et note.
Preuve : `stable: "Tu confirmes ta maîtrise : %{current}/20."`
Proposition : « Tu passes de Bronze à Argent » / « Tu gardes ton Or » ; garder « faits sur » pour l'avancement du devoir uniquement.
Effort : S

### Médailles (exposition chiffrée) — voir tableau final ; constats UI/UX ci-dessous

#### U-E01 — Cible tactile des cases/boutons radio de 32 px (copie)
Gravité : P3 · /exercise_sessions/:id · assessment/exercise_sessions/kinds/_choice.html.erb:17, 20 · Description : l'input fait `size-8` (32 px) ; le `<label>` entier (`min-h-tap`) est cliquable, donc la cible réelle est correcte au toucher, mais le focus visible et le clic précis sur la pastille restent à 32 px (WCAG 2.5.8 : OK car label). À confirmer au test mobile 390 px.
Preuve : `class: "peer size-8 cursor-pointer appearance-none ..."` dans un `<label class="flex min-h-tap ...">`.
Proposition : passer à `size-11` ou laisser tel quel en l'attestant par test système.
Effort : S

#### U-E02 — Bouton « Refaire » de l'historique en `size: :sm`, sous 44 px
Gravité : P3 · /home (frame historique) · student_homes/_history.html.erb:36-38 (`BUTTON_SIZES[:sm]`) · Description : bouton de taille sm accolé à une ligne `min-h-tap` ; hauteur probable < 44 px sur 390 px. À confirmer (`BUTTON_SIZES[:sm]` dans components_helper).
Preuve : `class_names(ComponentsHelper::BUTTON_BASE, ComponentsHelper::BUTTON_SIZES[:sm], ...)`.
Proposition : `min-h-tap` sur le bouton ou lien « Refaire » de la ligne.
Effort : S

#### U-E03 — Les lignes de l'historique ne disent pas la médaille ; la couleur verte seule porte le sens
Gravité : P2 · /home, /student/archive · _history.html.erb:31-32 ; _result_row.html.erb:102-105 · Description : vert dès 14/20 vs encre sinon : la couleur distingue sans texte (l'archive ajoute un `sr-only` « 14 sur 20 » mais pas le palier). Pas de trophée visible.
Preuve : `grading.reaches?(..., MASTERY_THRESHOLD) ? "text-success" : "text-ink"`.
Proposition : pastille avec trophée coloré par palier + libellé texte (« Argent ») ; `sr-only` = nom du palier.
Effort : S

#### U-E04 — Contenus « d'aide » en infobulle seule pour expliquer les seuils des badges
Gravité : P3 · résultat · session_results/_badge.html.erb:15 (`ui_info_tip badges_tip`) et show:72 (`stat_info_tip mastery_tip`) · Description : la règle d'obtention d'une médaille n'est lisible qu'en infobulle (tap/hover) ; au téléphone, découverte faible. Aucun prochain palier (« encore 2 points pour l'Argent ») n'est proposé.
Preuve : `<%= ui_info_tip badges_tip, label: t(".help") %>`.
Proposition : afficher « Prochaine médaille : Argent » + n questions justes manquantes, sous le badge.
Effort : M

#### U-E05 — Titre « Interrogation » dans le cartouche, même pour un exercice de « Fixation »
Gravité : P2 · /exercises/:id et /exercise_sessions/:id · exercises/show.html.erb:20 ; exercise_sessions/show.html.erb:28 ; config exercises.fr.yml:19 / exercise_sessions.fr.yml:35 (`exam_kind: "Interrogation"`) · Description : libellé fixe alors que `exercise_types` = Fixation / Évaluation et que le badge de type est affiché juste dessous (exercises/show:26). Un exercice de fixation est présenté comme une interrogation → stress inutile à l'élève.
Preuve : `<span><%= t(".exam_kind") %></span>` constant.
Proposition : cartouche selon `exercise.exercise_type` (« Entraînement » / « Évaluation »).
Effort : S

#### U-E06 — Cartes « traités » : un seul lien étiré, action `aria-hidden`
Gravité : P3 · /student/classroom · assessment/exercises/_card.html.erb:48-53 · Description : l'action « Voir ma copie » est `aria-hidden="true"` ; l'accessibilité repose sur le lien du titre. Acceptable mais la carte lit le titre sans sa médaille/état (`card.status` hors du lien). À confirmer au lecteur d'écran.
Preuve : `<span ... aria-hidden="true"><%= card.action %>`.
Proposition : inclure la médaille dans `aria-label`/`sr-only` du lien.
Effort : S

#### U-E07 — Écrans qui se recoupent : « Ma classe » (traités), « Mon historique », frame Historique d'accueil
Gravité : P3 · /home, /student/classroom, /student/archive · student_homes/_history.html.erb, student_classrooms/show.html.erb:31-43, student_archives/show.html.erb:37-52 · Description : trois listes d'exercices terminés avec trois présentations (ligne 1 jour, carte avec « · Acquis », ligne avec pastille note). L'accueil dit « Voir plus » vers l'archive mais « Ma classe » ré-affiche les mêmes exercices en cartes.
Preuve : `exercise_card_for_treated` vs `_result_row` vs `_history`.
Proposition : un seul composant « exercice terminé + médaille », réutilisé ; dédoublonner « Exercices traités » de Ma classe avec l'archive (ou ne garder que la classe courante).
Effort : M

#### U-E08 — Après « Vérifier ma copie », pas de feedback intermédiaire si le réseau échoue ailleurs que hors-ligne
Gravité : P3 · /exercise_sessions/:id · assessment/copy_controller.js:10-16 · Description : si l'import de `copy_sheet` échoue, `console.warn` seul : plus de brouillon ni confirmation, et l'élève n'en est pas averti (pas de message UI) ; perte de réponses possible si l'appareil est coupé. À confirmer côté `lib/assessment/copy_sheet`.
Preuve : `catch (error) { console.warn("copie : brouillon indisponible", error) }`.
Proposition : afficher le bandeau `offline` (cible déjà prévue) ou une alerte discrète.
Effort : S

#### U-E09 — Message « Une fois ta copie vérifiée, tu ne pourras plus changer tes réponses » après la barre sticky ; avertissement « compteront fausses » négatif
Gravité : P3 · exercise_sessions/show · exercise_sessions.fr.yml:58 (« 3 questions sans réponse compteront fausses ») · Description : formulation punitive qui va à l'inverse d'une maîtrise bienveillante par paliers.
Preuve : `other: "%{count} questions sans réponse compteront fausses."`
Proposition : « Il reste 3 questions sans réponse. Tu peux encore y répondre. »
Effort : S

#### U-E10 — Compteur de copie « 3/10 répondues » sticky : rapport x/y (chiffre) en cours d'exercice
Gravité : P3 · exercise_sessions/show:32 ; locale exercise_sessions.fr.yml:33 · Description : avancement, légitime, mais coexiste avec le barème « · barème : N points » (l.30, locale 42-43) et « (2 points) » par question : l'élève est exposé à des points pendant la copie alors que le résultat n'est censé plus montrer que la médaille.
Preuve : `t(".scale", count: total_points, ...)`.
Proposition : cacher barème et points élève ; garder le compteur de questions répondues.
Effort : S

### Wording

#### W-E01 — « Fiches de cours assignées » contredit ADR-0072 (seuls les exercices s'assignent)
Gravité : P2 · /student/classroom · config/locales/classroom/student_classrooms.fr.yml:8-13 ; app/views/classroom/student_classrooms/_courses.html.erb:1 (« Cours assignés ») · Description : le titre dit que des fiches/cours sont assignés ; le commentaire de la vue et la query disent « ADR-0072 : un cours ne s'assigne plus ». Trois mots pour une chose : cours / fiche de cours / leçon.
Preuve : `courses_title: "Fiches de cours assignées"` ; `# assigned_count : ... (ADR-0072 : un cours ne s'assigne plus)` (student_classroom_query.rb:65).
Proposition : « Leçons de ma classe » (ou « Mes leçons »).
Effort : S

#### W-E02 — « Exercices assignés » (titre) mais cartes « DEVOIR DU … »
Gravité : P3 · /student/classroom · student_classrooms.fr.yml:15, 43 (`assigned_title: "Exercices assignés"`, `title: "DEVOIR DU %{date}"`) · Description : exercice / devoir / feuille / copie / interro (« Prépare interros ») / session selon l'écran ; « DEVOIR » en majuscules en dur dans la clé.
Preuve : `title: "DEVOIR DU %{date}"` (mise en forme dans la valeur).
Proposition : « Devoirs reçus » ; casse via CSS.
Effort : S

#### W-E03 — « Meilleur score » / « Meilleure note » / « Meilleur résultat » + clé morte
Gravité : P3 · student_classrooms.fr.yml:19 (« ton meilleur score »), :40 (`treated_exercise.best: "Meilleur score"`, clé non utilisée : aucun `t(...best)` dans app/views hors exercises/show) ; exercises.fr.yml:36 (« Meilleure note : 16/20 ») ; session_results.fr.yml:96 (« Ton meilleur résultat ») · Description : trois mots pour la même donnée, et « score » est interdit à l'écran par UDR-0058 (note unique).
Preuve : voir lignes citées.
Proposition : « Ta meilleure médaille : Or » partout ; supprimer la clé morte.
Effort : S

#### W-E04 — « Score » et « Note » affichés ensemble côté enseignant/équipe sur la page de l'élève
Gravité : P2 · session_results/show.html.erb:67-70 ; session_results.fr.yml:34-36 (`grade: "Note"`, `score: "Score"`, `score_value: "%{score} %"`) · Description : un pourcentage est encore rendu (« 68 % ») à côté de « 14/20 » pour les lecteurs non propriétaires, contredisant le commentaire du fichier « Aucun pourcentage » (l.102).
Preuve : `<dd ...><%= t(".score_value", score: result.score_percent) %></dd>`.
Proposition : retirer la tuile Score ; médaille + « x/y justes ».
Effort : S

#### W-E05 — Vocabulaire « notion » / « fiche » / « fiche de révision » / « leçon » mêlé sur le même écran
Gravité : P2 · /home, /student/classroom, résultat · student_homes.fr.yml:35-38 (« Relis la fiche », « Revoir la fiche », « Fiche de révision ») ; student_classrooms.fr.yml:21-22 (titre « Notions à revoir » mais commentaire « Fiches à revoir ») ; session_results.fr.yml:104-110 (« Cette notion passe à revoir », « Notion levée ! », « À revoir dans la leçon ») · Description : glossaire : Essential = fiche de révision ; notion/leçon/fiche utilisés indifféremment. « Lacune » (jargon interne) évitée, c'est bien, mais « levée » (« Notion levée ! ») est obscur pour un élève.
Preuve : `lifted: message: "Notion levée !"`.
Proposition : « Notion maîtrisée ! » ; une seule paire de termes élève : « leçon » et « notion ».
Effort : S

#### W-E06 — Pluriel absent : « 1 exercices faits sur 3 »
Gravité : P2 · /home · student_homes.fr.yml:20 (`progress_label: "%{done} exercices faits sur %{total}"`), alors que `progress:` (l.17-19) gère `one/other` · Description : le `aria-label` de la barre n'a pas de forme singulière (`next_step/_progress.html.erb:8` passe `done:` sans `count:`).
Preuve : `label: t("...progress_label", done: step.done_count, total: step.total_count)`.
Proposition : clé avec `count:` et `one/other`.
Effort : S

#### W-E07 — Vouvoiement dans un message envoyé par l'élève (OK) ; mais « vos classes » côté élève sur la page exercice partagée
Gravité : P3 · exercises.fr.yml:25-27 (`assign_targets`, `assign_none`: « vos classes ») · Description : ces clés ne sont affichées qu'aux enseignants (`@targets`), donc cohérent ; à confirmer qu'un élève n'y accède jamais. Le message WhatsApp (student_homes.fr.yml:88) vouvoie légitimement l'enseignant.
Preuve : `assign_none: "Aucune de vos classes n'est en %{level}."`.
Proposition : aucun changement si `@targets` reste réservé enseignant/équipe.
Effort : S

#### W-E08 — Mots « copie », « session », « tentative » mélangés
Gravité : P3 · exercise_sessions.fr.yml:32, 54, 63 (« Copie », « Vérifier ma copie », « Cette session est terminée ») ; exercise_cards.fr.yml:6 (« Voir ma copie ») ; classroom_courses.fr.yml:34 (« copies ratées ») ; student_registrations.fr.yml:73 (« tentatives » = essais de code) · Description : le glossaire fixe « session » (ExerciseSession) et « tentative » (QuestionAttempt) ; l'UI élève utilise surtout « copie ». « tentative » (limite de débit à l'inscription) est un 3e sens.
Preuve : `page_title: "Copie · %{title}"`, `rate_limited: "Trop de tentatives..."`.
Proposition : élève : « copie » uniquement ; remplacer « tentatives » par « essais » à l'inscription ; mettre à jour le glossaire.
Effort : S

#### W-E09 — Jargon « code secret », « PIN », « DRENA » dans l'inscription
Gravité : P3 · student_registrations.fr.yml:10-11, 86, 106 (`drena_name: "DRENA %{name}"`) ; classes nommées `pin_confirmation` en interne · Description : « code secret » est cohérent côté UI ; « DRENA » est un sigle institutionnel non expliqué pour un élève de 6e. À confirmer en parcours.
Preuve : `drena_name: "DRENA %{name}"`.
Proposition : « Direction régionale (DRENA) » en première occurrence.
Effort : S

#### W-E10 — Ton des encouragements d'erreur : « Tu as tapé petit poteau », « Erreur de parcours »
Gravité : P3 · session_results.fr.yml:23-29 (`cheers.error`) · Description : les messages sont choisis par tone success/error = seuil Acquis 14/20 ; un 13/20 reçoit un message d'échec (« Oups ! ») malgré une médaille Bronze/Argent. Avec les médailles, le message doit dépendre du palier (progrès), pas d'un échec binaire.
Preuve : `tone = grading.reaches?(..., MASTERY_THRESHOLD) ? :success : :error` (show:9) ; `cheers[result.session_public_id.sum % cheers.size]`.
Proposition : messages par palier ; une phrase « prochaine médaille ».
Effort : S

### Optimisation

#### O-E01 — `classmates_count` calculé à chaque accueil et jamais affiché
Gravité : P3 · /home · app/infrastructure/queries/classroom/student_home_query.rb:57 (`classmates_count: Orm::ClassroomStudent.where(classroom_id:, left_at: nil).count`) · Description : COUNT lancé sur chaque rendu de l'accueil ; `grep classmates_count app` : seule la définition et ce calcul (aucune vue).
Preuve : `grep -rn classmates_count app` → 2 lignes, toutes dans la query.
Proposition : supprimer le champ et la requête (UDR-0011 : pas de liste nominative).
Effort : S

#### O-E02 — `pending_gaps` + `badges` chargés par l'accueil sans usage ; `pending_gaps` rejoué pour « Ma classe »
Gravité : P3 · /home · student_home_query.rb:58 (`pending_gaps: pending_gaps(student_id:)`), :173 (`badges = Orm::ExerciseBadge.where(...)`) ; student_classroom_query.rb:96 · Description : l'accueil ne lit que `next_step` (via `oldest_review`) et `subjects` ; `Row.pending_gaps`, `assigned_exercises`, `ExerciseRow.badge_level` ne sont pas utilisés dans app/views/classroom/student_homes (grep). Trois requêtes inutiles par ouverture d'accueil. À confirmer qu'aucun test ne les lit seul.
Preuve : `grep "badge_level" app/views` ne trouve que session_results ; `home.pending_gaps` absent des vues.
Proposition : retirer ces champs ; si la médaille doit s'afficher à l'accueil (C-E01), garder `badges` et l'utiliser.
Effort : S

#### O-E03 — `recent_sessions` lit 10 lignes pour n'en montrer que 3
Gravité : P3 · /home (frame Historique) · student_home_query.rb:32, 85 (`RECENT_SESSIONS = 10`) ; _history.html.erb:5, 12, 47 (`shown = 3`, `sessions.size > shown`) · Description : on plombe `StudentAudienceQuery` + 8 lignes pour tester « Voir plus » ; 4 suffisent.
Preuve : `limit(RECENT_SESSIONS)` vs `sessions.first(shown)`.
Proposition : limite 4 (ou `shown + 1`).
Effort : S

#### O-E04 — Niveau de l'élève (`StudentAudienceQuery`) relu par requêtes séparées sur la même navigation
Gravité : P3 · /home puis frame historique · student_home_query.rb:96 ; student_homes_controller.rb:21, 33 · Description : `query.new` à chaque appel (`query = Queries::Classroom::StudentHomeQuery.new`) : `own_level` n'est mémoïsé que par instance ; la page principale et le frame différé le recalculent (2 requêtes minimum). Gain faible mais répété à chaque visite d'accueil.
Preuve : `def query = Queries::Classroom::StudentHomeQuery.new`.
Proposition : mémoïser le niveau en session/cache court, ou le passer en paramètre.
Effort : S

#### O-E05 — `earned_now` = `ExerciseBadge.exists?` par résultat ; progrès + écart = 3 requêtes supplémentaires
Gravité : P3 · /exercise_sessions/:id/result · session_result_query.rb (~l.79 `earned_now: Orm::ExerciseBadge.exists?(...)`, `progress`, `gap_outcome`) · Description : au total ~10-12 requêtes pour un résultat (chaque `pluck` est borné, pas de N+1 constaté). Acceptable ; simple à réduire en joignant.
Preuve : lecture de `call` (l.63-80).
Proposition : joindre `exercise_badges` dans la requête principale ; non prioritaire.
Effort : S

#### O-E06 — Archive : `COUNT` + jusqu'à 200 lignes + pagination purement client
Gravité : P3 · /student/archive · student_archive_query.rb:15, 28, 45-46 ; show:41-49 (`ui_reveal_data(step: 10)`) · Description : 200 lignes sont rendues dans le HTML (masquées par « Voir plus ») ; index couvert (`student_id, completed_at`), pas de N+1. Sur mobile 3G, ~200 lignes de DOM avec `image_tag lazy` par ligne.
Preuve : `RESULTS_LIMIT = 200`.
Proposition : rendre 20-30 puis charger la suite (Turbo Frame paginé) ; avec les médailles, une ligne = un exercice (dernier palier) au lieu d'une session.
Effort : M

#### O-E07 — `treated_exercises` (Ma classe) sans limite ni pagination
Gravité : P3 · /student/classroom · student_classroom_query.rb:127-134 (`DISTINCT ON ... OVER (PARTITION BY ...)` puis `sort_by` Ruby, aucune LIMIT) ; show:36-41 · Description : tous les exercices terminés du niveau sont chargés et rendus en cartes (jusqu'à plusieurs centaines à terme) ; la fenêtre MAX() sur toute la table d'élève.
Preuve : pas de `.limit` ; `ui_reveal_more treated.size` (masquage client).
Proposition : LIMIT 30 + lien vers l'archive ; ou tri SQL.
Effort : S

### Comprehension (vue enseignant dans mon périmètre : classement et chiffres)

#### C-E07 — Rapport de compréhension : classement des élèves par score, pourcentages en barres, cases en nombre
Gravité : P2 · /classrooms/:id/assignments/:id (enseignant) · assessment/comprehension/_section.html.erb:2 (« du meilleur score au plus faible »), :55-63 (barre `svg width="<%= question.rate %>%"` + « 18 / 20 justes »), :18-19 (« 20 / 27 faits ») ; comprehension_detail_query.rb:93 (`sort_by { |row, rank| [ -row.best, rank ] }`) ; comprehension_helper.rb:87 (« 🏆 16/20 ») · Description : liste classée par score, taux de réussite par question en barre %, pastille élève avec note /20. Contraire de la maîtrise par médaille et expose un classement.
Preuve : `.each_with_index.sort_by { |row, rank| [ -row.best, rank ] }`.
Proposition : tri par palier (puis alphabétique pour ne pas classer), pastille = trophée seul, barre par question → « à revoir »/« maîtrisée » (3 états) ; compteur « faits » conservé (assiduité, pas note).
Effort : M

#### U-E11 — `done_ratio` « 18/25 » pour la catégorie dominante (cercle)
Gravité : P3 · assessment/comprehension/_circle.html.erb:5-9 ; comprehension.fr.yml:17 (`done_ratio: "%{done}/%{present}"`) · Description : ratio en chiffres pour une catégorie ; remplaçable par une médaille. Utilisé par la page classe (petit format).
Preuve : `<%= comprehension_label(category) %> · <span class="tabular-nums"><%= ratio %>`.
Proposition : « 18 élèves sur 25 en Argent ou mieux ».
Effort : S

#### U-E12 — Pas d'état de chargement/erreur du frame Historique
Gravité : P3 · /home · student_homes/_history.html.erb:6 (`turbo_frame_tag ..., target: "_top"`) et show.html.erb (frame différé) · Description : si la requête du frame échoue (réseau), Turbo affiche « Content missing » sans message ni réessai ; pas d'indicateur de chargement visible dans le partial (squelette absent). À confirmer dans show.html.erb (frame lazy).
Preuve : partial sans état `loading`/`aria-busy`.
Proposition : placeholder + message « Impossible de charger ton historique. Réessayer ».
Effort : S

## Constats — Enseignant

Périmètre lu : classroom/{teacher_homes, classrooms, classroom_students, assignments, assignment_follow_ups}, assessment/comprehension (rapport d'un exercice assigné), identity (referrals, profile_materials, teacher_registrations), school (teacher_schools), locales classroom/identity/assessment, queries TeacherHome/TeacherFollowUps/ClassroomOverview/StudentFile/AssignmentFollowUp/ComprehensionDetail/AssignmentScores, db/schema.rb. UDR lues : 0007, 0026, 0131, 0134. Les écrans `school/*` (level_classrooms, drena_schools) sont côté élève/inscription : hors enseignant, un seul relevé (teacher_schools).

Constat structurel : l'enseignant lit déjà des médailles (cases Bronze/Argent/Or/Diamant, pastille de classe), mais chacune est **accompagnée d'une note /20 ou d'un % ou d'une moyenne**, et deux règles de médaille différentes coexistent (par exercice vs par classe).

### O-T — Médailles à la place des notes / scores

#### O-T01 — Pastille de l'élève dans la liste de classe : « Moyenne 15/20 · Or »
Gravité P1 · Enseignant, page d'une classe `/classrooms/:id` · `app/views/classroom/classrooms/_roster.html.erb:104` et `:107` ; `config/locales/classroom/classrooms.fr.yml` (`badge_grade`, `average_none` : « Moyenne %{grade}/20 · %{badge} ») · Description : le badge n'est jamais seul, il porte la moyenne /20. Sous le Bronze la pastille dit « Moyenne 7/20 · Non acquis/Pas encore » (chiffre de la faiblesse, en toutes lettres).
Preuve : `t(".badge_grade", badge: badge_label(student.badge), grade: student.grade)` ; `t(".average_none", grade: student.grade, badge: comprehension_box_label(:none))`.
Proposition : afficher la médaille seule (trophée + « Or ») ; sous le seuil, un état neutre « À consolider » sans chiffre. La note reste dans l'infobulle/fiche si elle doit survivre.
Effort S

#### O-T02 — « Dernier score » en pourcentage dans la liste de classe
Gravité P1 · même écran · `_roster.html.erb:62-66,122-124` ; locale `last_score`, `last_score_tip` (« en pourcentage de bonnes réponses ») · Description : colonne « Dernier score » = `84 %`, brut, à côté d'une note /20 dans la pastille voisine : deux échelles sur la même ligne, et c'est le seul % de l'écran (ADR-0106/UDR-0131 : « ce que l'élève lit fait foi », sur 20). C'est aussi le score de n'importe quelle session (standard, fait seul, remédiation), pas celui du devoir.
Preuve : `<%= student.last_score_percent %> %`.
Proposition : remplacer par la médaille de la dernière session (`Grading.badge_for(last_score_percent)`) + lien « Voir le résultat ». Supprimer le mot « score ».
Effort S

#### O-T03 — Fiche élève : pastille « Moyenne 14/20 · Or » et note /20 sur chaque exercice
Gravité P1 · `/classrooms/:id/students/:id` · `app/views/classroom/classroom_students/_summary.html.erb:14-18` (`student_file_average`) et `_assignments.html.erb:28-33` (`grade_label(assignment.best)` dans la pastille) · Description : le résumé affiche la moyenne puis des pastilles de badges comptées par exercice ; chaque ligne d'exercice affiche « 14/20 » avec le trophée.
Preuve : `t(".average", grade: file.class_grade, badge: …)` ; `<%= grade_label(assignment.best) %>`.
Proposition : ligne d'exercice = médaille + libellé (« Argent ») ; le chiffre disparaît. Résumé = « 3 exercices : Or ×1, Argent ×2 » sans moyenne.
Effort S

#### O-T04 — Rapport d'un exercice : pastille « 🏆 16/20 » par élève et classement par meilleur score
Gravité P1 · `/classrooms/:id/assignments/:id` · `app/helpers/assessment/comprehension_helper.rb:83-88` (`comprehension_grade_badge`), `app/infrastructure/queries/assessment/comprehension_detail_query.rb:93` (`sort_by { [-row.best, rank] }`), en-tête `_section.html.erb:3` (« du meilleur score au plus faible ») · Description : la liste « Élèves » est un classement par score, chaque ligne montre la note /20 à côté du trophée. Contraire à l'esprit « maîtrise » (pas de palmarès, pas de chiffre).
Preuve : `tag.span(t("assessment.badges.grade", grade: student.grade), class: "text-ink tabular-nums")`.
Proposition : grouper par médaille (les cases-filtres existent déjà), tri alphabétique dans le groupe, pastille = médaille seule. Retirer `grade`/`best` de `StudentRow` côté vue.
Effort M

#### O-T05 — « Copies rendues » : 1re copie et meilleure note de chaque élève (doublon + notes)
Gravité P1 · `/classrooms/:id/assignments/:id` · `app/views/classroom/assignment_follow_ups/show.html.erb:44-58` ; locale `assignment_follow_ups.fr.yml:11-12` (« 1re copie %{first} · meilleure note %{best} ») ; `AssignmentFollowUpQuery#copies` (`assignment_follow_up_query.rb:99-109`) · Description : liste de tous les élèves avec deux notes /20, placée au-dessus de la section « Élèves » qui liste déjà les mêmes élèves avec leur meilleure note. Doublon d'écran + notes + mot « copie » hors glossaire (voir W-T03).
Preuve : `grade_label(copy.first_score)` / `grade_label(copy.best_score)`.
Proposition : supprimer le bloc ; reporter « 1re médaille → médaille actuelle » (ex. Bronze → Or) dans la ligne de la section « Élèves » (trend déjà calculé par `Comprehension.trend_for`).
Effort S

#### O-T06 — Historique de l'accueil : « Moyenne de la classe » /20 en vert
Gravité P1 · Accueil `/teacher` · `app/views/classroom/teacher_homes/_history.html.erb:33-39` ; `TeacherFollowUpsQuery` (`teacher_follow_ups_query.rb:42`, `average_percent`) ; locale `history.average` « %{grade}/20 » · Description : chaque assignation échue montre une moyenne de classe chiffrée, colorée vert dès 14/20 (couleur = jugement).
Preuve : `grading.reaches?(row.average_percent, grading::MASTERY_THRESHOLD) ? "text-success" : "text-ink"`.
Proposition : remplacer par la répartition médaillée (ex. quatre mini-trophées avec compte, comme la carte de classe) ou la médaille dominante ; supprimer `average_percent` de `Row`.
Effort M

#### O-T07 — Fait seul (fiche élève) : score en %
Gravité P2 · `/classrooms/:id/students/:id` · `app/views/classroom/classroom_students/_self_practice.html.erb:26` · Preuve : `number_to_percentage(row.score_percent, precision: 0, format: "%n %")`. Description : seul endroit de la fiche en %, alors que les devoirs voisins sont en /20 (incohérence d'échelle). Proposition : médaille de la session (ou « Pas encore ») + « Voir le résultat ». Effort S

#### O-T08 — Infobulles de seuils chiffrés (Bronze dès 10/20…) vues par l'enseignant
Gravité P3 · `config/locales/shared/layouts.fr.yml:27-28`, `BadgesHelper#badges_tip/mastery_tip` (`badges_helper.rb:24-35`) · Description : l'aide « Badge » et « Maîtrise » explique les médailles par des notes /20. Garder pour la transparence des critères, mais c'est le dernier endroit à convertir (« Bronze : plus de la moitié juste… ») une fois les notes retirées partout. Effort S

#### O-T09 — Requêtes qui n'existent que pour porter la note (à purger après bascule)
Gravité P3 · `RosterGrade` (`app/domain/entities/classroom/roster_grade.rb`, groupes 0-10/11-15/16-20 + `UNGRADED`) ; `ClassroomOverviewQuery::StudentRow(:grade,:last_score_percent)` (`classroom_overview_query.rb:28`) ; `StudentFileQuery(:class_grade)` · Description : `RosterGrade::GROUPS` n'est plus utilisé par l'UI (la liste filtre par badge, `BADGE_FILTERS`) mais reste dans le domaine : code mort ou à vérifier (à confirmer par grep des appelants). Effort S

### U-T — UI / UX

#### U-T01 — Deux règles de médaille sur la même fiche élève
Gravité P1 · `/classrooms/:id/students/:id` · `_summary.html.erb:14-23` (pastille de classe « Moyenne · Or » = `Grading.class_badge_for` sur la **moyenne**) et pastilles « Or 2 · Argent 1 » (= `badge_for` du **meilleur score de chaque exercice**, `student_file_query.rb` `badge_counts`) · Description : un élève peut avoir « Bronze » en classe (moyenne) et « Or 2 » (exercices) sur la même ligne. Même vocabulaire, deux sens (voir C-T01).
Preuve : `student_file_query.rb:6` « la moyenne … et le badge de classe qu'elle donne » vs `badge_counts`: « un palier par exercice fait ».
Proposition : une seule médaille « de maîtrise de la classe » (ex. médaille la plus basse des exercices ou majorité) ou ne montrer que la répartition par exercice. Décision métier à porter.
Effort M

#### U-T02 — Retirer un exercice de la classe sans confirmation ni annulation
Gravité P2 · fiche exercice, catalogue, page classe `/courses/...` · `app/views/classroom/assignments/_toggle.html.erb:74-77` (`button_to … archive_assignment_path … method: :patch`, aucun `turbo_confirm`) ; `archive.turbo_stream.erb:10` (toast seul) · Description : un ✕ de 48 px à côté de « Assigné » retire l'assignation ; le suivi disparaît (`ComprehensionDetailQuery` n'accepte que `status: "active"`, → 404). Aucun « Annuler » dans le toast.
Proposition : toast avec « Annuler » (réassigner), ou confirmation légère quand des élèves ont déjà rendu. À confirmer : réversibilité réelle côté use case.
Effort M

#### U-T03 — Cibles tactiles < 44 px sur les liens de résultat
Gravité P2 · `_roster.html.erb:125-127` (« Voir le résultat », `block text-xs`, sans padding ≈ 16 px), `_self_practice.html.erb:27-28` (`py-1 text-xs` ≈ 24 px), `_assignments.html.erb:53-54` (« Voir la meilleure session », `py-1 text-xs`), `comprehension_helper.rb:68` (nom d'élève `py-1` ≈ 32 px) · Description : cibles sous 44 px sur mobile ; dans la liste de classe le lien est de plus caché sous `sm:` (`hidden … sm:block`) donc **absent à 390 px** (voir U-T04).
Proposition : `min-h-11 inline-flex items-center` ou étendre le lien à la ligne (`after:absolute after:inset-0`, déjà utilisé sur l'accueil).
Effort S

#### U-T04 — À 390 px, la liste de classe perd « Fait seul » et « Dernier score »
Gravité P2 · `_roster.html.erb:116-127` (`hidden … sm:block`) ; commentaire ligne 114 (« au téléphone, … ») vs classes réelles · Description : le commentaire promet « une ligne sous le nom » au téléphone mais `hidden` masque ces deux cellules sous 640 px ; le lien « Voir le résultat » devient inaccessible sur mobile (la décision du porteur 2026-09-27 « le score mène au résultat » n'est plus tenue en mobile). Les en-têtes de colonnes (l.62-67) sont aussi `hidden sm:flex`. À confirmer visuellement (captures 390 px requises par CLAUDE.md).
Proposition : sur mobile, afficher la médaille de la dernière session cliquable sous le nom.
Effort S

#### U-T05 — Cases de médailles du rapport à 390 px (5 colonnes)
Gravité P3 · `_badge_boxes.html.erb:19,26` (`grid-cols-5 gap-2`, `px-1`) · Description : ≈ 62 px par case à 390 px ; « Pas encore » (text-xs) et « Diamant » risquent de passer à la ligne ou d'être tronqués. À confirmer en capture. Proposition : `grid-cols-3` + 2 lignes, ou libellés courts. Effort S

#### U-T06 — « Voir plus » en JS seulement sur l'accueil
Gravité P3 · `components_helper.rb:509-517` (`ui_reveal_more`, bouton `reveal#more`) · Description : sans JavaScript les lignes au-delà de la 3ᵉ sont présentes mais le bouton ne fait rien (à confirmer : le contrôleur `reveal` masque-t-il côté serveur ou côté client ?). Pas d'état d'erreur si le reveal échoue. Effort S

#### U-T07 — Pas d'état de chargement sur l'accueil enseignant / rapport
Gravité P3 · `teacher_homes/show.html.erb`, `assignment_follow_ups/show.html.erb` · Description : pages pleines rendues serveur avec 5-8 requêtes agrégées ; pas de skeleton, acceptable. En revanche le frame `comprehension_frame` (filtre par case) a `aria-busy:opacity-50` mais **aucun état d'erreur** si la requête échoue (contrairement à la recherche de la liste de classe qui a `template[data-search-target="error"]`, `_roster.html.erb:35`). Proposition : même gabarit d'erreur. Effort S

#### U-T08 — Doublons d'écrans pour le suivi par élève
Gravité P3 · trois lectures de la note d'un élève : liste de classe (`_roster`), liste « Élèves » du rapport (`_student_row`), fiche élève (`_assignments`) + « Copies rendues » (O-T05). Chacune recalcule meilleur score / badge / tendance. Proposition : une seule pastille partagée (`ui_medal(level)`) pour les trois, une fois les notes retirées. Effort M

#### U-T09 — Pastille du badge « Pas encore » : même mot, trois significations
Gravité P2 · `config/locales/assessment/comprehension.fr.yml:24` (`badge_none: "Pas encore"`), `follow_ups.pending: "%{count} pas encore"` (non fait), `student.pending: "Pas encore fait"`, `badges.levels.none: "Non acquis"` · Description : dans le rapport, la case « Pas encore » compte des élèves **qui ont fait** l'exercice mais sont sous le Bronze ; juste à côté, « Pas encore fait » désigne ceux qui ne l'ont pas rendu, et « 7 pas encore » sur l'accueil désigne les non rendus. Un enseignant lit « 3 élèves Pas encore » sans savoir s'ils ont composé.
Proposition : renommer la case « Bronze non atteint » / « À consolider » (médaille vide) et réserver « Pas encore » au non rendu.
Effort S

### W-T — Wording

#### W-T01 — Tutoiement dans un message adressé à l'enseignant
Gravité P2 · Sélecteur de devoir du catalogue (`app/views/catalog/courses/sheets/_batch_bar.html.erb:13`) · `config/locales/classroom/assignments.fr.yml:66` · Preuve : `invalid_count: "Choisis entre 1 et 10 exercices."` · Reste de l'espace enseignant au vouvoiement (« Choisissez vos matières », « Videz la sélection », ligne 68). Proposition : « Choisissez entre 1 et 10 exercices. » Effort S

#### W-T02 — « Moyenne » : mot déconseillé par l'UDR-0007, utilisé 4 fois
Gravité P2 · `config/locales/classroom/classrooms.fr.yml` (`badge_grade`, `average_none`), `classroom_students.fr.yml:22` (`summary.average`), `teacher_homes.fr.yml:32` (`average_label`) · Description : UDR-0007 §tableau (l.46) liste « Moyenne » parmi les termes à ne pas employer pour Score/Note ; un commentaire du roster invoque un amendement du 2026-10-29 (à confirmer). Avec la bascule médaille, ces libellés disparaissent (voir O-T01/O-T03/O-T06). Effort S

#### W-T03 — « Copie » / « 1re copie » / « meilleure note » hors glossaire
Gravité P3 · `assignment_follow_ups.fr.yml:11-12` ; le glossaire impose « session » (UDR-0007, `docs/guide/glossaire.md:94`) et le lien voisin dit « Voir la meilleure session » (`classroom_students.fr.yml` `best_session`) · Description : trois mots pour la même chose (copie, session, exercice) sur le parcours rapport → fiche. Effort S

#### W-T04 — Vocabulaire maîtrise/compétence mélangé dans l'aide enseignant
Gravité P3 · `comprehension.fr.yml` : titre de section « Compréhension » (`section.title`), catégories « En difficulté / Fragile / Acquis » (`categories`), tendances « En progrès / Stagne » (`trends`), médailles « Bronze… » ; les catégories ne s'affichent plus qu'au prochain geste ; `categories.unreadable` « Pas encore lisible » (4ᵉ « pas encore »). Proposition : un seul champ lexical : maîtrise = médaille. Voir C-T02. Effort M

#### W-T05 — Libellé générique « Compréhension » vs « Suivi »
Gravité P3 · l'écran s'appelle « suivi » (`FollowAssignmentPolicy`, `assignment_follow_ups`, bouton « Suivre » `exercise_cards.card.follow`), la section « Compréhension », le toast « Retirer … de la classe ». Proposition : « Suivi » partout côté enseignant. Effort S

#### W-T06 — Chaîne en dur non traduite
Gravité P3 · `app/views/identity/teacher_registrations/new.html.erb:68` · Preuve : `<section aria-label="Lnclass" …>` (règle d'or I18n `t(".key")`). Marque : acceptable, mais à passer en clé pour la cohérence. Effort S

#### W-T07 — Messages de parrainage en tutoiement (à confirmer)
Gravité P3 · `config/locales/identity/referrals.fr.yml:24,35` (« Inscris-toi comme enseignant… »). Message partagé par un enseignant à un collègue : tutoiement plausible, mais en rupture avec le vouvoiement de l'espace ; à confirmer par le porteur. Effort S

### C-T — Contradictions / mélanges conceptuels

#### C-T01 — « Badge » désigne deux calculs (exercice vs classe)
Gravité P1 · `Grading.badge_for` (meilleur score d'un exercice, glossaire `ExerciseBadge` « un badge par élève et par exercice ») vs `Grading.class_badge_for` (`grading.rb`, moyenne des meilleurs scores, **Diamant dès qu'un seul exercice fait et sans faute**) · Description : la pastille de liste/carte d'accueil (`teacher_homes/_classroom_card.html.erb:12-19`, `TeacherHomeQuery#badge_counts`) utilise la règle « classe » et la case de rapport la règle « exercice », avec les mêmes noms/icônes. Un élève ayant 1 seul exercice parfait est « Diamant » en classe alors qu'il a manqué les 5 autres non faits. Le glossaire ne définit que le badge d'exercice.
Proposition : définir en ADR la « médaille de maîtrise d'un élève dans la classe » (ex. plus bas palier atteint sur les exercices requis, ou % d'exercices à Or+) ; ajouter au glossaire. Décision irréversible côté produit : à poser au porteur.
Effort M

#### C-T02 — Trois couches parallèles : médaille, catégorie de maîtrise, tendance
Gravité P2 · médaille (`Grading.badge_for`), maîtrise Acquis/Fragile/En difficulté (`Grading.mastery_for`, `Comprehension.category_for`), tendance (`trend_for`), plus la note /20 · seuils quasi identiques (Argent = Acquis = 14/20 ; Bronze = « Fragile » = 10/20) : deux libellés pour le même palier (`BadgesHelper#mastery_tip` vs `badges_tip`). Côté enseignant, `Comprehension.category_for` n'alimente plus que `NextStep` et les partiels morts (C-T03). Proposition : faire de la médaille l'unique échelle et dériver le « prochain geste » de la répartition des médailles. Effort M

#### C-T03 — Code mort lié à l'ancienne lecture « cercle de catégorie »
Gravité P3 · `app/views/assessment/comprehension/_circle.html.erb` et `_badge_counts.html.erb` (jamais rendus : `grep render` ne trouve que `badge_boxes`), `ComprehensionHelper#comprehension_label/dot_class/soft_class` (seul appelant : `_circle`), locale `comprehension.categories`, `done_ratio`, `badge_count`, `badge_none`(partiel) · à confirmer par la CI (tests de vue éventuels). Effort S

#### C-T04 — Compteurs « fait » ≠ « médaille » dans la même ligne (progression vs maîtrise)
Gravité P3 · `_roster.html.erb:92-95` « 9 faits sur 18 · 1 en retard » (progression) à côté de la pastille de maîtrise : deux informations proches, la première en texte, la seconde en pastille ; la barre `ui_progress` n'existe qu'à l'accueil et dans le rapport. Proposition : barre de progression + médaille sur chaque ligne, même gabarit. Effort S

### P-T — Performance (pas de N+1 trouvé ; points à surveiller)

#### P-T01 — Rang de toute la classe recalculé à chaque recherche/page de la liste
Gravité P2 · `classroom_overview_query.rb:105-132` (`roster` → `standings` → `AssignmentScores.for` sur **toutes** les assignations actives × tous les élèves, y compris à chaque frappe de « Chercher un élève », `data-action="search#queue"`) · Description : calcul en mémoire (`it.scores.max`) pour toute la classe pour n'afficher 30 lignes ; reste constant en nombre de requêtes (2-3) mais O(élèves × exercices) à chaque requête. Proposition : ne calculer `standings` que si filtre badge actif ou pour les `student_id` de la page (la liste est ordonnée par nom/arrivée, pas par rang) ; mettre en cache court (clé : max(completed_at) de la classe). À confirmer par mesure sur 250 élèves × 40 exercices. Effort M

#### P-T02 — `members.count { … }` quadratique et IN géant sur l'accueil
Gravité P3 · `teacher_home_query.rb:44,49,72-73` : `members.count { it.first == id }` par classe (O(classes × élèves)) et `student_id IN (tous les élèves)` + `classroom_id IN (…)`. Proposition : `members.group_by(&:first).transform_values(&:size)` ; joindre `classroom_students` côté SQL. Effort S

#### P-T03 — Questions recalculées deux fois quand une case est filtrée
Gravité P3 · `comprehension_detail_query.rb:54-55` (`questions(exercise_id, members)` puis `questions(exercise_id, scores)` si `selected`) : 2 lectures de `questions` + `question_attempts`. Proposition : charger `Orm::Question` une fois et ne refaire que les tentatives. Effort S

#### P-T04 — Index
Gravité P3 (info, rien de manquant bloquant) · `db/schema.rb:355-363` : `exercise_sessions` a `(classroom_assignment_id, student_id) WHERE completed INCLUDE score_percent` (couvre `AssignmentScores`, `best_scores`) et `(student_id, completed_at)` (couvre `last_sessions` DISTINCT ON). `classroom_students` : unique `(classroom_id, student_id)` mais pas d'index partiel `left_at IS NULL` sur `classroom_id` : le filtre « présent » se fait sur l'index complet (acceptable aux volumes visés, à confirmer par `EXPLAIN`). Effort S

## Constats — École / direction (et parent)

Périmètre lu : app/views/school_admin (toutes), shared/*, layouts, components, identity (school_staff_registrations, invitations, sessions, second_factor_enrollments, profiles), locales school_admin/shared, StudentWorkQuery, DirectionHomeQuery, SchoolActivityQuery, contrôleurs school_admin. Non vérifié : rendu réel (contraste, 390 px), EXPLAIN des requêtes.

Rôle PARENT : aucune trace d'écran ou de rôle parent dans l'UI, les contrôleurs, les helpers de navigation (ROLE_ACCENTS / NAV : student, teacher, team, school_admin) ni le schéma. Seules mentions : texte légal / commerce (`communication/pages/sales_terms.fr.yml:18` « payé par l'élève ou par son parent », `:32` Wave ; `privacy.fr.yml:91`), `identity/deletion_request_input.rb:2` et `cancel_deletion_request.rb:2` (« l'élève ou son parent » demande la suppression au support, config/locales/teams/account_deletions.fr.yml:21). Cohérent avec le glossaire (docs/guide/glossaire.md:27 « Le rôle parent n'existe pas ») : le « parent » est un interlocuteur du support, pas un compte. Voir C-S06 pour les CGU.

---

### O-S — Optimisations

#### O-S01 — Page classe direction : requête lourde juste pour lister des slugs
Gravité P2 · Rôle direction · `/school_admin/classrooms/:id` · app/controllers/school_admin/classrooms_controller.rb:31-34
Description : `gaps` appelle `ClassroomOverviewQuery#call` (vue complète de la classe côté enseignant) uniquement pour `courses.map(&:slug)`, puis `ClassroomGapsQuery`. S'ajoute à `StudentWorkQuery#classroom` (4 requêtes agrégées). La recherche `q` ne filtre qu'en mémoire, mais chaque frappe fait un GET de la page entière (`search#queue`) : `gaps` et `classroom` sont donc rejoués à chaque fois.
Preuve : `courses = Queries::Classroom::ClassroomOverviewQuery.new.call(public_id:, show_roster: false).courses` ; `data: { turbo_frame: "student_work_students", controller: "search" }` (show.html.erb:52).
Proposition : (a) requête dédiée « slugs des cours affichés » ; (b) pour le frame de recherche, ne pas rejouer `gaps` ni `@detail.link` (court-circuiter si `turbo_frame_request?`). À confirmer par mesure (EXPLAIN / logs).
Effort M

#### O-S02 — Accueil direction : chiffres gardés 5 min, sans invalidation
Gravité P3 · direction · `/school_admin/classrooms` · app/infrastructure/queries/school/direction_home_query.rb:15
Description : `CACHE_TTL = 5.minutes` sans invalidation fine. Après « + classe », rattachement d'un enseignant ou retrait, l'accueil (alertes « classe sans enseignant », bulles) reste faux jusqu'à 5 min, alors que la page Établissement est à jour. Choix assumé (ADR-0065), à noter comme risque de confusion (« j'ai ajouté, rien ne change »).
Preuve : `@cache.fetch(key, expires_in: CACHE_TTL)`.
Proposition : invalider la clé (`school_id/year/today`) dans les use cases de structure, ou afficher « mis à jour à HH:MM ».
Effort S

#### O-S03 — Activité récente : les erreurs hors AR remontent, retry pleine page
Gravité P3 · direction · frame différé accueil · app/views/school_admin/activities/_activity.html.erb:12 / app/controllers/school_admin/activities_controller.rb:16-20
Description : l'état d'erreur a `retry_href: school_admin_classrooms_path` avec `target: "_top"` : « Réessayer » recharge TOUTE la page (et ses requêtes de cache) au lieu de recharger seulement le frame. Le 503 est rendu dans un frame Turbo : OK, mais le retry est lourd.
Preuve : `ui_error_state retry_href: school_admin_classrooms_path`.
Proposition : retry vers `school_admin_activity_path` avec `target: "direction_home_activity_feed"`.
Effort S

#### O-S04 — Polices / logo : image du logo répétée sans dimensions intrinsèques
Gravité P3 · tous rôles · app/views/shared/navigation/_header.html.erb:17,34,55 ; school_staff_registrations/new.html.erb:10,21 ; invitations/show.html.erb:123,134
Description : `image_tag brand_logo, alt: "", class: "size-9 …"` sans `width`/`height` : la taille ne vient que de la classe CSS (risque de décalage avant CSS, en pratique faible puisque la feuille est dans `<head>`). Le logo source est un `.jpeg` (layouts/application.html.erb:31 « lnclass.jpeg ») redimensionné à 36/56/64 px : poids probable > nécessaire. À confirmer (taille du fichier).
Proposition : `width: 36, height: 36` + variante 2x ; vérifier le poids de `brand_logo`.
Effort S

#### O-S05 — Index : rien de bloquant trouvé (constat négatif vérifié)
Gravité P3 (info) · db/schema.rb:355-357,969,1047-1048
Description : les agrégats de la direction sont couverts : `index_exercise_sessions_handed_in` (partiel, INCLUDE score_percent), `index_teacher_classrooms_on_classroom_id`, index trigramme sur `users` (recherche élève). Les requêtes de StudentWorkQuery sont en nombre fixe (pas de N+1) : `classroom_rows` = 4 requêtes. Rien à corriger ; ne pas casser en passant à la médaille (voir Médailles : une nouvelle agrégation par médaille doit lire `exercise_badges` avec index unique `(student_id, exercise_id)` et joindre aux élèves présents, comme `handed`).

---

### U-S — UI/UX

#### U-S01 — Pastille de signal : couleur seule sur la carte classe/niveau
Gravité P2 · direction · `/school_admin/levels/:slug`, accueil bulles · app/views/school_admin/levels/_classroom_card.html.erb:15-16 ; _levels.html.erb:50
Description : le taux de rendu est dit par un point vert/jaune/rouge `aria-hidden`, doublé d'un texte `sr-only` seulement. Un voyant daltonien ne distingue pas rouge/vert sans lire la légende (tout en bas de page, `_signal_legend`). Le chiffre « Taux de rendu : 62 % » est affiché sur la carte classe (L37) mais pas sur la bulle de l'accueil.
Preuve : `tag.span(class: [ "absolute -top-0.5 -right-0.5 size-3.5 rounded-full ring-2 ring-white", SIGNAL_DOTS…]), "aria-hidden": true) if signal`.
Proposition : forme/icône différente par niveau (✓ / ! / ✕) ou texte court visible ; légende près des bulles (déjà là sur l'accueil, L62-64). Disparaît si le signal devient une médaille (forme + nom).
Effort S

#### U-S02 — Retrait d'un élève depuis la direction : formulaire vide dans une modale par ligne
Gravité P3 · direction · `/school_admin/classrooms/:id` · app/views/school_admin/classrooms/show.html.erb:118-128
Description : une `<dialog>` complète est rendue par élève (classe de 40 élèves = 40 modales + formulaires dans le HTML) ; le formulaire de suppression est vide (`do %><% end %>`) et relié par `form:`. Poids HTML et DOM inutiles ; `teachers/index` a déjà corrigé ce point (confirmation chargée à la demande, ADR-0067).
Preuve : `ui_modal title: t("#{roster}.remove_title"…) … form_with … method: :delete … do %>\n<% end %>` dans la boucle `@students.each`.
Proposition : même motif que `teacher_removal` (frame « modal » à la demande).
Effort M

#### U-S03 — Doublon : trois « premier du mois » et deux styles de retour
Gravité P3 · direction · app/views/school_admin/classrooms/index.html.erb:10 ; departed_teachers/index.html.erb:26-27 ; shared/_school_staff_row.html.erb:24
Description : la même lambda `date.day == 1 ? "1er …" : l(date, format: :long)` est copiée 3 fois. Par ailleurs `departed_teachers/index.html.erb:6-7` et `teachers/removal.html.erb:10-11` écrivent à la main un lien « retour » (`link_to … class: "mb-4 inline-flex min-h-tap …"`) alors que `ui_page_header back:` existe et est utilisé ailleurs (departed_students L75, levels/show L12, student_searches L6).
Preuve : voir lignes.
Proposition : helper `ui_long_date(time)` ; `ui_page_header back:` partout (sauf removal en page complète sans frame).
Effort S

#### U-S04 — Lambda de formatage du pourcentage copiée 3 fois
Gravité P3 · direction · levels/_classroom_card.html.erb:5-9 ; classrooms/show.html.erb:8-12 ; departed_students/index.html.erb:70-74
Description : `percent`/`figure` (valeur ou « — » + « non calculé » sr-only) copié trois fois, avec des rendus différents (span `font-medium` dans la carte, texte nu ailleurs). À la bascule médaille, trois endroits à changer.
Proposition : helper unique `ui_mastery_figure(value)` (ou partial) → point de bascule unique vers la médaille.
Effort S

#### U-S05 — Classe « sans élève » / « sans donnée » : état vide partiellement explicatif
Gravité P3 · direction · classrooms/show.html.erb:46-47, 135-138
Description : le « — » est expliqué par une légende discrète en bas de liste (`text-xs`) et une infobulle ; sur les trois tuiles du haut (L27-40), un « — » seul ne dit pas qu'il faut 5 élèves ayant rendu (seulement dans l'infobulle `tips.missing`). Un directeur qui voit « Moyenne — » ne sait pas pourquoi.
Preuve : `average: "… Elle s'affiche à partir de 5 élèves ayant rendu un devoir."` (classrooms.fr.yml:12) mais seulement au clic de l'infobulle.
Proposition : sous-texte visible « à partir de 5 élèves » dans la tuile vide.
Effort S

#### U-S06 — Barre basse direction : 4 destinations dont « Annonces » en lecture seule
Gravité P3 · direction mobile · app/helpers/navigation_helper.rb:32-33
Description : la direction a 4 entrées (Accueil, Enseignants, Établissement, Annonces). L'accueil affiche déjà le carrousel d'annonces (classrooms/index L22-24) sans croix, et « Annonces » est une page de plus pour un rôle en lecture seule : doublon d'écran. À confirmer avec le porteur (UDR-0071/0074 le décident).
Proposition : garder, mais vérifier que la page est utile (liste complète) ; sinon la retirer de la barre.
Effort S

#### U-S07 — Mode sombre de la direction introuvable sur mobile
Gravité P3 · direction <lg · app/views/shared/navigation/_header.html.erb:54 ; identity/profiles/show.html.erb:31
Description : l'interrupteur d'en-tête est `max-lg:hidden` ; sur téléphone il n'est que dans « Mon profil » (carte « Apparence », en bas). Deux clics + scroll depuis l'avatar. Découvrabilité faible.
Proposition : entrée « Mode sombre » dans le menu avatar (comme l'enseignant, ACCOUNT_PANELS).
Effort S

#### U-S08 — Formulaires d'inscription/connexion : pas de retour de soumission homogène
Gravité P3 · identity · identity/invitations/show.html.erb:209 ; identity/sessions/new.html.erb (submit sans `turbo_submits_with`) vs school_staff_registrations/_form.html.erb:110 (avec `turbo_submits_with: t(".submitting")`)
Description : l'inscription direction désactive/relabellise le bouton à l'envoi, pas l'acceptation d'invitation ni la connexion : double envoi possible et aucun feedback sur réseau lent (usage en Côte d'Ivoire, 3G).
Preuve : `ui_button t(".submit"), type: :submit, variant: :brand, size: :lg, full: true` (invitations L209) sans `data: { turbo_submits_with }`.
Proposition : ajouter `turbo_submits_with` aux trois (ou dans `ui_button` quand `type: :submit`).
Effort S

#### U-S09 — Duplication des deux écrans d'accueil auth (invitation / inscription direction)
Gravité P3 · identity · school_staff_registrations/new.html.erb:5-48 et invitations/show.html.erb:118-214 (+ le fieldset « genre » dupliqué : _form L65-84 ≈ invitations L169-188)
Description : même gabarit 2 colonnes, même bloc genre (radio) recopié, mêmes classes. Risque de divergence (a11y : `aria-describedby` du genre identique aujourd'hui).
Proposition : partial `identity/_gender_fieldset` + layout `auth_two_columns` ; il existe déjà `shared/_auth_welcome`.
Effort M

#### U-S10 — Rang « vie scolaire » : gestes cachés, explication en note discrète
Gravité P3 · direction · school_admin/shared/_rank_note.html.erb:6 ; BaseController#rank_note
Description : le menu ⋮ et les boutons disparaissent pour la fonction « vie scolaire » ; seule une note `text-xs text-mute` explique pourquoi (affichée seulement si `hideable`). Sur un écran sans geste caché (ex. accueil), aucun indice. Accessibilité : icône info + texte, correct.
Proposition : conserver ; passer en `text-sm`. À confirmer avec le porteur.
Effort S

#### U-S11 — Cibles tactiles : boutons `sm` à 40 px
Gravité P3 · direction · app/assets/stylesheets/application.tailwind.css:411-413
Description : `ui-button-sm` = `h-10` (40 px < 44/48 px) compensé par un pseudo-élément `after:-inset-1` (zone cliquable ~48 px). Acceptable en tactile, mais « Rétablir » (departed_teachers L32), « Afficher les archives » (archives_toggle L130-132), « Retirer… » (info) restent visuellement < 44 px ; la zone étendue peut chevaucher le bouton voisin quand deux `sm` sont adjacents. À confirmer sur appareil.
Effort S

#### U-S12 — Toasts fixés en haut sur mobile
Gravité P3 · tous · app/views/shared/_toasts.html.erb:4
Description : `fixed inset-x-0 top-0 … sm:top-auto sm:bottom-0` : sur 390 px le toast recouvre l'en-tête sticky (z-50 vs z-40) pendant le délai ; un toast d'erreur (permanent, `role="alert"`) masque le logo et l'avatar jusqu'à fermeture. À confirmer visuellement.
Proposition : `top-bar` offset ou position basse au-dessus de la barre basse.
Effort S

---

### W-S — Wording

#### W-S01 — « Score », « Moyenne », « Taux de rendu » : jargon absent du glossaire
Gravité P2 · direction · config/locales/school_admin/classrooms.fr.yml:7-13,53,91,96 ; departed_students.fr.yml:12,21 ; levels.fr.yml:24-25
Description : le glossaire ne définit ni « taux de rendu », ni « moyenne », ni « signal », ni « Faits seul ». Pire, trois noms pour la même donnée : tuile « Moyenne » (classrooms.fr.yml:91), colonne « Score moyen » (L96), infobulle « Moyenne des scores » (L12-13), carte niveau « Moyenne : » (levels.fr.yml:25). « Signal vert/jaune/rouge » est un mot interne (signals.fr.yml) jamais défini à l'utilisateur.
Preuve : cf. lignes.
Proposition : un seul mot (« Maîtrise » avec médaille) ; définir « rendu » (devoir rendu = ≥ 1 exercice terminé) au glossaire.
Effort S

#### W-S02 — « Faits seul (7 j) : N » : formulation obscure
Gravité P3 · direction · classrooms.fr.yml (levels.self_practice, ~L77-79) ; _levels.html.erb:53-57
Description : « Faits seul » + « (7 j) : 3 » est cryptique (sans verbe, abréviation « j »). Sens : exercices faits sans devoir en 7 jours (ADR-0089 §4.2).
Proposition : « Exercices libres cette semaine : 3 ».
Effort S

#### W-S03 — « Établissement » désigne trois choses ; « Enseignants retirés » vs « Anciens élèves »
Gravité P3 · direction · navigation.fr.yml (`school: "Établissement"`) ; teachers.fr.yml:13 `departed: "Enseignants retirés"` ; classrooms.fr.yml `links.departed: "Anciens élèves"`
Description : « Établissement » = entrée de menu, carte d'accueil (« Voir l'établissement » + « Établissement » carte) et page. Les élèves quittés sont « Anciens élèves », les enseignants « retirés »/« départ » (`departed_teachers`, `detached_on`) : vocabulaire incohérent (retirer / quitter / détacher).
Proposition : « Anciens enseignants » ou « Anciens élèves » et « retirés » partout ; renommer la carte d'accueil.
Effort S

#### W-S04 — Écriture inclusive et orthographe : « retiré(e) »
Gravité P3 · direction · config/locales/school_admin/teachers.fr.yml:36-38
Description : « a été retiré(e) » alors que le genre est connu (`teacher_gender` sert à « M. / Mme » dans l'activité, _activity.html.erb:109). Incohérent avec le reste de l'interface qui accorde.
Proposition : accord par genre ou formulation neutre « Retrait de %{name} : … ».
Effort S

#### W-S05 — Chiffres : « 40 % » avec espace simple, « 5 élèves » sans insécable
Gravité P3 · direction · classrooms.fr.yml:8 `percent: "%{value} %"` ; school_card `red_signal` « moins de 40 % »
Description : l'espace avant « % » est une espace normale : « 62 » / « % » peuvent se couper en fin de ligne (cartes étroites 390 px). Typographie française : espace insécable (U+00A0 ou U+202F).
Proposition : `"%{value} %"` avec espace insécable partout (aussi `sr_rate`).
Effort S

#### W-S06 — Tutoiement/vouvoiement : cohérent (constat négatif vérifié)
Gravité P3 (info)
Description : élèves tutoyés (navigation.fr.yml:85-122), adultes (direction, enseignants, équipe) vouvoyés (« Votre établissement… », « Cherchez un nom… », « Inscrivez-vous »). `sessions/new` annonce « au vous » (en-tête de vue). Pas d'incohérence relevée dans le périmètre direction.

#### W-S07 — Titre d'écran « Accueil » et « Bonjour, X » : anglicismes absents mais « Pilotage » / « Activité récente »
Gravité P3 · direction · classrooms.fr.yml `index.activity.title: "Activité récente"`
Description : le sous-titre dit « Les 30 derniers jours » mais la liste est plafonnée à 10 événements (SchoolActivityQuery::LIMIT = 10) : l'utilisateur croit voir tous les événements du mois.
Preuve : `subtitle: "Les 30 derniers jours dans votre établissement"` / `LIMIT = 10`.
Proposition : « Les 10 derniers événements ».
Effort S

---

### C-S — Cohérence maîtrise / note / score (grille médaille)

#### C-S01 — Moyenne en % par classe sur la carte du niveau
Gravité P1 · direction · `/school_admin/levels/:slug` · app/views/school_admin/levels/_classroom_card.html.erb:40 ; locale levels.fr.yml:25
Description : chaque carte classe affiche « Moyenne : 62 % » (`classroom.average_percent`) et « Taux de rendu : 71 % ». C'est exactement le pourcentage/moyenne que Lnclass veut abandonner.
Preuve : `t(".average_html", value: figure.call(classroom.average_percent))`.
Proposition : médaille dominante de la classe (voir tableau) ; supprimer la moyenne ; garder la participation en mots.
Effort M

#### C-S02 — Tuile « Moyenne » + colonne « Score moyen » par élève (page classe)
Gravité P1 · direction · `/school_admin/classrooms/:id` · app/views/school_admin/classrooms/show.html.erb:29 (tuile) et :83, :110 (colonne, une moyenne % nominative par élève)
Description : la direction voit pour chaque élève un « Score moyen » en %, ce qui est un classement implicite (tri par nom, mais lisible). Le code règle un seuil de 5 élèves pour la moyenne de classe (`MIN_STUDENTS_FOR_AVERAGE`) précisément parce que la donnée est sensible ; la colonne élève, elle, n'a pas ce seuil.
Preuve : `percent.call(student.work.average_percent)` ; `StudentRow … average_percent: total.average` (student_work_query.rb:191).
Proposition : par élève, la meilleure médaille / le nombre de médailles ; par classe, la répartition (ex. 8 bronze · 6 argent · 3 or).
Effort M

#### C-S03 — Anciens élèves : « Score moyen » %
Gravité P1 · direction · `/school_admin/departed_students` · app/views/school_admin/departed_students/index.html.erb:112,126 ; query departed_students_query.rb:10
Description : même moyenne en % nominative pour des élèves partis.
Proposition : médailles obtenues dans l'établissement (compte par niveau) à la place.
Effort M

#### C-S04 — Alerte « classe rend moins de 40 % des devoirs »
Gravité P2 · direction · accueil carte « À surveiller » · config/locales/school_admin/classrooms.fr.yml:53-55 ; entities/school/work_signal.rb:5-6 (70 / 40)
Description : seuil chiffré en pourcentage dans la phrase d'alerte et les légendes (signals.fr.yml : « 70 % et plus », « de 40 à 69 % »). C'est une mesure de participation (rendu), pas de maîtrise : le mélange « signal » (feu tricolore) + « médaille » créerait deux systèmes de couleurs.
Proposition : conserver la participation en phrases (« rend peu de devoirs ») sans %, ou la mesurer par exercices terminés ; ne pas la colorer comme une médaille (bronze/argent/or/diamant).
Effort M

#### C-S05 — « Fiches à revoir » : seuil « moins de X/20 »
Gravité P2 · direction · app/views/classroom/classrooms/_gaps.html.erb:7 ; classroom locale `subtitle: "Des élèves ont eu moins de %{grade}/20…"`
Description : la page classe direction réutilise un partial enseignant qui affiche une note sur 20 (`Grading.grade_on_20(PASS_THRESHOLD)`). Autre usage de `grade_on_20` : assessment/exercises/show L121, classroom/student_archives/_result_row L7, help/show L7-9 (hors périmètre, à traiter par les autres parts).
Proposition : « n'ont pas encore obtenu la médaille de bronze ».
Effort S

#### C-S06 — Définition de « rendu » et de « devoir » : mélange maîtrise/progression
Gravité P2 · direction · classrooms.fr.yml:11-12 ; student_work_query.rb:44-49
Description : « un devoir est rendu quand l'élève a terminé au moins un exercice » : une session terminée à 0 % compte comme rendue. Le taux de rendu mesure l'activité, la moyenne le score : deux notions, et la médaille ADR-0033 une troisième. Pas de lien visible direction ↔ badge de l'élève (table `exercise_badges`, jamais lue côté direction).
Proposition : faire de la médaille la seule mesure de qualité, et du « rendu » un simple indicateur de participation sans couleur.
Effort M

#### C-S07 — Textes légaux visibles avec placeholders « à compléter par les juristes »
Gravité P2 · public · config/locales/communication/pages/terms.fr.yml:64,68,72,76 (et L55)
Description : les CGU affichent « ‹ Âge minimum et accord des parents : à compléter par les juristes › » au public. Hors rôle parent mais seule trace du parent côté UI. À confirmer si la page est publiée en prod.
Proposition : retirer ou masquer tant que non validé.
Effort S

---

## Constats — Équipe A (imports, établissements, pilotage, croissance)

Périmètre lu : `app/views/teams/{imports,schools,dashboards,growth,homes,account_lookups,deletion_requests}`, contrôleurs `app/controllers/teams/*` correspondants, `Queries::School::TeamDashboardQuery`, `DrenaSchoolsQuery`, `Queries::Identity::GrowthMetricsQuery`, `Queries::Catalog::{ImportReports,ImportReport,TeamHome}Query`, `RunImport`/`StartImport`, locales `config/locales/teams/*.fr.yml`, Stimulus `teams/import_{status,files}_controller.js`, `db/schema.rb`, ADR-0033 et glossaire.
Constat clé pour la grille : sur cette part, il n'y a qu'**un seul chiffre de note** (« Réussite moyenne » du Pilotage). Tout le reste est du comptage (comptes, classes, partages), donc pas de médaille à proposer.

### Optimisation

#### O-A01 — L'accueil équipe fait ~12 requêtes dont 3 inutilisées ou dupliquées
Gravité : P2 · Rôle/écran : Équipe, accueil `/teams/home` · Fichier : `app/controllers/teams/homes_controller.rb:15` + `app/infrastructure/queries/catalog/team_home_query.rb:20-25`
Description : `show` appelle `query.call`, qui lit aussi `levels`, `series_count`, `materials_count`, `classroom_plan_total` (calcul du barème + `TaxonomyRepository.lookup`) et les 3 listes « récentes ». La vue `homes/show` n'utilise que `drenas_count`, `schools_count`, `classrooms_count`. Les 3 listes sont de plus relues par le frame différé (`render_recent_content`). Les autres champs ne servent qu'à `teams/referentials/_summary`.
Preuve : `@home = query.call` (homes_controller:15) ; `Row.new(... levels:, series_count:, materials_count:, classroom_plan_total:, recent_courses:, recent_exercises:, recent_imports:)` ; vue : `@home.drenas_count, @home.schools_count, @home.classrooms_count`.
Proposition : une méthode `counts` (3 COUNT) pour l'accueil ; garder `call` pour Référentiel.
Effort : S

#### O-A02 — La période par défaut du Pilotage (7 jours) n'est jamais en cache
Gravité : P2 · Pilotage `/teams/dashboard` (route `team_dashboard_path`) · Fichier : `team_dashboard_query.rb:34` et `reporting_period.rb:22`
Description : seule la période `year` est gardée 5 min. La page s'ouvre sur `7d` (`DEFAULT = "7d"`), donc chaque ouverture exécute les ~12 requêtes d'agrégats en direct : `COUNT(DISTINCT student_id)` sur `exercise_sessions`, `placed_students` avec `IN (SELECT student_id FROM exercise_sessions WHERE started_at >= …)` par couple niveau/DRENA, `territorial_users` (OR de deux sous-requêtes) appelé 3 fois sous filtre DRENA. Coût linéaire avec le volume de sessions.
Preuve : `CACHED_PERIODS = %w[year].freeze` ; `DEFAULT = "7d"` ; `started = Orm::ExerciseSession.where(started_at: @since..)...to_sql` (l.174).
Proposition : mettre aussi 7d/30d en cache 1 à 5 min (la clé contient déjà `period.since.iso8601`) ; corriger le sous-titre (voir W-A01) ; remplacer `IN (subselect)` par `EXISTS`/jointure sur un `DISTINCT` pré-agrégé. À mesurer sur données réelles (à confirmer).
Effort : M

#### O-A03 — Suivi d'import : rechargement du frame chaque seconde, sans plafond ni ralentissement
Gravité : P2 · Imports, modale de suivi et `/teams/imports/:public_id` · Fichier : `app/javascript/controllers/teams/import_status_controller.js:7-17`, `imports_controller.rb:31-40`
Description : tant que le statut est queued/validating/importing (et même quand l'import est signalé « bloqué », l'écran continue « au cas où »), le navigateur refait un GET par seconde. Chaque GET relit le rapport entier : `ImportReportQuery` ramène `details`, `import_errors` (jusqu'à 1 000 entrées jsonb) et `files` en un `pick`, plus `regeneration_scope` (requête d'aperçu) pour une régénération. Aucun backoff, aucune pause si l'onglet est caché, aucune limite de durée.
Preuve : `const INTERVAL = 1000` ; `COLUMNS = ... "import_reports.import_errors", "import_reports.files"` ; `@regeneration_scope = regeneration_scope(@import)` avant le rendu.
Proposition : intervalle croissant (1 s puis 3-5 s), arrêt sur `document.hidden`, colonnes légères pour le suivi (statut, compteurs, `updated_at`) et lecture complète seulement à l'état final ; calculer `regeneration_scope` une fois (ou seulement à l'état final).
Effort : M

#### O-A04 — Rapports d'erreurs : jusqu'à 1 000 lignes rendues d'un bloc, sans regroupement
Gravité : P3 · Import terminé/rejeté · Fichier : `app/views/teams/imports/_import_errors.html.erb:4-15`
Description : la liste est rendue en entier (MAX_ERRORS = 1 000) dans la page et dans la modale, sans pagination, sans regroupement par motif ni export. Poids DOM et lecture pénibles pour un fichier de 5 000 éléments.
Preuve : `import.import_errors.each` ; `MAX_ERRORS = 1_000` (`import_kind.rb:13`).
Proposition : grouper par `code`+fichier (« Niveau inconnu : 42 éléments », dépliable), ou paginer à 50 et proposer un téléchargement CSV.
Effort : M

#### O-A05 — Liste des imports : limite silencieuse à 50, aucune pagination
Gravité : P3 · `/teams/imports` · Fichier : `import_reports_query.rb:22`, `imports/index.html.erb:35`
Description : `limit: 50` sans indication ni page suivante ; au-delà, l'historique est inaccessible. L'index `(kind, created_at)` existe, mais le tri sans filtre se fait sur `created_at` seul (pas d'index dédié ; coût faible tant que la table reste petite, à confirmer).
Preuve : `def call(kind: nil, limit: 50)` ; aucun `ui_pagination` dans `index.html.erb`.
Proposition : `ui_pagination` (même schéma que `SchoolsQuery`) ou « Voir plus ».
Effort : S

#### O-A06 — Liste des demandes de suppression non paginée (les 3 lignes sont masquées côté client)
Gravité : P3 · `/teams/deletion_requests` · Fichier : `deletion_requests/index.html.erb:13-26`, `pending_deletion_requests_query.rb:22-26`
Description : toutes les demandes en attente sont lues et rendues ; `ui_reveal_more` ne fait que cacher les lignes au-delà de 3 (déjà dans le DOM). Sans conséquence aujourd'hui, mais sans plafond.
Proposition : `LIMIT` + page, ou accepter tel quel (volume faible attendu).
Effort : S

#### O-A07 — Imports lourds : fichiers lus en mémoire (à confirmer)
Gravité : P3 · Import (tous types) · Fichier : `run_import.rb:read_sources` (`@files.read(report_id:)`, `file.content.bytesize`, `JSON.parse(file.content)`)
Description : le contenu complet de chaque fichier (jusqu'à 20 Mo au total) est chargé en String puis parsé en une fois, et le rapport complet de toutes les erreurs est gardé en mémoire avant écriture. Le traitement est bien asynchrone (`Shared::ImportJob`, concurrence 1 par type, avancement tous les 100 éléments) : pas de blocage de requête. Le risque est seulement mémoire/temps du worker.
Proposition : surveiller ; si l'import `course_tree` approche la limite, parser en flux. Non prioritaire.
Effort : L

#### O-A08 — Aide d'import qui interroge la base depuis la vue
Gravité : P3 · Modale « Importer des établissements » · Fichier : `app/views/teams/imports/kinds/_schools.html.erb:4`
Description : `Queries::School::SchoolOptionsQuery.new.drenas` est appelé dans le partial d'aide, et `UseCases::School::ImportSchools::ALIASES` y est lu : la vue contourne le contrôleur (règle « Delivery transforme, UI n'appelle pas les queries »). Fonctionnellement sans effet (une requête, petites tables).
Proposition : charger les DRENA dans `ImportsController#new` pour le seul type `schools`.
Effort : S

### UI / UX

#### U-A01 — Le Pilotage affiche une table d'élèves sans lien vers leur fiche ; deux recherches de compte qui se doublonnent
Gravité : P2 · Équipe, Pilotage (bloc « Rechercher un élève ou un enseignant ») et « Débloquer un compte » · Fichier : `dashboards/_search_results.html.erb:139-153`, `account_lookups/show.html.erb`
Description : deux écrans cherchent un compte (nom ou numéro à 4 chiffres dans le Pilotage ; numéro exact dans « Débloquer un compte »). Les résultats du Pilotage sont des lignes mortes (aucun lien) : pour agir il faut recopier le numéro complet, qui est masqué (`contact` masqué). Impasse d'usage.
Preuve : `<li id="account_<%= account.public_id %>" ...>` sans `link_to` ; `_recent_signups` pareil.
Proposition : fusionner les deux recherches sur une seule page, ou lier la ligne vers `teams_account_lookup_path` par `public_id` (le contrôleur n'accepte aujourd'hui que `contact`).
Effort : M

#### U-A02 — Modale d'import : double envoi possible, pas d'état « envoi en cours »
Gravité : P2 · Import (modale) · Fichier : `imports/new.html.erb:137-139`
Description : le bouton « Lancer l'import » n'est pas désactivé à l'envoi (pas de `data-turbo-submits-with`/`disable_with`). Un fichier de 20 Mo est téléversé sans indicateur de progression. Un second clic crée un second rapport, bloqué ensuite par l'index unique `index_import_reports_one_running_per_kind` (message « Un import de ce type est déjà en cours. » sans lien vers l'import qui tourne).
Preuve : `ui_button t(".submit"), type: :submit, form: "import-upload-form"` ; `config/locales/catalog/imports.fr.yml:12`.
Proposition : désactiver au submit et afficher « Envoi du fichier… » ; sur `already_running`, afficher le suivi existant (comme `classroom_generations` le fait déjà).
Effort : S

#### U-A03 — La ligne d'import ajoutée en tête ne se met jamais à jour
Gravité : P3 · `/teams/imports` · Fichier : `imports/create.turbo_stream.erb:14-15`, `_import_row.html.erb`
Description : le tableau reste figé sur « En file d'attente » tant que la page n'est pas rechargée, alors que la modale se met à jour toutes les secondes. Après fermeture de la modale, l'équipe voit un statut périmé et des compteurs à 0. De plus, la ligne est ajoutée même si un filtre d'un autre type est actif.
Proposition : recharger la ligne à la fermeture (frame par ligne) ou diffuser un Turbo Stream à la fin ; ne préfixer que si `@kind` est nil ou égal.
Effort : M

#### U-A04 — Pastilles de filtre des imports à 40 px (cible tactile < 48 px)
Gravité : P3 · `/teams/imports` mobile 390 px · Fichier : `imports/index.html.erb:20`
Description : `min-h-10` (40 px) alors que le jeton projet `--spacing-tap` vaut 3rem (48 px) et que `dashboards/_filters` et `growth` utilisent `min-h-tap`. Incohérence.
Preuve : `inline-flex min-h-10 items-center rounded-full border px-4` vs `min-h-tap` ailleurs.
Proposition : `min-h-tap`.
Effort : S

#### U-A05 — Table des imports : 8 colonnes, `min-w-3xl`, défilement horizontal sur téléphone
Gravité : P3 · `/teams/imports` à 390 px · Fichier : `imports/index.html.erb:25-37`
Description : le tableau défile horizontalement ; date, type et fichier sortent à gauche de l'écran, le bilan (importés/ignorés/erreurs) hors champ. Les autres écrans équipe (accueil) utilisent des cartes-liste en mobile.
Proposition : en dessous de `sm`, une carte par import (type + statut + « 12 importés · 3 ignorés ») au lieu du tableau.
Effort : M

#### U-A06 — Aucune annonce d'accessibilité quand le suivi d'import change d'état
Gravité : P3 · Suivi d'import · Fichier : `imports/_status.html.erb:53-72`
Description : `aria-live="polite"` est posé sur le conteneur, mais ce conteneur est remplacé en entier toutes les secondes : les lecteurs d'écran peuvent relire à chaque rechargement ou rien annoncer. `<progress>` est indéterminé (sans `value`/`max`) alors que `processed_count` et `total` sont connus en phase d'écriture.
Preuve : `<progress class="h-2 w-full ..." aria-label=...>` sans `value`.
Proposition : annoncer seulement le changement de phase et le résultat final (région live stable, texte mis à jour) ; `<progress value= max=>` quand le total est connu (à confirmer : le total est-il connu avant la fin ?).
Effort : M

#### U-A07 — Pilotage : tableau « Par DRENA » à 6 colonnes dont 2 avec infobulle, `min-w-2xl`
Gravité : P3 · `/teams/dashboard` à 390 px · Fichier : `dashboards/_drenas.html.erb:20`, `dashboards/_schools.html.erb:88`
Description : ces tableaux défilent latéralement sur téléphone, sans indication de défilement (ombre de bord) et sans tri (l'ordre est fixe : élèves décroissants). Les infobulles dans les en-têtes sont des cibles étroites.
Proposition : sur mobile, carte par DRENA avec les 5 chiffres ; garder le tableau à partir de `md`.
Effort : M

#### U-A08 — Lien « Pilotage » : le périmètre n'est pas repris dans les exports ni dans l'URL de recherche de compte
Gravité : P3 · `/teams/dashboard` · Fichier : `dashboards/_search.html.erb`, `dashboards_controller.rb:18-25`
Description : la recherche de compte du Pilotage est lancée même sans terme (`AccountSearchQuery.new.call(term: nil)`) à chaque chargement de page, puis le frame ne renvoie que `prompt`. Coût minime, mais la recherche de comptes ne devrait pas dépendre du filtre DRENA affiché (elle l'ignore) : l'équipe peut croire qu'elle cherche dans la DRENA filtrée.
Preuve : `render "search", search: @search, period: @period, drena: @dashboard.drena` (période et DRENA passées au formulaire de recherche, mais `AccountSearchQuery` ne les reçoit pas).
Proposition : retirer `period`/`drena` du formulaire ou dire « Recherche dans tout le pays ».
Effort : S (à confirmer en lisant `_search.html.erb`)

#### U-A09 — Pas d'état d'erreur de chargement pour le frame différé « activité récente » de l'accueil
Gravité : P3 · `/teams/home` · Fichier : `homes/show.html.erb:28-30`
Description : le frame `loading: :lazy` affiche un squelette ; si la requête échoue, le squelette reste indéfiniment. Les écrans `schools` et `dashboards` ont déjà un état d'erreur (`ui_error_state` dans `schools/_filters`).
Proposition : `<template>` d'erreur avec « Réessayer » ou slot `[data-turbo-frame-error]`.
Effort : S

#### U-A10 — Numéro complet dans l'URL de la liste des suppressions
Gravité : P3 · `/teams/deletion_requests` → `/teams/account_lookup?contact=…` · Fichier : `deletion_requests/index.html.erb:17`, `pending_deletion_requests_query.rb:10,23`
Description : le lien porte le numéro complet (`row.contact`), qui reste dans l'historique du navigateur et les en-têtes `Referer`. Le paramètre est filtré dans les logs Rails (`:contact` dans `filter_parameter_logging.rb`), c'est donc surtout une exposition côté navigateur. Cohérent avec l'UDR-0020 (recherche par numéro exact), mais le pilotage masque les numéros partout ailleurs.
Proposition : chercher par `public_id` (nécessite une route/param ; coupler avec U-A01) ou accepter et documenter.
Effort : M

### Wording

#### W-A01 — « Lus en direct » faux pour l'année scolaire
Gravité : P3 · `/teams/dashboard` · Fichier : `config/locales/teams/dashboards.fr.yml:16` vs `team_dashboard_query.rb:34-35`
Description : le sous-titre dit « Indicateurs agrégés, lus en direct dans les données de Lnclass. » alors que la période « Année scolaire » est servie d'un cache de 5 minutes (la liste des inscrits récents, elle, est en direct). Écart avec l'ADR-0062.
Proposition : « Indicateurs agrégés. Mis à jour à chaque ouverture (année scolaire : toutes les 5 minutes). » ou aligner le code (O-A02).
Effort : S

#### W-A02 — Jargon de la page Croissance
Gravité : P2 · Équipe, `/teams/growth` · Fichier : `config/locales/teams/growth.fr.yml:17-20,30-36`, `growth/show.html.erb:30-33`
Description : « k enseignant », « Cohorte », « Cycle viral médian », « Conversion par partage », « filleuls », « garant », « partage(s) par enseignant » (parenthèse d'accord forcée) : vocabulaire de growth hacking non défini dans le glossaire. La formule s'affiche « = 0,8 partage(s) par enseignant × 25 % de conversion » sans explication hors infobulle, et l'infobulle de `k` n'existe que pour trois des six indicateurs.
Preuve : `k_unit: "partage(s) par enseignant"` ; `k_note: "Cohorte : … Les parrainages par garant ne comptent pas dans la conversion."`.
Proposition : « Enseignants amenés par chaque enseignant » ; « Délai médian entre une inscription et celle de la personne parrainée » ; « partages » avec pluriel `one/other` ; définir « garant » ou le retirer ; ajouter l'infobulle du k.
Effort : S

#### W-A03 — « Réussite moyenne » : libellé en pourcentage, infobulle en « scores »
Gravité : P2 · `/teams/dashboard` · Fichier : `config/locales/teams/dashboards.fr.yml:41-45`, `_key_figures.html.erb:6,15-16`
Description : « Réussite moyenne : 72 % » et l'infobulle « Moyenne des scores des exercices terminés… ». Deux mots (réussite, score) pour une même donnée, et la note reste un pourcentage alors que l'élève voit une note sur 20 (ADR-0106). Le « % » est précédé d'une espace ordinaire (`%{rate} %`), pas insécable, contrairement à Croissance (` %`) : retour à la ligne possible avant le signe.
Proposition : voir `## Médailles`. Au minimum, utiliser l'espace insécable.
Effort : S

#### W-A04 — Messages d'import peu actionnables
Gravité : P2 · Imports (rapport) · Fichier : `config/locales/teams/imports.fr.yml:122-140` (`error_codes`), `imports/_import_errors.html.erb:20`, `_status.html.erb:101`
Description : plusieurs messages décrivent le problème sans dire où ni quoi corriger : « Valeur non conforme au format attendu. » (`schema`), « Valeur non valide. » (`invalid_value`), « Valeur obligatoire manquante. » (sans nom de la clé), « Unité » `unit_not_allowed`, « Question incomplète… » ; la colonne gauche montre le chemin brut (`$.courses[3].essentials[0]`), jargon JSON-path pour l'équipe contenu. « Le fichier n'est pas un JSON lisible. » ne donne ni ligne ni caractère. Le message d'échec : « Relancé, le fichier comptera en doublons ce qui a déjà été écrit » est ambigu.
Preuve : `schema: "Valeur non conforme au format attendu."`, `failed: "L'import s'est arrêté sur une erreur imprévue. Relancé, le fichier comptera en doublons ce qui a déjà été écrit."`.
Proposition : citer le champ (« La clé « niveau » est obligatoire »), traduire le chemin en phrase (« Fiche de cours n° 4, notion n° 1 »), et reformuler : « L'import s'est arrêté. Vous pouvez le relancer : les éléments déjà importés seront ignorés (comptés dans « Ignorés »). »
Effort : M

#### W-A05 — Vocabulaire des statuts et compteurs d'import incohérent
Gravité : P3 · Imports · Fichier : `imports.fr.yml:67-72,162-166,205`, `imports/index.html.erb`
Description : colonne « Importés / Ignorés / En erreur », mais le détail dit « Ignorés (doublons) » ; statuts « Rejeté » (rejeté en bloc), « Échoué » (arrêt imprévu) et « Refusé » (fichier) pour trois cas voisins ; « Fini le » ; « Vérification » vs « Vérification de tout le fichier… » ; « Détails » avec la seule clé « Classes générées » et repli `key.to_s.humanize` (clé anglaise non traduite si un détail apparaît).
Preuve : `details: classrooms: "Classes générées"` + `default: key.to_s.humanize` (`_status.html.erb:89`).
Proposition : un seul verbe (« refusé » pour fichier et lot), « Ignorés (déjà présents) » partout, supprimer le repli `humanize` pour échouer aux tests I18n.
Effort : S

#### W-A06 — Mélange « DRENA » / sigle non expliqué et « Couverture » ambigu
Gravité : P3 · `/teams/dashboard` · Fichier : `dashboards.fr.yml:73-75,97`
Description : « DRENA » est défini dans le glossaire (« Direction Régionale… ») mais jamais développé à l'écran ; « Couverture, triée par nombre d'élèves » et « Couverture des établissements actifs » désignent deux choses différentes (comptage des classes/enseignants vs part d'établissements équipés). « Élèves actifs » (au moins une session commencée) sans lien avec la maîtrise.
Proposition : infobulle ou `<abbr title>` sur « DRENA » ; renommer le bloc « Par DRENA : effectifs » ; « Établissements équipés ».
Effort : S

#### W-A07 — Libellés d'accueil et d'écran non alignés sur les titres
Gravité : P3 · Équipe, navigation · Fichier : `homes/_shortcuts.html.erb:129-138`, `dashboards.fr.yml:15`
Description : le raccourci « Débloquer un compte » (`unlock_account`) mène à une page dont le titre n'est pas vérifié ici (à confirmer dans `account_lookups.fr.yml`) ; l'écran « Pilotage » est atteint par la nav alors que la home n'a pas de raccourci « Pilotage ». Les 7 raccourcis de l'accueil forment un mur de boutons à 390 px.
Proposition : à confirmer en capture ; regrouper les raccourcis rarement utilisés (blog, invitation, déblocage) dans un menu « Plus ».
Effort : S

### Cohérence maîtrise / médailles

#### C-A01 — « Réussite moyenne » (moyenne de `score_percent`) est la seule note de cette part
Gravité : P1 (au regard de la décision médailles) · Pilotage `/teams/dashboard` · Fichier : `team_dashboard_query.rb:137` (`ROUND(AVG(score_percent))`), `_key_figures.html.erb:6,14-17`, `dashboards.fr.yml:41-45`
Description : un pourcentage moyen, calculé sur toutes les sessions terminées de la période (moyenne des sessions, pas des élèves), affiché dans la tuile « exercices terminés ». Il alimente l'idée de « niveau global » à l'échelle du pays. Une moyenne de `score_percent` est exactement ce que le passage aux médailles veut retirer ; de plus elle est calculée sur le score brut alors que ADR-0106 lit les seuils sur la note affichée sur 20.
Preuve : `.pick(Arel.sql("COUNT(*)"), Arel.sql("ROUND(AVG(score_percent))"))` ; `Row ... :average_score`.
Proposition : remplacer par une répartition des **médailles décernées** sur la période (voir `## Médailles`), calculée à partir de la meilleure médaille par élève et exercice (comme ADR-0033), sans moyenne. L'index `index_exercise_sessions_completed_on_completed_at` (avec `score_percent` en INCLUDE) couvre déjà la lecture ; une répartition en `COUNT(*) FILTER (WHERE score_percent >= …)` tient dans la même requête. Mettre à jour `CACHE_VERSION` (7).
Effort : M

#### C-A02 — « Niveau » désigne le niveau scolaire dans le Pilotage ; risque de collision avec les niveaux de maîtrise
Gravité : P2 · Pilotage, carte « Élèves par niveau » · Fichier : `dashboards/_levels.html.erb`, `dashboards.fr.yml:70-80`
Description : « Élèves par niveau » (6ème…Tle) affiche « 12 élèves · 18 % » : une part (pas une note) mais le même écran mélangera bientôt « niveau scolaire » et « niveau de maîtrise » (bronze/argent…). Le glossaire fixe `Level` = niveau académique ; l'ADR-0033 parle déjà d'« Acquis / Fragile / En difficulté ».
Proposition : garder « niveau scolaire » en toutes lettres sur cet écran (« Élèves par classe de… » ou « par niveau scolaire »), réserver « médaille » à la maîtrise ; ne jamais écrire « niveau » pour une médaille. La part en % reste (c'est un effectif, pas une performance).
Effort : S

#### C-A03 — « Élève actif » suit l'activité, pas la maîtrise : à ne pas confondre avec progression
Gravité : P3 · Pilotage · Fichier : `dashboards.fr.yml:30-31`, `drena_schools_query.rb:73-77`
Description : « Élève actif » = au moins une session commencée sur la période. Les trois colonnes « Élèves / Élèves actifs » mêlent effectif et engagement. Acceptable, mais la progression (taux d'achèvement, `progress_percent`) n'apparaît nulle part : pas de mélange maîtrise/progression sur cette part.
Proposition : conserver tel quel ; ajouter plus tard (si voulu) une colonne « Élèves avec une médaille » à côté de « Élèves actifs » plutôt qu'un pourcentage.
Effort : S

#### C-A04 — Croissance : pourcentages de conversion et k, pas des notes
Gravité : P3 (information) · `/teams/growth` · Fichier : `growth/show.html.erb:9,30-37,47`
Description : « 67 % de conversion », « k = 0,8 », « Cible 1,0 · ambition 1,5 » : indicateurs commerciaux, hors périmètre des médailles. Aucune note d'élève ici. À laisser en chiffres.
Effort : — (aucun)

## Constats — Équipe B (contenu, référentiels, invitations)

Périmètre lu : answer_keys, articles, series/level_series, levels, drenas, materials, classroom_plans, announcement_illustrations, courses, invitations, staff_invitations, code_regenerations, referentials, school_classrooms, classroom_settings + locales et contrôleurs associés. Constat global : cette part expose très peu de chiffres de réussite ; la seule vraie donnée de note est le corrigé (points). Les autres écrans sont de la gestion de référentiel.

### C — Conformité grille maîtrise / médaille

#### C-B01 — Corrigé : points par question affichés (« Question 1 · 1 pt »)
Gravité P1 · Équipe, corrigé d'une fiche de cours, /courses/:slug/answer_key (à confirmer pour le chemin exact) · app/views/teams/answer_keys/show.html.erb:45 + config/locales/teams/answer_keys.fr.yml:18
Description : chaque question affiche son barème en points (`question_heading: "Question %{number} · %{points} pt"`), donnée issue de `QuestionRow.points` (lesson_answer_key_query.rb:13,66). C'est la logique note/score que la maîtrise par médaille remplace.
Preuve : `t(".question_heading", number: question.position, points: number_with_precision(question.points, ...))`.
Proposition : retirer « · N pt » de l'affichage équipe (garder `points` en base tant que le moteur ADR-0033 calcule encore le % de clôture) ; ne montrer que « Question N ». À défaut, ne l'afficher que dans l'édition auteur.
Effort : S

#### C-B02 — Collision « barème » : barème des classes (ADR-0058) vs barème des badges (ADR-0033)
Gravité P1 · Équipe, Référentiel, /classroom-plan, Niveaux · config/locales/teams/classroom_plans.fr.yml:11,12,47 ; levels.fr.yml:28,29,43 ; referentials.fr.yml:25
Description : « Barème » désigne ici le nombre de classes à générer par niveau/série, alors que le glossaire et ADR-0033 l'emploient pour les seuils de badges (bronze 50 %, argent 70 %, or 80 %, diamant 100 %). En passant à la maîtrise par médaille, « barème » deviendra ambigu dans toute l'interface (« Hors barème », « Barème de « 6ème » », « Ouvrir le barème des classes »).
Preuve : « Barème des classes » (classroom_plans.fr.yml:11), « Hors barème » (levels.fr.yml:43), « Barème de « %{name} » » (:47).
Proposition : renommer côté UI en « Plan des classes » / « Classes par niveau » (clés `teams.classroom_plans.*`, `levels.*outside_generation`, `referentials` l.25), réserver « barème » aux seuils de médaille. À trancher par le porteur (UDR de vocabulaire).
Effort : S (libellés), M si on renomme aussi les routes/domaine (`ClassroomPlan`)

#### C-B03 — Mélange « série » : filière du second cycle (A1, C, D) vs « série de questions » (glossaire Exercise)
Gravité P2 · Équipe, Séries, Niveaux, Cours · config/locales/teams/series.fr.yml (tout), docs/guide/glossaire.md:75
Description : le glossaire définit `Exercise` comme « Série de questions » ; l'interface équipe utilise « Série » pour la filière (Series). Dans les écrans équipe, « série » = filière uniquement, mais le glossaire crée un synonyme à risque quand les exercices passent à la médaille (« ma série », « série réussie »).
Preuve : « Les séries du second cycle, et les niveaux auxquels chacune est ouverte. » (series.fr.yml:21) vs glossaire l.75.
Proposition : retirer « Série de questions » du glossaire/UI et dire « exercice » ; garder « série » pour la filière seule.
Effort : S

#### C-B04 — « Non noté » mélangé à la notion de maîtrise dans le corrigé
Gravité P3 · Équipe, corrigé · app/views/teams/answer_keys/_practice.html.erb:10 (clé `catalog.revision_sheets.practice.unscored` = « Je m'entraîne (non noté) »)
Description : le qualificatif « non noté » suppose un régime de notes. Avec les médailles, l'entraînement « ne compte pas pour la médaille ».
Proposition : « Je m'entraîne (sans médaille) » ; commentaire du partial (l.1, « sous l'exercice noté ») à mettre à jour ; show.html.erb:119 dit aussi « exercice noté ».
Effort : S

#### C-B05 — Tolérance numérique et « Valeur attendue » : seuil chiffré implicite
Gravité P3 · Équipe, corrigé · answer_keys/show.html.erb:71-73,81 ; answer_keys.fr.yml:21 (`à %{tolerance} près`)
Description : c'est un paramètre de correction, pas une note ; à conserver mais à confirmer qu'il ne sera pas confondu avec un « seuil » de médaille.
Proposition : aucune action côté médaille ; garder le libellé.
Effort : S (aucun)

### W — Wording

#### W-B01 — « cours » au lieu de « fiche de cours » (glossaire l.180)
Gravité P3 · Équipe, corrigé vide · config/locales/teams/answer_keys.fr.yml:16 (`empty: "Ce cours n'a pas encore d'exercice."`)
Description : le glossaire interdit « Cours » pour nommer l'objet (hors navigation). Le reste des locales équipe respecte la règle.
Proposition : « Cette fiche de cours n'a pas encore d'exercice. »
Effort : S

#### W-B02 — « leçon » et « notion » en commentaires/requêtes vs glossaire
Gravité P3 · Équipe, corrigé · app/views/teams/answer_keys/show.html.erb:1 (« le corrigé d'une leçon »), answer_keys.fr.yml:2 et lesson_answer_key_query.rb:3 ; show.html.erb:22 (`essential_name`, « notion »)
Description : `Lesson` et « notion » sont des synonymes proscrits par le glossaire (concept = un seul mot : fiche de cours / fiche de révision). Le code (`LessonAnswerKeyQuery`, `lesson_wide`) et les commentaires employent « leçon »/« notion ». Pas visible à l'écran, mais source de dérive. À confirmer : « notion » est-il toléré par l'UDR-0141 ?
Proposition : renommer `LessonAnswerKey*` en `CourseAnswerKey*` ; documenter « notion » dans le glossaire si c'est l'usage UI voulu.
Effort : M (renommage)

#### W-B03 — « problème N » vs « exercice »
Gravité P3 · Équipe, corrigé · answer_keys.fr.yml:17 (`lesson_wide: "%{group} — problème %{number}"`), imports.fr.yml:87
Description : l'objet est partout appelé « exercice » (summary l.11 : « N exercices »), mais l'exercice de toute la fiche s'appelle « problème ». Deux mots pour un concept (glossaire règle 2).
Proposition : « exercice de synthèse N » ou se tenir à « exercice ». À trancher.
Effort : S

#### W-B04 — « Prépare interros » cité en commentaire, tutoiement dans un contexte vouvoiement
Gravité P3 · Équipe, corrigé · app/views/teams/answer_keys/show.html.erb:1 (« dans l'ordre de « Prépare interros » ») et lesson_answer_key_query.rb:3
Description : « Prépare interros » (tutoiement, produit élève) apparaît en référence ; l'espace équipe vouvoie partout (« Transmettez », « Saisissez »). Aucune incohérence visible à l'écran, mais le libellé du produit élève doit être confirmé pour qu'il ne fuite pas.
Effort : S (confirmer)

#### W-B05 — Orthographe « 6ème » (usage correct : « 6e »)
Gravité P3 · Équipe, Niveaux · config/locales/teams/levels.fr.yml:31 (« de la 6ème à la Tle »), :53 (« Ex. : 6ème, 2nde, Tle ») ; glossaire l.55
Description : « 6ème » est tolérée mais l'usage typographique est « 6e ». Cohérent avec le glossaire ; à ne changer que si l'on harmonise tout le produit.
Effort : S (optionnel)

#### W-B06 — Placeholders de numéro incohérents entre invitations
Gravité P3 · Équipe, invitations · config/locales/teams/invitations.fr.yml:32 (« 01 00 00 00 00 ») ; staff_invitations.fr.yml:29 (« 07 00 00 00 00 ») ; account_lookups.fr.yml:13 (« 01 02 03 04 05 ») ; messages d'erreur « par exemple 01 02 03 04 05 »
Proposition : un seul exemple (01 02 03 04 05) partout.
Effort : S

#### W-B07 — Durée « 72 h » écrite en dur dans deux locales
Gravité P3 · Équipe, invitations · invitations.fr.yml:42 ; staff_invitations.fr.yml:40 (« il expire dans 72 h »)
Description : si le TTL du jeton change côté domaine, le texte devient faux. À confirmer : existe-t-il une constante (`INVITATION_TTL`) ?
Proposition : interpoler `%{hours}` depuis la constante.
Effort : S

#### W-B08 — Libellés techniques exposés à l'équipe
Gravité P3 · Équipe, DRENA/Niveaux · app/views/teams/drenas/index.html.erb (colonne « slug »), levels/_level_row.html.erb:143 (`<code>level.slug</code>`), drenas.fr.yml:48 (« Le slug … ne change pas »)
Description : « slug » est du jargon développeur ; l'équipe terrain/contenu ne le connaît pas. Remplacer par « identifiant dans les imports » / « code ».
Effort : S

#### W-B09 — Vocabulaire de rôle d'équipe : « Terrain », « Contenu » sans définition à l'écran du module
Gravité P3 · Équipe, invitation · invitations.fr.yml:19-23
Description : les rôles « Administration / Contenu / Terrain » ont une aide (team_role_hints) correcte ; le terme « codes de récupération » (l.23) est du jargon non défini.
Proposition : « codes de secours de connexion ». À confirmer avec la terminologie du reste de l'app.
Effort : S

### U — UI/UX

#### U-B01 — Liste des DRENA : pas de pagination ni de recherche
Gravité P3 · Équipe, /drenas · app/controllers/teams/drenas_controller.rb:9-10 (`@drenas = drenas_query.call`), views/teams/drenas/index.html.erb:118-120
Description : toutes les DRENA sont rendues d'un coup (nombre borné, ~30 en Côte d'Ivoire). Acceptable ; la requête agrège établissements et classes en SQL (`COUNT(DISTINCT schools.id)`, drenas_query.rb:9) sans N+1.
Proposition : aucune urgence ; surveiller si le référentiel grandit.
Effort : S

#### U-B02 — Bibliothèque d'illustrations non paginée, aperçu SVG reconstruit 3 fois par ligne
Gravité P2 · Équipe, /teams/announcement_illustrations · app/views/teams/announcement_illustrations/_illustration.html.erb:57-59 (boucle `%w[ciel mangue nuit]` appelant `announcement_illustration` 3 fois) ; index.html.erb:29-31 (collection `library` entière)
Description : chaque illustration est reconstruite (relecture des formes) trois fois, même les deux aperçus masqués sur téléphone (`hidden sm:block`) ; liste entière rendue sans pagination ni limite.
Preuve : `<% %w[ciel mangue nuit].each do |theme| %> ... announcement_illustration illustration ...` (le `theme` n'est pas passé : à confirmer qu'il l'est via CSS data-announcement-theme).
Proposition : reconstruire une seule fois (capturer le SVG dans une variable) ; paginer ou plafonner la liste si > 50 ; ne rendre qu'un aperçu sur mobile.
Effort : S à M

#### U-B03 — Aucune confirmation visuelle / état de chargement à l'envoi d'une illustration SVG
Gravité P3 · Équipe, /teams/announcement_illustrations · index.html.erb:11-20
Description : le formulaire multipart (file SVG) n'a ni `turbo_submits_with` ni indicateur d'envoi, contrairement à classroom_settings (`data-turbo-submits-with`). Double soumission possible sur réseau lent.
Proposition : ajouter `data: { turbo_submits_with: ... }` sur le bouton + désactivation.
Effort : S

#### U-B04 — Formulaire d'article : écran très chargé dans une modale (parcours long)
Gravité P2 · Équipe, /teams/articles/new (frame modal) · app/views/teams/articles/_form.html.erb:14-132, articles/index.html.erb:6
Description : titre, résumé avec compteur, couverture (aperçu, upload, alt), éditeur Trix, panneau d'images avec alt par image, signature : 6 blocs dans une modale (`data-turbo-frame="modal"`). Sur 390 px, une modale à défilement long + éditeur Trix + sélecteur de fichiers rend la saisie pénible ; pas de brouillon automatique visible.
Proposition : ouvrir « Nouvel article » en page pleine (`/teams/articles/new`) plutôt qu'en modale, séparer « Contenu » et « Publication » ; vérifier à 390 px (à confirmer en capture).
Effort : M

#### U-B05 — Sélecteur de fichier natif stylé uniquement par `file:` ; feedback d'envoi hors vue
Gravité P3 · Équipe, article, couverture · _form.html.erb:57-61,71
Description : `<input type="file">` brut avec statut `aria-live` mais le bouton « Retirer » est un `ui_button` `size: :sm` (cible tactile potentiellement < 44 px ; `min-h-tap` n'est appliqué qu'à l'input, ligne 60).
Proposition : forcer `min-h-tap` sur le bouton Retirer et aligner la grille (`flex-wrap`).
Effort : S

#### U-B06 — Matrice niveaux × séries : cases de 32 px
Gravité P3 · Équipe, /series · app/views/teams/level_series/_cell.html.erb:7 (`size-8`, avec `after:-inset-2` pour étendre la zone)
Description : visuel 32 px compensé par un pseudo-élément (zone tactile ~48 px) : correct. Mais pas de retour visuel pendant le POST/DELETE (la case est remplacée seule).
Proposition : confirmer un `turbo_submits_with` ou un état « en cours » ; scroll horizontal sur 390 px à confirmer (tableau `overflow-x-auto`, une colonne par série).
Effort : S

#### U-B07 — Page Référentiel : tuile « Barème des classes » avec compteur total ambigu
Gravité P3 · Équipe, /referential · app/views/teams/referentials/_summary.html.erb:7 (`home.classroom_plan_total`), referentials.fr.yml:25
Description : le chiffre de la tuile (somme du plan) est libellé « classes d'un lycée public · Barème des classes » ; la phrase mélange un total et un type, lisible difficilement. Lien vers C-B02.
Proposition : tuile « Classes par établissement » avec un seul chiffre clair.
Effort : S

#### U-B08 — Régénération de masse : modale dense, bouton danger sans résumé final
Gravité P3 · Équipe, Établissements → Codes · app/views/teams/code_regenerations/_form.html.erb:35-62
Description : plusieurs paragraphes, une liste de règles, un filtre année avec lien qui recharge le frame, puis un champ « Tapez N pour confirmer ». Correct pour une action destructive, mais le défilement sur 390 px de la modale `size: :sm` est à vérifier ; le lien « Inclure les années passées » ne conserve pas la saisie `typed_count`.
Proposition : capture 390 px ; réordonner : portée → règles → confirmation.
Effort : S

#### U-B09 — Doublon d'écrans de création d'invitation (équipe vs direction)
Gravité P3 · Équipe · app/views/teams/invitations/new.html.erb et staff_invitations/new.html.erb, _created.html.erb des deux (29 lignes chacun, quasi identiques)
Description : deux partials « lien créé » presque identiques (champ readonly, bouton copier, avertissement « une seule fois »), deux jeux de locales dupliqués (`created.*`).
Proposition : extraire `shared/invitation_link`.
Effort : S

#### U-B10 — Table des niveaux : 8 colonnes sans scroll signalé, colonnes numériques sans libellé d'unité
Gravité P3 · Équipe, /levels · app/views/teams/levels/_level_row.html.erb:130-158
Description : nom, code, position, cycle, séries, classes, cours, actions ; colonnes « classes »/« cours » sans `text-right` ni unité (le tableau DRENA aligne à droite). Mobile : `overflow-x-auto` à confirmer sur le conteneur de levels/index.
Effort : S

### O — Optimisations

#### O-B01 — Corrigé : `includes(:answers)` correct mais tout le contenu d'une fiche chargé et rendu d'un coup
Gravité P3 · Équipe, corrigé · app/infrastructure/queries/catalog/lesson_answer_key_query.rb:55 (`Orm::Question.where(exercise_id: ids).includes(:answers)`)
Description : pas de N+1 (4 requêtes) ; mais `question.answers.group_by(&:blank)` est recalculé en vue (show.html.erb:49) pour chaque question et figures décodées via `Figure.from_raw` pour toute la liste. Volume borné (≈ 12 notions × 4 problèmes). Aucun problème mesuré.
Proposition : aucune ; ne pas optimiser avant mesure.
Effort : S (aucun)

#### O-B02 — Liste équipe des articles triée sur `updated_at` sans index
Gravité P3 · Équipe, /teams/articles · db/schema.rb:120-123 (index sur author_id, public_id, `published_at,id` partiel publié, slug), articles/index.html.erb:171-192
Description : la liste de gestion est paginée (`ui_pagination`) mais ordonnée « du plus récemment modifié » ; aucun index sur `updated_at`/`id`. Sans conséquence tant que le blog compte quelques centaines d'articles.
Proposition : index `(updated_at DESC, id DESC)` si > 1 000 articles ; sinon rien.
Effort : S

#### O-B03 — Upload d'images d'articles : allègement côté navigateur, bornes raisonnables
Gravité P3 (info) · Équipe, article · app/domain/entities/communication/article_image.rb:15-21 (JPEG/PNG/WebP, `MAX_SIDE = 1600`, `MAX_PER_ARTICLE = 10`, `ALT_MAX = 150`), communication/cover_picker_controller.js
Description : images « allégées avant l'envoi » (cover_hint). Poids max exact (`MAX_MEGABYTES`) non vérifié dans ce passage ; pas de génération de variantes (WebP/AVIF, tailles) à confirmer côté affichage public du blog.
Proposition : à confirmer ; vérifier le rendu `srcset` côté blog public (hors part B).
Effort : M

#### O-B04 — Turbo Streams : bien utilisés, un morphing par transition
Gravité P3 (info) · Équipe · app/views/teams/*/*.turbo_stream.erb (levels, series, drenas, materials, essentials, courses, exercises, classroom_plans)
Description : mises à jour par ligne (remplacement ciblé) ; aucun constat bloquant. Le total du barème est recalculé par `replace` (classroom_plans/update.turbo_stream.erb) : correct.
Effort : S (aucun)

### Constats positifs vérifiés (à ne pas corriger)
- Accessibilité : `caption sr-only`, `scope="col"`, `aria-live` sur les totaux, `aria-pressed` sur la matrice, `aria-label` sur les actions, libellés `sr-only` pour les icônes de bonne réponse (answer_keys/show.html.erb:60,79).
- Pas de pourcentage, moyenne, score ni seuil exposé dans les vues part B autres que les « points » du corrigé (grep `point|score|moyenne|seuil|badge|%` sans autre résultat).
- Wording équipe cohérent sur « fiche de cours » / « fiche de révision » dans levels, series, materials, courses, essentials, exercises.

## Constats — Catalogue et communication

Périmètre lu : `app/views/catalog/**`, `communication/**`, `homepage`, `errors`, `pwa`, `public/*.html`, contrôleurs `Catalog::*` / `Communication::*`, queries `catalog/*` et `communication/*`, locales correspondantes, `db/schema.rb`. Non exécuté (aucun bin/ci, aucune app). Tout ce qui n'est pas vérifié dans le code est marqué « à confirmer ».

Bilan court : les écrans catalogue ne montrent AUCUNE note, aucun % ni score. Les chiffres exposés sont des compteurs binaires (« n / N exercices réussis », « n / N élèves ont réussi ») et une progression de LECTURE (En cours / Terminée). Le gros du travail « médaille » est : (1) la FAQ `/aide` qui enseigne toute l'échelle /20 + « Maîtrise » Acquis/Fragile/En difficulté ; (2) la notion de « Réussi » = 100 % de bonnes réponses, qui contredit la médaille ; (3) aucune médaille affichée dans la liste des cours ni sur les cartes de feuilles. Le moteur de liste des cours est globalement sain (pluck, 3 requêtes par page, pas de N+1 par carte).

---

### Optimisation (O-C)

#### O-C01 — Élève : la liste des cours est calculée et rendue deux fois (téléphone + ordinateur)
Gravité : P1 · Rôle/écran : élève, `/cours` (et `/cours?material=`) · Fichier : `app/views/catalog/courses/index.html.erb:255-258`, `app/controllers/catalog/courses_controller.rb:20-28,174-180`
Description : l'élève reçoit toujours les DEUX blocs, `<div class="lg:hidden"><%= body %></div>` et `<div id="student_lessons" class="hidden lg:block">`. Le bloc téléphone appelle `CourseCatalogQuery#call` (24 cartes + progression), le bloc ordinateur rappelle la query avec `with_essentials: true` (`lessons_page`), plus `student_materials`, plus `next_exercise_for` (2 matières potentielles), plus `ReferentialOptionsQuery`. Le navigateur télécharge, parse et garde dans le DOM les deux jeux de cartes, un des deux est `display:none`.
Preuve : `<div class="lg:hidden"><%= body %></div>` / `<% if lessons.present? %><div id="student_lessons" class="hidden lg:block">`.
Proposition : choisir la variante côté serveur (détection de largeur impossible → au minimum ne rendre le bloc ordinateur que par un `turbo_frame` `loading: :lazy` + `src`, déclenché seulement dès `lg` via media query/Stimulus), ou unifier les deux vues sur la même query. À défaut, au moins ne pas appeler `CourseCatalogQuery` deux fois.
Effort : M

#### O-C02 — Élève, ordinateur : la vue « leçons » n'est pas paginée (24 leçons max, silencieusement)
Gravité : P1 · Rôle/écran : élève, `/cours` ≥ 1024 px · Fichier : `courses_controller.rb:174-180`, `index.html.erb:222-238`
Description : `lessons_page` appelle la query sans `page:` ; `PER_PAGE = 24` (`course_catalog_query.rb`). Le bloc `lessons` ne rend qu'un `<ul>` des `page.rows`, sans frame « page suivante » (contrairement à `_page.html.erb:46-53`). Une matière de plus de 24 leçons est tronquée alors que `lessons_total` affiche `page.total_count` (« 31 fiches de cours »). Le bloc téléphone, lui, pagine.
Preuve : `render partial: "catalog/courses/course_card", collection: page.rows` sans lien `courses_page_N` ; total = `page.total_count`.
Proposition : réutiliser le mécanisme `courses_page_N` pour `lessons_list` (ou monter la taille de page pour ce mode), ajouter un test système à 25 leçons.
Effort : M

#### O-C03 — Ouverture d'une leçon : une lecture + deux requêtes par fiche de révision (N+1 en écriture)
Gravité : P2 · Rôle/écran : élève, `/cours/:slug` · Fichier : `courses_controller.rb:81-92`
Description : `record_reads` boucle sur `@detail.essentials` : `find_by_slug` (1 requête) + policy + `reads.record` (upsert) par fiche, soit 3 à 5 notions = 3 à 5 SELECT + 3 à 5 écritures à chaque ouverture, sur un GET. Aucun regroupement, pas de `upsert_all`.
Preuve : `@detail.essentials.each do |row| essential = essentials.find_by_slug(slug: row.slug)`.
Proposition : un use case « RecordCourseReads » avec une seule écriture `upsert_all` sur les ids déjà présents dans `@detail` ; ne pas réécrire si `last_read_at` date de moins de quelques minutes. À mesurer (à confirmer : la page met ~0,09 s, ce coût est peut-être masqué).
Effort : M

#### O-C04 — Page leçon : `PrepareSheetsQuery` construit tout le contenu des feuilles pour n'afficher que des cartes
Gravité : P2 · Rôle/écran : tous, `/cours/:slug` (section « Prépare interros/devoirs ») · Fichier : `app/infrastructure/queries/catalog/prepare_sheets_query.rb:60-80,150-260`, `app/views/catalog/courses/_prepare_sheets.html.erb:28-41`, `sheets/_card.html.erb`
Description : la leçon n'affiche par feuille que titre, `sheet.exercises.size` et `passed`. Mais la query charge énoncés, `statement_blocks`, figures, toutes les questions, propositions, images, copies et tentatives de l'élève, mélange les items (`AnswerShuffle`), pour tous les exercices de la leçon. Ces données ne servent qu'aux pages `/cours/:slug/feuille/...`.
Preuve : `build_exercises` → `questions(ids)`, `copies(ids…)`, `question_list`, `play(row, …)` appelés depuis `call`, rendu par cartes uniquement dans `_prepare_sheets`.
Proposition : une variante `summary` (ids, titres, comptes, `passed`) pour la leçon ; la version complète seulement pour la page de la feuille. Gain probable sur les leçons riches (à mesurer).
Effort : M

#### O-C05 — Recherche du catalogue : `translate(lower(...)) LIKE '%x%'` sans index alors que `pg_trgm` est déjà activé
Gravité : P3 · Rôle/écran : tous, `/cours?q=` (recherche pendant la frappe, chaque frappe = 1 requête + 1 compte) · Fichier : `app/infrastructure/queries/shared/text_search.rb:16-19`, `db/schema.rb:16` (extension `pg_trgm`), `db/schema.rb:251-272` (aucun index trigramme sur `courses.name`)
Description : la recherche est un scan séquentiel. Négligeable aujourd'hui (peu de cours) mais, avec l'élève qui tape et `search#queue`, chaque frappe relance count + page. L'en-tête de la query annonce « sans extension ni index » alors que l'extension existe.
Proposition : index GIN `gin_trgm_ops` sur `translate(lower(name), …)` (ou colonne `unaccent`), seulement si le catalogue dépasse quelques centaines de lignes ; vérifier que le `search` Stimulus a un debounce ≥ 250 ms (à confirmer dans `app/javascript/controllers/search_controller.js`).
Effort : S

#### O-C06 — Tri « Leçon N » par regex SQL recalculée à chaque requête
Gravité : P3 · Fichier : `course_catalog_query.rb` (`LESSON_NUMBER`, `PROGRAM_ORDER`, `CATALOG_ORDER`)
Description : l'ordre des leçons vient de `substring(courses.subtitle from '(?i)leçon\s+(\d+)')::integer` dans l'`ORDER BY` : pas d'index possible, et l'ordre pédagogique dépend d'un texte libre (le sous-titre). Une coquille dans le sous-titre change l'ordre.
Proposition : colonne `lesson_number` (migration + backfill), triable et indexable ; garder le sous-titre comme libellé seul.
Effort : M

#### O-C07 — Référentiel (niveaux/séries/matières) relu à chaque requête de liste
Gravité : P3 · Fichier : `courses_controller.rb:207` (`filter_options`), `queries/catalog/referential_options_query.rb`
Description : `ReferentialOptionsQuery` est exécutée à chaque `index` (sélecteurs, `teacher_level_label`, `student_material`) sans mémo inter-requêtes. Données quasi statiques.
Proposition : `Rails.cache.fetch` court (5-10 min) invalidé à l'import/édition du référentiel.
Effort : S

#### O-C08 — Masquage d'une annonce : le carrousel est recalculé même sur la page « Annonces »
Gravité : P3 · Rôle/écran : élève, `/annonces` · Fichier : `communication/message_dismissals_controller.rb:42-47`, `message_dismissals/create.turbo_stream.erb:9-10`
Description : `load_announcements` exécute `inbox.card` + `inbox.carousel` (3-4 requêtes) à chaque masquage, alors que sur la liste le remplacement `student_home_announcements` n'a pas de cible (`create.turbo_stream.erb` le dit : « un remplacement sans cible ne fait rien »). Calcul gaspillé hors accueil.
Proposition : ne calculer le carrousel que si la requête vient de l'accueil (paramètre `from=home` ou en-tête `Referer`).
Effort : S

#### O-C09 — « Mes annonces » : un `<dialog>` d'archivage rendu par ligne (20 modales par page)
Gravité : P3 · Fichier : `communication/authored_messages/_row.html.erb:28-40`
Description : chaque ligne `manageable?` embarque son menu et sa modale complète : jusqu'à 20 dialogs dans le DOM pour 20 annonces.
Proposition : une seule modale partagée remplie via Stimulus (`data-action`) ou un `turbo_frame` chargé à la demande.
Effort : M

#### O-C10 — « Prochain exercice » : toute la liste des exercices candidats est chargée pour en choisir un
Gravité : P3 · Fichier : `queries/catalog/next_exercise_query.rb:32-37,55`
Description : le `pluck` ramène tous les exercices publiés de la matière (ou du cours), puis `pending.find { candidates.index(it) > index }` (O(n²)) côté Ruby. Appelé jusqu'à deux fois par `/cours` (matière mobile + matière ordinateur).
Proposition : filtrer en SQL (exercices sans session `completed` de l'élève, `LIMIT 1`), ou mémoïser par requête (déjà fait par matière dans `next_exercise_for`).
Effort : M

---

### UI / UX (U-C)

#### U-C01 — Liste des cours (élève, ordinateur) : « N fiches de cours » compte des leçons, mais montre des cartes de leçons
Gravité : P3 · Rôle/écran : élève, `/cours` ≥ 1024 px · Fichier : `index.html.erb:226`, `config/locales/catalog/courses.fr.yml:44-50`
Description : le compteur dit « 12 fiches de cours · Progression DPFC 2026-2027 » au-dessus de cartes titrées « LEÇON N ». Les en-têtes de carte emploient « leçon » alors que le commentaire locale (`courses.fr.yml:12-13`) affirme que « le mot leçon n'est pas du vocabulaire de l'écran ». Voir aussi W-C03.
Effort : S

#### U-C02 — Filtres de la liste (équipe/visiteurs connectés) : `select` avec rechargement par `change`, pas d'état « chargement » dédié
Gravité : P3 · Rôle/écran : équipe, `/cours` · Fichier : `index.html.erb:103-119`
Description : le frame `courses` passe en `aria-busy:opacity-50`, seul retour visuel du filtrage. Pas de squelette (alors que `moderations/index.html.erb:35-37` utilise `ui_loading_state variant: :skeleton` avec `group-aria-busy`). `aria-live="polite"` sur le total est en place (bon point).
Proposition : harmoniser avec le squelette de la modération.
Effort : S

#### U-C03 — Cartes de feuilles (« Prépare interros n°1 ») : la progression est un texte en italique gris, sans repère visuel de maîtrise
Gravité : P2 · Rôle/écran : élève, `/cours/:slug` · Fichier : `catalog/courses/sheets/_card.html.erb:11` (`<i class="ps-card-meta">`)
Description : « 1 / 3 exercices réussis » en `<i>` sans icône ni couleur ; aucune différence visuelle entre « jamais ouvert » (0/3) et « tenté, raté » (0/3). Pas d'indicateur Bronze/Argent/Or/Diamant pourtant disponible via `ExerciseBadge`.
Proposition : voir `## Médailles` ; afficher la meilleure médaille de la feuille en pastille + texte (jamais la couleur seule).
Effort : M

#### U-C04 — Message d'état « Tu vois seulement les fiches de cours de ton niveau » caché dans une infobulle
Gravité : P3 · Rôle/écran : élève mobile, `/cours` · Fichier : `index.html.erb:54-57` (`ui_info_tip`)
Description : l'information qui explique pourquoi la liste est limitée n'est accessible que par un toucher sur une icône (cible à vérifier ≥ 44 px, à confirmer dans `ui_info_tip`). Un élève qui cherche un cours d'un autre niveau tombe sur « Aucune fiche de cours ne correspond » sans cette explication.
Proposition : ajouter la phrase dans l'état vide de la recherche (`student_no_match_description`).
Effort : S

#### U-C05 — Pages d'erreur Rails (403/404) et pages statiques `public/*.html` : deux jeux de pages, vouvoiement figé
Gravité : P3 · Rôle/écran : tous · Fichier : `app/views/errors/not_found.html.erb`, `forbidden.html.erb`, `public/404.html:52`, `public/500.html:52`
Description : même page « Page introuvable » existe en deux versions (Rails dans le layout, statique hors Rails) avec des textes différents (« Le lien est peut-être ancien… » vs « Cette page n'existe pas ou n'est plus disponible. Vérifiez l'adresse… »). Pas de lien « Réessayer » sur la 500 (retour accueil seul), pas de bouton retour. Les 403/404 Rails n'ont pas de contenu spécifique selon le rôle.
Proposition : un seul texte source (clés I18n copiées dans les statiques par un script de build), ajouter « Réessayer » sur la 500.
Effort : S

#### U-C06 — Page hors ligne : le bouton « Réessayer » recharge `href=""` et reste muet si le réseau manque encore
Gravité : P3 · Rôle/écran : tous (PWA), `public/offline.html:15` · Fichier : `public/offline.html`, `app/views/pwa/service-worker.js:19-24`
Description : le lien `href=""` recharge la page courante, ce qui est correct, mais aucun retour (« Toujours pas de connexion ») n'est donné si l'échec se répète : l'utilisateur ne sait pas si son geste a été pris en compte. Le service worker ne met en cache que la page hors ligne (`OFFLINE_FILES`), donc aucune leçon lisible hors ligne (cohérent avec l'ADR-0082, mais voir W-C06).
Proposition : petit script de 3 lignes : `fetch('/')` + message de statut `aria-live` ; ou texte statique « Si la connexion revient, la page s'ouvrira. ».
Effort : S

#### U-C07 — Pratique « Je m'entraîne » : l'état « Correction » s'ouvre mais ne dit pas combien de cases sont justes
Gravité : P3 · Rôle/écran : élève, fiche de révision de la leçon · Fichier : `catalog/practice_checks/_result.html.erb:24-30`
Description : le retour est un seul message (`all_correct` / `some_wrong` / `incomplete`) et un verdict « Juste/À revoir » par case. C'est cohérent avec la maîtrise sans chiffre (bon point) mais aucun repère de progression ni de médaille ne se déclenche (l'entraînement est « sans trace », ADR-0119). Pas de défaut ; à noter pour la grille médaille (voir tableau).
Effort : —

#### U-C08 — Cartes d'annonce : zone de l'image/audio fixée à `w-24` et croix de masquage en position absolue
Gravité : P3 · Rôle/écran : élève mobile 390 px, accueil + `/annonces` · Fichier : `communication/messages/_card.html.erb:18-20,56`
Description : la colonne droite (`w-24 shrink-0`) réduit le texte à ~250 px à 390 px ; le titre (`text-base`) et le corps (`line-clamp-2`) restent lisibles, mais la croix (`size-tap`, 48 px) en `absolute top-0 right-0` chevauche le coin de l'illustration/lecteur audio de la colonne droite sur les cartes à image (à confirmer visuellement à 390 px).
Proposition : réserver `pr-12` sur l'en-tête de carte ou placer la croix dans le flux sur mobile.
Effort : S

#### U-C09 — Accueil public : matières en dur dans la vue, absentes sur téléphone
Gravité : P3 · Rôle/écran : visiteur, `/` · Fichier : `app/views/homepage/index.html.erb:8-10,60-71`
Description : la liste `subjects` (noms français en dur dans l'ERB) contredit la règle d'or 3 (I18n) ; la bande « Matières » est `hidden … lg:flex` : le visiteur sur téléphone (cas dominant en Côte d'Ivoire) ne voit aucune matière. L'accueil ne mentionne le programme ivoirien ni le niveau que dans l'alt de la photo.
Proposition : clés I18n ; une ligne réduite de matières sur mobile.
Effort : S

---

### Wording (W-C)

#### W-C01 — « À revoir » désigne trois choses différentes sur la même page de leçon
Gravité : P2 · Rôle/écran : élève, `/cours/:slug` · Fichier : `config/locales/catalog/courses.fr.yml:104,142` (`to_review`), `revision_sheets.fr.yml:14,22` (`wrong: "À revoir"`, `todo.label: "À revoir :"`), `essential_row.review`
Description : (1) une lacune de notion (« À revoir : fais cet exercice »), (2) l'exercice raté d'une feuille (`sheets.to_review`), (3) une case fausse dans « Je m'entraîne » (`practice.wrong: "À revoir"`). La feuille d'exercice, elle, dit « ✗ Faux » (`sheets.verdict.wrong`). Trois vocabulaires de verdict (Juste/Faux, Juste/À revoir, Réussi/À revoir).
Proposition : un lexique unique : verdict de case = Juste / Faux ; statut d'exercice = médaille (ou « Pas encore réussi ») ; « À revoir » réservé à la notion en lacune (UDR-0139 : « Notion à revoir »).
Effort : S

#### W-C02 — Mélange fiche essentielle / fiche de révision / notion / leçon / cours (glossaire vs écran)
Gravité : P2 · Rôle/écran : tous, `/cours*` · Fichier : `courses.fr.yml` (lignes 12-13, 76, 82, 97, 107, 108, 138), `glossaire.md:73-74`, UDR-0130, UDR-0139 §46-49
Description : le glossaire (UDR-0130) interdit « Notion(s) clé(s) » et « Leçon » comme nom d'objet, mais UDR-0139 a réintroduit « notion » comme intertitre et « Notion à revoir ». Résultat à l'écran : « Fiche de cours » (objet), « Cours » (rubrique), « leçon » (« Toute la leçon », « Révisions de la leçon », « Leçon 2 »), « Fiche de révision », « notion » (« Un exercice par notion », « Notion 1 / 4 », ancres `notion-…`), et dans le glossaire « Essential » = fiche de révision alors que `essentials_title` « Révisions de la leçon » est encore là. Le glossaire ne contient aucune entrée « Notion » (grep : seulement la ligne 74 et la table de remplacements, ligne 179).
Proposition : ajouter une entrée « Notion / Leçon » au glossaire (arbitrage UDR-0139 vs 0130) et passer toutes les clés par une liste de termes autorisés (test de lint I18n sur « essentielle », « habileté »).
Effort : M

#### W-C03 — « Progression DPFC 2026-2027 » codée en dur dans trois locales et deux regex de vue
Gravité : P2 · Rôle/écran : élève et enseignant, `/cours` · Fichier : `courses.fr.yml:10-11,22`, `_course_card.html.erb:25`, `_teacher_course.html.erb:1` (regex `/\AProgression DPFC/i`), `index.html.erb`
Description : l'année scolaire est dans les textes ET dans un filtre qui retire cette expression du sous-titre des cours. À la rentrée 2027-2028 il faudra modifier locales, données importées et regex ; « DPFC » (sigle) n'est expliqué nulle part dans le glossaire (à confirmer). De plus, « Progression » ici désigne le programme officiel, pas la progression de l'élève : mot ambigu à côté de « En cours / Terminée ».
Proposition : `Rails.configuration.x.school_year` + clé unique ; renommer en « Programme DPFC 2026-2027 ».
Effort : S

#### W-C04 — Ton incohérent dans les pages d'erreur et d'accès (tu/vous)
Gravité : P3 · Rôle/écran : élève, 403 · Fichier : `config/locales/errors/pages.fr.yml:6-7` (« votre espace »), `public/*.html` (« Vérifiez… », « Réessayez… »), `public/offline.html` (« Vérifie ton réseau »)
Description : l'élève est tutoyé partout (accueil, FAQ, vide du catalogue, offline) mais vouvoyé sur 403/404/422/500. L'offline tutoie (même public). Aucune règle de choix selon le rôle (les pages statiques ne peuvent pas la connaître).
Proposition : décider d'un registre unique neutre pour les pages sans rôle (ex. forme impersonnelle : « Cette page n'existe pas ou n'est plus disponible. »), tutoiement conservé seulement dans l'espace élève.
Effort : S

#### W-C05 — Verbes de statut incohérents entre feuilles et résultats : « Réussi », « Terminée », « Juste », « Acquis »
Gravité : P2 · Fichier : `courses.fr.yml:79-81,142-147`, `common.fr.yml:72-73` (`acquired`, `fragile`), `layouts.fr.yml:28`
Description : la liste des cours dit « Terminée » (toutes les fiches *lues*), la feuille « Réussi », la FAQ « Acquis / Fragile / En difficulté », la FAQ badges « Bronze… Diamant ». « Terminée » sur une carte de cours laisse croire à une maîtrise acquise alors qu'elle signifie seulement « lu » (voir C-C04).
Proposition : « Lue » / « Fiches lues » pour la lecture, médaille pour la maîtrise.
Effort : S

#### W-C06 — Pastille d'accueil « Même sans internet » : promesse contredite par la page hors ligne
Gravité : P2 · Rôle/écran : visiteur, `/` · Fichier : `config/locales/homepage/index.fr.yml:2-3,10`, `public/offline.html:12`, `pwa/service-worker.js:4`
Description : la locale reconnaît (« décision du porteur : la lecture hors ligne arrive ensuite ») que la pastille annonce une fonction absente ; le service worker ne met en cache que `/offline.html`, `/offline.css`, `/icon-192.png`, et la page hors ligne dit « Lnclass a besoin d'internet pour s'ouvrir ». Contradiction visible au premier hors-ligne.
Proposition : retirer la pastille tant que la lecture hors ligne n'existe pas, ou la reformuler (« Léger sur ton téléphone »).
Effort : S

#### W-C07 — Pluralisation et orthographe : « Fiches de cours » dans le commentaire du tout premier titre, « Effacer la recherche » vs « Tout voir »
Gravité : P3 · Fichier : `courses.fr.yml:23-24,66,69-71` (`reset: "Tout voir"` vs `clear_search: "Effacer la recherche"`, deux libellés pour la même action selon le contexte), `public.fr.yml`
Description : deux actions équivalentes (« Tout voir » dans le frame, « Effacer la recherche » dans l'état vide). Libellé `new_course: "Nouvelle fiche de cours"` correct. Aucune faute d'orthographe relevée dans les fichiers lus.
Proposition : « Effacer la recherche » partout.
Effort : S

---

### Cohérence « maîtrise par médaille » (C-C)

#### C-C01 — FAQ `/aide` : l'échelle de notes /20 et « Meilleure note » sont expliquées comme règle centrale
Gravité : P1 · Rôle/écran : tous (élève surtout), `/aide` · Fichier : `config/locales/communication/help.fr.yml:30-46`, `communication/help/show.html.erb:6-10`
Description : cinq questions sur sept sur la notation parlent de notes : « Comment ma note sur 20 est-elle calculée ? » (« 8 bonnes réponses sur 10, c'est 80 %, soit 16/20 »), « Comment gagner un badge ? » (« Bronze dès 10/20, Argent dès 14/20, Or dès 16/20 »), « Que veut dire Maîtrise ? » (« Acquis dès 14/20, Fragile dès 10/20, En difficulté sous 10/20 »), « À revoir » (« moins de 10/20 »), « Meilleure note et ton badge restent acquis ». `show.html.erb` calcule les seuils sur 20 (`grading.grade_on_20`). Trois échelles coexistent : % brut, note /20, médaille, plus une 4e (Acquis/Fragile/En difficulté).
Preuve : `answer: "Elle vient de la part de bonnes réponses : 8 bonnes réponses sur 10, c'est 80 %…"`.
Proposition : réécrire en médailles seules : « Bronze = tu as compris l'essentiel… Diamant = sans-faute », supprimer la question « note sur 20 » et la question « Maîtrise », garder « À revoir » exprimée en « pas encore Bronze ». Les seuils numériques (ADR-0033) restent dans le domaine, plus dans la FAQ.
Effort : M

#### C-C02 — « Réussi » sur les cartes de feuilles = 100 % de bonnes réponses, sans lien avec la médaille
Gravité : P1 · Rôle/écran : élève, `/cours/:slug` (« n / N exercices réussis ») · Fichier : `prepare_sheets_query.rb:201` (`passed: correct == count`), `sheets/_card.html.erb:11`, `courses.fr.yml:144-148`
Description : `Copy.passed` ne vaut vrai que si toutes les questions sont justes : l'élève qui obtient Bronze, Argent ou Or n'est jamais compté « réussi » sur la carte, alors que `ExerciseBadge` le récompense. Le statut sur l'exercice (« Réussi / À revoir », `_exercise.html.erb:24`) suit la même règle. Résultat : la leçon affiche « 0 / 3 exercices réussis » alors que l'élève a trois médailles. Faux signal décourageant.
Preuve : `Copy.new(session_public_id: public_id, passed: correct == count)`.
Proposition : remplacer `passed` par la médaille du badge de l'exercice (`bronze/silver/gold/diamond/none`) ; carte : « 2 médailles sur 3 exercices » ou 3 pastilles.
Effort : M

#### C-C03 — « Réussi » suit la DERNIÈRE copie, la FAQ promet que la meilleure reste acquise
Gravité : P2 · Fichier : `prepare_sheets_query.rb:190-195` (`DISTINCT ON … ORDER BY completed_at DESC`), `help.fr.yml:49-50`
Description : la FAQ dit « Ta meilleure note et ton badge restent acquis ». La carte de feuille lit la dernière session terminée : refaire un exercice et le rater fait repasser « Réussi » en « À revoir » alors que le badge est conservé. Incohérence (le comportement « badge ne baisse jamais » est ADR-0033).
Proposition : lire le badge (monotone) plutôt que la dernière copie.
Effort : S

#### C-C04 — « En cours » / « Terminée » sur les cours = lecture des fiches, présentée comme avancement d'apprentissage
Gravité : P2 · Rôle/écran : élève, `/cours` · Fichier : `course_catalog_query.rb` (`progress_of`, `NEUTRAL`), `_course_card.html.erb:46-60`, `courses.fr.yml:79-81`
Description : `:done` = toutes les fiches publiées ont été *ouvertes* (`essential_reads`), pas comprises. L'élève voit une coche verte « Terminée » sur une leçon dont il a raté tous les exercices. Mélange lecture / progression / maîtrise sur un même pictogramme.
Proposition : conserver « Lue » (neutre) ; ajouter à côté la meilleure médaille de la leçon (agrégat des badges de ses exercices). Voir tableau.
Effort : M

#### C-C05 — « Prépare interros » : compteurs enseignant « n / N élèves ont réussi » = taux de réussite de classe
Gravité : P2 · Rôle/écran : enseignant, `/cours/:slug` (vue classe) · Fichier : `courses.fr.yml:123-127`, `sheets/_success.html.erb`
Description : « 8 / 24 élèves ont réussi » est une moyenne de classe déguisée (le commentaire dit « jamais de pourcentage seul »). Pas de répartition par médaille. Avec la maîtrise par médaille, l'enseignant a besoin de la distribution (combien en Bronze/Argent/Or/Diamant, combien sans médaille).
Proposition : 4 compteurs de médailles + « sans médaille » ; supprimer le ratio.
Effort : M

#### C-C06 — Pages de l'épreuve (`paper`) : points par exercice « (3 points) »
Gravité : P3 · Rôle/écran : élève/enseignant, `/cours/:slug/feuille/:id` · Fichier : `courses.fr.yml:189-191`, `sheets/_paper.html.erb:11,25-30`
Description : l'épreuve est présentée « en forme d'épreuve officielle » avec points par exercice. Ce n'est pas une note affichée à l'élève, mais c'est un barème chiffré visible avant de faire l'exercice, qui entre en conflit avec l'esprit « maîtrise ».
Proposition : à trancher avec le porteur : garder (décor d'épreuve) ou supprimer l'affichage des points.
Effort : S

#### C-C07 — Entraînement « Je m'entraîne » sans médaille : aucun lien avec la maîtrise
Gravité : P3 · Fichier : `revision_sheets.fr.yml:20-34`, `catalog/practice_checks/_result.html.erb`
Description : l'entraînement (ADR-0119 « sans trace ») juge case par case et ne produit rien. Cohérent et sans chiffre (conforme à la cible). Seule remarque : « Tout est juste, bravo ! » est la seule récompense ; ne pas ajouter de score ici.
Effort : —

---

## Constats — Optimisations transverses

Bilan global : le code des queries/repositories est déjà très sobre. Aucun N+1 net trouvé : les listes sont paginées (catalogue 24, écoles 50, élèves 30 cumulés, annonces 20, imports 50) et les imports passent par des jobs avec `insert_all!` par lots de 100. Les constats ci-dessous sont donc surtout des risques d'échelle ou de configuration. Rien n'a été exécuté (pas d'EXPLAIN) : les risques d'index sont marqués « à confirmer ».

#### O-X01 — Pool de connexions DB sous-dimensionné face à Puma + Solid Queue dans le même process
Gravité : P1 (à confirmer selon les variables Railway)
Écran/rôle : tous · toutes les URL, surtout pendant un import (`/teams/imports`)
Fichier:ligne : config/database.yml:3 · config/puma.rb:28,48 · config/queue.yml
Description : Puma lance 3 threads web (`RAILS_MAX_THREADS` défaut 3) et le plugin `solid_queue` dans le même process, qui ouvre en plus 1 dispatcher, 3 threads de worker, le scheduler et le heartbeat du superviseur. Ils consomment tous le pool de la base principale, dont `max_connections` vaut `RAILS_MAX_THREADS` (3, ou 5 selon l'env). Pendant un import long, les requêtes web peuvent attendre une connexion (`ConnectionTimeoutError`) et les threads du worker concurrencent le GVL des threads web.
Preuve : `max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>` ; `threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)` ; `plugin :solid_queue unless PrEnvironment.active?` ; `workers: threads: 3`. Une seule réplique (`.railway/railway.ts:31`). Les valeurs réelles de `RAILS_MAX_THREADS` / `JOB_CONCURRENCY` en prod ne sont pas dans le dépôt : à confirmer.
Proposition : fixer `max_connections` à web threads + worker threads + 2 (~10) ; passer les workers à 1 ou 2 threads, ou déplacer Solid Queue dans un service Railway séparé (`bin/jobs`) ; poser un `RAILS_MAX_THREADS` explicite dans railway.ts.
Effort : S

#### O-X02 — `limits_concurrency` des imports sans `duration` : le verrou tombe après 3 min par défaut
Gravité : P2
Écran/rôle : équipe · `/teams/imports`
Fichier:ligne : app/jobs/shared/import_job.rb:7 · app/jobs/classroom/generate_missing_classrooms_job.rb:7
Description : `RegenerateSchoolCodesJob` et `RegenerateClassroomLinksJob` passent `duration: STALE_AFTER.seconds` (10 min), mais `Shared::ImportJob` (cours, écoles, DRENA) et `GenerateMissingClassroomsJob` n'ont que `to: 1`. Le sémaphore Solid Queue expire alors à son délai par défaut (3 min, d'après la valeur par défaut de la gem : à confirmer). Un import de 20 Mo / 5 000 lignes qui dépasse 3 min laisse un second job du même type démarrer en parallèle.
Preuve : `limits_concurrency to: 1, key: ->(_report_id) { self.class.name }` (sans duration). Le garde-fou `import_reports_one_running_per_kind` (schema.rb, index unique partiel) et `claim` évitent la corruption, mais le second job échoue en conflit au lieu d'attendre.
Proposition : ajouter `duration: UseCases::Catalog::StartImport::STALE_AFTER.seconds` aux deux jobs, comme pour les deux autres.
Effort : S

#### O-X03 — Aucun `retry_on` / `discard_on` générique sur ApplicationJob ; une exception remonte sans retry maîtrisé
Gravité : P3
Écran/rôle : équipe, tâches planifiées · jobs
Fichier:ligne : app/jobs/application_job.rb:5-9
Description : `retry_on ActiveRecord::Deadlocked` est commenté. Les imports ne se rejouent pas (voulu : `RunImport` passe le rapport en `failed` puis relève l'exception), mais les tâches récurrentes (purges, `PublishScheduledMessagesJob` toutes les 5 min) n'ont ni retry sur deadlock ni sur coupure de connexion. Elles repassent à la prochaine échéance, donc l'impact est faible.
Preuve : `# retry_on ActiveRecord::Deadlocked` (commenté).
Proposition : activer `retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3` dans ApplicationJob, et laisser les imports en `retry_on` explicite vide.
Effort : S

#### O-X04 — Tableau de bord équipe : 7 et 30 jours lus en direct, plusieurs balayages d'`exercise_sessions` et `users`
Gravité : P2
Écran/rôle : équipe · `/teams/dashboard` (périodes 7 jours / 30 jours)
Fichier:ligne : app/infrastructure/queries/school/team_dashboard_query.rb:34,63-67,135-179
Description : seule la période `year` est mise en cache 5 min (`CACHED_PERIODS = %w[year]`). 7 et 30 jours relancent à chaque affichage une dizaine de requêtes d'agrégats : `COUNT(*) FILTER (WHERE student_id IN (SELECT student_id FROM exercise_sessions WHERE started_at >= …))` par couple niveau×DRENA (l. 174-177), `distinct.count(:student_id)` des sessions de la période, `AVG(score_percent)`, `active_users.group(:role).count` (balayage de `users`), `COVERAGE` avec 3 `EXISTS` corrélés par école. Avec des centaines de milliers de sessions, la période 30 jours coûte plusieurs secondes. Les agrégats ne contiennent aucune donnée personnelle : le cache est sans risque (seul `recent_signups` est lu en direct, déjà exclu).
Preuve : `CACHED_PERIODS = %w[year].freeze` ; `Orm::ExerciseSession.where(started_at: @since..).select(:student_id).to_sql` injecté en sous-requête.
Proposition : mettre en cache aussi `7d` et `30d` (TTL 1-2 min, clé avec `@since` arrondi à l'heure ou au jour, car `period.since` varie à chaque appel et ruinerait le cache). Remplacer le `IN (subquery)` par un `EXISTS` ou une jointure sur une table dérivée `SELECT DISTINCT student_id`.
Effort : M

#### O-X05 — Index manquant sur `classroom_students.student_id` hors adhésion principale active
Gravité : P2 (à confirmer par EXPLAIN)
Écran/rôle : élève, enseignant, direction · `/student/archive` (StudentArchive), rejoindre/quitter une classe, accueil direction
Fichier:ligne : db/schema.rb (`classroom_students`) · app/infrastructure/queries/classroom/student_archive_query.rb:33,39 · app/infrastructure/repositories/classroom/membership_repository.rb:45
Description : les seuls index sont `(classroom_id, student_id)` (unique) et `student_id WHERE "primary" AND left_at IS NULL` (partiel). Les requêtes qui filtrent seulement `student_id:` (`ClassroomStudent.exists?(student_id:)`, `.where(student_id:).…` sur l'historique, `where(student_id:, left_at: nil).update_all`) ne peuvent pas utiliser l'index partiel, ni l'index composite (mauvaise colonne de tête) : balayage séquentiel de la table. Les jointures `classroom_students ON student_id = exercise_sessions.student_id AND left_at IS NULL` (direction_home_query.rb:~64, teacher_follow_ups_query.rb:~89) sont dans le même cas.
Preuve : `t.index ["student_id"], name: "index_classroom_students_one_active_primary", unique: true, where: "(\"primary\" AND (left_at IS NULL))"`.
Proposition : migration `add_index :classroom_students, :student_id, algorithm: :concurrently` (+ `disable_ddl_transaction!`). La table croît d'une ligne par élève et par année : le coût d'écriture est négligeable.
Effort : S

#### O-X06 — « Accueil direction » : le calcul « fait seul » part de toutes les sessions de la plateforme
Gravité : P2
Écran/rôle : direction · accueil direction (DirectionHomeQuery, cache 5 min par école)
Fichier:ligne : app/infrastructure/queries/school/direction_home_query.rb:~62-70 (`self_practice_by_level`) · app/infrastructure/queries/classroom/classroom_overview_query.rb:95-98
Description : la requête prend d'abord `ExerciseSession.self_practice(today)` (toutes les sessions terminées sans assignation des 7 derniers jours, de toutes les écoles), puis joint users/classroom_students/classrooms pour garder une école. Le filtre `schools` arrive après. Sans index sur `student_id` côté `classroom_students` (O-X05), PostgreSQL passera par un hash join sur la fenêtre complète. Coût proportionnel à l'activité nationale, pour chaque école et toutes les 5 min.
Preuve : `.where(classrooms: { school_id:, school_year:, status: "active" })` placé après les `joins` de la fenêtre nationale ; `.group("levels.slug").distinct.count(:id)`.
Proposition : partir des élèves de l'école (`WHERE exercise_sessions.student_id IN (SELECT student_id FROM classroom_students JOIN classrooms … WHERE school_id = ?)`) pour que l'index `(student_id, completed_at)` serve ; ou calculer dans une seule passe pour toutes les écoles et en cache. À valider par EXPLAIN.
Effort : M

#### O-X07 — `last_sessions` : `DISTINCT ON` sur toutes les sessions terminées des élèves de la page
Gravité : P3
Écran/rôle : enseignant · classe `/classrooms/:id` (liste des élèves, 30 par page)
Fichier:ligne : app/infrastructure/queries/classroom/classroom_overview_query.rb:169-173
Description : `ExerciseSession.where(student_id: ids, status: "completed").order(:student_id, completed_at: :desc).pluck("DISTINCT ON (student_id) …")` lit toutes les sessions terminées de ces ≤ 30×N élèves pour n'en garder qu'une chacune. La page cumulative (`PER_PAGE * page`, jusqu'à MAX_STUDENTS_LIMIT) augmente le nombre d'élèves. L'index `(student_id, completed_at)` permet un index scan ordonné, donc c'est acceptable aujourd'hui ; ce n'est pas un problème tant que les élèves ont < ~200 sessions chacun.
Preuve : `.order(:student_id, completed_at: :desc).pluck(Arel.sql("DISTINCT ON (student_id) student_id"), …)`.
Proposition : surveiller ; si la durée monte, passer à `LATERAL JOIN … ORDER BY completed_at DESC LIMIT 1` par élève ; ou dénormaliser `last_score_percent` sur `classroom_students`.
Effort : M

#### O-X08 — Liste de classe : les courses/assignations sont rechargés à chaque page « charger la suite »
Gravité : P3
Écran/rôle : enseignant · `/classrooms/:id?page=N`
Fichier:ligne : app/infrastructure/queries/classroom/classroom_overview_query.rb:75-89
Description : `call` recalcule à chaque page cumulative : `standings` (scores de toute la classe), les assignations, le bloc cours, `follow_up`. Le coût est borné à la classe (≤ MAX_STUDENTS_LIMIT), pas de N+1 (« Deux requêtes, quel que soit l'effectif »), mais la page 3 refait tout ce que la page 1 avait déjà lu. Faible volume : environ 40 élèves.
Preuve : `roster = show_roster ? roster(id, search, since, today, page, badge)` + `assignments(id, show_follow_up)` + `courses(...)` recalculés à chaque appel.
Proposition : si le chargement progressif passe par Turbo Frame, ne rendre que `students` pour `page > 1` (sauter `assignments`, `courses`, `session_days`). Gain faible.
Effort : S

#### O-X09 — Imports : fichier entier téléchargé et parsé en mémoire, tables de clés existantes chargées entièrement
Gravité : P2
Écran/rôle : équipe · `/teams/imports` (cours, écoles, DRENA)
Fichier:ligne : app/infrastructure/repositories/catalog/import_file_store.rb:~21-25 · app/domain/use_cases/catalog/run_import.rb:115-120,161-163 · app/infrastructure/repositories/catalog/essential_repository.rb:49-51 · app/infrastructure/repositories/assessment/exercise_repository.rb:71-73 · app/domain/use_cases/school/import_schools.rb:~46-50
Description : `blob.download` charge jusqu'à 20 Mo (`MAX_BYTES`) en String, `JSON.parse` en crée l'arbre (facteur 3-5 : 60-100 Mo), l'envoi peut compter plusieurs fichiers (`max_total_bytes`) conservés dans `@sources` jusqu'à la fin. `existing_keys(…)` charge toutes les clés naturelles en `Set` ; `Essential.all` / `Exercise.all` sans filtre si `course_ids:` / `essential_ids:` sont nil (paramètre par défaut, à confirmer selon l'appelant : les adaptateurs de cours ne semblent pas appeler `existing_keys` avec nil). Tout se passe dans le process web (Solid Queue dans Puma, O-X01) : un OOM sur un petit conteneur Railway tuerait aussi le web.
Preuve : `attachment.blob.download.force_encoding(Encoding::UTF_8)` ; `Orm::Essential.all` quand `course_ids.nil?` ; `max_roots: 5_000` ; `MAX_BYTES = 20 * 1024 * 1024`.
Proposition : mesurer le pic mémoire d'un import de 20 Mo en préproduction ; imposer `course_ids:` obligatoire dans les deux `existing_keys` ; envisager `Oj`/streaming ou 10 Mo par envoi si le conteneur a < 512 Mo ; sortir les jobs d'import du process web.
Effort : M

#### O-X10 — `ContentTreeWriter#rewrite` détruit via callbacks ligne par ligne (Action Text, images)
Gravité : P3
Écran/rôle : équipe · import de cours complets qui remplace une leçon en brouillon
Fichier:ligne : app/infrastructure/repositories/catalog/content_tree_writer.rb:114,210
Description : `texts.each(&:destroy!)` et `images.find_each(&:destroy!)` détruisent un à un les `ActionText::RichText` et `QuestionImage` d'une leçon (nécessaire pour purger les blobs Active Storage ; commenté « pour que ses pièces jointes partent avec lui »). Une leçon comptant 100 images génère ~300 requêtes + des `purge_later` dans la transaction du lot. Acceptable pour une leçon à la fois (lots de 100 racines = 100 leçons possibles ⇒ jusqu'à plusieurs milliers de requêtes dans une seule transaction).
Preuve : `deleted[:course_text] = texts.each(&:destroy!).size` ; `images.find_each(&:destroy!)`.
Proposition : conserver (correct) ; si un import de masse de leçons remplacées devient courant, collecter les `blob_id` et purger en dehors de la transaction avec `ActiveStorage::Blob.where(id:).find_each(&:purge_later)`, et réduire `BATCH_SIZE` pour les cours (verrous longs).
Effort : M

#### O-X11 — `ExerciseRepository#write_questions` : 1 INSERT par question et par réponse, plus `UPDATE` d'image par question
Gravité : P3
Écran/rôle : équipe · création/modification d'exercice (`/teams/exercises`), import de cours (via un autre writer)
Fichier:ligne : app/infrastructure/repositories/assessment/exercise_repository.rb:107-124
Description : `Orm::Question.create!` + `Orm::Answer.create!` dans une boucle, plus `attach_image` (1 `update_all` par question). Pour un exercice de 20 questions × 4 réponses : ~100 INSERT + callbacks/validations AR. Le volume (écriture rare, par l'équipe) reste faible. De même `record_copy` (exercise_session_repository.rb:57-63) crée une tentative à la fois (une copie de 20 questions → 20 INSERT dans un savepoint) à chaque rendu de copie d'élève : plus fréquent.
Preuve : `question.answers.each_with_index do |answer, rank| Orm::Answer.create!(…)` ; `written.each do |attempt| Orm::QuestionAttempt.create!(…)`.
Proposition : `Orm::Answer.insert_all!` par question (ou un seul pour tout l'exercice avec `returning: id`) ; `Orm::QuestionAttempt.insert_all!` pour `record_copy` (garder la contrainte unique pour le `RecordNotUnique`).
Effort : S

#### O-X12 — Chargement et tri en Ruby de toutes les lignes d'une DRENA pour paginer (`DrenaSchoolsQuery`)
Gravité : P3
Écran/rôle : équipe · `/teams/dashboard?drena=…` (liste des établissements de la DRENA, pagination 25)
Fichier:ligne : app/infrastructure/queries/school/drena_schools_query.rb:25-45
Description : `rows` ramène tous les établissements de la DRENA avec leurs 3 agrégats, puis `page` découpe en Ruby (`rows.slice`) ; la recherche ajoute un second `pluck` de `public_id` pour tout filtrer en Ruby. L'objectif est la cohérence (`figures` + `school_rows` au même instant, mis en cache avec `figures`). Le volume est borné à quelques centaines d'écoles par DRENA, ce qui reste raisonnable ; le cache 5 min de `figures` amortit.
Preuve : `rows.slice((page - 1) * PER_PAGE, PER_PAGE)` ; `Orm::School.where(public_id: rows.map(&:public_id))`.
Proposition : acceptable. Pour une DRENA de > 1 000 écoles, ajouter un `LIMIT/OFFSET` SQL avec `COUNT(*) OVER()`.
Effort : M

#### O-X13 — `TeamHomeQuery` : 7 `COUNT(*)` sur tables entières à chaque accueil équipe
Gravité : P3
Écran/rôle : équipe · `/teams` (accueil)
Fichier:ligne : app/infrastructure/queries/catalog/team_home_query.rb:19-24
Description : `Orm::Drena.count`, `Orm::School.count`, `Orm::Classroom…count`, `Orm::Series.count`, `Orm::Material.count` plus `classroom_plan_total` (deux repositories) sont exécutés à chaque visite, « sans cache » par choix documenté (CA-25 : un compteur suit la dernière création). `School.count` et `Classroom.count` sont des balayages d'index sur quelques milliers de lignes : < 10 ms. Aucun risque réel aujourd'hui.
Preuve : « Lecture directe des tables, sans cache : un compteur suit la dernière création de l'équipe (CA-25) ».
Proposition : laisser tel quel. Si > 100 000 classes : cache 30 s invalidé à la création.
Effort : S

#### O-X14 — Fichiers images non référencés et lourds : `app/assets/images/assets/bg.png` (2,4 Mo)
Gravité : P2 (à confirmer)
Écran/rôle : tous · `/assets/*` (livré par Propshaft), image Docker
Fichier:ligne : app/assets/images/assets/bg.png (2 498 217 octets) · bg_lnclass.png (144 Ko) · app/assets/images/logo/school.jpg (94 Ko)
Description : aucune référence à `bg.png` / `bg_lnclass.png` dans `app`, `lib`, `config`, `public` ni `test` (grep sur `bg(_lnclass)?\.png`, `assets/bg`). Propshaft digère et publie tout le dossier : l'image reste dans l'image Docker et sert si quelqu'un l'appelle par URL. Une `bg_lnclass.svg` existe déjà. Si une vue la charge dynamiquement par nom, la page paierait 2,5 Mo (à confirmer). Le reste (logos 25-95 Ko, illustrations de matières en SVG/WebP) est correct.
Preuve : `2498217 app/assets/images/assets/bg.png` ; absence de référence.
Proposition : confirmer l'usage (grep dans les vues et le CSS compilé) puis supprimer, ou convertir en WebP/AVIF (< 150 Ko) à la bonne largeur. Compresser `logo/school.jpg`, `teacher.jpg`, `team.jpg` (94/56/54 Ko) ; fournir des dimensions (`width`/`height`) aux `image_tag` du header (`shared/navigation/_header.html.erb:19,34,47`, qui n'ont que des classes Tailwind) pour limiter le CLS. 
Effort : S

#### O-X15 — Un seul `application.css` + trois feuilles de fiches ; `image_tag` du logo (JPEG) en tête de chaque page
Gravité : P3
Écran/rôle : tous
Fichier:ligne : app/assets/stylesheets/ (application.tailwind.css 31 Ko, course_sheet.css 20 Ko, prepare_sheet.css 22 Ko, exam_sheet.css 8 Ko) · app/views/layouts/application.html.erb:36-38
Description : le CSS Tailwind compilé est minifié par `build:css`; les feuilles de fiches ne sont chargées que par les pages concernées (à confirmer : `grep stylesheet_link_tag`). Un seul `preload` de police (`dm-sans-latin-wght-normal.woff2`). Le logo `lnclass.jpeg` (25 Ko) est servi en `<img>` 36-64 px sans dimensions déclarées sur plusieurs vues. Pas de problème majeur de taille de bundle : JS 716 Ko de sources, KaTeX/Trix/figures chargés à la demande par `import()` (math_controller.js:25, rich_text_editor_controller.js:62, figure_controller.js:40), splitting esbuild actif.
Preuve : `splitting: true`, `minify: true` (esbuild.config.mjs) ; `await import("katex/contrib/auto-render")`.
Proposition : ajouter `width`/`height` aux logos ; servir une version 72 px (WebP) du logo ; ajouter `font-display: swap` si absent (à confirmer dans la `@font-face`).
Effort : S

#### O-X16 — Cache HTTP : bon sur les images Active Storage, absent sur les pages publiques
Gravité : P3
Écran/rôle : visiteur anonyme · pages publiques (`/`, `/cours/…`, `/blog`)
Fichier:ligne : app/controllers/catalog/public_controller.rb · app/controllers/communication/articles_controller.rb (pas de `expires_in`/`fresh_when`) ; vs app/controllers/communication/sitemaps_controller.rb:12,20 et article_images_controller.rb:26-27
Description : seuls sitemap, photos, images d'article/question ont `Cache-Control`/ETag. Les pages publiques du catalogue et du blog (`PublishedArticlesQuery` 10/page, `PublicCourses`) sont recalculées à chaque visite, sans `fresh_when` ni `Rails.cache`. Charge actuelle faible ; trafic SEO/partage de liens possible. Thruster (HTTP cache/compression) est devant Puma, mais ne met en cache que si la réponse porte des en-têtes publics.
Preuve : `grep -rn "expires_in\|fresh_when\|stale?" app/controllers` ne trouve que les 6 contrôleurs ci-dessus ; `config.public_file_server.headers = { "cache-control" => "public, max-age=1 an" }` couvre les assets.
Proposition : `expires_in 5.minutes, public: true, stale_while_revalidate: 1.minute` sur les pages publiques sans session (comme `sitemaps_controller.rb` qui prend déjà soin d'éviter le cookie/nonce CSP) ; ou `fresh_when` sur `updated_at` max des articles.
Effort : M

#### O-X17 — `PurgeUnattachedBlobsJob` : `find_each(&:purge_later)` met en file un job par blob
Gravité : P3
Écran/rôle : tâche planifiée 3h00
Fichier:ligne : app/jobs/shared/purge_unattached_blobs_job.rb:9
Description : en cas de gros arriéré (premier passage, ou ~10 000 blobs non rattachés), la boucle insère autant de `ActiveStorage::PurgeJob` dans `solid_queue_jobs` dans le process principal, 3 threads de worker, tout de suite après avoir été planifiée. Le job est idempotent (un blob déjà purgé n'est plus sélectionné), donc sûr.
Preuve : `ActiveStorage::Blob.unattached.where(created_at: ...GRACE_PERIOD.ago).find_each(&:purge_later)`.
Proposition : `purge` direct en lots de 100 avec `sleep` court, ou `limit(1_000)` par exécution (le reste passe à la nuit suivante).
Effort : S

#### O-X18 — Solid Cable configuré (polling 0,1 s) alors qu'aucune diffusion Turbo n'est utilisée
Gravité : P3
Écran/rôle : tous
Fichier:ligne : config/cable.yml:12-15
Description : aucune occurrence de `turbo_stream_from` ni `broadcast_*` dans `app/` (recherche textuelle faite) : les `*.turbo_stream.erb` sont des réponses à des requêtes, pas des diffusions. Pas de broadcast trop large à signaler. Si un client ouvre un `ActionCable` (aucun abonnement trouvé), `polling_interval: 0.1.seconds` ferait une requête SELECT toutes les 100 ms par process. Aucun abonné ⇒ pas de coût (Solid Cable ne poll qu'avec des abonnés : à confirmer).
Preuve : `polling_interval: 0.1.seconds`, `message_retention: 1.day`.
Proposition : si le cable n'est pas utilisé, retirer `solid_cable` et la table `solid_cable_messages`. Sinon passer le polling à 0,5-1 s.
Effort : S

#### O-X19 — Pas de `PrepareSheetsQuery` borné : toute la leçon (exercices + questions + réponses) en une page
Gravité : P3
Écran/rôle : élève, enseignant, équipe · `/courses/:slug/prepare…` (Prépare interros / devoirs)
Fichier:ligne : app/infrastructure/queries/catalog/prepare_sheets_query.rb:57-79,173-187
Description : 3 requêtes (exercices, questions, réponses, images) pour toute la leçon puis construction d'objets Data en mémoire. Pas de N+1 (documenté et vérifié dans le code), mais aucune borne : une leçon avec 60 exercices × 10 questions × 4 réponses ≈ 2 400 lignes réponses, ≈ 30-50 ms et un HTML volumineux. La vue peut dépasser 500 Ko, à confirmer en rendant une leçon réelle.
Preuve : `Orm::Answer.where(question_id: ids).order(:question_id, :position, :id).pluck(…)`.
Proposition : à mesurer sur la plus grande leçon réelle ; charger une feuille par `turbo_frame` différé si le HTML dépasse 300 Ko.
Effort : M

#### O-X20 — Aucun index sur `classroom_assignments.due_on` pour les accueils enseignant et direction
Gravité : P3 (à confirmer)
Écran/rôle : enseignant · accueil `/teacher` (suivi des devoirs)
Fichier:ligne : app/infrastructure/queries/classroom/teacher_follow_ups_query.rb:~75-85 · db/schema.rb (`classroom_assignments`)
Description : `where(due_on: window).or(where(due_on: nil))` joint `classrooms` filtrées par `school_id`/`status`/`school_year` et `TeacherClassroom` ; le planificateur partira vraisemblablement de `classrooms` puis de l'index `classroom_id`, donc sans besoin d'un index sur `due_on`. L'index `assigned_at` seul est utile pour d'autres écrans. Pas d'action tant qu'un EXPLAIN ne le montre pas.
Preuve : indexes listés : `classroom_id`, `(classroom_id, assignable_type, assignable_id)` partiel actif, `assigned_at`.
Proposition : mesurer sur une base de volume réel avant d'ajouter `(classroom_id, due_on) WHERE status = 'active'`.
Effort : S

### Points vérifiés sans défaut (pour éviter de les rouvrir)
- Catalogue des cours : `CourseCatalogQuery` (24/page, `pluck`, 3-4 requêtes constantes, pas de N+1, `LESSON_NUMBER` calculé en SQL ; tri sur expression non indexée, sur ≤ quelques milliers de cours, sans impact).
- Imports : asynchrones (`ImportQueue` → `perform_later`), transactions par lot de 100 avec rejouage unitaire, `insert_all!` pour écoles/classes/DRENA/audit, progression toutes les 100 lignes, `max_roots`, `MAX_BYTES`, `MAX_ERRORS` bornés, statut "stale" au bout de 10 min.
- Jobs récurrents : idempotents (purges sélectionnent par date, journal du nombre traité), `erase_ips_before` par lots avec index partiel `index_audit_events_with_ip_on_created_at`.
- Production : `cache_store :solid_cache_store` (256 Mo), `perform_caching`, `eager_load`, `force_ssl`, assets Propshaft digérés (`max-age` 1 an), Thruster devant Puma (compression + cache), pas d'Active Storage variants/`image_processing` (libvips absent, images redimensionnées côté navigateur par `image_upload.js` en WebP 0,82).
- JS : esbuild minifié, `splitting`, KaTeX / Trix / figures en import dynamique ; sourcemaps générées (`sourcemap: true`) : vérifier qu'elles ne sont pas servies publiquement (taille et exposition du code, à confirmer).

## Constats — Concepts et vocabulaire transverses

Sources lues : glossaire §4 et §8, ADR-0033, ADR-0106, ADR-0115 (début), UDR-0007, UDR-0023/0073/0112/0119/0131 (en-têtes), `grading.rb`, `test/i18n/locale_files_test.rb`, `test/architecture/thresholds_on_grade_test.rb`, vues, helpers, locales fr, queries.
Tout ce qui n'est pas cité avec ligne est « à confirmer ».

### Synthèse du modèle actuel (vérifié)

- Quatre paliers de badge existent : `bronze/silver/gold/diamond` (`grading.rb` BADGE_THRESHOLDS ; ADR-0033). Ils se lisent sur la note sur 20 : Bronze dès 10/20, Argent dès 14, Or dès 16, Diamant = sans-faute (ADR-0106 §4.1, §4.3).
- Un « palier zéro » existe déjà, avec trois libellés différents selon l'écran : « Pas encore de badge » (`session_results.fr.yml:100`), « Pas encore » (`comprehension.fr.yml:24` `badge_none`, utilisé via `comprehension_box_label(:none)` dans `_roster.html.erb:107` et `_summary.html.erb:16`), et « Non acquis » (`badges.fr.yml:11`, `common.fr.yml` `badges.none`). `Grading.class_badge_for` renvoie déjà `nil` = « Pas encore » (`grading.rb` commentaire « nil (« Pas encore ») »).
- Trois échelles superposées sur la même note : badge (4 paliers), maîtrise (Acquis/Fragile/En difficulté, `mastery_for`), appréciation (Très bien/Bien/Assez bien/À retravailler, `appreciation.rb`, seuils 16/12/10). Plus la note /20 et le score %.
- Le badge stocké (`exercise_badges`) n'est lu que par `ExerciseProgressQuery:17` et `StudentHomeQuery:173` (champ `badge_level`) ; la plupart des écrans recalculent le palier depuis `score_percent` (`badge_for`).

**Verdict UX élève : 4 paliers + « pas encore » suffisent.** « Pas encore » existe déjà côté enseignant et sur le résultat élève ; il suffit de l'unifier (un seul libellé, une seule clé). Pas besoin de « en cours » : l'état « session démarrée » est déjà dit par le bouton « Reprendre » (`exercises/show.html.erb:101`). Réserve : « En difficulté » (maîtrise) disparaît du côté élève si les médailles remplacent la maîtrise ; l'enseignant garde besoin d'un signal sous Bronze (« Pas encore » le couvre, voir C-X03).

---

### Constats concepts (C-X)

#### C-X01 — « Médaille » et « Trophée » sont interdits par UDR et par test
Gravité P1 · Rôle : tous · Fichier:ligne : `test/i18n/locale_files_test.rb:6` · Description : passer à « médaille » contredit UDR-0007 §2 (« Interdits à l'écran : Platine, Médaille, Trophée ») et casse `FORBIDDEN` (regex contient `médaille|trophée`). Le glossaire §4 dit « Badge » partout (`glossaire.md` ligne ExerciseBadge, ligne 94 « Les badges s'affichent Bronze… »). · Preuve : `FORBIDDEN = /(?<![[:alpha:]])(habilet|…|leçon|quiz|essai|platine|médaille|trophée|essentielle)/i` · Proposition : si le porteur veut « médaille » : nouvelle UDR qui remplace UDR-0007 §2 (ligne ExerciseBadge), mise à jour glossaire §4 et §8, retrait de `médaille` de `FORBIDDEN`, renommage de la clé i18n (voir C-X09). Terme à valider : « Médaille » (ou garder « Badge »). · Effort S (doc + regex) à M (clés i18n).

#### C-X02 — Quatre écrans élève affichent la note /20 sans médaille
Gravité P2 · Rôle : élève · Fichier:ligne : `classroom/student_homes/_history.html.erb:32`, `student_archives/_result_row.html.erb:18`, `assessment/exercises/show.html.erb:120-121`, `exercise_cards_helper.rb:15-16` · Description : l'élève voit « 14/20 » partout mais un seul écran (le résultat de session) montre son palier. Un remplacement par médaille ajoute un affichage, ne retire pas de donnée. · Preuve : `grade_label(session.score_percent)` ; `t(".best", grade: grading.grade_on_20(@progress.best_score_percent))` · Proposition : voir l'inventaire. Garder la note en second plan (décision UDR-0023 : l'élève lit des notes sur 20) ou la retirer : décision porteur. · Effort M.

#### C-X03 — Sous Bronze, l'élève n'a aucun signal propre : « En difficulté » vit côté maîtrise
Gravité P2 · Rôle : élève, enseignant · Fichier:ligne : `grading.rb` `mastery_for` ; `session_results/show.html.erb:72-75` ; `shared/layouts.fr.yml:28` · Description : maîtrise = 3 niveaux (Acquis ≥ 14, Fragile ≥ 10, En difficulté < 10). Les médailles couvrent ≥ 10. Si la maîtrise est supprimée, « En difficulté » devient « Pas encore » (déjà utilisé par `class_badge_for`). Mapping : Acquis ≈ Argent+, Fragile ≈ Bronze, En difficulté ≈ Pas encore. · Proposition : conserver `mastery_for` (utilisé par `Comprehension.category_for`, `ExerciseProgressQuery:28`) comme vue enseignant ; ne plus l'afficher à l'élève. · Effort M.

#### C-X04 — Cinq échelles de lecture d'un même score
Gravité P2 · Rôle : élève, enseignant · Fichier:ligne : `session_results/show.html.erb:55-76` (appréciation `h1`, note, score %, maîtrise, badge, tous dans la même carte pour l'enseignant) · Description : un résultat affiche badge + titre « Très bien/Bien… » + note /20 + (non-élève) score % + maîtrise. C'est la surcharge à supprimer en priorité. · Preuve : `t(".headline.#{result.appreciation.level}")`, `t(".grade")`, `t(".score")`, `t(".mastery")` · Proposition : élève = médaille + « Très bien »… (ou note) ; garder le détail chiffré uniquement pour enseignant. · Effort M.

#### C-X05 — Seuils effectifs ne sont pas les seuils annoncés par la doc (glossaire, UDR-0007)
Gravité P2 · Rôle : tous · Fichier:ligne : `docs/guide/glossaire.md` (ExerciseBadge : « ≥ 50 %, ≥ 70 %, ≥ 80 % ») ; `docs/decisions/udr/0007…` §2 tableau (« Badge Bronze (≥ 50 %) ») · Description : la doc cite des pourcentages ; ADR-0106 a décalé à 48/68/78 % (lecture sur 20). UDR-0007 et le glossaire n'ont pas été amendés (ADR-0106 amende 0033, pas le glossaire). · Proposition : corriger glossaire + UDR-0007 en même temps que l'UDR médailles. · Effort S.

#### C-X06 — « Score », « Note », « Moyenne », « Réussite », « Taux », « Résultat » : six mots pour des mesures proches
Gravité P2 · Rôle : tous · Fichier:ligne : `session_results.fr.yml:34-35` (Note / Score), `classrooms.fr.yml:56` (Dernier score), `student_classrooms.fr.yml:40` (Meilleur score), `exercises.fr.yml:36` (Meilleure note), `dashboards.fr.yml:41-45` (Réussite moyenne), `school_admin/departed_students.fr.yml:21` (Score moyen), `school_admin/classrooms.fr.yml:91,96` (Moyenne / Score moyen), `classroom_students.fr.yml:22` (Moyenne /20 · badge) · Description : UDR-0007 §2 fixe « Score (en %) ; Note (sur 20) ; interdits : Pourcentage, Moyenne », mais « Moyenne » est utilisé dans au moins 6 écrans enseignant/direction (UDR ultérieures de l'espace enseignant). · Proposition : mot unique recommandé élève = « Médaille » (ou « Badge ») ; enseignant/direction = « Note » (/20) pour un exercice, « Moyenne » pour un agrégat ; supprimer « Score » de l'UI (réservé au code `score_percent`). · Effort M.

#### C-X07 — « Meilleur score » vs « Meilleure note » pour la même donnée
Gravité P2 · Rôle : élève · Fichier:ligne : `student_classrooms.fr.yml:40` (`treated_exercise.best: "Meilleur score"`) vs `assessment/exercises.fr.yml:36` (`best: "Meilleure note : %{grade}/20"`) · Description : même donnée (MAX score_percent), deux mots. La clé `treated_exercise.best` semble orpheline (grep `treated_exercise.best` ne trouve aucune vue ; la carte utilise `exercise_card_for_treated`) : à confirmer. · Proposition : supprimer la clé orpheline ; « Meilleure médaille » si médailles. · Effort S.

#### C-X08 — Le pourcentage brut survit sur 3 écrans alors que l'élève lit /20 (ADR-0106)
Gravité P1 · Rôle : enseignant, direction, équipe · Fichier:ligne : `classroom/classrooms/_roster.html.erb:124` (`student.last_score_percent %`), `classroom_students/_self_practice.html.erb:26` (`number_to_percentage(row.score_percent …)`), `classrooms.fr.yml:57` (infobulle « en pourcentage de bonnes réponses »), `session_results/show.html.erb:68` (tuile Score % pour non-propriétaire) · Description : même exercice : /20 dans la liste d'exercices de la fiche élève (`_assignments.html.erb:32`) mais % dans « Fait seul » et « Dernier score ». · Proposition : passer en /20 + médaille. · Effort S.

#### C-X09 — Clés i18n « badge » partout : un renommage « médaille » touche ~25 clés et 3 helpers
Gravité P2 · Fichier:ligne : `assessment/badges.fr.yml`, `shared/common.fr.yml` (blocs `badges:` et `mastery:`, doublons probablement morts : aucun `t("badges.` ni `t("mastery.` dans app/, à confirmer car clés dynamiques possibles), `comprehension.fr.yml:18-24,33,53-58,72`, `classrooms.fr.yml:41-50`, `teacher_homes.fr.yml:58`, `classroom_students.fr.yml:16-23`, `help.fr.yml:31-33`, `joins.fr.yml:13`, `account_deletions.fr.yml:22`, `pages/privacy.fr.yml:29,77`, `pages/mission.fr.yml:27` · Proposition : décider d'abord le terme, garder `badge` en code (glossaire règle « code anglais ») et ne changer que le texte ; supprimer les doublons `shared.common.badges/mastery`. · Effort M.

#### C-X10 — Trois libellés pour « pas de palier »
Gravité P2 · Fichier:ligne : `session_results.fr.yml:100` « Pas encore de badge » ; `comprehension.fr.yml:24` « Pas encore » ; `badges.fr.yml:11` « Non acquis » (aussi `common.fr.yml` `badges.none`) · Description : le commentaire de `_badge.html.erb:4-5` dit avoir écarté « Non acquis » pour ne pas doubler « En difficulté », mais la clé reste et `BadgesHelper#badge_label(nil)` la sert (`badges_helper.rb:12`). Qui appelle `badge_label(nil)` : à confirmer. · Proposition : « Pas encore » seul (terme déjà validé en UDR enseignant §3.5), supprimer « Non acquis ». · Effort S.

#### C-X11 — Exemples de seuils codés dans la FAQ et les infobulles mais calculés : à garder calculés
Gravité P3 · Fichier:ligne : `badges_helper.rb:25-33`, `help/show.html.erb:7-9`, `layouts.fr.yml:27-28`, `help.fr.yml:29-36` · Description : bon point, les seuils viennent de `Grading`. Mais « 8 bonnes réponses sur 10, c'est 80 %, soit %{example_grade}/20 » (`help.fr.yml:30`) reste en %. · Proposition : conserver le mécanisme ; réécrire les textes avec le terme final. · Effort S.

#### C-X12 — Le test d'architecture empêche de comparer un score brut ; toute nouvelle logique de médaille doit passer par `Grading`
Gravité P3 · Fichier:ligne : `test/architecture/thresholds_on_grade_test.rb:5-6` · Description : contrainte utile : ne pas créer de seuils « médaille » parallèles. Préserver `Grading.badge_for` comme source unique. · Effort S.

#### C-X13 — Diamant n'est pas un seuil mais un fait ; incompatibilité avec « médaille de maîtrise » si on change le barème
Gravité P2 · Fichier:ligne : `grading.rb` `perfect?`, `score_percent` (division entière) ; ADR-0106 §4.3 · Description : tout changement de barème (ex. suppression de Diamant ou seuils en %) se heurte à l'invariant « 100 % = toutes justes » et à la règle de points fractionnaires (`points_percent`, `.floor`). · Proposition : garder le barème, changer seulement l'affichage. · Effort S.

---

### Dépendances techniques d'un passage aux médailles (4)

#### C-X14 — Colonnes et index sur `score_percent` : ne pas migrer
Gravité P3 · Fichier:ligne : `db/schema.rb:346` (`score_percent`), `:355-357` (index `include: score_percent`), `:368-369` (CHECK 0..100, `completed_has_score`) · Description : tout le calcul (moyennes, meilleur score, tendance, rendu) lit cette colonne. Les médailles sont dérivées (`badge_for`). Les migrer exige de toucher 3 index couvrants (créés 20260929200000, 20260929200100, 20261004190000). · Proposition : aucune migration ; médaille = fonction du score. · Effort S.

#### C-X15 — `exercise_badges` : table de « meilleur badge », mal alignée avec l'affichage
Gravité P2 · Fichier:ligne : `exercise_progress_query.rb:17`, `student_home_query.rb:173`, `session_result_query.rb:78,97-98`, `student_file_query.rb:105` · Description : la table stocke un badge mais plusieurs écrans le recalculent depuis `score_percent` (badge de la session, pas le meilleur). Risque d'incohérence si le barème change : `exercise_badges.level` figé à l'ancien barème, `badge_for` recalculé au nouveau (ADR-0106 a déjà décalé les seuils sans rejouer la table : à confirmer en base). · Proposition : si le barème change, prévoir un backfill `exercise_badges` depuis `MAX(score_percent)` ou supprimer la lecture de la table. · Effort M.

#### C-X16 — Agrégats « classe » (`class_badge_for`) calculés en Ruby à 3 endroits
Gravité P2 · Fichier:ligne : `classroom_overview_query.rb:137`, `teacher_home_query.rb:79`, `student_file_query.rb:67`, `comprehension_summary_query.rb:21`, `comprehension_detail_query.rb:65` · Description : toutes les requêtes enseignant lisent `best` en SQL puis classent en Ruby. Aucune requête de classement par rang d'élèves (`ranking`/`classement` ne désigne que `teams/growth` : classement d'établissements par croissance, `growth_metrics_query.rb:66`, sans rapport avec les notes). Aucun export CSV/xlsx de notes (grep `csv|export|xlsx` dans app : aucun résultat pertinent, hors `script/perf/dataset.rb`). · Proposition : risque faible ; un changement de barème reste confiné à `Grading`. · Effort S.

#### C-X17 — Moyennes d'équipe et de direction restent en pourcentage et ne passent pas par `Grading`
Gravité P2 · Fichier:ligne : `team_dashboard_query.rb`, `student_work_query.rb`, `departed_students_query.rb` (champs `average_percent`/`average_score`) ; `dashboards.fr.yml:41-45` ; ADR-0106 §4.4 (« moyennes : statistiques, aucun seuil ») · Description : si la médaille remplace la note pour les élèves, les moyennes direction/équipe n'ont pas de médaille équivalente ; ADR-0106 les exclut volontairement. · Proposition : décider si direction voit des médailles par élève (via `class_badge_for` sur sa note moyenne /20) ou garde « Moyenne » /20. · Effort M.

#### C-X18 — Tests système et i18n à réécrire
Gravité P3 · Fichier:ligne : `test/system/assessment/session_result_test.rb:180` (`.badge()`), `student_progress_test.rb`, `exercise_page_test.rb`, `classroom/classroom_desktop_test.rb`, `teams/dashboard_test.rb`, `locale_files_test.rb:6` · Description : les tests lisent des libellés (« Bronze », « Pas encore », « /20 »). Estimation : ≥ 8 fichiers de test système (à confirmer en détail). · Effort M.

#### C-X19 — Aucune donnée n'est exportée ni persistée hors base ; risque de migration faible mais RGPD/pages légales à mettre à jour
Gravité P3 · Fichier:ligne : `communication/pages/privacy.fr.yml:29,77` (« notes, badges ») ; `account_deletions.fr.yml:22` · Description : si le mot change, ces pages légales doivent suivre. · Effort S.

---

### Contradictions de vocabulaire (W-X)

#### W-X01 — « Niveau » désigne trois choses
Gravité P1 · Rôle : tous · Fichier:ligne : niveau scolaire `Level` (`teams/levels.fr.yml:23-24`, `catalog/courses.fr.yml:38`, `student_registrations.fr.yml:102`) ; palier de badge `level` (`badges_helper.rb:13` `badge_label(level)`, `comprehension.fr.yml:19` `%{level}` = nom du badge) ; niveau de maîtrise (notion non affichée, mais `UDR-0007` « Maîtrise »). · Description : en code `level` = Level (scolaire) et `Orm::ExerciseBadge#level` (palier) : collision réelle. En UI le mot « niveau » seul désigne la classe (6ème…) ; ne pas l'employer pour les médailles. · Proposition : UI : « niveau » = niveau scolaire uniquement ; palier = « médaille » ; maîtrise = « maîtrise » (ou supprimée côté élève). Côté code, renommer `badge.level` en `tier` à terme (terme à valider, hors glossaire). · Effort M.

#### W-X02 — « Maîtrise » vs « Acquis » vs « Réussi » vs « Fragile »
Gravité P2 · Fichier:ligne : `session_results.fr.yml:37`, `badges.fr.yml:10-13`, `shared/layouts.fr.yml:28`, `comprehension.fr.yml:6-9` · Description : « Maîtrise » est un libellé de tuile, « Acquis/Fragile/En difficulté » ses valeurs, « Argent » est parfois aussi « seuil de maîtrise » (`MASTERY_THRESHOLD` = 70 = Argent), le texte de progrès dit « Tu confirmes ta maîtrise » (`session_results.fr.yml:95`) et un encouragement « Tu maîtrises le sujet » (`:20`). Trois sens : seuil Argent, catégorie d'exercice, phrase d'encouragement. · Proposition : « maîtrise » = catégorie (Acquis/Fragile/En difficulté) réservée à l'enseignant ; pour l'élève : médaille. · Effort S.

#### W-X03 — « Progression » / « progrès » / « avancement » / « faits »
Gravité P2 · Fichier:ligne : `catalog/courses.fr.yml:10-11,22` (« Progression DPFC 2026-2027 » = calendrier du programme, pas l'élève), `catalog/courses.fr.yml:79,146` (progress.started/done = avancement de l'élève dans la fiche), `comprehension.fr.yml:12,25` (« En progrès » = tendance ; `progress.label` = « Élèves qui ont fait l'exercice »), `session_results.fr.yml:93-96` (phrase « Tu progresses »), `student_homes.fr.yml:17-20` (« 3 exercices faits sur 5 »), colonne DB `progress_percent` (avancement dans une session, jamais affiché : seul `session_play_query.rb:61,75` la lit) · Description : « progression » désigne 4 notions (calendrier, avancement dans la fiche, tendance de score, compteur d'exercices). · Proposition : « Progression DPFC » = le programme (à nommer autrement, terme à valider : « Programme DPFC ») ; « faits » pour les compteurs ; « En progrès » pour la tendance. · Effort S.

#### W-X04 — « Lacune » (code/docs) vs « À revoir » (UI) vs « levée »
Gravité P2 · Fichier:ligne : glossaire §4 (KnowledgeGap = « lacune »), `classroom_courses.fr.yml:31` (« Lacune levée (%{count}) »), `account_deletions.fr.yml:22` (« lacunes »), contre `student_homes.fr.yml:34` (badge « À revoir »), `session_results.fr.yml:60-66`, `classrooms.fr.yml:100` (« ne les ont pas encore levées »), `classroom/classrooms/_gaps.html.erb:7` · Description : l'élève voit « À revoir » et « levée » ; l'enseignant voit « Lacune levée » une fois, « à revoir » ailleurs ; glossaire garde « Lacune ». · Proposition : UI : « à revoir » (élève et enseignant) ; « lacune » uniquement code/docs ; corriger les 2 occurrences UI de « lacune ». · Effort S.

#### W-X05 — « Compétence » : absent de l'UI (bon), mais réclamé par le glossaire comme proscrit « Habileté »
Gravité P3 · Fichier:ligne : `locale_files_test.rb:6` (`habilet`), grep « compétence » dans config/locales/**/*.fr.yml : aucune occurrence hors imports (à confirmer sur `teams/imports`) · Description : pas de concept « compétence » dans le modèle ; ne pas l'introduire pour décrire les médailles. · Effort S.

#### W-X06 — Classement : aucun classement d'élèves à retirer
Gravité P3 · Fichier:ligne : `teams/growth/show.html.erb:79-84` (`schools_leaderboard` = établissements par croissance) · Description : aucun classement d'élèves ni de points d'expérience dans l'UI (grep `ranking|leaderboard|classement|xp` sur app/views : seul le classement d'établissements de l'équipe). Les « points » sont des points de barème de question (`exercise_sessions.fr.yml:42-50`, `session_results.fr.yml:55-59`, `answer_keys.fr.yml:18`), pas de la gamification. · Proposition : renommer éventuellement « points » en « points de barème » pour ne pas être confondu avec des points de gamification. · Effort S.

---

### Termes divergeant du glossaire dans l'UI (3)

#### W-X07 — « Leçon » : exclu par UDR-0130 et par test, présent sur 11 clés + 1 locale non listée
Gravité P2 · Rôle : élève, enseignant · Fichier:ligne : autorisé par `locale_files_test.rb:9-21` : `back_to_lesson` « Retour à la leçon » (`session_results.fr.yml:41`), `to_review_lesson_html` (`:62`), `whole_lesson` (`:66`), `exercises.fr.yml:37`, `courses.fr.yml:107-108`, `classroom_courses.fr.yml:7,17-18`. Hors test (commentaires seulement) : `courses.fr.yml:12-13`. · Description : « leçon » = « fiche de cours parente » (UDR-0130 §3.2, UDR-0139 « La page de la leçon »). Le glossaire §3 ne définit pas « leçon » (seulement « Ne jamais écrire Lesson ») et §8 interdit `Lesson`, alors que le code a `lesson_source`, `LessonAnswerKey`, `app/controllers/catalog/courses_controller.rb` (grep `lesson`). · Proposition : ajouter « leçon » au glossaire comme alias d'écran de « fiche de cours » ou le retirer des 11 clés. Choix porteur. · Effort S (doc) / M (retrait).

#### W-X08 — « Notion » : terme d'UI massif (≥ 12 clés), non défini au glossaire
Gravité P2 · Rôle : élève, enseignant · Fichier:ligne : `courses.fr.yml:107,110,138,141,166,168`, `session_results.fr.yml:106,112,115`, `student_classrooms.fr.yml:22` (« Notions à revoir »), `comprehension.fr.yml:60-63`, `revision_sheets.fr.yml:37` ; ADR-0116 « fiche de révision faite de notions » · Description : glossaire §4 : `Essential` = fiche de révision ; §8 interdit « Notion(s) clé(s) » mais pas « notion » ; l'UI mélange « fiche de révision », « notion », « fiche » (`_review.html.erb` : « Revoir la fiche »). La règle 3 du glossaire (« terme absent = bug de documentation ») s'applique. · Proposition : ajouter « notion » au glossaire (ADR-0116) en disant s'il est synonyme de « fiche de révision » (un Essential = une notion). · Effort S.

#### W-X09 — « Fiche » seul dans les titres élève (interdit par UDR-0007 mais présent)
Gravité P3 · Fichier:ligne : `student_homes.fr.yml:35` « Relis la fiche, puis refais un exercice », `:36-37` « Revoir la fiche », `session_results.fr.yml` (`open_essential`, à confirmer) · Description : UDR-0007 §2 interdisait « Fiche seul dans un titre » ; il s'agit ici de phrases, donc acceptable ; à confirmer par l'UDR. · Effort S.

#### W-X10 — « Session », « tentative », « essai », « copie », « exercice », « devoir »
Gravité P2 · Fichier:ligne : `assignment_follow_ups.fr.yml:12` (« 1re copie · meilleure note »), `classroom_students.fr.yml` (« session »), `exercise_cards.fr.yml:8` (« Voir ma copie »), `session_results.fr.yml:33,94` (« à ta première session »), `student_homes.fr.yml` (« Tu as eu … », « Exercice du jour »), `joins.fr.yml:13` (« tes sessions ») · Description : « copie » (ADR-0115 « copie vérifiée ») et « session » désignent la même `ExerciseSession` terminée ; l'élève lit « Voir ma copie » mais « première session » ; « devoir » (assignation) vs « exercice » (`TeacherHomes`, « Rendu » en feuilles). Glossaire §4 ne définit ni « copie » ni « devoir ». · Proposition : ajouter au glossaire « copie » (= session terminée, vue élève) et « devoir » (= exercice assigné) ou les retirer. · Effort S.

#### W-X11 — « Tentative » : utilisé pour des erreurs de connexion (OK), pas pour les réponses
Gravité P3 · Fichier:ligne : `common.fr.yml:12-21`, `pending_accounts.fr.yml:27`, `joins.fr.yml:15`, `student_registrations.fr.yml:73-75,124` · Description : « Trop de tentatives » = limitation de débit, sens « essai de connexion » ; UDR-0007 dit « tentative » = `QuestionAttempt`. Le mot est cohérent avec l'usage courant ; aucun écran n'emploie « tentative » pour une réponse d'élève (non vérifié exhaustivement). · Effort S.

#### W-X12 — « Cours » (rubrique) vs « Fiche de cours » (objet) vs « Leçon »
Gravité P3 · Fichier:ligne : `navigation.fr.yml:113,125`, `courses.fr.yml:8,17`, `UDR-0130` · Description : trois mots, règles écrites en UDR-0130 ; respecté. Pas de nouvelle divergence trouvée. · Effort S.

#### W-X13 — « Moyenne » : interdit par UDR-0007 §2 mais standard de l'UDR enseignant
Gravité P2 · Fichier:ligne : `classrooms.fr.yml:49-50`, `classroom_students.fr.yml:22`, `teacher_homes.fr.yml:31-32`, `school_admin/levels.fr.yml:25`, `school_admin/classrooms.fr.yml:91`, `UDR-0007` §2 « Interdits : Pourcentage, Moyenne » · Description : l'UDR-0007 interdit encore « Moyenne » pour « Score » ; les écrans enseignant et direction l'emploient (UDR enseignant, UDR-0112 abandonnée « pas de moyenne de classe » mais la direction en affiche : `school_admin/classrooms/show.html.erb:29`). · Proposition : réconcilier UDR-0007 (amender : « Moyenne » autorisée pour un agrégat). · Effort S.

#### W-X14 — « Score » : un mot UI pour une donnée qu'on veut cacher à l'élève
Gravité P2 · Fichier:ligne : `session_results.fr.yml:35,36` (`score: "Score"`, `score_value: "%{score} %"`), `show.html.erb:67-68` (visible pour non-propriétaire seulement) · Description : le score % n'est plus vu par l'élève (UDR-0023 amendée 2026-10-02) mais l'enseignant et l'équipe le voient ; il double la note /20. · Proposition : retirer la tuile Score de l'écran enseignant (garder note + médaille). · Effort S.

#### W-X15 — « Taux de rendu » (devoirs rendus, %) mélangé aux scores dans les mêmes tuiles
Gravité P2 · Rôle : direction · Fichier:ligne : `school_admin/classrooms.fr.yml:90-91` (Taux de rendu / Moyenne côte à côte), `signals.fr.yml:7-15` (seuils 70/40 % codés dans la locale) · Description : deux pourcentages de nature différente (taux de devoirs rendus vs score moyen) dans la même grille ; seuils de signaux 70 % et 40 % écrits en dur dans les libellés (non calculés), contrairement à `Grading` (le test `thresholds_on_grade_test.rb` ne couvre que `*_THRESHOLD`). · Proposition : conserver le taux (ce n'est pas une note) mais renommer « Devoirs rendus » ; calculer les libellés de signaux depuis une constante. · Effort S.

#### W-X16 — Badge UI générique `ui_badge` vs badge de palier : même mot, deux composants
Gravité P2 · Fichier:ligne : `components_helper.rb` (`ui_badge` pastille d'état : « Publié », « En retard », « À revoir » partout dans `app/views`) vs `BadgesHelper` (palier) · Description : « badge » désigne les pastilles d'état de l'interface (> 30 usages `ui_badge`) et les paliers Bronze→Diamant. C'est aussi un argument pour renommer le palier en « médaille » côté UI. · Proposition : la médaille évite l'homonymie avec `ui_badge` : renommer côté code (`ui_badge` → `ui_pill`/`ui_chip`) est hors périmètre. · Effort S.

#### W-X17 — Trois emplois de l'icône « trophy » pour des paliers qui se disent « médaille »
Gravité P3 · Fichier:ligne : `_badge.html.erb:11` (`ui_icon … "trophy"`), `badges_helper.rb:48` (`comprehension_trophy`), `classroom_students/_assignments.html.erb:31` · Description : l'icône est un trophée (mot interdit en texte par `FORBIDDEN`), la zone textuelle dit « badge ». Pour des médailles, prévoir une icône « médaille » (heroicons n'en a pas : `ui_icon` utilise `trophy`/`check-badge`/`flag` ; à confirmer dans l'icon set). · Effort S.

#### W-X18 — Accessibilité : le nom de palier est lu par aria-label « Badge Or » ; à reprendre
Gravité P3 · Fichier:ligne : `_badge.html.erb:6` (`t(".label", level: name)`), `session_results.fr.yml:98` (« Badge %{level} »), `UDR-0007 §3 Accessibilité` · Effort S.

#### W-X19 — « Non acquis » / « Acquis » : « acquis » signifie aussi « acquis pour toujours » (FAQ)
Gravité P3 · Fichier:ligne : `help.fr.yml:43` (« Ta meilleure note et ton badge restent acquis ») · Description : même mot pour « maîtrise Acquis » et « badge conservé ». Source d'ambiguïté. · Proposition : « restent » seul. · Effort S.

---

## Ordre de traitement proposé (demain)

1. **Décision porteur, avant tout code** : règle unique de médaille (par exercice, pas par classe), mot « médaille » vs « badge », libellé unique de l'état sans médaille. Écrire l'UDR, mettre à jour le glossaire (seuils 48/68/78 %) et la regex `FORBIDDEN` (C-X01, C-X05, C-X10, W-X01). Effort S.
2. **Retouches sans risque** (un lot, `/retouche`) : tutoiement des erreurs 403/404/422/500 et de `assignments.fr.yml:66`, fautes et synonymes (cours/leçon/fiche), « Pas encore » à trois sens, helpers copiés en triple, `turbo_submits_with` manquants, cibles tactiles < 44 px.
3. **Perf rapide** : index `classroom_students.student_id` (O-X05), `duration` du verrou d'import (O-X02), pool DB (O-X01), cache du Pilotage 7/30 jours (O-X04), requête de la liste des cours calculée une fois (O-C01) et pagination des leçons (O-C02), suppression de `bg.png` après confirmation qu'il est inutilisé (O-X14).
4. **Chantier médailles, côté élève** : un seul jugement sur le résultat, médaille sur accueil, historique, Ma classe (C-E01, C-E02), suppression du % brut (C-X08).
5. **Chantier médailles, côté enseignant/direction/équipe** : fin de « Moyenne » et du classement, répartition par médaille, Pilotage, corrigé, FAQ et « Réussi » (C-T01, C-S01..S03, C-A01, C-B01, C-C01, C-C02).
6. **Ensuite** : imports (double envoi, ligne qui ne se met jamais à jour, messages d'erreur précis, mémoire des fichiers de 20 Mo), doublon recherche de compte / « Débloquer un compte », illustrations d'annonce sans pagination, modale « Nouvel article » trop longue.
7. **Captures 390 px et ordinateur** pour confirmer tous les constats marqués « à confirmer » avant de les traiter.
