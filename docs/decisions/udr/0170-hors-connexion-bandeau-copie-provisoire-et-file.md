# UDR-0170 : Hors connexion — bandeau, copie hors ligne, note provisoire, copies à envoyer
<!-- index
titre: Hors connexion : bandeau, note provisoire et copies à envoyer
statut: Accepté
adr-lie: 0133-hors-connexion-pages-ouvertes-et-copies-synchronisees
problematique: Hors ligne, l'élève doit savoir ce qu'il lit (une page gardée), que sa note est provisoire et où en sont ses copies, sans écran nouveau à apprendre.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-12 |
| **Chantier** | `docs/chantiers/hors-connexion` |
| **ADR lié** | ADR-0133 ; amende UDR-0078 §3.2 (page « Pas de connexion ») |
| **Remplacé par** | — |

---

## 1. Contexte

Hors ligne, l'élève voit aujourd'hui « Pas de connexion » partout. Avec le chantier, il voit des pages gardées : il doit comprendre qu'il lit une version gardée, qu'une copie rendue hors ligne a une note **provisoire**, et que ses copies partiront seules. Un élève qui croit sa copie envoyée alors qu'elle ne l'est pas, ou qui croit sa note définitive, se plaindra à son enseignant.

## 2. Décision

- **Un seul bandeau discret** en haut de toute page servie hors ligne, plutôt qu'une modale : l'élève lit d'abord, l'état est secondaire.
- **La copie hors ligne réutilise la feuille de l'UDR-0138** à l'identique (même partials) : aucun écran à apprendre. Seul le pied change (« Rendre ma copie » garde le libellé ; un texte dit que la copie partira au retour du réseau).
- **Le résultat provisoire** reprend la page de résultat existante, réduite (note + corrigé par question), avec une étiquette « Provisoire ».
- **Les copies à envoyer** sont dites dans une puce sur l'accueil élève, pas dans la navigation (pas de badge permanent).
- Pas de JavaScript pour l'état « gardée » côté serveur : c'est le programme d'arrière-plan qui marque la réponse (`Lnclass-Offline-Served: <heure ISO>`) et le contrôleur Stimulus `offline-status` qui affiche.

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement. Textes : `config/locales/shared/offline.fr.yml` (Lot 0), clé `offline.*`. Tutoiement pour l'élève, vouvoiement pour l'enseignant (`.student` / `.teacher`).

### 3.1 Bandeau hors ligne — `shared/offline/_status_banner` (Lot 0)

**Où** : `layouts/shell`, premier enfant de `main#main`, **avant** le bandeau d'installation, pour `student` et `teacher`.

```
div#offline_status.mb-4.flex.items-center.gap-2.rounded-card.bg-mist.px-4.py-2.text-sm.text-ink
  [hidden]
  [role="status"]
  [data-controller="offline-status"]
  ui_icon "signal-slash", size: :sm  (aria-hidden)
  span[data-offline-status-target="text"]
```

- Contrôleur `app/javascript/controllers/offline_status_controller.js` : au `connect`, et sur `online` / `offline` de `window`. Si `navigator.onLine === false` → visible, texte `offline.banner.<role>.offline` (« Hors ligne. Tu lis une page gardée sur ton téléphone. » / « Hors ligne. Vous lisez une page gardée sur votre téléphone. »). Si la meta `lnclass-offline-served` (posée par le programme d'arrière-plan dans la page servie depuis le cache) porte une date → ajoute `offline.banner.saved_on` (« Gardée le %{date} »), date au format court `jj/mm à hh:mm`. Retour en ligne → caché.
- Pas de bouton. Contraste ink sur mist (≥ 4,5:1).

### 3.2 Page « Pas de connexion » — `public/offline.html` (Lot A, amende UDR-0078 §3.2)

Garde la structure UDR-0078 ; ajoute sous le paragraphe existant :
`p.offline-note` → « Les leçons et exercices que tu as déjà ouverts restent lisibles sans connexion. Celle-ci n'a pas encore été ouverte sur ce téléphone. »
Incrémenter `<N>` du cache `lnclass-offline-v<N>`.

### 3.3 Sujet d'exercice hors ligne — `assessment/exercises/show` (Lot B)

- Le bouton « Commencer » existant reçoit `data-controller="offline-start"` et `data-offline-start-copy-url-value="<offline_copy_exercise_path>"`.
- En ligne : inchangé. Hors ligne et paquet présent dans la base locale → le clic mène à `offline_copy_exercise_path` (visite Turbo). Hors ligne et paquet absent → le bouton est `disabled` (`aria-disabled="true"`) et un `p.mt-2.text-sm.text-mute` dit `offline.start.unavailable` (« Ouvre cet exercice une fois avec du réseau pour le faire hors ligne. »).

### 3.4 Copie hors ligne — `assessment/offline_copies/new` (Lot B)

- Rendue avec les **mêmes partials** que `assessment/exercise_sessions/show` (UDR-0138) : compteur collant, énoncé `details`, questions, pied collant. Aucun indice (les indices demandent le réseau) : le bouton « Indice » n'est pas rendu.
- `form[data-controller="offline-copy"][data-offline-copy-exercise-value="<public_id>"]`, sans `action` serveur : le contrôleur intercepte `submit`, lit les champs (mêmes noms `copy[answers][<question_id>]`), corrige avec `offline/grader.js`, range la copie en file, puis affiche le résultat provisoire (§3.5) **dans la même page** (remplace le contenu de `#copy-sheet`), focus sur son titre.
- Pied : `p.mb-3.text-sm.text-mute` → `offline.copy.footer` (« Ta copie sera envoyée à ton enseignant dès que tu auras du réseau. »).
- Stockage plein ou base indisponible : la copie n'est pas rangée ; message `p[role="alert"].rounded-card.bg-warning-soft.px-4.py-3.text-sm.font-medium.text-warning` → `offline.copy.not_saved` (« Copie non gardée : libère de la place sur ton téléphone, puis réessaie. »), réponses laissées dans le formulaire.
- Pause « Recommencer » (3 copies d'affilée) appliquée localement : la page affiche le message existant de pause à la place du formulaire.

### 3.5 Résultat provisoire (Lot B)

```
section#offline_result[aria-labelledby="offline_result_title"]
  div.flex.items-center.gap-2
    h1#offline_result_title.font-display.text-2xl.font-extrabold.text-ink[tabindex="-1"] → offline.result.title (« Ta note »)
    span.rounded-full.bg-warning-soft.px-2.py-0.5.text-xs.font-bold.text-warning → offline.result.provisional (« Provisoire »)
  p.mt-1.font-display.text-4xl.font-extrabold.tabular-nums → « %{percent} % »
  p.mt-2.text-sm.text-mute → offline.result.explain (« Note calculée sur ton téléphone. Elle sera confirmée à l'envoi. »)
  ol.mt-6.grid.gap-4  → une li par question : verdict (icône check-circle / x-circle, texte « Juste » / « À revoir » / « Non noté »), bonne réponse, explication
  ui_button offline.result.back (« Retour à l'exercice »), variant: :secondary → sujet
```

### 3.6 Copies à envoyer — accueil élève (Lot C)

- Partial `shared/offline/_pending_copies` sous le titre de l'accueil élève, `div[data-controller="offline-queue"][hidden]`.
- Rien en file → caché. N copies `pending` → `p.text-sm.text-ink` + `ui_icon "arrow-up-tray"` : `offline.queue.pending` (« 1 copie à envoyer » / « %{count} copies à envoyer »), et en ligne `offline.queue.sending` (« Envoi… ») pendant l'envoi, `aria-live="polite"`.
- Copie `rejected` → `ul` de lignes `rounded-card.bg-warning-soft.px-4.py-3.text-sm.text-warning`, texte `offline.queue.rejected.<reason>` (`stale` : « Exercice modifié depuis : copie non comptée. » ; `forbidden`, `locked`, `invalid`, `wrong_owner` : « Copie refusée par le serveur. »), titre de l'exercice, bouton `ui_button offline.queue.dismiss` (« J'ai compris »), `variant: :ghost, size: :sm`, qui la retire.
- Copie `synced` → la note provisoire est remplacée par celle du serveur ; une ligne `offline.queue.synced` (« Copie envoyée · %{percent} % ») 1 fois, puis disparaît au chargement suivant.

### 3.7 Copie rendue hors ligne vue par l'enseignant (Lot C)

Sur le résultat de copie, sous l'en-tête existant, si `received_at` : `p.text-sm.text-mute` + `ui_icon "cloud-arrow-up", size: :sm` → `offline.teacher.received` (« Rendue hors ligne le %{completed} · reçue le %{received} »).

### 3.8 Corrigé reçu avant une copie de devoir (Lot B2, amendement du 2026-11-12)

Pour l'enseignant et l'équipe seulement (jamais l'élève propriétaire), quand une copie rattachée à un devoir a commencé après la première remise du corrigé sur le téléphone :
- **Résultat de copie** : sous la mention §3.7 (ou à sa place si la copie a été rendue en ligne), `p#session_offline_pack_marker.flex.items-center.justify-center.gap-2.text-sm.text-warning` + `ui_icon "exclamation-triangle", size: :sm` → `offline.teacher.pack_before` (« Corrigé reçu sur le téléphone le %{delivered}, avant cette copie »).
- **Suivi du devoir** (liste des élèves d'une assignation) : sur la ligne de l'élève, après son statut, `span.text-xs.text-warning` avec `ui_icon "exclamation-triangle", size: :sm` (la plus petite taille de `ui_icon`) et le texte court `offline.teacher.pack_before_short` (« Corrigé reçu avant ») ; `title` et `aria-label` = le texte long.
- Aucune marque : rien n'est rendu (pas d'espace réservé).

### États obligatoires

| Surface | Vide | Chargement | Erreur | Succès |
|---|---|---|---|---|
| Bandeau | en ligne : caché | — (synchrone) | — | hors ligne : visible |
| Copie hors ligne | paquet absent : page non atteignable (bouton désactivé §3.3) | — | stockage plein §3.4 | résultat provisoire §3.5 |
| Copies à envoyer | caché | « Envoi… » | refusée §3.6 ; réseau coupé : reste « N copies à envoyer » | « Copie envoyée · %» |

### Accessibilité

- Cibles ≥ 48 px (`min-h-tap`) pour tous les boutons ; bandeau `role="status"`, file `aria-live="polite"`, erreur `role="alert"`.
- Après rendu de la copie, focus sur `#offline_result_title`.
- Aucune information portée par la seule couleur : « Provisoire » est un texte.

## 4. Conséquences

- Toute nouvelle page gardable (ADR §4.1) affiche le bandeau sans travail : il vit dans le layout.
- Interdit : une note hors ligne affichée sans l'étiquette « Provisoire » ; une copie en file non dite à l'élève.
