# Features de la refonte Lnclass — liste de reprise

> Généré le 2026-09-22, régénéré le 2026-09-28 (puis mis à jour le même jour : clôture de la V1, CL-02 en V3, CA-23 en V4) à partir de la table de traçabilité de [`chantiers/refonte-application/feuille-de-route.md` §6](chantiers/refonte-application/feuille-de-route.md#6-traçabilité--chaque-feature-de-lexistant-a-une-vague), **qui fait foi** : en cas d'écart, c'est elle qui gagne. Ce fichier est une vue de travail, rangée par vague, avec une case à cocher par feature.
> La fiche détaillée de chaque ID (règles métier, preuves `chemin:ligne`) est dans [`chantiers/refonte-application/inventaire/complements-*.md`](chantiers/refonte-application/inventaire/).

**Légende.**

- **État ancien** : ✅ marche · ⚠️ fragile · ❌ cassé · 💀 jamais exécuté, dans l'ancienne application.
- **Ne pas reproduire** : le défaut de l'ancienne application, qui devient un test dans la vague.
- ☑ : feature en production, marquée « livrée » dans sa première vague au §6. ☐ : pas encore livrée, ou livrée en partie.
- Une feature livrée sur deux vagues est rangée dans la **première** qui la livre.

## Où reprendre

État au 2026-09-28 : la V0 et la V1 sont en production depuis le 2026-09-27 et **closes** (chantiers `amorcage-depot` et `boucle-pedagogique`) ; plusieurs chantiers sont livrés hors ordre ; les vagues V2 à V6 sont recadrées. Détail : [état d'avancement](chantiers/refonte-application/feuille-de-route.md#état-davancement-au-2026-09-28) et [§5 de la feuille de route](chantiers/refonte-application/feuille-de-route.md#5-les-vagues).

1. **Finir la V1** : la recette `Staging` par un rôle distinct est en cours (2026-09-28) ; son rapport va dans le [journal de la boucle pédagogique](chantiers/boucle-pedagogique/journal.md#clôture). CL-02 (modifier une classe) est passée en V3.
2. **Avant la V2** : faire accepter les décisions en production restées `Proposé` (ADR-0057, 0059, 0063, 0064 ; UDR-0044, 0046, 0050), corriger les tests instables, obtenir du porteur les réponses aux [questions Q1 à Q15](chantiers/refonte-application/feuille-de-route.md#questions-à-poser-au-porteur).
3. **Travailler sous CI bloquée jusqu'au 2026-10-03** : `bin/ci` complet en local avant chaque fusion, fusion par l'agent seul, déploiement de production à la main sur Railway ([§8](chantiers/refonte-application/feuille-de-route.md#8-risques-du-programme)).
4. **Ouvrir la V2** : `espace-direction`, puis `annuaire-equipe` ; en parallèle, `catalogue-complet` (V4), disjoint de la V2 ([tableau de collision](chantiers/refonte-application/feuille-de-route.md#chevauchement-v2--v4--tableau-de-collision)).
5. **Corriger [`feature_listing.md`](feature_listing.md)** : `classroom_courses`, `classroom_essentials` et `classroom_exercises` n'existent plus ; elles sont fusionnées dans `classroom_assignments` (contradiction C-35).

## Sommaire

| Groupe | Features | dont livrées au 2026-09-28 |
|---|---|---|
| V0 — Amorçage du dépôt | 10 | 10 |
| V1 — Boucle pédagogique | 84 | 84 |
| V2 — Organisation scolaire et espace direction | 30 | 1 |
| V3 — Suivi pédagogique enseignant | 12 | 1 |
| V4 — Contenu à l'échelle et back-office équipe | 12 | 3 |
| V5 — Remédiation et lacunes | 4 | 2 |
| V6 — Communication (annonces) | 10 | 0 |
| V8 — Hors vague, à décider | 1 | 0 |
| Retirées du plan le 2026-09-22 | 26 | 0 |
| Écartées (doublons, code mort, routes injustifiées) | 24 | 0 |
| **Total** | **213** | **101** |


## V0 — Amorçage du dépôt

### Transverse — `TR`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | TR-01 | Landing et modales élève / enseignant | ✅ | V0 (squelette, garde-fou n° 7) — livrée 2026-09-25 (#6) · V1 (contenu) — livrée 2026-09-27 (#33) | — |
| ☑ | TR-26 | Mesure d'audience | ⚠️ | V0 (F-27) — livrée 2026-09-25 (#6) | Des identifiants en dur, sans consentement ni CSP |
| ☑ | TR-31 | Purge horaire des jobs terminés | ⚠️ | V0 (F-30) — livrée 2026-09-25 (#6) | Un job récurrent qui dépend d'un worker jamais lancé |
| ☑ | TR-32 | Cache des agrégats et référentiels | ✅ | V0 (installation) — livrée 2026-09-25 (#6) · V3 (rapports) | Un cache actif en production seulement |
| ☑ | TR-34 | Sonde de santé `/up` | ❌ | V0 (garde-fou n° 6) — livrée 2026-09-25 (#6) | — |
| ☑ | TR-35 | Refus des navigateurs anciens | ✅ | V0 (F-29) — livrée 2026-09-25 (#6) | Un 406 sur les Android d'entrée de gamme du public cible |
| ☑ | TR-36 | Déploiement en production | ⚠️ | V0 (F-30) — livrée 2026-09-25 (#6) | Une configuration de déploiement non versionnée |
| ☑ | TR-37 | Conservation des fichiers téléversés | ⚠️ | V0 (F-25, stockage objet) — livrée 2026-09-25 (#6) · V2 pour l'avatar : photo de profil livrée 2026-09-28 (#50) | Un stockage local perdu à chaque déploiement |
| ☑ | TR-39 | Journaux sans donnée sensible | ⚠️ | V0 (garde-fou n° 6) — livrée 2026-09-25 (#6) | `:contact` en clair dans les logs |
| ☑ | TR-40 | Interface en français par clés | ⚠️ | V0 (`raise_on_missing_translations`) — livrée 2026-09-25 (#6) · toutes les vagues | 1 vue sur 315 qui passe par `t()` |


## V1 — Boucle pédagogique

### Identité — `ID`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | ID-01 | S'inscrire comme élève | ⚠️ | V1 (Lot A) — livrée 2026-09-27 (#33) | La classe choisie par listes en cascade, **sans code** : le [PRD cadre](prd.md#2-acteurs) exige un code de classe valide. Le PIN laissé vide qui devenait le contact. Une création non transactionnelle |
| ☑ | ID-02 | S'inscrire par le lien `/c/<code>` | ⚠️ | V1 (Lot A) — livrée 2026-09-27 (#33) | Un PIN dérivé du contact |
| ☑ | ID-03 | S'inscrire comme enseignant | ⚠️ | V1 (Lot D) — livrée 2026-09-27 (#33) | — |
| ☑ | ID-07 | Vérifier en direct un code de classe | ⚠️ | V1 (Lot A) — livrée 2026-09-27 (#33) | Un endpoint énumérable, sans limite de débit, qui renvoie plus que le strict nécessaire |
| ☑ | ID-08 | Listes en cascade DRENA → écoles, école + niveau → classes | ✅ | V1 pour DRENA → écoles (inscription enseignant) — livrée 2026-09-27 (#33), remplacée le 2026-09-28 par le code d'établissement (ADR-0057, #49) · **écartée** pour école + niveau → classes | Rejoindre une classe sans son code |
| ☑ | ID-12 | Se connecter | ⚠️ | V1 (0b) — livrée 2026-09-27 (#33) | PIN affiché en clair ; aucune limite de débit ; aucune rotation de session |
| ☑ | ID-13 | Être dirigé vers son espace | ⚠️ | V1 (0b) — livrée 2026-09-27 (#33) | Deux boucles de redirection infinies ; l'onboarding déduit de `classrooms.empty?` |
| ☑ | ID-14 | Se déconnecter | ⚠️ | V1 (0b) — livrée 2026-09-27 (#33) | Aucun `reset_session` |
| ☑ | ID-15 | Récupérer un PIN oublié | ❌ absent | V1 (0b, F-08) — livrée 2026-09-27 (#33) | La perte définitive du compte |
| ☑ | ID-16 | Restreindre chaque espace à son rôle | ⚠️ | V1 (Lot 0a, F-04) — livrée 2026-09-27 (#33) | Une autorisation par `before_action` au lieu d'une policy testée |
| ☑ | ID-28 | Normaliser et valider le contact | ⚠️ | V1 (0b, F-28) — livrée 2026-09-27 (#33) | — (règle juste, à reprendre) |
| ☑ | ID-29 | Générer l'identifiant public et le slug | ⚠️ | V1 (Lot 0a, F-05) — livrée 2026-09-27 (#33) | Un préfixe qui révèle le rôle ; le repli sur l'identifiant entier |

### Communication — `CO`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | CO-09 | Toasts de confirmation et d'erreur | ⚠️ | V1 (Lot 0c, F-31) — livrée 2026-09-27 (#33) | Un toast d'erreur Turbo qui perd son message |

### Établissements — `SC`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | SC-01 | Gérer les DRENA | ⚠️ | V1 (`referentiels-equipe`, ADR-0034) — livrée 2026-09-27 (#33) | Une suppression qui échoue dès qu'une école a du personnel |
| ☑ | SC-03 | Créer un établissement | ⚠️ | V1 (`referentiels-equipe`, par import JSON seulement, sans formulaire : décision du porteur du 2026-09-25 ; classes générées : ADR-0030) — livrée 2026-09-27 (#33) | Une erreur 500 pour les rôles non autorisés au lieu d'un refus |
| ☑ | SC-04 | Liste nationale des établissements | ⚠️ | V1 (`referentiels-equipe`) — livrée 2026-09-27 (#33) | Des filtres factices ; un bouton « Nouvelle École » mort |
| ☑ | SC-05 | Consulter un établissement | ✅ | V1 (`referentiels-equipe`) — livrée 2026-09-27 (#33) | Une fiche ouverte à tout connecté |
| ☑ | SC-06 | Modifier un établissement | ⚠️ | V1 (`referentiels-equipe`, dont le cycle) — livrée 2026-09-27 (#33) | Une modification ouverte à tout connecté |
| ☑ | SC-07 | Supprimer un établissement | ❌ | V1 (`referentiels-equipe`, F-14) — livrée 2026-09-27 (#33) | `RecordNotDestroyed` dès qu'un membre du personnel existe ; une suppression ouverte à tout connecté |
| ☑ | SC-08 | Importer des établissements | ⚠️ | V1 (`referentiels-equipe`, import en masse : ADR-0039) — livrée 2026-09-27 (#33) | Aucun rapport d'import ; des comptes démo créés en effet de bord |
| ☑ | SC-09 | Générer les classes par défaut | ⚠️ | V1 (`referentiels-equipe`, ADR-0030) — livrée 2026-09-27 (#33) | Des collisions de slug qui laissent l'école sans classes |
| ☑ | SC-26 | API des établissements d'une DRENA | ✅ | V1 (inscription enseignant) — livrée 2026-09-27 (#33) ; l'inscription ne l'appelle plus depuis le code d'établissement (ADR-0057, #49), l'adresse reste publique | Un endpoint public sans limite de débit |
| ☑ | SC-27 | Rattachement à l'école à l'inscription enseignant | ✅ | V1 (Lot D) — livrée 2026-09-27 (#33) | — |

### Classes — `CL`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | CL-01 | Créer une classe (équipe) | ❌ | V1 (Lot D : « les classes sont créées par l'équipe », [`plan.md`](plan.md) §1) — livrée 2026-09-27 (#33) | Un slug passé à `find_by_id` ; un code de 6 caractères pour une colonne de 5 |
| ☑ | CL-04 | Générer et afficher le code d'adhésion | ⚠️ | V1 (Lot D) — livrée 2026-09-27 (#33) | Un affichage tantôt en minuscules, tantôt en majuscules |
| ☑ | CL-06 | Rejoindre une classe par `/c/<code>` | ⚠️ | V1 (Lot A) (= ID-02) — livrée 2026-09-27 (#33) | — |
| ☑ | CL-07 | S'inscrire avec un code | ✅ | V1 (Lot A) (= ID-01) — livrée 2026-09-27 (#33) | — |
| ☑ | CL-08 | API de vérification de code et de liste de classes | ⚠️ | V1 pour la vérification (= ID-07) — livrée 2026-09-27 (#33) · **écartée** pour la liste de classes | Une API énumérable |
| ☑ | CL-09 | Déclarer les classes que l'on enseigne | ⚠️ | V1 (Lot D) — livrée 2026-09-27 (#33) | Un remplacement qui efface les classes de toutes les écoles |
| ☑ | CL-10 | Fiche d'une de ses classes | ❌ | V1 (Lot D) — livrée 2026-09-27 (#33) | La fiche qui casse dès le premier exercice assigné |
| ☑ | CL-11 | Consulter un cours dans sa classe | ❌ | V1 (Lot D) — livrée 2026-09-27 (#33) | — |
| ☑ | CL-12 | Consulter une fiche dans sa classe | ❌ | V1 (Lot D) — livrée 2026-09-27 (#33) | — |
| ☑ | CL-16 | Assigner ou retirer un cours | 💀 | V1 (Lot D) — livrée 2026-09-27 (#33) | Réassigner une ressource retirée lève `RecordNotUnique` au lieu de la réactiver |
| ☑ | CL-17 | Assigner ou retirer une fiche | 💀 | V1 (Lot D) — livrée 2026-09-27 (#33) | Idem |
| ☑ | CL-20 | Assigner ou retirer un exercice | ⚠️ | V1 (Lot D) — livrée 2026-09-27 (#33) | Idem CL-16 |
| ☑ | CL-22 | Sa classe et ses cours (élève) | ⚠️ | V1 (Lot A / D) — livrée 2026-09-27 (#33) | Des cours retirés (archivés) encore affichés |
| ☑ | CL-23 | Fil d'accueil élève | ❌ | V1 (= TR-04) — livrée 2026-09-27 (#33) | — |

### Catalogue — `CA`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | CA-01 | Parcourir le catalogue publié | ⚠️ | V1 (Lot B, liste simple) — livrée 2026-09-27 (#33) · V4 (`catalogue-complet`) | Un niveau et une matière qui ne filtrent pas les brouillons |
| ☑ | CA-04 | Consulter un cours | ✅ | V1 (Lot B) — livrée 2026-09-27 (#33) | Un brouillon lisible par URL directe |
| ☑ | CA-05 | Créer un cours | ⚠️ | V1 (Lot B) — livrée 2026-09-27 (#33) | Aucun point d'entrée dans l'interface |
| ☑ | CA-06 | Modifier un cours | ❌ | V1 (Lot B) — livrée 2026-09-27 (#33) | Deux familles d'entités incompatibles (C-19) |
| ☑ | CA-07 | Supprimer un cours | ✅ | V1 (Lot B, archivage : F-14) — livrée 2026-09-27 (#33) | Une cascade qui détruit lacunes et assignations |
| ☑ | CA-08 | Importer des cours en masse | ⚠️ | V1 (`import-contenu`, ADR-0039) — livrée 2026-09-27 (#33) | Un import non atomique, sans rapport, qui crée de la taxonomie implicite |
| ☑ | CA-10 | Lister les fiches d'un cours | ⚠️ | V1 (Lot B) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-11 | Consulter une fiche et sa progression | ✅ | V1 (Lot B / C) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-12 | Créer une fiche | ❌ | V1 (Lot B, `team` seulement) — livrée 2026-09-27 (#33) | Une création ouverte à tout connecté |
| ☑ | CA-13 | Modifier une fiche | ❌ | V1 (Lot B) — livrée 2026-09-27 (#33) | Idem ; C-19 |
| ☑ | CA-14 | Supprimer une fiche | ✅ | V1 (Lot B, archivage) — livrée 2026-09-27 (#33) | Idem ; cascade |
| ☑ | CA-15 | Importer des fiches dans un cours | 💀 | V1 (`import-contenu`, ADR-0039) — livrée 2026-09-27 (#33) | Un import synchrone ouvert à tout connecté |
| ☑ | CA-16 | Lister les niveaux | ✅ | V1 (écran de l'équipe, ADR-0034) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-18 | Gérer les niveaux | ⚠️ | V1 (écran de l'équipe, ADR-0034) — livrée 2026-09-27 (#33) | Supprimer un niveau détruit ses classes |
| ☑ | CA-19 | Associer des séries à un niveau | ✅ | V1 (ADR-0034) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-20 | Lister les matières | ⚠️ | V1 (écran de l'équipe, ADR-0034) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-22 | Gérer les matières | ⚠️ | V1 (ADR-0034, `category` obligatoire) — livrée 2026-09-27 (#33) | `category` laissée à `NULL` ; une clé de cache jamais invalidée |
| ☑ | CA-24 | Gérer les séries | ⚠️ | V1 (ADR-0034) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-25 | Taxonomie depuis l'onglet « Setup » | ⚠️ | V1 (= TR-13, ADR-0034) — livrée 2026-09-27 (#33) | — |
| ☑ | CA-26 | Icône et couleur de la matière | ✅ | V1 (Lot B, UDR) — livrée 2026-09-27 (#33) | Une couleur déduite du nom au lieu de `category` |
| ☑ | CA-27 | Affecter un cours depuis sa page | 💀 | V1 (Lot D) — livrée 2026-09-27 (#33) : le point d'entrée de l'assignation est fixé par l'UDR du lot | Un bouton inatteignable (`@teacher_classrooms` jamais affecté) |

### Évaluation — `AS`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | AS-02 | Consulter le détail d'un exercice | ⚠️ | V1 (Lot C) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-03 | Créer un exercice par le formulaire | ❌ | V1 (Lot B), **construite** de zéro — livrée 2026-09-27 (#33) | « + Ajouter une question » inerte (contrôleur Stimulus absent) ; des questions jamais persistées ; un titre passé en `titleize` |
| ☑ | AS-04 | Modifier un exercice | ❌ | V1 (Lot B) — livrée 2026-09-27 (#33) | Idem |
| ☑ | AS-05 | Supprimer un exercice | ✅ | V1 (Lot B, archivage : F-14) — livrée 2026-09-27 (#33) | Une cascade qui détruit sessions, tentatives et badges des élèves |
| ☑ | AS-07 | Démarrer une session | ✅ | V1 (Lot C) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-08 | Reprendre une session en cours | ✅ | V1 (Lot C) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-09 | Répondre aux questions une à une | ❌ ⚠️ | V1 (Lot C, F-34) — livrée 2026-09-27 (#33) | Une question déjà répondue qu'on peut re-soumettre après avoir vu le corrigé, doublon compté dans le score ; une réponse vide qui produit une erreur 500 en Turbo |
| ☑ | AS-10 | Voir la correction immédiate | ⚠️ | V1 (Lot C) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-11 | Obtenir un badge à la clôture | ⚠️ | V1 (Lot C, F-10) — livrée 2026-09-27 (#33) | Un badge écrit mais jamais affiché |
| ☑ | AS-12 | Voir le résultat d'une session | ⚠️ | V1 (Lot C, F-11) — livrée 2026-09-27 (#33) | Le pourcentage seul, sans la note ni le badge promis par l'ADR-0008 |
| ☑ | AS-13 | Recommencer un exercice | ✅ | V1 (Lot C) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-18 | Assigner un exercice à une classe | ❌ | V1 (Lot D) (= CL-20) — livrée 2026-09-27 (#33) | Une réponse `204` qui laisse le bouton inchangé ; `assigned_by_id` qui reçoit un id de profil pour une clé vers `users` |
| ☑ | AS-19 | Retirer un exercice d'une classe | ⚠️ | V1 (Lot D) (= CL-20) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-20 | Exercices d'un chapitre dans une classe | ❌ | V1 (Lot D) (= CL-12) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-36 | Exercices de ma classe sur l'accueil élève | ❌ | V1 (Lot A / D) (= TR-04) — livrée 2026-09-27 (#33) | — |
| ☑ | AS-37 | Ma progression sur la fiche d'un chapitre | ⚠️ | V1 (Lot C) (= CA-11) — livrée 2026-09-27 (#33) | Des exercices non publiés listés à l'élève |
| ☑ | AS-38 | Créer exercices, questions et réponses par l'import de cours | ⚠️ | V1 (`import-contenu`, = CA-08) — livrée 2026-09-27 (#33) | `questions.position` jamais écrite |
| ☑ | AS-39 | Aperçu des questions sur la carte d'exercice | ❌ | V1 (Lot C) — livrée 2026-09-27 (#33) | **Fuite des bonnes réponses** : un fragment mis en cache par question, sans le rôle dans la clé, servi à un élève après un enseignant ([`securite.md`](securite.md) n° 29) |

### Transverse — `TR`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | TR-02 | Redirection selon le rôle | ⚠️ | V1 (0b) (= ID-13) — livrée 2026-09-27 (#33) | La boucle infinie de l'enseignant sans école |
| ☑ | TR-04 | Fil d'accueil élève | ❌ | V1 (Lot A / D, F-31) — livrée 2026-09-27 (#33) · annonces en V6 | Un écran d'accueil sans test système (il levait une exception sans alerte) |
| ☑ | TR-05 | Fil d'accueil enseignant | ❌ | V1 (Lot D) — livrée 2026-09-27 (#33) · activité des élèves en V3 | Idem |
| ☑ | TR-09 | Fil d'accueil équipe | ✅ | V1 (Lot B, minimal) — livrée 2026-09-27 (#33) · V4 (`pilotage-equipe`) — livrée 2026-09-28 (#51) | — |
| ☑ | TR-13 | « Configuration Plateforme » | ✅ | V1 (`referentiels-equipe`, ADR-0034) — livrée 2026-09-27 (#33) | — |
| ☑ | TR-27 | Navigation par rôle | ⚠️ | V1 (Lot 0c, F-31) — livrée 2026-09-27 (#33) | 4 × 4 partials divergents |
| ☑ | TR-28 | Imports JSON en arrière-plan | ⚠️ | V1 (écoles et contenu, ADR-0039) — livrée 2026-09-27 (#33) | Un échec de job silencieux ; un fichier posé sur le disque éphémère du conteneur ; un nom de fichier client dans un chemin disque |
| ☑ | TR-41 | Formules mathématiques (KaTeX) | ✅ | V1 (Lot B / C, F-29) — livrée 2026-09-27 (#33) | KaTeX chargé depuis un CDN tiers |


## V2 — Organisation scolaire et espace direction

### Identité — `ID`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | ID-09 | Rattacher un enseignant existant à l'établissement | ⚠️ | V2 (`espace-direction`) | Un formulaire sans vue (`MissingTemplate`) |
| ☐ | ID-10 | Rattacher un élève existant à une classe | ⚠️ | V2 (`espace-direction`) | Idem ; adhésion non principale sans règle |
| ☐ | ID-11 | Lister les enseignants et les élèves de l'établissement | ⚠️ | V2 (`espace-direction`) | Comptes démo mêlés aux vrais élèves |
| ☑ | ID-17 | Modifier son profil | ⚠️ | V2 (`mon-compte`) — livrée 2026-09-28 (#37), hors ordre des vagues : chantier `profil-utilisateur` | Changer son PIN sans saisir le PIN actuel |
| ☐ | ID-18 | Modifier une fiche depuis `/users/:id/edit` | ❌ | V2 (`annuaire-equipe`, fusionnée avec ID-17) | Des clés de formulaire que le contrôleur ne lit pas |
| ☐ | ID-19 | Profil de direction, avatar compris | ❌ | V2 (`mon-compte`) — avatar livré 2026-09-28 (#50, chantier `photo-de-profil`) ; le profil de direction reste à livrer avec l'espace direction | Un avatar qu'aucun chemin n'enregistre |
| ☐ | ID-20 | Changer son PIN côté direction | ❌ | V2 (`mon-compte`, fusionnée avec ID-17) — changement du PIN sous PIN actuel livré pour tous les rôles 2026-09-28 (#37) ; à recetter côté direction avec la V2 | Idem ID-17 ; route `settings/edit` sans action |
| ☐ | ID-21 | Lister tous les utilisateurs | ⚠️ | V2 (`annuaire-equipe`) | — |
| ☐ | ID-22 | Consulter la fiche d'un utilisateur | ⚠️ | V2 (`annuaire-equipe`) | Une fiche ouverte à tout connecté, qui expose le contact et accepte l'identifiant numérique |
| ☐ | ID-23 | Supprimer un utilisateur | ⚠️ | V2 (`annuaire-equipe`, F-14) | Une cascade qui détruit sessions, badges et lacunes |

### Établissements — `SC`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | SC-11 | Lister et créer les rôles d'un établissement | ⚠️ | V2 (F-22 : rôles de référence) | Un échec de création silencieux |
| ☐ | SC-12 | Supprimer un rôle | ⚠️ | V2 | Une suppression non scopée à l'école de l'URL |
| ☐ | SC-13 | Rattacher un membre du personnel | ⚠️ | V2 (invitation, F-22) | Un doublon affiché comme un succès ; le rôle d'une autre école accepté |
| ☐ | SC-14 | Retirer un membre du personnel | ⚠️ | V2 | Un retrait non scopé à l'école |
| ☐ | SC-15 | Tableau de bord de l'établissement | ⚠️ | V2 (`espace-direction`) | Un fil d'actualité vide codé en dur |
| ☐ | SC-16 | Page « en attente d'affectation » | ✅ | V2 | — |
| ☐ | SC-17 | Classes de son établissement | ✅ | V2 | — |
| ☐ | SC-18 | Tableau de bord d'une classe (direction) | ❌ | V2 | Une fuite inter-établissements ; des statistiques vides |
| ☐ | SC-19 | Créer une classe (direction) | ❌ | V2 (qui crée une classe : F-06) | Une action sans vue |
| ☐ | SC-20 | Lister les élèves de l'établissement | ✅ | V2 (= ID-11) | — |
| ☐ | SC-21 | Ajouter un élève existant à une classe | ❌ | V2 (= ID-10) | — |
| ☐ | SC-22 | Lister les enseignants de l'établissement | ✅ | V2 (= ID-11) | — |
| ☐ | SC-23 | Rattacher un enseignant existant | ❌ | V2 (= ID-09) | — |
| ☐ | SC-24 | Profil de direction | ✅ | V2 (= ID-19) | — |
| ☐ | SC-25 | Changer son PIN côté direction | ⚠️ | V2 (= ID-20) | — |

### Transverse — `TR`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | TR-15 | Tableau de bord de l'établissement | ⚠️ | V2 (= SC-15) | — |
| ☐ | TR-16 | « En attente d'affectation » | ✅ | V2 (= SC-16) | — |
| ☐ | TR-20 | Annuaire des comptes | ⚠️ | V2 (= ID-21) | — |
| ☐ | TR-21 | Fiche d'un compte | ⚠️ | V2 (= ID-22) | — |
| ☐ | TR-22 | Modifier ou supprimer un compte | ⚠️ | V2 (= ID-18, ID-23) | — |


## V3 — Suivi pédagogique enseignant

### Identité — `ID`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | ID-27 | Enseigner dans plusieurs établissements | ⚠️ | V3 (`multi-etablissements-enseignant`, F-06) | `schools.first` sans ordre |

### Classes — `CL`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CL-02 | Modifier une classe | ❌ | V3 (`vie-de-la-classe`) — **déplacée de V1 le 2026-09-28** : aucun lot de la V1 ne la portait (ajout et retrait seulement, `classes-par-niveau`) ; elle touche au plafond et au code de l'ADR-0041 et à la numérotation de l'ADR-0059 | Un échec muet |
| ☐ | CL-03 | Supprimer une classe | ⚠️ | V3 (`vie-de-la-classe` : archivage, F-19) | Une suppression définitive qui détruit l'historique des assignations |
| ☑ | CL-05 | Partager le lien de classe sur WhatsApp | 💀 | V3 (`vie-de-la-classe`) — livrée 2026-09-28 (#71), hors ordre des vagues : chantier `croissance-parrainage` | — |
| ☐ | CL-13 | Fiche d'un élève de sa classe | ❌ | V3 (`rapports-de-classe`) | — |
| ☐ | CL-14 | Tableau de bord générique d'une classe | ❌ | V3, fusionné avec CL-10 | Une classe ouverte à tout connecté ; 3 compteurs sur 4 toujours vides |
| ☐ | CL-15 | Liste paginée des élèves d'une classe | ⚠️ | V3 | Un cache de ligne jamais invalidé ; une liste ouverte à tout connecté |

### Évaluation — `AS`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | AS-21 | Rapport de synthèse d'un exercice | ❌ | V3 (`rapports-de-classe`) | « Tentatives » qui compte des sessions ; des niveaux de badge affichés en anglais |
| ☐ | AS-22 | Rapport détaillé par question et par élève | ❌ | V3 | Un taux de réussite qui dépasse 100 % dès qu'un élève recommence ; des questions numérotées par `id` |
| ☐ | AS-23 | Message d'encouragement à l'enseignant | ❌ | V3 | 36 phrases en dur dans la vue |
| ☐ | AS-24 | Détail d'un élève | ⚠️ | V3 (= CL-13) | Un mur de badges qui mélange toutes les classes |
| ☐ | AS-25 | Compteurs de badges de la classe sur la carte | ⚠️ | V3 | Une requête par carte (N+1) |


## V4 — Contenu à l'échelle et back-office équipe

### Identité — `ID`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | ID-26 | Bannière d'installation PWA | ⚠️ | V4 (`installation-pwa`) | « Installée » enregistré sur iOS sans installation ; n'importe quelle valeur d'enum acceptée |

### Catalogue — `CA`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CA-02 | Filtrer par niveau ou matière | ⚠️ | V4 | — |
| ☐ | CA-03 | Pagination infinie | 💀 | V4 | Un lien de page jamais rendu |
| ☐ | CA-17 | Espace Niveau | ⚠️ | V4 (`catalogue-complet`) | — |
| ☐ | CA-21 | Page matière | ⚠️ | V4 | — |
| ☐ | CA-23 | Pages des séries | ❌ | V4 (`catalogue-complet`) — **déplacée de V2 le 2026-09-28** : page publique du catalogue, avec CA-17 et CA-21 | — |

### Évaluation — `AS`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | AS-01 | Parcourir tous les exercices de la plateforme | ⚠️ | V4 (`catalogue-complet`) | Une page liée nulle part ; une carte mise en cache sans l'utilisateur ni le rôle dans la clé |

### Transverse — `TR`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | TR-10 | « Control Center » équipe | ❌ | V4 (`pilotage-equipe`) — livrée 2026-09-28 (#51) | Un tableau de bord sans test (méthode renommée sans mise à jour de l'appelant) |
| ☑ | TR-11 | Rechercher un élève ou un enseignant | ❌ | V4 (`pilotage-equipe`) — livrée 2026-09-28 (#51) | — |
| ☑ | TR-12 | Répartition des élèves par niveau | 💀 | V4 (`pilotage-equipe`) — livrée 2026-09-28 (#51) | — |
| ☐ | TR-24 | Manifeste PWA et service worker | ⚠️ | V4 (`installation-pwa`) | Un service worker entièrement commenté |
| ☐ | TR-25 | Bandeau d'installation | ⚠️ | V4 (= ID-26) | — |


## V5 — Remédiation et lacunes

### Évaluation — `AS`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☑ | AS-14 | Détecter une lacune après un échec | 💀 | V5 (F-21) — livrée en avance avec la V1, 2026-09-27 (#33) : à la clôture de session, seuil de résolution 75 % (ADR-0043 amendé) | Une détection branchée sur un use case que le parcours réel n'appelle pas |
| ☑ | AS-15 | Résoudre une lacune après une réussite | 💀 | V5 (F-21) — livrée en avance avec la V1, 2026-09-27 (#33) : à la clôture de session, seuil de résolution 75 % (ADR-0043 amendé) | Idem |
| ☐ | AS-16 | Lancer une session de remédiation | ❌ | V5 | Un bouton qui appelle un helper de route inexistant |
| ☐ | AS-17 | Suivre les remédiations de sa classe | ❌ | V5 | `NoMethodError` sur panneau fermé |


## V6 — Communication (annonces)

### Communication — `CO`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CO-01 | Publier une annonce | ⚠️ | V6a (`annonces`) | Des pièces jointes non validées ; un flux Turbo qui ne cible rien |
| ☐ | CO-02 | Modifier une annonce | ⚠️ | V6a | Aucun bouton Éditer pour l'équipe sur `/messages` |
| ☐ | CO-03 | Supprimer une annonce | ⚠️ | V6a | Idem |
| ☐ | CO-04 | Parcourir les annonces qui me sont destinées | ⚠️ | V6a | — |
| ☐ | CO-05 | Lire le détail d'une annonce | ⚠️ | V6a | Une annonce lisible hors de son audience ou avant sa publication, par URL directe |
| ☐ | CO-06 | Voir les annonces récentes dans son fil | ⚠️ | V6a | — |
| ☐ | CO-07 | Écarter une annonce | ⚠️ | V6a (`message_dismissals`) | Un rejet stocké dans un cookie de session, perdu au changement d'appareil |
| ☐ | CO-10 | Programmer ou archiver une annonce | ❌ | V6a (job de publication, F-23) | Des statuts sans effet |
| ☐ | CO-11 | Annonces dans l'espace direction | ❌ | V6a | Un bloc vide codé en dur ; une audience sans valeur `school_admin` |
| ☐ | CO-12 | Widget « annonces » du tableau de bord équipe | 💀 | V6a | — |


## V8 — Hors vague, à décider

### Catalogue — `CA`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CA-28 | Validation collaborative | 💀 | V8 (F-33) | — |


## Retirées du plan le 2026-09-22

### Identité — `ID`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | ID-06 | S'inscrire depuis la page « Prépa BAC » | ❌ | **écartée** — retirée du plan le 2026-09-22 | Une route publique qui crée un compte dont le PIN est le contact |
| ☐ | ID-25 | Espace parent | ❌ absent | **écartée** — retirée du plan le 2026-09-22 (hors périmètre depuis le 2026-09-18) | Un rôle déclaré sans espace, qui retombe sur `/` |
| ☐ | ID-30 | Comptes démo qui occupent des numéros | ⚠️ | **écartée** — retirée du plan le 2026-09-22 | Des démos stockées dans `users` |
| ☐ | ID-34 | Tableau des examens sur le fil équipe (branche) | ⚠️ non fusionné | **écartée** — retirée du plan le 2026-09-22 | — |

### Communication — `CO`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CO-08 | Recevoir une annonce sans recharger la page | ❌ absent | **écartée** — retirée du plan le 2026-09-22 | — |

### Classes — `CL`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CL-24 | Peupler les classes d'élèves démo | ⚠️ | **écartée** — retirée du plan le 2026-09-22 | Des démos dans `users` |
| ☐ | CL-26 | Simuler l'activité des démos | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | CL-27 | Purger les démos | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |

### Évaluation — `AS`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | AS-26 | Simuler les sessions des démos | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-27 | Catalogue de sujets d'examen (élève) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-28 | Consulter un sujet (paywall) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-29 | Refaire un sujet | ❌ 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-30 | Banque de sujets (enseignant) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-31 | Sujet et classes éligibles | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-32 | Assigner ou retirer un sujet | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-33 | Valider une assignation de sujet | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-34 | Gérer la banque de sujets (équipe) | ❌ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | AS-35 | Importer des sujets en JSON | ❌ | **écartée** — retirée du plan le 2026-09-22 | Un message d'erreur d'import passé en `html_safe` (injection HTML par fichier) |

### Transverse — `TR`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | TR-03 | « Espace Etabl. » à 2 000 FCFA | ❌ | **écartée** — retirée du plan le 2026-09-22 | Un lien vers une route inexistante |
| ☐ | TR-06 | Gains « Prepa » en FCFA | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | TR-14 | « LnclassAI » | ⚠️ | **écartée** — retirée du plan le 2026-09-22 : iframe vers un artefact externe non inspecté, aucun besoin documenté | Charger un contenu tiers dans l'espace équipe sans CSP |
| ☐ | TR-17 | Formulaire « Prepa BAC » enseignant | ⚠️ | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | TR-18 | PDF « Analyse de récurrence » | 💀 | **écartée** — retirée du plan le 2026-09-22 | Un téléchargement sans contrôle de rôle ; un bouton `href="#"` |
| ☐ | TR-19 | Paywall « Prepa BAC » | 💀 | **écartée** — retirée du plan le 2026-09-22 | Un faux numéro WhatsApp ; un statut de paiement jamais persisté |
| ☐ | TR-30 | Démos : générer et simuler | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |
| ☐ | TR-33 | Temps réel (Solid Cable) | 💀 | **écartée** — retirée du plan le 2026-09-22 | — |


## Écartées (doublons, code mort, routes injustifiées)

### Identité — `ID`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | ID-04 | S'inscrire comme membre de l'équipe | ❌ | **écartée** : aucune route publique ne crée un compte `team`. Remplacée par le seed et l'invitation (V1, F-16) | La route `/team-signup` |
| ☐ | ID-05 | S'inscrire comme administrateur d'établissement | ❌ | **écartée** : remplacée par l'invitation de la direction (V2, F-22) | La route `/staff-signup` |
| ☐ | ID-24 | Changer de rôle | ❌ absent | **écartée** : aucun besoin exprimé | — |
| ☐ | ID-31 | Refonte visuelle des pages d'authentification (branche) | ⚠️ non fusionné | **écartée** comme code ; matière d'inspiration pour l'UDR du Lot 0c | — |
| ☐ | ID-32 | Délégation ORM → entités (branche) | ❌ non fusionné, cassé | **écartée** : l'architecture cible (F-01, F-03) la rend sans objet | Fusionner cette branche : elle casserait les cinq inscriptions |
| ☐ | ID-33 | Plan « Ticket 4 » (branche) | ❌ jamais livré | **écartée** : document obsolète (il suppose Devise et un ADR-0016 d'identité) | — |

### Communication — `CO`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CO-13 | Annonces factices en développement | ⚠️ | **écartée** : remplacée par des seeds de développement | Des données factices dans le code des contrôleurs |

### Établissements — `SC`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | SC-02 | Importer des DRENA | ⚠️ | **écartée** : les 41 DRENA se saisissent à l'écran (ADR-0034) ; aucun format d'import (ADR-0039) | Une action d'import sans route (TR-29) |
| ☐ | SC-10 | S'inscrire comme administrateur d'établissement | ⚠️ | **écartée** (= ID-05) | — |

### Classes — `CL`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CL-18 | Cours dans le contexte d'une classe (chemin générique) | ❌ | **écartée** : doublon de CL-11 | — |
| ☐ | CL-19 | Fiche dans le contexte d'une classe (chemin générique) | ❌ | **écartée** : doublon de CL-12 | — |
| ☐ | CL-21 | Assignations depuis l'espace enseignant | 💀 | **écartée** : doublon de CL-16, CL-17 et CL-20 ; les use cases n'ont jamais existé | — |
| ☐ | CL-25 | Second générateur de démos | 💀 | **écartée** (doublon mort de CL-24) | — |
| ☐ | CL-28 | Liste nationale des classes | ⚠️ | **écartée** : l'équipe liste les classes par école (V2) | Une liste nationale ouverte à tout connecté |

### Catalogue — `CA`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | CA-09 | « Import JSON Express » dans le formulaire | 💀 | **écartée** : aucun contrôleur JavaScript n'existe ; l'import de la V1 (ADR-0039) le remplace | — |
| ☐ | CA-29 | Bandeau « Conforme au programme » | ⚠️ | **écartée** : affirmation fausse affichée à tous (F-33) | Une validation affichée qui n'a jamais eu lieu |

### Évaluation — `AS`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | AS-06 | Importer des exercices par le « content engine » | ❌ 💀 | **écartée** : le service n'a jamais existé dans aucun commit ; l'import d'exercices de la V1 (ADR-0039) le remplace | — |
| ☐ | AS-40 | Durée estimée d'un exercice | 💀 | **écartée** : jamais affichée, aucune règle décidée | — |

### Transverse — `TR`

| | ID | Feature | État ancien | Vague / précision | Ne pas reproduire |
|---|---|---|---|---|---|
| ☐ | TR-07 | `/teachers/dashboard` | 💀 | **écartée** : page d'échafaudage vide ; le tableau de bord de classe est livré en V3 | — |
| ☐ | TR-08 | `/teachers/setup` | 💀 | **écartée** : remplacée par un onboarding à état persisté (V1, Lot D) | — |
| ☐ | TR-23 | Thème clair / sombre | 💀 | **écartée** en V1 (F-09, approuvée le 2026-09-25) | Une bascule sans palette sombre |
| ☐ | TR-29 | Import des DRENA en arrière-plan | 💀 | **écartée** (= SC-02) | — |
| ☐ | TR-38 | E-mails (Action Mailbox) | 💀 | **écartée** : aucune feature ne l'utilise ; les 14 routes sont retirées | — |
| ☐ | TR-42 | `Current.user` dans les couches basses | 💀 | **écartée** comme feature : l'acteur est passé en paramètre au use case et à sa policy (F-04) | — |
