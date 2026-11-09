# Chantiers

**C'est ici que vit le travail.** Un chantier sans dossier ici n'existe pas : ni pour l'équipe, ni pour les agents.

## Ouvrir un chantier

```
/feature <slug>    /bugfix <slug>    /refactor <slug>    /optimize <slug>    /hotfix <slug>
```

Un petit changement sans règle métier n'ouvre pas de chantier : `/retouche <slug>` ([`retouche.md`](../workflows/retouche.md)), une ligne dans le journal du chantier parent.

Sans Claude Code : `cp -r docs/chantiers/_TEMPLATE docs/chantiers/<slug>`

Le `<slug>` est en kebab-case, court, sans type ni numéro : `messagerie-classe`, pas `feature-5-messagerie`.

## Contenu d'un chantier

| Fichier | Phase | Rôle |
|---|---|---|
| `memo.md` | 1 — Cadrer | Le problème, pour qui, hors périmètre, ce que le grill a révélé |
| `prd.md` | 2 — Décider | Les specs figées et les critères d'acceptation |
| `plan.md` | 3 — Planifier | Le graphe de lots et les portes de sortie |
| `journal.md` | tout du long | Ce qui a dérapé, ce qu'on a appris, la dette laissée |
| `etat.md` | 4 — Exécuter | **Seulement s'il est orchestré.** Lots, PR, SHA, décisions, prochaine action, prompt de reprise ([`orchestrateur.md`](../workflows/orchestrateur.md)) |
| `pr-faq.md` | 1 — Cadrer | **Optionnel.** Pour les gros chantiers seulement : on rédige le communiqué de presse et la FAQ *avant* de construire (« working backwards »). Si le communiqué n'enthousiasme personne, la feature ne mérite pas d'être faite. |

Les ADR et UDR produits par un chantier ne vivent **pas** ici : ils vont dans [`../decisions/`](../decisions/), parce qu'ils survivent au chantier. Le chantier les référence.

## Programme ouvert

| Programme | En une phrase | Point d'entrée |
|---|---|---|
| [`refonte-application`](refonte-application/memo.md) | Recoder Lnclass dans un nouveau dépôt Rails, par vagues V0 → V8 | [`feuille-de-route.md`](refonte-application/feuille-de-route.md) — le plan complet, les décisions à prendre, la traçabilité de chaque feature |

Liste de travail des 213 features, rangée par vague et cochable : [`../features-refonte.md`](../features-refonte.md). Elle est générée à partir du §6 de la feuille de route, qui fait foi.

Un programme suit [`../workflows/programme.md`](../workflows/programme.md) : il ne produit pas de code, il ouvre vague par vague des chantiers ordinaires.

## Tous les chantiers

Tableau **généré** depuis l'en-tête du `memo.md` de chaque dossier (titre, **Statut**, **Type de cycle**, **Ouvert le**), par ordre alphabétique : `script/docs/build_index` le réécrit, et le pre-commit le lance dès qu'un memo est commité. On ne l'édite jamais à la main, on ne le commite jamais seul : clore un chantier, c'est passer son memo en `Statut: livré` dans le commit de clôture.

<!-- chantiers:start -->
| Chantier | Statut | Type | Ouvert le | Sujet |
|---|---|---|---|---|
| [`abonnement-mobile-money`](abonnement-mobile-money/memo.md) | cadrage | feature | 2026-10-02 | Abonnement payé par Mobile Money (Wave) |
| [`acceleration-du-flux`](acceleration-du-flux/memo.md) | livré | refactoring | 2026-10-20 | Accélération du flux : numéros de décision posés à la fusion, migrations en deux temps, retour arrière |
| [`accueil-direction`](accueil-direction/memo.md) | livré | feature | 2026-10-04 | Accueil de la direction : établissement, niveaux, annonces, activité |
| [`accueil-eleve`](accueil-eleve/memo.md) | planification | feature | 2026-10-15 | Accueil élève aux couleurs Wave et Djamo |
| [`acteurs-fantomes-parent-examsubject`](acteurs-fantomes-parent-examsubject/memo.md) | abandonné | bugfix | 2026-09-18 | `Parent` et `ExamSubject` : déclarés partout, persistés nulle part |
| [`actions-en-menu`](actions-en-menu/memo.md) | livré | feature | 2026-09-28 | Actions d'un objet dans un menu ⋮ |
| [`afficher-pin`](afficher-pin/memo.md) | livré | feature | 2026-09-28 | Afficher le code PIN |
| [`aide-whatsapp-message-pret`](aide-whatsapp-message-pret/memo.md) | livré | feature | 2026-10-16 | Message prêt dans le lien WhatsApp de la carte d'aide |
| [`alt-couverture-perdu`](alt-couverture-perdu/memo.md) | livré | bugfix | 2026-10-07 | Une image glissée dans un article prend le focus à l'auteur qui écrit ailleurs |
| [`amorcage-depot`](amorcage-depot/memo.md) | livré | feature | 2026-09-25 | Amorçage du dépôt (V0) |
| [`annonce-audio-mp3`](annonce-audio-mp3/memo.md) | abandonné | bugfix | 2026-10-05 | Un MP3 enregistré au téléphone est refusé à la création d'une annonce |
| [`annonces`](annonces/memo.md) | livré en PR | feature | 2026-10-03 | Annonces ciblées, programmables et écartables |
| [`annonces-logo-audio`](annonces-logo-audio/memo.md) | en revue | feature | 2026-10-30 | Annonces : le logo officiel, un audio de 10 secondes, plus de « Toutes les annonces » |
| [`annonces-v2`](annonces-v2/memo.md) | livré en PR | feature | 2026-10-05 | Annonces, deuxième version — saisie guidée, illustrations de l'équipe, trois annonces visibles, thèmes de couleur |
| [`annuaire-equipe`](annuaire-equipe/memo.md) | décision | feature | 2026-09-28 | Annuaire de l'équipe (« Comptes ») |
| [`app-android`](app-android/memo.md) | app élèves exécutée | feature | 2026-09-30 | App Android pour élèves et enseignants |
| [`archivage-classes`](archivage-classes/memo.md) | livré | feature | 2026-10-09 | Archiver une classe |
| [`audit-500-et-messages`](audit-500-et-messages/memo.md) | en cours | bugfix | 2026-11-08 | Audit : 500 évitables et messages trompeurs |
| [`audit-bugs-p2`](audit-bugs-p2/memo.md) | exécution | bugfix | 2026-11-08 | audit-bugs-p2 — B-003, B-004, B-005 |
| [`audit-code-mort`](audit-code-mort/memo.md) | livré | refactoring | 2026-11-08 | Audit code mort (M-001 à M-004) |
| [`audit-decisions-produit`](audit-decisions-produit/memo.md) | en cours | bugfix | 2026-11-08 | Décisions produit de l'audit du 8 novembre 2026 |
| [`audit-gems-loofah`](audit-gems-loofah/memo.md) | livré | bugfix | 2026-11-02 | Avis de sécurité loofah, nokogiri, rails-html-sanitizer |
| [`audit-jobs-echecs-muets`](audit-jobs-echecs-muets/memo.md) | livré | bugfix | 2026-11-08 | Jobs : échecs muets (audit 2026-11-08) |
| [`audit-perf-rapide`](audit-perf-rapide/memo.md) | livré | optimisation | 2026-11-08 | Audit perf rapide |
| [`audit-ux-roles`](audit-ux-roles/) | pas de memo | — | — | — |
| [`audit-yarn-braces`](audit-yarn-braces/memo.md) | livré en PR | bugfix | 2026-10-03 | L'audit Yarn bloque toute la CI sur une faille de braces sans correctif |
| [`b001-privileges-equipe`](b001-privileges-equipe/memo.md) | livré | bugfix | 2026-11-08 | B-001 : privilèges entre sous-rôles de l'équipe |
| [`badge-liste-moyenne`](badge-liste-moyenne/memo.md) | livré | bugfix | 2026-10-29 | Liste de la classe : le badge dit qu'il vient de la moyenne |
| [`bareme-classes`](bareme-classes/memo.md) | livré | feature | 2026-09-28 | Barème des classes modifiable par l'équipe |
| [`base-de-lecons`](base-de-lecons/memo.md) | en cours | refactoring | 2026-11-06 | Base de leçons : seules les leçons au format complet actuel |
| [`blog`](blog/memo.md) | planifié | feature | 2026-10-02 | Blog de Lnclass |
| [`blog-toast-instable`](blog-toast-instable/memo.md) | preuve | bugfix | 2026-10-27 | Le toast « Article créé » arrive parfois après la fin de l'attente du test |
| [`boucle-pedagogique`](boucle-pedagogique/memo.md) | livré | feature | 2026-09-25 | Boucle pédagogique (V1) |
| [`boucle-pedagogique-instable`](boucle-pedagogique-instable/memo.md) | preuve | bugfix | 2026-10-27 | La boucle pédagogique perd parfois un clic du Référentiel |
| [`cache-ecrans-lourds`](cache-ecrans-lourds/memo.md) | lots 1 à 4 et 2c | optimisation | 2026-09-29 | Écrans lourds : mesurer avant de mettre en cache |
| [`calcul-litteral-comme-thales`](calcul-litteral-comme-thales/memo.md) | livré | feature | 2026-11-05 | Calcul littéral préparé comme Thalès |
| [`canal-whatsapp`](canal-whatsapp/memo.md) | cadrage | feature | 2026-09-28 · cadrage repris le 2026-10-16 | Canal WhatsApp pour joindre les utilisateurs hors de l'application |
| [`carrousel-classes-enseignant`](carrousel-classes-enseignant/memo.md) | livré | bugfix | 2026-10-30 | Carrousel des classes de l'enseignant : revenir vers la gauche sur ordinateur |
| [`carte-profil-eleve`](carte-profil-eleve/memo.md) | livré | feature | 2026-10-30 | Carte de profil de l'élève dans la barre latérale |
| [`cartes-activation`](cartes-activation/memo.md) | livré | feature | 2026-11-07 | Cartes d'activation vendues au point relais |
| [`catalog-lecture-ecriture-incompatibles`](catalog-lecture-ecriture-incompatibles/memo.md) | abandonné | bugfix | 2026-09-18 | Catalogue : entités de lecture et d'écriture incompatibles |
| [`catalogue-complet`](catalogue-complet/memo.md) | livré | feature | 2026-10-16 | Catalogue complet : pages publiques Niveau, Matière et Série |
| [`catalogue-niveau-eleve`](catalogue-niveau-eleve/memo.md) | livré | bugfix | — | Le catalogue de l'élève limité à son niveau |
| [`changement-etablissement-eleve`](changement-etablissement-eleve/memo.md) | livré | feature | 2026-10-16 | Un élève change de classe ou d'établissement en cours de scolarité |
| [`chargement-lecons-v3-develop`](chargement-lecons-v3-develop/memo.md) | livré | feature | 2026-11-02 | Develop charge seul les leçons v3 du programme, entières |
| [`charger-toutes-les-lecons-develop`](charger-toutes-les-lecons-develop/memo.md) | livré | feature | 2026-11-04 | Develop charge toutes les leçons v3 du dépôt, entières |
| [`choix-classe-eleve`](choix-classe-eleve/memo.md) | lots A et B livrés sur feature/choix-cla… | feature | 2026-10-15 | « Choisis ta classe » aux couleurs Wave et Djamo |
| [`ci-audit-yarn-local`](ci-audit-yarn-local/memo.md) | livré | optimisation | 2026-09-25 | L'audit Yarn ralentit chaque `bin/ci` local |
| [`ci-cloud-claude`](ci-cloud-claude/memo.md) | en cours | feature | 2026-10-05 | La CI rejouée dans le cloud Claude |
| [`ci-durees-enregistrees`](ci-durees-enregistrees/memo.md) | livré | optimisation | 2026-11-06 | Durées système enregistrées par la CI |
| [`ci-gardes-en-double`](ci-gardes-en-double/memo.md) | livré | optimisation | 2026-09-26 | Les gardes tournent deux fois dans `bin/ci` |
| [`ci-par-train`](ci-par-train/memo.md) | livré | optimisation | 2026-10-20 | Une CI complète par train, plus par PR |
| [`ci-perf-a-la-demande`](ci-perf-a-la-demande/memo.md) | livré | optimisation | 2026-10-19 | La perf des imports et les CI répétées ralentissent chaque PR |
| [`ci-quota`](ci-quota/memo.md) | en cours | optimisation | 2026-09-29 | La CI épuise le quota de minutes GitHub Actions |
| [`ci-rapide`](ci-rapide/memo.md) | en cours | optimisation | 2026-09-28 | La CI GitHub dure près de 10 minutes |
| [`ci-rejeu-cible`](ci-rejeu-cible/memo.md) | livré | optimisation | 2026-10-27 | Rejouer seulement ce qu'un changement peut casser |
| [`ci-train-rapide`](ci-train-rapide/memo.md) | en cours | optimisation | 2026-11-05 | Un train plus rapide sur GitHub |
| [`ci-unit-en-parts`](ci-unit-en-parts/memo.md) | livré | optimisation | 2026-11-04 | La suite unitaire en parts sur GitHub, couverture fusionnée |
| [`classe-vide-lien-cours`](classe-vide-lien-cours/memo.md) | livré | bugfix | 2026-10-29 | Classe sans exercice : « ci-dessous » ne montre rien |
| [`classes-par-niveau`](classes-par-niveau/memo.md) | livré | feature | 2026-09-28 | Ajuster le nombre de classes par niveau d'un établissement |
| [`classroom-assignment-belongs-to-casses`](classroom-assignment-belongs-to-casses/memo.md) | livré | bugfix | 2026-09-18 | Les trois `belongs_to` scopés de `ClassroomAssignment` sont inutilisables |
| [`classroom-code-adhesion-trop-long`](classroom-code-adhesion-trop-long/memo.md) | abandonné | bugfix | 2026-09-18 | Code d'adhésion généré trop long pour sa colonne |
| [`code-etablissement`](code-etablissement/memo.md) | livré | feature | 2026-09-28 | Code d'établissement pour l'inscription des enseignants |
| [`comptes-de-test-staging`](comptes-de-test-staging/memo.md) | en cours | feature | 2026-11-05 | Comptes de test sur Staging |
| [`connexion-inscription-eleve`](connexion-inscription-eleve/memo.md) | livré | feature | 2026-10-15 | Connexion et inscription de l'élève aux couleurs Wave et Djamo |
| [`contenu-en-blocs`](contenu-en-blocs/memo.md) | livré | feature | 2026-10-12 | Fiches de révision en blocs |
| [`contenus-1ere-a-physique-chimie`](contenus-1ere-a-physique-chimie/memo.md) | livré | feature | 2026-11-02 | Les leçons de Physique-Chimie de 1ère A (A1 et A2) au format v3 |
| [`contenus-1ere-a-svt`](contenus-1ere-a-svt/memo.md) | livré | feature | 2026-11-02 | Les 9 leçons de SVT de 1ère A1 et A2 |
| [`contenus-1ere-francais`](contenus-1ere-francais/memo.md) | livré | feature | 2026-11-01 | Les 11 leçons de Français de Première (A, C, D) |
| [`contenus-1ere-histoire-geographie`](contenus-1ere-histoire-geographie/memo.md) | terminé | feature | 2026-11-02 | Leçons de 1ère en Histoire-Géographie au format v3 |
| [`contenus-1ere-mathematiques-a`](contenus-1ere-mathematiques-a/memo.md) | en cours | feature | 2026-11-02 | Les 7 leçons de Mathématiques de 1ère A |
| [`contenus-1ere-mathematiques-cd`](contenus-1ere-mathematiques-cd/memo.md) | en cours | feature | 2026-11-01 | Les 10 premières leçons de Mathématiques de 1ère C et de 1ère D |
| [`contenus-1ere-philosophie`](contenus-1ere-philosophie/memo.md) | livré | feature | 2026-11-02 | Les 8 premières leçons de Philosophie de 1ère (A1, A2, C, D) |
| [`contenus-1ere-physique-chimie-cd`](contenus-1ere-physique-chimie-cd/memo.md) | livré | feature | 2026-11-01 | Les leçons de Physique-Chimie de 1ère C et D au format v3 |
| [`contenus-1ere-svt-cd`](contenus-1ere-svt-cd/memo.md) | livré | feature | 2026-11-01 | Les 10 premières leçons de SVT de 1ère C et D |
| [`contenus-3e-autres-matieres`](contenus-3e-autres-matieres/memo.md) | livré | programme | 2026-10-30 | Leçons de 3ème en SVT, Physique-Chimie, Histoire-Géographie, Français et EDHC, et leurs figures |
| [`contenus-3e-edhc`](contenus-3e-edhc/memo.md) | livré | feature | 2026-10-30 | Les 10 premières leçons d'EDHC de 3ème |
| [`contenus-3e-francais`](contenus-3e-francais/memo.md) | planifié | feature | 2026-10-30 | Les 10 premières leçons de Français de 3ème |
| [`contenus-3e-histoire-geographie`](contenus-3e-histoire-geographie/memo.md) | en cours | feature | 2026-10-30 | Leçons de 3ème en Histoire-Géographie, et leurs figures (frise, carte, schéma, courbe) |
| [`contenus-3e-physique-chimie`](contenus-3e-physique-chimie/memo.md) | planifié | feature | 2026-10-30 | Les 10 premières leçons de Physique-Chimie de 3ème, tracé optique, molécule et planches de PC |
| [`contenus-3e-svt`](contenus-3e-svt/memo.md) | livré | feature | 2026-10-30 | Les 10 premières leçons de SVT de 3ème et leurs planches |
| [`contenus-develop-staging`](contenus-develop-staging/memo.md) | livré | feature | 2026-10-31 | Les leçons arrivent seules sur Develop et Staging |
| [`contenus-tle-francais`](contenus-tle-francais/memo.md) | livré | feature | 2026-10-31 | Les 7 leçons de Français de Terminale (A1, A2, C, D) |
| [`contenus-tle-histoire-geographie`](contenus-tle-histoire-geographie/memo.md) | livré | feature | 2026-10-31 | Les 10 premières leçons d'Histoire-Géographie de Tle (progression commune) |
| [`contenus-tle-mathematiques-a`](contenus-tle-mathematiques-a/memo.md) | livré | feature | 2026-10-31 | Les leçons de Mathématiques de Tle A1 et de Tle A2 |
| [`contenus-tle-mathematiques-cd`](contenus-tle-mathematiques-cd/memo.md) | livré | feature | 2026-10-31 | Les 10 premières leçons de Mathématiques de Tle C et de Tle D |
| [`contenus-tle-philosophie`](contenus-tle-philosophie/memo.md) | livré | feature | 2026-10-31 | Les 10 premières leçons de Philosophie de Tle (A1, A2, C, D) |
| [`contenus-tle-physique-chimie`](contenus-tle-physique-chimie/memo.md) | livré | feature | 2026-10-31 | Les leçons de Physique-Chimie de Tle C et D au format v3 |
| [`contenus-tle-svt-a`](contenus-tle-svt-a/memo.md) | livré | feature | 2026-10-31 | Les 7 leçons de SVT de Terminale A1 et A2 |
| [`contenus-tle-svt-cd`](contenus-tle-svt-cd/memo.md) | livré | feature | 2026-10-31 | Les 10 premières leçons de SVT de Terminale C et D |
| [`contenus-v3-tous-niveaux`](contenus-v3-tous-niveaux/memo.md) | en cours | programme | 2026-10-31 | Leçons au format v3 pour tous les niveaux (Tle → 6ème) |
| [`contrat-de-session`](contrat-de-session/memo.md) | livré | refactoring | 2026-11-05 | Contrat de session |
| [`copie-refusee-page-bloquee`](copie-refusee-page-bloquee/memo.md) | livré | bugfix | 2026-10-29 | Copie refusée : la page ne répond plus |
| [`correction-comme-en-classe`](correction-comme-en-classe/memo.md) | livré | feature | 2026-10-28 | Corriger une copie comme en classe |
| [`cours-eleve`](cours-eleve/memo.md) | planification | feature | 2026-10-15 | Page Cours de l'élève aux couleurs Wave et Djamo |
| [`cours-pleine-largeur`](cours-pleine-largeur/memo.md) | livré | feature | 2026-11-04 | La fiche de cours remplit l'écran du téléphone |
| [`couverture-catalogue`](couverture-catalogue/memo.md) | livré | bugfix | 2026-10-30 | Couverture à 100 % perdue par la refonte des maths |
| [`couverture-train`](couverture-train/memo.md) | livré | bugfix | 2026-10-31 | Couverture du train #417 |
| [`crm-ecoles`](crm-ecoles/memo.md) | cadrage | feature | 2026-11-04 | CRM des écoles |
| [`croissance-parrainage`](croissance-parrainage/memo.md) | livré | feature | 2026-09-28 | Croissance par parrainage entre enseignants, démarrage à froid et mesure du k-factor |
| [`cycles-en-radio`](cycles-en-radio/memo.md) | livré | feature | 2026-09-28 | Cycles en boutons radio |
| [`deploiement-seeds-variantes`](deploiement-seeds-variantes/memo.md) | livré | bugfix | 2026-09-29 | Seeds joués deux fois au déploiement, `image_processing` réclamé au démarrage |
| [`dette-contrats-ports-et-injection`](dette-contrats-ports-et-injection/memo.md) | abandonné | refactoring | 2026-09-18 | Contrats de ports et injection de dépendances non respectés |
| [`dettes-reorganisation`](dettes-reorganisation/memo.md) | livré | bugfix | 2026-10-04 | Dettes du chantier « réorganisation équipe / enseignant » |
| [`develop-rouge-medailles`](develop-rouge-medailles/memo.md) | livré | bugfix | 2026-11-09 | Develop rouge après les médailles |
| [`dockerfile-docker-hub-429`](dockerfile-docker-hub-429/memo.md) | en cours | bugfix | 2026-10-09 | Dockerfile et limite de Docker Hub (429) |
| [`ecrans-direction-lents`](ecrans-direction-lents/memo.md) | livré | optimisation | 2026-10-04 | Écrans de la direction dans leur budget |
| [`enrolement-secret-stable`](enrolement-secret-stable/memo.md) | livré | bugfix | 2026-09-30 | Le QR code d'enrôlement reste valable quand la page est rouverte |
| [`enseignant-plusieurs-matieres`](enseignant-plusieurs-matieres/memo.md) | exécution | feature | 2026-10-16 | Un enseignant qui enseigne plusieurs matières |
| [`environnements-de-pr`](environnements-de-pr/memo.md) | livré | feature | 2026-10-21 | Environnements de PR sur Railway |
| [`epuration-contenus`](epuration-contenus/memo.md) | livré | feature | — | Épuration des en-têtes de contenu et « Tout publier » |
| [`espace-direction`](espace-direction/memo.md) | exécution | feature | 2026-10-16 | Espace direction, ce qui reste de la V2 |
| [`espace-direction-simple`](espace-direction-simple/memo.md) | planifié | feature | 2026-09-28 | Espace direction, version simple |
| [`essential-images-instable`](essential-images-instable/memo.md) | preuve | bugfix | 2026-10-27 | Le test des images d'une fiche juge l'image avant qu'elle soit chargée |
| [`exercice-eleve`](exercice-eleve/memo.md) | livré | feature | 2026-10-15 | Parcours d'exercice de l'élève aux couleurs Wave et Djamo |
| [`exercices-en-cartes`](exercices-en-cartes/memo.md) | livré | feature | 2026-10-30 | Les exercices en cartes |
| [`feuille-pleine-largeur`](feuille-pleine-largeur/memo.md) | livré | feature | 2026-11-04 | La feuille remplit l'écran du téléphone |
| [`feuilles-rendues`](feuilles-rendues/memo.md) | livré | bugfix | 2026-11-06 | Les feuilles d'exercices vérifiées et lisibles sur chaque leçon |
| [`fiche-revision-coupe-50-mots`](fiche-revision-coupe-50-mots/memo.md) | livré | feature | 2026-10-31 | La fiche de révision coupée à 50 mots |
| [`finitions-generation-menu`](finitions-generation-menu/memo.md) | livré | bugfix | 2026-09-28 | Finitions de la génération des classes et du menu ⋮ au téléphone |
| [`finitions-ux`](finitions-ux/memo.md) | livré | feature | 2026-09-29 | Finitions UX |
| [`flux-allege`](flux-allege/memo.md) | livré | refactoring | 2026-11-06 | Un flux allégé : petites branches, retouches, messages, mesure mensuelle |
| [`fonctions-espace-eleve`](fonctions-espace-eleve/memo.md) | planifié | feature | 2026-10-02 | Fonctions de l'espace élève |
| [`generer-classes`](generer-classes/memo.md) | livré | feature | 2026-09-28 | Générer les classes manquantes des établissements |
| [`gestion-etablissement-direction`](gestion-etablissement-direction/memo.md) | planifié | feature | 2026-10-01 | La direction gère son établissement |
| [`historique-eleve`](historique-eleve/memo.md) | livré | feature | 2026-10-15 | Historique de l'élève aux couleurs Wave et Djamo |
| [`hitl-refs-adr-obsoletes`](hitl-refs-adr-obsoletes/memo.md) | abandonné | refactoring | 2026-09-18 | En-têtes HITL citant des numéros d'ADR périmés |
| [`images-dans-les-cours`](images-dans-les-cours/memo.md) | livré | feature | 2026-10-10 | Des images dans les fiches de cours |
| [`import-cours-multiple`](import-cours-multiple/memo.md) | livré | feature | 2026-09-29 | Importer plusieurs fichiers de cours en une fois |
| [`import-drenas`](import-drenas/memo.md) | planifié | feature | 2026-09-29 | Import des DRENA par fichier |
| [`import-second-cycle-force`](import-second-cycle-force/memo.md) | livré | bugfix | 2026-10-09 | Import des établissements : second cycle pour tous |
| [`infobulle-badges-hors-ecran`](infobulle-badges-hors-ecran/memo.md) | livré | bugfix | 2026-10-19 | La bulle « Badges » de la page de résultat sort de l'écran |
| [`inscription-classe-meme-wifi`](inscription-classe-meme-wifi/memo.md) | livré | bugfix | 2026-10-29 | Une classe s'inscrit ensemble depuis le wifi de l'école |
| [`inscription-direction`](inscription-direction/memo.md) | livré | feature | 2026-10-04 | Inscription de la direction sans invitation |
| [`inscription-eleve-sans-code`](inscription-eleve-sans-code/memo.md) | planifié | feature | 2026-10-07 | Inscription des élèves sans code de classe |
| [`inscription-enseignant`](inscription-enseignant/memo.md) | livré | feature | 2026-10-07 | Amélioration du parcours d'inscription des enseignants |
| [`inscription-test-course`](inscription-test-course/memo.md) | livré | bugfix | 2026-10-30 | Le test d'inscription enseignant rouge sous charge |
| [`installation-pwa`](installation-pwa/memo.md) | livré | feature | 2026-10-07 | Installer Lnclass sur le téléphone (PWA) |
| [`interface-eleve-organisation`](interface-eleve-organisation/memo.md) | livré | feature | 2026-10-05 | Organisation des écrans élève : accueil, « Ma classe » et rythme d'une session |
| [`interface-enseignant-organisation`](interface-enseignant-organisation/memo.md) | livré | feature | 2026-10-05 | Organisation des écrans enseignant : accueil, catalogue, fiche et page d'une classe |
| [`interface-epuree`](interface-epuree/memo.md) | planifié | feature | 2026-09-30 | Interface épurée |
| [`interrupteur-theme`](interrupteur-theme/memo.md) | en cours | feature | 2026-10-03 | Interrupteur clair / sombre |
| [`je-m-entraine-dans-la-fiche`](je-m-entraine-dans-la-fiche/memo.md) | livré | feature | 2026-10-30 | « Je m’entraîne » dans la fiche de révision |
| [`lecons-3eme-comme-thales`](lecons-3eme-comme-thales/memo.md) | PR prête | feature | 2026-11-05 | Les leçons de 3ème préparées comme Thalès |
| [`lecons-defauts-affichage`](lecons-defauts-affichage/memo.md) | décision | bugfix | 2026-11-02 | Leçons v3 en défaut d'affichage |
| [`lecons-tle-a1-comme-thales`](lecons-tle-a1-comme-thales/memo.md) | en cours | feature | 2026-11-07 | Les leçons de Terminale A1 préparées comme Thalès |
| [`lecons-tle-a2-comme-thales`](lecons-tle-a2-comme-thales/memo.md) | en cours | feature | 2026-11-08 | Les leçons de Terminale A2 préparées comme Thalès |
| [`lecons-tle-c-comme-thales`](lecons-tle-c-comme-thales/memo.md) | en cours | feature | 2026-11-05 | Les leçons de Terminale C préparées comme Thalès |
| [`lecons-tle-comme-thales`](lecons-tle-comme-thales/memo.md) | en cours | feature | 2026-11-08 | Les leçons de Terminale (Histoire-Géographie) préparées comme Thalès |
| [`lecons-tle-d-comme-thales`](lecons-tle-d-comme-thales/memo.md) | en cours | feature | 2026-11-07 | Les leçons de Terminale D préparées comme Thalès |
| [`libelles-courts-matieres`](libelles-courts-matieres/memo.md) | livré | feature | 2026-10-30 | Les libellés courts des matières |
| [`ma-classe-eleve`](ma-classe-eleve/memo.md) | livré | feature | 2026-10-15 | Page Ma classe de l'élève aux couleurs Wave et Djamo |
| [`medailles-direction`](medailles-direction/memo.md) | terminé | feature | 2026-11-09 | Médailles : écrans de la direction |
| [`medailles-eleve`](medailles-eleve/memo.md) | en cours | feature | 2026-11-08 | Médailles : écrans de l'élève |
| [`medailles-enseignant`](medailles-enseignant/memo.md) | en cours | feature | 2026-11-09 | Médailles : écrans de l'enseignant |
| [`medailles-equipe`](medailles-equipe/memo.md) | en cours | feature | 2026-11-09 | Médailles : écrans de l'équipe |
| [`medailles-grading-bronze`](medailles-grading-bronze/memo.md) | décision | feature | 2026-11-08 | Bronze pour tout exercice traité |
| [`medailles-vocabulaire`](medailles-vocabulaire/memo.md) | en cours | refactoring | 2026-11-08 | Médailles : vocabulaire et garde-fous |
| [`menu-enseignants-masque`](menu-enseignants-masque/memo.md) | livré | bugfix | 2026-10-04 | Menu ⋮ des enseignants masqué par la ligne suivante |
| [`message-repository-fuite-activerecord`](message-repository-fuite-activerecord/memo.md) | abandonné | refactoring | 2026-09-18 | Fuite d'objets ActiveRecord dans `Entities::Message` |
| [`mise-a-jour-en-direct`](mise-a-jour-en-direct/memo.md) | cadrage | feature | 2026-09-30 | Mise à jour en direct |
| [`modales-sans-js`](modales-sans-js/memo.md) | livré | bugfix | 2026-09-28 | Une modale servie ouverte reste invisible sans JavaScript |
| [`mode-sombre`](mode-sombre/memo.md) | livré | feature | 2026-10-03 | Mode sombre de l'application |
| [`multi-etablissements-enseignant`](multi-etablissements-enseignant/memo.md) | PR prête | feature | 2026-10-16 | Un enseignant dans plusieurs établissements |
| [`mvp-teacher-student`](mvp-teacher-student/memo.md) | replanifié élève d'abord | feature | 2026-10-22 | MVP Lnclass Teacher & Student — pilote du 27 octobre |
| [`note-sur-20-partout`](note-sur-20-partout/memo.md) | PR prête | feature | 2026-10-19 | La note sur 20 décide partout |
| [`orchestrateur-court-et-index`](orchestrateur-court-et-index/memo.md) | livré | refactoring | 2026-11-05 | Orchestrateurs courts et index des chantiers généré |
| [`ordre-lecons-progression`](ordre-lecons-progression/memo.md) | livré | bugfix | 2026-10-29 | Les leçons dans l'ordre de la progression |
| [`outils-ci-budgets`](outils-ci-budgets/memo.md) | livré | correction | 2026-10-28 | Deux outils de CI en retard sur leurs règles |
| [`ouverture-remediation`](ouverture-remediation/memo.md) | livré | feature | 2026-11-09 | La fiche s'ouvre sous l'Or |
| [`page-d-accueil-photo`](page-d-accueil-photo/memo.md) | cadrage | feature | 2026-10-14 | Page d'accueil publique en photo plein écran |
| [`parcours-matiere-exercice`](parcours-matiere-exercice/memo.md) | livré | optimisation | 2026-10-30 | Parcours matière → exercice |
| [`pentest-develop`](pentest-develop/) | pas de memo | — | — | — |
| [`pentest-strix`](pentest-strix/memo.md) | cadrage | feature | 2026-09-28 | Pentest automatisé de la recette avant la mise en ligne |
| [`photo-de-profil`](photo-de-profil/memo.md) | en cours | feature | 2026-09-28 | Photo de profil |
| [`pilotage-equipe`](pilotage-equipe/memo.md) | livré | feature | 2026-09-28 | Pilotage de l'équipe |
| [`politique-cache`](politique-cache/memo.md) | en cours | optimisation | 2026-10-03 | Politique de cache : ce qui rend les pages lentes, et ce qu'un cache peut y changer |
| [`prepare-interros-cahier`](prepare-interros-cahier/memo.md) | livré | feature | 2026-10-30 | « Prépare interros » et « Prépare devoirs » à l'identique des maquettes cahier |
| [`profil-eleve`](profil-eleve/memo.md) | lots 0 | feature | 2026-10-15 | Profil de l'élève aux couleurs Wave et Djamo |
| [`profil-utilisateur`](profil-utilisateur/memo.md) | livré | feature | 2026-09-27 | Page profil de chaque utilisateur |
| [`progres-eleve`](progres-eleve/memo.md) | livré | feature | 2026-10-04 | L'élève voit son propre progrès |
| [`qcm-plusieurs-reponses`](qcm-plusieurs-reponses/memo.md) | livré | bugfix | 2026-11-04 | Un QCM à plusieurs bonnes réponses refuse tout l'exercice sans dire pourquoi |
| [`queries-constantes-orm-disparues`](queries-constantes-orm-disparues/memo.md) | livré | bugfix | 2026-09-18 · repris le 2026-09-24 | Requêtes de lecture appelant des modèles ORM disparus (ADR-0007 non propagé) |
| [`question-matching-instable`](question-matching-instable/memo.md) | preuve | bugfix | 2026-10-27 | Les tests « aucun id révélé » des questions à relier et à ordonner échouent sans fuite |
| [`rapports-de-classe`](rapports-de-classe/memo.md) | livré en PR | feature | 2026-10-16 | Rapports de classe : la fiche d'un élève et ce qui reste du suivi enseignant |
| [`rapports-exercices`](rapports-exercices/memo.md) | livré | feature | 2026-10-04 | Comprendre où en est la classe sur un exercice |
| [`recette-v1-defauts`](recette-v1-defauts/memo.md) | livré | bugfix | 2026-09-28 | Défauts de la recette V1 |
| [`refaire-ou-continuer`](refaire-ou-continuer/memo.md) | livré | feature | 2026-11-04 | Refaire ou continuer depuis la correction |
| [`refonte-application`](refonte-application/memo.md) | décision | programme | 2026-09-18 | Refonte de l'application dans un nouveau projet Rails |
| [`refonte-contenus-maths`](refonte-contenus-maths/memo.md) | livré | feature | 2026-10-29 | Refonte des contenus de mathématiques |
| [`refonte-homepage`](refonte-homepage/memo.md) | livré | feature | 2026-10-02 | Refonte de la page d'accueil publique |
| [`refonte-page-lecon`](refonte-page-lecon/memo.md) | livré | feature | 2026-10-28 | Refonte de la page de la leçon : fiche de révision, « Prépare interros » et exercices sur feuille |
| [`regeneration-codes-en-masse`](regeneration-codes-en-masse/memo.md) | exécution | feature | 2026-10-16 | Régénérer en une fois les codes d'établissement et les liens des classes |
| [`remediation-ciblee`](remediation-ciblee/memo.md) | livré | feature | 2026-10-16 | Remédiation ciblée : l'élève lève sa fiche, l'enseignant voit qui bloque |
| [`remediation-comptee-faite`](remediation-comptee-faite/memo.md) | livré | bugfix | 2026-10-04 | Une remédiation compte comme exercice fait |
| [`rendu-lecons-v3-390`](rendu-lecons-v3-390/memo.md) | en cours | bugfix | 2026-11-02 | Rendu des leçons v3 à 390 px |
| [`renommage-fiche-revision`](renommage-fiche-revision/memo.md) | planifié | feature | 2026-10-12 | « Fiche de cours » et « Fiche de révision » à l'écran |
| [`reorganisation-equipe-enseignant`](reorganisation-equipe-enseignant/memo.md) | livré | feature | 2026-10-03 | Réorganisation des espaces Équipe et Enseignant |
| [`retention-ip-audit`](retention-ip-audit/memo.md) | livré | feature | 2026-10-05 | Rétention de l'adresse IP du journal d'audit |
| [`retouches`](retouches/memo.md) | permanent | retouche | 2026-11-06 | Retouches sans chantier parent |
| [`retrait-debugbar`](retrait-debugbar/memo.md) | livré | bugfix | 2026-10-03 | Retrait de debugbar |
| [`revision-eleve`](revision-eleve/memo.md) | en pause | feature | 2026-10-15 | Révision de l'élève (fiche de révision) aux couleurs Wave et Djamo |
| [`routage-modeles`](routage-modeles/memo.md) | livré | refactoring | 2026-10-19 | Routage des modèles par rôle |
| [`secrets-hors-cache`](secrets-hors-cache/memo.md) | livré | bugfix | 2026-09-29 | Secrets à usage unique hors de tout cache |
| [`seeds-premiere-serie-a`](seeds-premiere-serie-a/memo.md) | abandonné | feature | 2026-10-11 | Référentiel de développement : séries de la 1ère (abandonné, hypothèse « A, C et D » réfutée) |
| [`selection-par-carte-de-couverture`](selection-par-carte-de-couverture/memo.md) | cadrage | optimisation | 2026-10-03 | Ne jouer que les tests système que les fichiers touchés concernent (carte de couverture) |
| [`seuil-remediation`](seuil-remediation/memo.md) | livré | feature | 2026-11-09 | Une seule échelle : la remédiation suit la médaille |
| [`sobriete-tokens`](sobriete-tokens/memo.md) | en cours | refactoring | 2026-10-09 | Sobriété de tokens |
| [`sous-roles-equipe`](sous-roles-equipe/memo.md) | cadrage | feature | 2026-10-16 | Sous-rôles de l'équipe appliqués (admin, contenu, terrain) |
| [`standard-de-test`](standard-de-test/memo.md) | livré | feature | 2026-11-02 | Un standard de test pour Lnclass |
| [`suites-inscription-direction`](suites-inscription-direction/memo.md) | livré | bugfix | 2026-10-04 | Suites de l'inscription de la direction |
| [`suivi-classe-lecon`](suivi-classe-lecon/memo.md) | livré | feature | 2026-11-05 | Suivi de la classe sur une leçon : lacunes, réussite par exercice, remédiation |
| [`sujet-avant-de-commencer`](sujet-avant-de-commencer/memo.md) | livré | feature | 2026-10-31 | Chaque feuille dans une case, lue avant de commencer |
| [`sujet-comme-une-epreuve`](sujet-comme-une-epreuve/memo.md) | livré | feature | 2026-11-04 | Le sujet se lit comme une vraie épreuve |
| [`sujets-cahier-noir-blanc`](sujets-cahier-noir-blanc/memo.md) | livré | feature | 2026-11-05 | Les sujets d'interrogation en cahier noir et blanc |
| [`sujets-thales-feuilles`](sujets-thales-feuilles/memo.md) | livré | feature | 2026-10-31 | Sujets de devoir Thalès, titres numérotés des feuilles, correction en bloc |
| [`teams-dashboard-cours-recents`](teams-dashboard-cours-recents/memo.md) | livré | bugfix | 2026-09-23 | Le tableau de bord Team plante en 500 |
| [`test-date-figee`](test-date-figee/memo.md) | livré | bugfix | 2026-10-30 | Un test de suivi d'exercice rouge depuis le 30 octobre 2026 |
| [`tester-pr-en-local`](tester-pr-en-local/memo.md) | livré | feature | 2026-10-21 | Tester une PR sur sa machine |
| [`tests-correction-alignes`](tests-correction-alignes/memo.md) | livré | bugfix | 2026-10-29 | Dix tests d'intégration de l'évaluation, rouges sur Develop |
| [`tests-instables`](tests-instables/memo.md) | livré | bugfix | 2026-09-28 | Trois tests instables sous CI bloquée |
| [`tests-instables-cache-blog`](tests-instables-cache-blog/memo.md) | livré | bugfix | 2026-10-08 | Tests instables : cache de l'accueil de la direction et texte alternatif du blog |
| [`tests-numero-connexion`](tests-numero-connexion/memo.md) | livré | bugfix | 2026-10-15 | Tests système alignés sur le numéro en chiffres de la connexion |
| [`tests-systeme-develop`](tests-systeme-develop/memo.md) | livré | bugfix | 2026-10-04 | Tests système en retard sur Develop |
| [`tests-toast-masque-clic`](tests-toast-masque-clic/memo.md) | livré | bugfix | 2026-10-15 | Un toast ne masque plus le clic suivant dans les tests système |
| [`totp-emetteur-par-environnement`](totp-emetteur-par-environnement/memo.md) | livré | bugfix | 2026-09-30 | Émetteur TOTP par environnement |
| [`travail-eleves-budget`](travail-eleves-budget/memo.md) | livré | optimisation | 2026-10-05 | « Travail des élèves » de la direction sous son budget |
| [`ux-pages-eleve`](ux-pages-eleve/) | pas de memo | — | — | — |
| [`validation-enseignants-en-pause`](validation-enseignants-en-pause/memo.md) | en cours | feature | 2026-10-02 | Validation des enseignants en pause |
| [`validation-figures-bornee`](validation-figures-bornee/memo.md) | livré | optimisation | 2026-10-30 | Validation des figures bornée |
| [`verification-whatsapp`](verification-whatsapp/memo.md) | backlog | feature | 2026-09-28 | Vérifier le numéro par WhatsApp à l'inscription sans code |
| [`vie-de-la-classe`](vie-de-la-classe/memo.md) | livré | feature | 2026-10-16 | La vie de la classe : la modifier, la lire, la fermer pour de bon |
<!-- chantiers:end -->

## Backlog

Travail mis de côté par le porteur. Les vagues V2 à V6 y sont placées le 2026-09-28 (la V2 en sort le jour même dans sa version simple, [`espace-direction-simple`](espace-direction-simple/memo.md)) : aucune n'est ouverte avant une décision datée du porteur ; leur périmètre, leurs chantiers et leurs questions sont au [§5 de la feuille de route](refonte-application/feuille-de-route.md#5-les-vagues). Pour un chantier, le memo dit où reprendre. Le backlog ne liste que le travail pas encore livré : l'état d'un chantier qui a son dossier se lit dans le tableau généré ci-dessus, et une ligne d'ici s'efface quand son chantier est livré, dans le commit de clôture.

| Chantier | En une phrase |
|---|---|
| `annuaire-equipe` (V2) | Grill fait : l'équipe modifie nom, genre et numéro ; désactive puis anonymise automatiquement à 30 jours ; entrée « Comptes » qui remplace « Débloquer un compte » ; ni soi-même ni le dernier admin ; recherche par nom partiel, numéro ou matricule exacts. Memo sur la branche [`feature/annuaire-equipe`](https://github.com/Lnclassapp/App.Lnclassapp/tree/feature/annuaire-equipe). Il retirera aussi une direction |
| **V3 — Suivi pédagogique enseignant** | `rapports-de-classe`, `vie-de-la-classe` (dont CL-02) ; `multi-classes-eleve` si Q5 le confirme. `multi-etablissements-enseignant` est une ligne à part, ci-dessus |
| **V4 — Contenu à l'échelle et back-office** | 9 features : `catalogue-complet` (livré le 2026-10-16), `installation-pwa` (avancé, planifié le 2026-10-07), `sous-roles-equipe` ; Q9 ouverte, Q10 tranchée (hors ligne → `eleve-hors-ligne`) |
| **V5 — Remédiation** | 2 features : AS-16 (remédiation ciblée), AS-17 (suivi par l'enseignant) |
| **V6 — Communication** | 10 features : `annonces` et `annonces-v2` en production (2026-10-07) ; reste `canal-whatsapp` ([PR #70](https://github.com/Lnclassapp/App.Lnclassapp/pull/70)) ; Q11 à Q14 ouvertes |
| [`verification-whatsapp`](verification-whatsapp/memo.md) | Prouver le numéro par un code WhatsApp (hook n8n) à l'inscription sans code ; grill interrompu à la question 2. Rattaché à la V4 s'il reprend ([feuille de route §5](refonte-application/feuille-de-route.md#chantiers-hors-plan)) |
| [`canal-whatsapp`](canal-whatsapp/memo.md) | **Cadrage**, grill non commencé ; V6, après `annonces` : joindre élèves, enseignants et directions par WhatsApp hors de l'application, pour les annonces et peut-être le code de récupération du PIN. Memo et plan dans `Develop` ([#70](https://github.com/Lnclassapp/App.Lnclassapp/pull/70)) |
| [`pentest-strix`](pentest-strix/memo.md) | **En attente** depuis le 2026-09-28 (porteur) : pentest automatisé de la recette avant la mise en ligne ; grill arrêté à la question 5, le financement de la clé d'API facturée à l'usage n'étant pas décidé |
| [`ci-quota`](ci-quota/memo.md) | **En cours**, lots 1, 2, 5, 6, 7, 8 et 9 livrés ([#106](https://github.com/Lnclassapp/App.Lnclassapp/pull/106), [#136](https://github.com/Lnclassapp/App.Lnclassapp/pull/136), [#148](https://github.com/Lnclassapp/App.Lnclassapp/pull/148), [#149](https://github.com/Lnclassapp/App.Lnclassapp/pull/149), [#150](https://github.com/Lnclassapp/App.Lnclassapp/pull/150), [#190](https://github.com/Lnclassapp/App.Lnclassapp/pull/190), [#192](https://github.com/Lnclassapp/App.Lnclassapp/pull/192)), en production le 2026-10-07 ; restent la mesure sur 3 runs (lot 3) et `selection-par-carte-de-couverture` : CI sur les PR prêtes, preuve d'arbre et preuves cloud, tirage 1 sur 5, Dependabot vers `Develop` ; depuis le 2026-10-03, deux jobs `unit` ∥ `system`, le système en trois parts (lot 9), et budget de croissance 15 s par chantier (ADR-0069 §9) |
| [`ci-cloud-claude`](ci-cloud-claude/memo.md) | **En cours**, ouvert le 2026-10-05 : routine horaire qui joue `bin/ci` dans une session cloud neuve (hook SessionStart) sur chaque PR vers `Develop` et commente le verdict, preuve demandée par l'ADR-0069 pendant la coupure de la CI GitHub |
| [`selection-par-carte-de-couverture`](selection-par-carte-de-couverture/memo.md) | **Cadrage**, ouvert le 2026-10-03 (décision du porteur, `ci-quota`) : ne jouer que les tests système que les fichiers touchés concernent, à partir de la carte de couverture ; mesure avant prise, grill à tenir avec le porteur |
| [`app-android`](app-android/memo.md) | **App élèves exécutée** le 2026-10-08 ([#205](https://github.com/Lnclassapp/App.Lnclassapp/pull/205), [#206](https://github.com/Lnclassapp/App.Lnclassapp/pull/206)), test sur un vrai téléphone en attente ; **« Lnclass Teacher » exécutée** le même jour ([PRD](app-android/prd-teacher.md), [plan](app-android/plan-teacher.md), ADR-0086, UDR-0082) : l'app élèves « Lnclass » d'abord (Hotwire Native, Android 9 minimum, barres natives), puis « Lnclass Teacher ». Compte Google Play personnel tant que la société n'est pas créée. [ADR-0070](../decisions/adr/0070-deux-apps-android-hotwire-native-le-site-reste-la-reference.md) accepté et amendé, [ADR-0084](../decisions/adr/0084-coque-android-eleves-hotwire-native.md) et [UDR-0080](../decisions/udr/0080-en-tete-eleve-panneau-du-compte-et-barres-de-l-app-android.md) proposés ; 6 lots livrés, APK de recette compilé |
| `erreurs-dans-le-shell` | Une page d'erreur (403 « Accès interdit », 404) se rend dans le shell du rôle quand un compte est connecté, et dans le layout `application` pour un visiteur. Aujourd'hui, un élève connecté qui tombe sur « Accès interdit » perd sa navigation. Demande d'amender l'ADR-0026 (la règle « toujours dans le layout application » n'est écrite que dans `RendersResult` et les vues `errors/`) ; 65 appels à `render_forbidden` ou `render_not_found`. Sorti du lot 10 d'[`ux-pages-eleve`](ux-pages-eleve/README.md), mis au backlog par le porteur le 2026-10-06 |
| `notifications-push` | Notifications poussées dans les deux apps : quatre événements, résumés quotidiens pour l'enseignant, heures calmes, textes sans donnée personnelle. Pas de dossier encore : ses règles sont les questions 5 à 11 du [grill d'`app-android`](app-android/memo.md#ce-que-le-grill-a-révélé). S'ouvre après `app-android` |
| `eleve-hors-ligne` | Sans réseau, l'élève fait ses exercices assignés (corrigés par le serveur au retour du réseau), lit les fiches liées et voit « Ma classe » telle qu'à la dernière connexion. Pas de dossier encore : ses règles sont les questions 1 à 6, 12 et 13 du [grill d'`installation-pwa`](installation-pwa/memo.md#ce-que-le-grill-a-révélé). S'ouvre après `installation-pwa` |
| `inscription-eleve-durcissement` | Suites de [`inscription-eleve-sans-code`](inscription-eleve-sans-code/prd.md), jugées non prioritaires par le porteur le 2026-10-08 : plafond d'inscriptions publiques par classe et par heure contre le remplissage d'une classe ; débit compté par /64 en IPv6 et sans bloquer une salle de classe derrière une seule adresse ; « Retirer et changer le lien » dans la modale de retrait ; repli sans JavaScript qui n'envoie pas le code secret en `GET` ; trace d'audit du retrait et du changement de lien ; enseignant non confirmé qui gère une classe déclarée (ADR-0085 §5) |
| [`note-sur-20-partout`](note-sur-20-partout/memo.md) | PR prête vers `Develop` (2026-10-19), 2 lots ; décision du porteur « Oui, partout » ; [ADR-0106](../decisions/adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) et [UDR-0131](../decisions/udr/0131-paliers-et-maitrise-lus-sur-20-dans-les-infobulles-et-la-faq.md) « Accepté » | Badges, maîtrise, « à revoir » et réussite de la classe se lisent sur la note affichée sur 20, par `Grading.reaches?`, comme les lacunes ; le Diamant reste le sans-faute |
| `ci-en-50-secondes` | Toute CI tient en 50 s : `bin/ci-quiet` local à chaque niveau (doc, pr, train) et chaque tâche GitHub, suite complète comprise. Mis au backlog par le porteur le 2026-10-26, jugeant les durées inacceptables : sur `feature/mvp-teacher-student`, les seuls tests unitaires ont pris 4 min 07 s, avant les tests système. Remplace la borne de 5 minutes par tâche de l'ADR-0107, à amender ; reprend `selection-par-carte-de-couverture` |

Points mineurs non encore rattachés à un chantier : trois orthographes pour le même espace (`schoolstaff/`, `school_admins/`, `SchoolStaff`) ; `config/cable.yml` n'active `solid_cable` qu'en production, donc un broadcast Turbo Stream depuis la console locale n'atteint jamais le navigateur.

## Cycle de vie

Un chantier livré reste en place. Son `memo.md` porte `Statut: livré` et son `journal.md` est clos. On ne supprime pas un chantier : c'est la mémoire du projet.

Un chantier abandonné passe en `Statut: abandonné` avec la raison dans le journal. C'est une information, pas un échec à cacher.
