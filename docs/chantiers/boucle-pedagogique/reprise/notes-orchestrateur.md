# Notes de l'orchestrateur — suivis et questions pour le porteur

> Notes prises au fil des fusions, du 2026-09-25 au 2026-09-26. Chaque « Question porteur » attend une décision ; la recommandation de l'orchestrateur est appliquée en attendant (voir `docs/workflows/README.md`, décisions en cours de lot).

## Après les lots de catalogue (B1 à B5)
- B1 (page du cours) : prouver en test système que le gras et la liste saisis par B2 s'affichent tels quels sur la page du cours, et que publier/archiver (B2) se fait sans rechargement ; repli HTML de B2 vers course_path.
- Question porteur : doublon de nom de cours selon casse/accents (« génétique » vs « Génétique ») — l'import les confond (NaturalKey), la saisie non.
- I3 (import des cours) : clé de doublon des cours = NaturalKey.compact (sans espaces), comme CourseRepository#existing_keys.
- B3 (page d'une fiche) : ajouter le bouton « Nouvel exercice » (équipe) qui ouvre la modale de B5 ; vérifier aussi « Nouvelle fiche » / « Nouveau cours » sur les pages B1/B3. Rendu du contenu riche de B4 à prouver sur la page.

## Après D2 (04dfa5f)
- D3 : le test système de D2 remplace l'accueil enseignant par une doublure qui s'efface à la fusion de D3 ; vérifier que ce test passe encore avec le vrai écran.
- Question porteur : l'onboarding se termine dès qu'une classe est déclarée, même archivée ou d'une autre année (`classroom_ids_for`), alors que le compteur ne compte que les classes affichées. Proposition : ne compter que les classes actives de l'année (changement du port, au socle).
- Question porteur : une école sans classe active bloque l'onboarding (état vide, sans bouton). Rare, car les classes sont créées à l'import.
- D2 n'a pas de « Tout cocher » par niveau ; pas de toast à chaque bascule (UDR-0025 §2).

## Après D5 (c4dc7d7)
- Question porteur : toasts d'assignation — D5 suit le PRD (« Méiose ajouté à 6ème 1. ») plutôt que le plan (« Assigné à la classe »).
- D6/D7 : réutiliser la bascule `classroom/assignments/_toggle` (locals stricts, contrat UDR-0028 §3).
- Socle : le commentaire de ClassroomHeaderQuery::Row parle d'AssignPolicy mais le Row n'a pas `active?` — corriger le commentaire (ou ajouter active?).
- Archive d'assignation : la bascule envoie classroom_public_id ; ArchiveAssignment vérifie l'appartenance (404 sinon).

## Après D4 (7e071b8)
- Question porteur / socle : PRD « enseignant sans configuration terminée : toute page enseignant ramène à la déclaration des classes ». Seul D3 l'applique au plan. Proposition : before_action commun au socle (concern) après D3, appliqué aux contrôleurs enseignants D4–D7.
- D3 : le test système de D4 remplace TeacherHomesController par un contrôleur de test (s'efface à la fusion de D3) — vérifier.
- UDR-0011 et UDR-0020 citées en texte simple dans UDR-0027 : remettre les liens après leur fusion.
- D4 : bouton « code de récupération » masqué si classe archivée ; dernier score = dernière session terminée, tous exercices.

## Après A1
- Question porteur : PRD « élève connecté qui ouvre le code d'une autre classe voit “Tu es déjà inscrit” » ; A1 l'affiche au clic sur « Rejoindre » (422), pas à l'ouverture.
- A2 : le test système d'A1 remplace l'accueil élève par un substitut qui s'efface à la fusion d'A2 — vérifier.
- A1 : refus JoinPolicy (classe archivée/complète) = 403 avec raison ; rate limit 10/min sur /c/<code>.

## Bonnes réponses (881a623)
- PRD AS-10 et plan C2/C3 alignés : l'élève voit verdict, ses choix, l'explication ; jamais answers.correct, même dans la revue de résultat (C3). Brief C3 : le rappeler + test que le HTML élève ne contient aucune proposition juste non choisie.
- Question porteur : garder l'explication pour l'élève ? (C2 la garde.)

## Après A2 (eb65b67)
- C2 : le test système d'A2 remplace ExerciseSessionsController ; vérifier qu'il passe avec le vrai (formats: :html).
- Questions porteur : lacune sur fiche archivée masquée (ou montrée sans lien ?) ; garder la section « Cours » (lien catalogue) sur l'accueil élève ?
- A2 : frame paresseux de l'activité récente sur student_home_path lui-même (pas de route dédiée).

## Après C1 (a36d042) et find(id:) (5796d2e)
- Questions porteur : après un exercice terminé, bouton « Commencer » ou « Refaire » ? ; énoncés de question en texte brut (la fabrique écrit « <p>Question 1</p> », affiché échappé) — accepter HTML/rich text ?
- C1 : questions chargées deux fois (repository + query) ; l'élève ne reçoit ni explication ni correct sur la page d'exercice.

## Socle, pendant B7/S3/C2
- dec27e9 : InvitationRepositoryPort#revoke_expired (une invitation expirée bloquait le contact pour toujours).
- b415461 : garde use_case_policies — un Importer avec KIND au registre et POLICY identique est autorisé (I1, I2, I3 : `POLICY = <policy du registre>`). À dire dans les briefs I1-I3.
- S3 : locale propre config/locales/school/import_schools.fr.yml (clés teams.imports.status.details.*) hors liste du plan — acceptée. I1-I3 pourront faire de même.

## Après B7 (923f3d0)
- Questions porteur : (a) ADR-0038 vérif du numéro à l'acceptation, absente du PRD/plan — l'ajouter ? (b) lien « Inviter un membre » sur l'accueil équipe (B6) : admins seulement ? (reco : oui)
- B6 : le lien ouvre /teams/invitations/new en modale ; B7 a un stand-in de Teams::HomesController.
- B7 : pas de bouton Copier (champ lecture seule) ; AcceptInvitation#check(token:) ; mark_accepted redondant après create_from_invitation.

## Après S3 (afdac79)
- Questions porteur : type d'établissement absent → erreur (choix S3) ou « public » par défaut (ancienne app) ? ; ADR-0039 annonce 35 000 classes, le mélange réel du plan en donne ~18 000 (500 lycées publics = 38 500, 29 s, 189 Mo).
- Rapport d'import : skipped_levels / skipped_series seulement si > 0 ; erreurs à la clé canonique même sous alias.

## Après C2 (1d685b1)
- Contradiction : PRD AS-11 résout une lacune à ≥ 70 %, ADR-0043 (accepté) et GapDecision à ≥ PASS_THRESHOLD (50). Code = ADR. Question porteur : 50 ou 70 ? Si 50 : corriger AS-11 ; si 70 : amender ADR-0043 + GapDecision (MASTERY_THRESHOLD).
- C2 : clôture sous SubmitAttemptPolicy (pas de policy dédiée) ; seule l'assignation de l'exercice rattache la session ; message doublon « Tu as déjà répondu à cette question. ».
- C3 : C2 a une doublure de SessionResultsController dans son test système (préchargement Turbo) — vérifier avec le vrai.
- Couverture : C2 mesure avec PARALLEL_WORKERS=1 (fusion SimpleCov perd des lignes en parallèle) — surveiller la CI.

## Après I1 + C3 (277b5eb)
- Perf I1 : 200 cours complets en 99,9 s au repos, 120,4 s sous charge (limite 120 s). 75 % dans ContentTreeWriter (insert_all! de 128 000 propositions). Chantier /optimize à proposer : insert_all par tranches / SQL brut. Vérifier sur Staging (porteur).
- Question porteur : libellé socle import_kinds.course_tree « Cours et chapitres » → « Cours complets » (chapitre absent de l'UDR-0007). Reco : oui, petit correctif socle.
- Questions porteur C3 : titre « Félicitations / Courage » vu aussi par l'enseignant (neutre ?) ; explication (même question que C2).
- C3 : teaches_student? calculé par la query (lecture), Row enrichi ; encouragements repris de l'ancienne locale, 3 écartés.
- I1 : type d'exercice obligatoire (ancienne app : fixation par défaut) ; alias ancienne app acceptés.

## Après I2 (b42a007) — perf des imports de contenu
- I2 PERF=1 : 132,8 / 145,7 s (agent), 163,5 s en COVERAGE=0 sous charge 5,6 (moi) ; 1 Go de mémoire. Budget 120 s. Ce n'est PAS la couverture.
- Détail I2 : json_schemer 21 s, adaptateur 5 s, ContentTreeWriter ~104 s (insert_all! answers ~64 s, questions ~19 s).
- Décision : chantier /optimize dédié (ContentTreeWriter : COPY ou insert SQL brut par tranches, ids pré-réservés par nextval ; validateur de schéma) APRÈS B3/I3, machine libre, avant la vague 3d. I3 (10 000 exercices) aura le même problème.
- Question porteur I2 : module commun des nœuds de contenu I1/I2/I3 (I2 a copié la construction exercice→question→proposition d'I1) — à faire dans le même chantier.

## Après B3 (d362373, 7a32f27)
- 7a32f27 : l'encart lacune de la fiche lisait MASTERY_THRESHOLD (70) alors que GapDecision lève à PASS_THRESHOLD (50) → aligné sur PASS_THRESHOLD. Décision porteur 50/70 toujours en attente.
- Question porteur : bouton de remédiation (StartRemediationSession, ADR-0043) dans l'encart de lacune, plus tard ?
- B3 : include_unpublished pour l'équipe ; boutons simples (ui_dropdown_item ne vise pas un frame — piste socle).

## Après D3 (665ee9d, NON POUSSÉ — réseau HTTPS en panne depuis ~12 h 50)
- À pousser dès retour réseau : 665ee9d (+ I3 à fusionner : 2e049e2, rapport jamais reçu). Branche docs/workflow-voie-legere (worktree lnclass-workflow) : amendement README non commité → commit + PR vers Develop.
- B6 : arrêté (API), rien écrit → relancer.
- Questions porteur D3 : score moyen limité à la matière de l'enseignant (ou toutes) ; « Score moyen » vs interdiction « Moyenne » (UDR-0007) ; seules les classes actives de l'année en cours.
- Tous les stand-ins de TeacherHomesController passent avec le vrai (16/16).

## Après I3 (fusion locale, non poussée)
- PERF I3 : 200,6 s (10 000 exercices, 200 000 propositions), 1,1 Go. json_schemer 25-31 s, ContentNode 6 s, écriture ~150 s.
- Piste chiffrée : dans insert_all!, construire le SQL coûte 0,6-0,7 s / 2 000 propositions contre 0,16 s en base ; les horodatages TimeWithZone ≈ 2/3 (0,71 s avec, 0,24 s sans) → poser created_at/updated_at en SQL (défaut DB ou valeur sérialisée). Ruby local SANS YJIT (Staging probablement avec) → mesurer aussi avec YJIT.
- Question porteur : clé de doublon d'exercice = normalize(titre) (ADR-0039 §4, port existing_keys) vs compact (règle des cours). Reco : aligner sur compact dans le chantier d'optimisation/refactor des imports.
- Bouton « Importer des exercices » sur la fiche : B3 l'a (menu équipe) — vérifier qu'il vise bien le partial d'I3.

## A3 (Ma classe, élève) — fusionné 57fa4ec
- L'élève peut-il copier le code de classe (bouton « Copier ») ? Recommandation appliquée : non, affichage seul.
- Bascule entre plusieurs classes (ADR-0003) hors V1 ? Recommandation : oui, hors V1.
- Traçabilité CL-10 du plan dit « sans code » : décision porteur appliquée (code affiché) → corriger le tableau du plan.

## B6 — bogue CSP + Turbo révélé (13 h 55)
- Nonce CSP aléatoire par requête (ADR-0049) + navigation Turbo Drive : le document garde le nonce de la 1re page, Turbo remplace meta csp-nonce → les <style> de Trix sont bloqués → éditeur cassé après toute navigation Turbo (ex. connexion → accueil équipe → « Nouveau cours »).
- Révélé par le vrai Teams::HomesController (le stand-in rechargeait la page) : 2 tests rouges dans test/system/teams/essential_management_test.rb.
- Décision porteur requise (amendement ADR-0049). Reco : nonce par session (`->(request) { request.session.id.to_s }`, forme Rails standard) + rechargement complet après connexion et second facteur (rotation de session). Correctif socle AVANT la fusion de B6.

## A4 (landing) — fusionné 17508e5
- Question porteur : textes de la landing à valider (UDR-0012) — slogan de l'ancienne app « Avec Lnclass, tu comprends chap chap ! », rien sur parents/établissements/devoirs en V1, « Inscrire mon établissement » retiré (V2).
- Socle : ui_modal(trigger:) n'a qu'une taille de bouton (md).

## B8 (débloquer un compte) — fusionné a671b6c
- Question porteur : l'entrée « Débloquer un compte » (`teams_account_lookup_path`) n'est dans aucune navigation — menu équipe (socle, UDR-0006) ou accueil équipe (B6) ? Reco : raccourci sur l'accueil équipe (B6), après la fusion de B6.
- B8 : limite de 10 codes/min comptée par émetteur (pas par IP) ; 429 en toast ; confirmation de réinitialisation du second facteur dans une <dialog>.
- B8 : le test système installe un stand-in de Teams::HomesController (`formats: :html`) — il s'effacera avec B6.
