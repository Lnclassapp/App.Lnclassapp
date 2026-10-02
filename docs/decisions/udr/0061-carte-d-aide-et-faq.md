# UDR-0061 : Carte d'aide et FAQ — « Besoin d'aide ? » ouvre une carte à trois options : questions fréquentes, WhatsApp, appel

| | |
|---|---|
| **Statut** | **FAQ (§3.1)** : Accepté (porteur, 2026-10-02, construction directe) · **Carte d'aide (§3.2 à §3.7)** : Proposé |
| **Date** | 2026-10-02 |
| **Chantier** | [`docs/chantiers/fonctions-espace-eleve`](../../chantiers/fonctions-espace-eleve/memo.md) — grill Q4, Q13, Q14 ; [PRD](../../chantiers/fonctions-espace-eleve/prd.md) |
| **ADR lié** | [ADR-0049](../adr/0049-mesure-d-audience-cote-serveur-et-csp-stricte.md) (aucun script tiers, CSP stricte) · [UDR-0057](0057-ecrans-eleve-epures.md) (règle R1 à R6, deux familles) · [UDR-0058](0058-accueil-eleve.md) (accueil élève) · [UDR-0060](0060-connexion-et-recuperation-du-pin.md) (motif des écrans d'entrée) · [UDR-0054](0054-finitions-d-interface.md) (retour, titre, focus) · [UDR-0005](0005-design-system-fondateur.md) (tokens, `ui_modal`) · [UDR-0063](0063-pages-publiques-mission-confidentialite-cgu-cgv.md) (pages publiques liées depuis `/aide`) |
| **Remplacé par** | — |

---

## 1. Contexte

Un élève bloqué n'a aujourd'hui aucun recours dans l'application. Il a oublié son PIN, ne comprend pas sa note sur 20 ou ne trouve pas comment changer de classe : il demande à son enseignant, ou il abandonne. L'UDR-0058 a retiré le bouton d'aide de la maquette, faute de page derrière (UDR-0057 §2.5 : rien d'affiché pour une fonction absente).

Le porteur a tranché au grill :

- **Q4** : « Besoin d'aide ? » ouvre une **fenêtre** sur ordinateur et une **carte qui monte du bas** sur téléphone (25 % de la hauteur), avec trois options : FAQ, WhatsApp, contact direct.
- **Q13** : l'exemple fourni (capture d'une application de banque mobile, non versionnée parce qu'elle montre la photo du porteur) est une carte « Contactez-nous » : poignée, croix de fermeture, fond assombri ; une ligne par option, avec une icône dans un rond teinté, un titre, une ligne grise (horaires, délai de réponse) et un chevron. Le contact direct est un **appel téléphonique** au service client.
- **Q14** : la FAQ est **écrite dans l'application** : une page statique, textes dans les locales, relue par le porteur ; toute modification passe par une PR.

Le 2026-10-02, le porteur a demandé que la **FAQ soit construite tout de suite**, avant le reste du chantier. Elle est codée (commit `189d7f92`, intégré par le coordinateur). Cette UDR décrit donc la FAQ telle qu'elle est construite (§3.1, acceptée), et la carte d'aide à construire (§3.2 et suivants, proposée).

## 2. Décision

1. **La FAQ est une page publique, `/aide`**, sur le motif des écrans d'entrée (UDR-0060) : logo, lien de retour, un `h1`, puis les questions. Elle est lisible sans être connecté, parce que « PIN oublié » est la première raison d'y venir.
2. **Une question = un `<details>` natif.** Toutes les questions sont visibles, toutes les réponses sont repliées. Aucun JavaScript : la page marche sur le plus vieux navigateur supporté (ADR-0051) et sans réseau lent pour le script.
3. **En attendant la carte, « Besoin d'aide ? » mène à `/aide`.** Quand la carte arrive, le même bouton l'ouvre, et sa ligne « Questions fréquentes » mène à `/aide`.
4. **La carte réutilise la `<dialog>` native de `ui_modal`**, avec une nouvelle disposition `placement: :sheet` : sous `lg`, une feuille ancrée en bas, pleine largeur ; à partir de `lg`, une modale centrée étroite. La `<dialog>` native donne le piège du focus, Échap et le fond (UDR-0005) ; un composant à part dupliquerait ces garanties.
5. **Les numéros et les horaires du support sont des données de configuration**, jamais écrites dans une vue ni dans une locale. Une option dont la donnée manque n'est pas affichée.
6. **Aucun service tiers** : WhatsApp et l'appel sont de simples liens (`https://wa.me/<numéro>`, `tel:+225…`). Aucun widget, aucun script, aucune requête sortante (ADR-0049).

## 3. Règles d'implémentation

> Contrat d'exécution. Un agent l'applique littéralement.

### 3.1 FAQ — `GET /aide` · Accepté (porteur, 2026-10-02, construction directe)

**Route et contrôleur**
- `get "aide", to: "communication/help#show", as: :help`, tracée dans `config/routes/communication.rb`.
- `Communication::HelpController#show`, `allow_unauthenticated_access` : la page est publique, pour tous les rôles et pour un visiteur.
- Ni table, ni query, ni use case. Les seuils cités par les réponses sont interpolés depuis `Entities::Assessment::Grading` (`PASS_THRESHOLD`, `MASTERY_THRESHOLD`, `GOLD_THRESHOLD`, `PERFECT_THRESHOLD`), jamais recopiés en chiffres dans la locale.

**Mise en page**
- Layout `application`, **sans le shell** : la page est la même connecté ou non.
- De haut en bas, dans une colonne centrée :
  - le logo, comme sur la connexion (UDR-0060) ;
  - `ui_back_link` : vers l'accueil du rôle si l'utilisateur est connecté (libellé « Accueil »), sinon vers `root_path` ;
  - un seul `h1` : « Questions fréquentes » ;
  - la liste des questions.
- `page_title` : « Questions fréquentes · Lnclass ».

**Contenu**
- Textes dans `config/locales/communication/help.fr.yml`, tutoiement (charte §1). La liste des questions **fait foi dans ce fichier** ; cette UDR ne la recopie pas. Au 2026-10-02, neuf questions : le PIN oublié, rejoindre une classe, changer de classe, la note sur 20, les badges, la maîtrise, les fiches à revoir, refaire un exercice, le profil.
- Chaque question : `details` > `summary` (la question, 15 px, 500, `text-ink`) puis la réponse (14 px, `text-mute`, au plus un court paragraphe et, s'il le faut, un lien vers l'écran concerné).
- Séparateurs `divide-y divide-line` ; chaque `summary` porte une cible ≥ 48 px et un chevron qui tourne à l'ouverture (`group-open:rotate-180`, `motion-reduce:transition-none`).

**R3 ne s'applique pas** (3 lignes puis « Voir plus »), comme pour la grille du catalogue (UDR-0013, amendement du 2026-10-02). La liste est l'objet même de la page, et ses lignes sont déjà courtes : une question de quelques mots, la réponse repliée. Masquer six questions derrière « Voir plus » cacherait justement celle que l'élève cherche, sans rien alléger.

**Tenue de la FAQ** (Q14) : un chantier qui change un parcours élève met la FAQ à jour dans la même PR. C'est une porte de sortie de son `plan.md`.

### 3.2 Bouton « Besoin d'aide ? »

- **Accueil élève actuel** (`app/views/classroom/student_homes/show.html.erb`, famille ordinateur de l'UDR-0058 §3.3, appliquée à toutes les tailles pendant la phase 1 d'`interface-epuree`) : dans le bloc d'actions de `ui_page_header`, un `ui_button` « Besoin d'aide ? », variante `ghost` (R1 : l'action principale de l'écran reste la première ligne « À faire »), icône `question-mark-circle`.
  - **Aujourd'hui** (provisoire) : un lien vers `help_path`.
  - **Avec la carte** : un bouton qui ouvre la carte (`data-action="modal#open"`, `aria-haspopup="dialog"`, `aria-controls="help-sheet"`). Sans JavaScript, il reste un lien vers `help_path` (le bouton est un `a href="/aide"` dont le contrôleur empêche la navigation et ouvre la carte).
- **Famille téléphone** (phase 2 d'`interface-epuree`) : dans le bandeau, à gauche de l'avatar, une icône seule de 44 px avec `aria-label="Besoin d'aide ?"` (charte §7). L'UDR-0058 §3.2 sera amendée à ce moment ; cette UDR fixe seulement que l'icône ouvre la même carte.

### 3.3 La carte — `shared/_help_sheet.html.erb`

**Composant**
- `ui_modal(id: "help-sheet", title: t("shared.help_sheet.title"), size: :sm, placement: :sheet)`.
- Nouvelle option `placement:` de `ui_modal` : `:center` (défaut, inchangé pour toutes les autres modales) ou `:sheet`. `:sheet` ajoute la classe `dialog-sheet`, définie dans `app/assets/stylesheets/application.tailwind.css` :
  - **sous `lg`** : `margin: auto 0 0`, `width: 100%`, `max-width: none`, coins hauts `--radius-sheet`, coins bas carrés, `min-height: 25dvh`, `max-height: 90dvh`, `overflow-y: auto`, `padding-bottom: env(safe-area-inset-bottom)` ;
  - **à partir de `lg`** : la modale centrée `sm` actuelle.
  - Animation : l'`open:animate-slide-up` existant ; `motion-reduce:animate-none`.
- La poignée : `span.sheet-handle` (36 × 4 px, `bg-line`, `rounded-full`, centrée, `aria-hidden="true"`), rendue seulement sous `lg` (`lg:hidden`). **Elle n'est pas interactive** : aucun geste de glissement n'est codé. Elle signale la feuille ; on ferme par la croix, par Échap ou en touchant le fond.
- La croix de `ui_modal` (cible `size-tap`) et le fond `backdrop:bg-ink/50` sont ceux du composant, sans changement.

**Hauteur : 25 % au minimum, la hauteur du contenu sinon.** Le porteur a dit « 25 % de la hauteur » (Q4). Le contenu en demande plus : poignée et titre (≈ 76 px), trois lignes de 72 px (216 px), le pied (≈ 44 px) et les marges (≈ 40 px) font **≈ 376 px**, soit 45 % d'un écran de 844 px et 59 % d'un écran de 640 px. Une carte limitée à 25 % couperait la troisième ligne. Les 25 % deviennent donc un **plancher** (ils ne jouent que sur une grande tablette en portrait), la hauteur suit le contenu, plafonnée à 90 % avec défilement interne (zoom à 200 %).

**Contenu, de haut en bas**
1. Titre `h2` (celui de `ui_modal`) : « Contacte-nous » (tutoiement de l'espace élève ; l'exemple du porteur dit « Contactez-nous »).
2. `ul.divide-y.divide-line` de trois lignes au plus, dans cet ordre :

| Ligne | Icône (heroicon, `outline`) | Titre | Ligne grise | Lien |
|---|---|---|---|---|
| FAQ | `question-mark-circle` | « Questions fréquentes » | « Les réponses aux questions les plus posées » | `help_path` |
| WhatsApp | `chat-bubble-left-right` | « Chatter avec le support » | horaires et délai de réponse (`support.hours`, `support.whatsapp_reply`) | `https://wa.me/<support.whatsapp>`, `target="_blank"`, `rel="noopener noreferrer"` |
| Appel | `phone` | « Appeler le service client » | horaires (`support.hours`) | `tel:+<support.phone>` |

3. Un pied discret (`text-sm`, `text-mute`, liens soulignés) : « Notre mission · Confidentialité · Conditions d'utilisation », vers les pages de l'UDR-0063, chacun présent seulement si sa page est en ligne (UDR-0063 §2.4).

**Une ligne** (`li` > `a`, toute la ligne est le lien) :
- `flex items-center gap-4 min-h-18 px-1 py-3 active:bg-mist rounded-ln`, focus visible `outline-2 outline-brand` ;
- icône dans un rond de 44 px, **`bg-brand-soft text-brand-strong`** pour les trois lignes ;
- titre (15 px, 500, `text-ink`), ligne grise en dessous (13 px, `text-mute`, `truncate`) ;
- `ui_icon "chevron-right", variant: :mini` en `text-mute`, `aria-hidden`.

Les trois ronds ont la **même teinte**. L'exemple du porteur teinte chaque rond différemment, mais R5 n'autorise qu'une couleur d'accent hors signal sémantique, et le vert est réservé à « réussi » (charte §5) : un rond vert pour WhatsApp dirait « réussi ».

### 3.4 Données du support — `config/support.yml`

- Fichier lu au démarrage par `config.x.support = config_for(:support)` (`config/application.rb`). Clés : `phone` et `whatsapp` (chiffres seuls, indicatif `225` compris, sans `+`), `hours` (texte court affiché tel quel, ex. « Lun.–ven., 08:00–18:00 »), `whatsapp_reply` (délai de réponse, texte court). Valeurs fixes et fictives en `test`.
- **Pas dans les credentials** : ces numéros sont publics, affichés à chaque élève. Les ranger avec des secrets les rendrait illisibles en revue et exigerait la clé maîtresse pour les changer. Un changement de numéro passe par une PR, comme la FAQ (Q14).
- **Valeurs à fournir par le porteur** (memo, question ouverte) : numéro d'appel, numéro WhatsApp, horaires, délai de réponse WhatsApp.
- Un helper `SupportHelper#support_contacts` rend les lignes disponibles. **Une clé vide supprime sa ligne** (UDR-0057 §2.5) : sans `whatsapp`, pas de ligne WhatsApp ; sans `phone`, pas de ligne d'appel. La ligne FAQ est toujours là, donc la carte n'est jamais vide.

### 3.5 Libellés — `config/locales/shared/help_sheet.fr.yml`

| Clé | Texte |
|---|---|
| `trigger` | « Besoin d'aide ? » |
| `title` | « Contacte-nous » |
| `faq.title` / `faq.hint` | « Questions fréquentes » / « Les réponses aux questions les plus posées » |
| `whatsapp.title` / `whatsapp.hint` | « Chatter avec le support » / « %{hours} · %{reply} » |
| `whatsapp.external` | « (ouvre WhatsApp) » — `sr-only` |
| `call.title` / `call.hint` | « Appeler le service client » / « %{hours} » |
| `footer.mission`, `footer.privacy`, `footer.terms` | « Notre mission », « Confidentialité », « Conditions d'utilisation » |

### 3.6 États obligatoires

- **Vide** : impossible (la ligne FAQ est toujours rendue).
- **Chargement** : aucun ; la carte est rendue dans la page, fermée (`<dialog>` sans `open`), sans requête à l'ouverture.
- **Erreur** : aucune requête, donc aucune erreur réseau. Un numéro mal formé est refusé au démarrage par un test (`test/config/support_config_test.rb` : chiffres seuls, 12 ou 13 chiffres).
- **Sans JavaScript** : le bouton est un lien vers `/aide`, qui donne la FAQ ; la page `/aide` ne montre pas les numéros (ils sont dans la carte seulement).

### 3.7 Accessibilité

- **Piège du focus et Échap** : fournis par `showModal()` (contrôleur `modal` existant).
- **Focus à l'ouverture** : la première ligne (« Questions fréquentes ») reçoit le focus, jamais la croix (UDR-0054). Le contrôleur `autofocus` gagne la cible `data-autofocus-first` pour une modale sans champ ni pied.
- **Retour du focus** : à la fermeture (croix, Échap, fond), le focus revient sur « Besoin d'aide ? ». Le navigateur le fait pour une `<dialog>` ouverte par `showModal()` ; le contrôleur `modal` mémorise le déclencheur à l'ouverture et le refocalise au `close` si `document.activeElement` est `body` (repli pour les navigateurs de l'ADR-0051 qui ne le feraient pas).
- `aria-labelledby` sur le titre (déjà dans `ui_modal`). Chaque lien a pour nom accessible son titre, et sa ligne grise en `aria-describedby`. Le lien WhatsApp annonce qu'il ouvre une autre application.
- Cibles ≥ 48 px (lignes de 72 px, croix `size-tap`) ; contraste du texte gris `mute` sur blanc conforme (UDR-0005).
- `prefers-reduced-motion` : pas d'animation d'entrée.

### 3.8 Contrôle de la règle (UDR-0057)

| Règle | Carte d'aide | FAQ `/aide` |
|---|---|---|
| R1 — une action principale | Aucune variante `primary` : trois liens de même poids. Le bouton d'ouverture est `ghost`. | Aucun bouton principal. |
| R2 — 5 blocs avant défilement | La carte est une couche, pas un bloc de la page. | Logo, retour, `h1`, liste : 4. |
| R3 — 3 lignes puis « Voir plus » | 3 lignes. | Exception justifiée au §3.1. |
| R4 — pas d'aide permanente | Les lignes grises sont des données (horaires, délai), pas une explication. | La page *est* l'aide, ouverte à la demande. |
| R5 — une couleur d'accent | Trois ronds `brand-soft`. | `brand` pour les liens seulement. |
| R6 — rien de répété | Titre de la carte ≠ libellé du bouton. | Chaque réponse ne dit qu'une chose. |

## 4. Conséquences

- `ui_modal` gagne `placement: :sheet`. Les autres modales ne changent pas ; une autre feuille basse (par exemple « Inviter », UDR-0058) pourra la reprendre.
- La FAQ suit les écrans (Q14) : le lot des échéances (UDR-0062) ajoute une question « Que veut dire « En retard » ? ».
- **Amendement proposé par l'UDR-0063 (§3.4)** : sous ses questions, `/aide` renvoie à la protection des données et aux conditions d'utilisation, dès que ces pages sont en ligne. Le reste du §3.1 est inchangé.
- L'UDR-0058 §3.2 (bandeau téléphone, « Aucun bouton d'aide tant qu'aucune page d'aide n'existe ») est à amender en phase 2 d'`interface-epuree` : l'icône d'aide y revient.
- Aucun service tiers, aucun cookie, aucune donnée envoyée : la carte ne fait qu'afficher des liens.
- Interdit désormais : écrire un numéro de support dans une vue ou une locale ; un widget de discussion chargé depuis un tiers.
