# UDR-0015 : Page fiche essentielle — contenu riche sous KaTeX, exercices avec la progression de l'élève, menu de l'équipe en modales

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-09-26 |
| **Chantier** | [`docs/chantiers/boucle-pedagogique`](../../chantiers/boucle-pedagogique/plan.md) — Lot B3, critères CA-10, CA-11, AS-37 ; CA-29 (bandeau retiré) |
| **ADR lié** | [ADR-0028](../adr/0028-policies-de-domaine-par-use-case.md) (`ReadPublishedPolicy`, tout exercice publié se démarre) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) (badges, maîtrise) · [ADR-0035](../adr/0035-cycle-de-vie-et-propriete-du-contenu.md) (statuts) · [ADR-0043](../adr/0043-remediation-declenchee-par-la-cloture.md) (lacune) · [ADR-0048](../adr/0048-statuts-d-assignation-active-et-archived.md) (assignations actives) · [ADR-0053](../adr/0053-validation-collaborative-requalifiee.md) (aucun label de conformité) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) · [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) · [UDR-0016](0016-formulaire-fiche-essentielle.md) (modale « Modifier ») · [UDR-0017](0017-formulaire-exercice.md) (modale « Nouvel exercice ») · [UDR-0021](0021-page-exercice.md) (page d'un exercice) |
| **Remplacé par** | — |

---

## 1. Contexte

La fiche essentielle est la page que l'élève ouvre pour réviser, puis pour s'exercer. Dans l'ancienne application (`views/catalog/essentials/show.html.erb`, captures « Brassage génétique par la méiose » et « Anomalies de la méiose ») :

- l'interface l'appelait « Habilité » (sic), et une fiche était visible dès qu'elle existait, publiée ou non ;
- chaque carte d'exercice rendait l'aperçu de ses questions dans un fragment mis en cache **sans le rôle dans la clé** : l'élève pouvait recevoir les bonnes réponses cochées (sécurité n° 29) ;
- un bandeau « Validation collaborative — Conforme au programme » s'affichait partout, alors qu'aucun contenu n'a jamais été validé (CA-29) ;
- le badge de l'élève n'était jamais affiché, faute d'être écrit ;
- l'élève ne savait pas quels exercices son enseignant lui avait demandés, ni que la fiche était à revoir ;
- le menu de l'équipe proposait « Supprimer », qui détruisait les exercices et leurs sessions.

## 2. Décision

1. **Une seule page, `/courses/:course_slug/essentials/:slug`**, pour l'élève, l'enseignant et l'équipe. Une fiche en brouillon ou archivée, ou une fiche d'un cours non publié, répond **404** hors de l'équipe, sans rien confirmer (`ReadPublishedPolicy`). Une fiche lue sous un autre cours que le sien répond aussi 404.
2. **Trois blocs empilés** : l'en-tête avec le contenu, la lacune éventuelle de l'élève, la liste des exercices. Tout se lit d'un défilement ; aucun chargement différé.
3. **Le contenu** est rendu par Action Text (assaini, calque `.trix-content`) et ses formules par KaTeX (contrôleur `math`, chargé à la demande). Il s'affiche en entier : pas de « Lire la suite ».
4. **La liste des exercices ne montre aucune question** : ni énoncé, ni proposition. L'aperçu, corrigé ou non selon le rôle, vit sur la page de l'exercice (UDR-0021). La fiche ne peut donc rien fuiter.
5. **L'élève** ne voit que les exercices **publiés**. Chacun porte son type, son nombre de questions, le badge de l'élève (« Badge Or »), son meilleur score et sa maîtrise, ou « Pas encore de session terminée ». **Tout exercice publié se démarre** (ADR-0028) : « Commencer » (POST, change de page) ou « Reprendre » (session en cours). Un exercice assigné à sa classe principale active, directement, par sa fiche ou par son cours, porte l'étiquette **« Assigné par ton enseignant »** ; l'assignation oriente, elle ne conditionne pas.
6. **La lacune** : si l'élève a une lacune en attente sur la fiche (ADR-0043), un encart « Fiche essentielle à revoir » le dit, avec sa date et la règle pour la lever (au moins 70 % à l'un des exercices de la fiche). Aucun bouton de remédiation en V1 : la route n'existe pas.
7. **L'enseignant** voit les exercices publiés et « Voir l'exercice », sans progression ni bouton de session. L'assignation se fait depuis la classe.
8. **L'équipe** voit tous les exercices, brouillons et archives compris, chacun avec son statut. Dans l'en-tête : le panneau de statut (`content_status_panel`, publier ou archiver), puis **« Modifier »**, **« Nouvel exercice »** et **« Importer des exercices »**, qui ouvrent tous trois leur écran dans le frame `modal`. Il n'y a **pas de « Supprimer »** : une fiche s'archive.
9. **Aucun label de conformité** (ADR-0053) : le bandeau « Validation collaborative » disparaît.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

**Structure**
- `catalog/essentials/show` : `#essential_header` (lien retour, `ui_card`), puis `div.space-y-8` → `#essential_gap` si `@detail.pending_gap`, puis `ui_card` `#essential_exercises`. `content_for :title` « Fiche essentielle : La méiose » ; `content_for :nav_key, "courses"`.
- `#essential_header` : lien « Cours : Génétique et évolution » vers `course_path(course_slug)` ; `ui_card` → surtitre « Fiche essentielle · <cours> », `h1` nom, sous-titre (`#essential_subtitle`) s'il existe, badges : matière **toujours** `ui_subject_badge(name, category:)`, niveau et série. Équipe : à droite (dessous au téléphone), `#essential_team_actions` (`role=group`) → `content_status_panel(record:)`, `ui_button` « Modifier » (`secondary`, `sm`, `pencil-square`), « Nouvel exercice » (`primary`, `sm`, `plus`), « Importer des exercices » (`secondary`, `sm`, `arrow-up-tray`, `new_teams_import_path(kind: "exercises", essential: slug)`), tous en `data-turbo-frame="modal"`. Sous un filet, `#essential_content[data-controller=math]` : le contenu, ou « Cette fiche essentielle n'a pas encore de contenu. ».
- `#essential_gap` : `rounded-card`, `bg-warning-soft`, icône `light-bulb`, titre « Fiche essentielle à revoir », « Depuis le 12 septembre 2026 », puis la règle avec `Grading::MASTERY_THRESHOLD`.
- `#essential_exercises` : `ui_card` « Exercices » (icône `academic-cap`), compteur « N exercices » en `ui_badge` `brand` dans `card.actions` ; `ul[data-controller=math]` de `_exercise_progress`.
- `_exercise_progress` (`li#essential_exercise_<public_id>`) : titre en lien vers `exercise_path`, description tronquée à 2 lignes, badges (« Assigné par ton enseignant » en ton `teacher` et icône `user-group` pour l'élève ; type en `brand` ; « N questions » ; statut `content_status_badge` pour l'équipe). Élève : ligne de progression (badge `trophy` au ton de `badge_tone`, « Meilleur score : 85 % » et maîtrise). Action à droite (dessous au téléphone) : élève → « Reprendre » (`brand`, lien vers la session) ou « Commencer » (`button_to` POST `exercise_sessions_path`, `primary`) ; autres → « Voir l'exercice » (`secondary`).
- Lecture : `EssentialRepository#find_by_slug` (fait de la policy et panneau de statut), `ReadPublishedPolicy`, puis `EssentialDetailQuery(course_slug:, slug:, student_id:, include_unpublished:)` ; `student_id` pour un élève seulement, `include_unpublished` si `ManageContentPolicy` l'accorde.

**Tokens**
- Composants `ui_*` et tokens `@theme` seulement. Aucune classe de l'ancienne application, aucune valeur arbitraire.

**Comportement**
- Lecture seule : aucun `*.turbo_stream.erb` propre à la page. « Commencer » et « Reprendre » changent de page (Turbo Drive) ; « Commencer » est un vrai formulaire `POST` qui marche sans JavaScript.
- Les modales « Modifier » (B4) et « Nouvel exercice » (B5) répondent par un stream qui rafraîchit la page par morphing (`turbo_stream.refresh`), sans rechargement de fenêtre ; les formules sont rendues de nouveau après le morphing. La publication ou l'archivage remplace le panneau `#content_status_essential_<slug>`.
- Aucun `cache` dans la page ni dans ses partials : le HTML dépend du rôle et de l'élève.

**États obligatoires**
- Vide, élève et enseignant : « Aucun exercice publié pour cette fiche. » (UDR-0007), avec une phrase qui dit qu'ils arriveront à leur publication.
- Vide, équipe : « Aucun exercice pour cette fiche essentielle », « Créez un exercice ou importez-en : chacun naît en brouillon, à publier ensuite. »
- Chargement : sans objet (page rendue d'un bloc).
- Erreur : 404 par `RendersResult`, sans aucune donnée de la fiche.
- Succès : sans objet sur cette page ; les toasts viennent des Lots B4 et B5.

**Accessibilité**
- « Commencer », « Reprendre », « Voir l'exercice » et « Modifier » nomment leur cible : « Commencer l'exercice « Méiose » », « Modifier la fiche essentielle « La méiose » ».
- Le badge se lit « Badge Or », jamais par la couleur seule ; l'étiquette d'assignation est un texte.
- Cibles tactiles ≥ 48 px ; la page tient dans 390 px sans défilement horizontal (test système).

## 4. Conséquences

- Le test système `test/system/catalog/essential_page_test.rb` prouve le rendu, sur la fiche, du contenu saisi dans Trix (gras, liste, formule) et des exercices créés par la modale du Lot B5, sans rechargement de page.
- Un futur bouton de remédiation (`StartRemediationSession`, ADR-0043) prendra place dans `#essential_gap`.
- « Supprimer une fiche essentielle » disparaît de l'interface ; l'archivage (UDR-0016) le remplace.
