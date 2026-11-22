# UDR-XXXX : Hors connexion total — carte « Hors connexion » de l'élève, file et mentions de l'enseignant
<!-- index
titre: Hors connexion total : carte de téléchargement, file de l'enseignant
statut: Accepté
adr-lie: XXXX-hors-connexion-total-catalogue-telecharge
problematique: L'élève doit savoir ce qui est téléchargé, combien ça pèse et pouvoir le mettre en pause ; l'enseignant doit voir ce qui attend l'envoi et ce qui a été refusé, sans nouvel écran.
-->

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-11-22 |
| **Chantier** | `docs/chantiers/hors-connexion-total` |
| **Remplace** | — *(prolonge l'UDR « hors-connexion bandeau, copie provisoire et file »)* |

---

## 1. Contexte

Télécharger plus de 50 Mo sur un téléphone modeste et un forfait limité ne peut pas se faire en silence : l'élève doit voir la taille, la place libre, la progression, et pouvoir arrêter. L'enseignant qui donne un devoir hors ligne doit savoir qu'il n'est pas encore parti, et pourquoi il a été refusé.

## 2. Décision

- **Pas de nouvel écran.** Une carte « Hors connexion » prend place sur l'accueil de l'élève, sous la carte de classe. Elle n'apparaît **que dans l'application installée** (`display-mode: standalone`) et **tant que le téléchargement n'est pas fini**.
- Une fois le niveau fini, la carte disparaît (règle Wave 2 : jamais de section vide). Une ligne « Hors connexion » dans « Mon compte » la remplace. C'est la seule porte vers le reste du catalogue et vers « Libérer la place ».
- L'enseignant réutilise la file de l'élève (`shared/offline/_pending_copies`, généralisée en `_pending_queue`). Ses actions en attente portent une mention en ligne, sans modale. Une modale bloquerait un écran qu'il ne peut pas recharger.

## 3. Règles d'implémentation

**Structure**

- Partial `app/views/shared/offline/_download_card.html.erb`, rendu dans `classroom/student_homes/show` juste après la carte de classe. Contrôleur Stimulus `offline-download` (lazy, chunk `offline/controllers.js`).
- La carte est une `section` `id="offline_download"`, avec `hidden` par défaut ; le contrôleur la montre. Ses classes sont `mx-gutter rounded-card bg-white p-5 space-y-3`.
  - Titre `h2`, `text-base font-medium text-ink` : « Hors connexion ».
  - Phrase d'état `p`, `text-sm text-mute`, cible `status` (textes ci-dessous).
  - Barre de progression `div role="progressbar"` (`aria-valuemin=0`, `aria-valuemax=<total>`, `aria-valuenow`, `aria-label="Téléchargement de ton niveau"`). La piste est en `bg-line rounded-full h-2`, le remplissage en `bg-brand rounded-full h-2`, et la largeur est posée par le contrôleur via `style.width`, la seule exception admise au contrôle des tokens, comme les barres existantes. Si une barre existe déjà dans `app/views/components/`, on la réutilise.
  - Rangée d'actions : `ui_button` principal (cible `primary`), plus un `ui_button variant: :ghost` (cible `secondary`).
- Ligne de « Mon compte » : `shared/screens/row` dans `shared/navigation/_avatar_menu` (élève seulement, application installée seulement). Titre « Hors connexion », détail « Niveau 3e téléchargé · 52 Mo », valeur à droite « 61/61 ». Elle mène à `/students/offline` (`Classroom::StudentOfflinesController#show`, écran intérieur Wave : flèche retour et grand titre). Cet écran porte la même carte en pleine largeur, plus deux groupes :
  - « Le reste du catalogue », avec « Télécharger tout le reste » et sa taille ;
  - « Place », avec « Libérer la place », qui demande confirmation et efface `lnclass-catalog-v1`, `lnclass-media-v1` et les listes, jamais la file.

**Textes** (clés `offline.download.*`, `fr` d'abord)

| État | `status` | `primary` | `secondary` |
|---|---|---|---|
| Prêt, Wi-Fi | « Ton niveau 3e pèse 52 Mo. Il reste 1,2 Go sur ce téléphone. » | « Télécharger » | — |
| Prêt, données mobiles ou réseau inconnu | « Ton niveau 3e pèse 52 Mo. Tu n'es pas en Wi-Fi. » | « Télécharger quand même » | « Plus tard » (cache la carte jusqu'au prochain lancement) |
| En cours | « 34 / 61 leçons · 18 Mo sur 52 Mo » | « Pause » | — |
| En pause | « En pause · 34 / 61 leçons » | « Reprendre » | — |
| Place insuffisante | « Il faut 52 Mo, il en reste 20 sur ce téléphone. » (`text-warning`, `role="alert"`) | — | « Réessayer » |
| Erreur réseau | « Téléchargement interrompu. Il reprendra avec du réseau. » | « Réessayer » | — |
| Fini | (la carte est retirée ; un toast « Ton niveau est disponible hors connexion ») | — | — |

**Comportement**

- Le contrôleur lit `/offline/catalog`, puis `navigator.storage.estimate()` et `navigator.connection?.type`. Il calcule le total des entrées `priority: 0`. Le choix « données mobiles acceptées » est retenu dans `localStorage` (`lnclass:download-cellular`, dans un try/catch ; sans stockage, la question revient).
- La progression se met à jour au plus une fois par seconde : pas d'annonce `aria-live` à chaque leçon. Seuls les changements d'état sont annoncés (`aria-live="polite"` sur `status`).
- Pas de Turbo Frame : tout est local. Sans JavaScript, la carte reste cachée.
- Page commune refusée (fin d'accès) : `public/offline-access-ended.html`, statique comme `offline.html`, même gabarit. Titre « Accès terminé », texte « Ton accès à cette leçon s'est terminé le {date}. Reconnecte-toi pour le renouveler. » La date est lue dans l'URL par un script de 10 lignes, et laissée vide si absente.

**Enseignant**

- `shared/offline/_pending_queue` (renommage de `_pending_copies`, paramètre `kind: :copies | :actions`). Elle est rendue en haut de l'accueil enseignant et de la page de classe, avec les mêmes cibles et textes que la file des copies :
  - « 1 action à envoyer » ou « N actions à envoyer » ;
  - « Envoi… » ;
  - « Action envoyée » ;
  - les refus en ligne `bg-warning-soft`, avec le motif `offline.actions.rejected.<motif>` et « Ignorer ».
- Un devoir donné hors ligne apparaît dans la liste de la classe, rendu par le contrôleur `offline-actions` à partir du `template` de la ligne existante. La mention « En attente d'envoi » est en `text-xs text-mute`, avec l'icône `clock`.
- Un devoir reçu avec `made_offline_at` porte, sur son suivi, la mention « Donné hors connexion le {date}, arrivé le {date} » (`text-xs text-mute`).
- Hors ligne (classe `offline` posée par `offline-status` sur `html`), « Retirer de la classe » et « Changer le lien » reçoivent `disabled` et `aria-disabled="true"`. Une aide « Disponible avec du réseau » (`text-xs text-mute`) apparaît sous le bouton.
- Sur le résultat d'une copie, la mention existante « corrigé reçu » devient « Corrigé disponible sur l'appareil de l'élève ».

**États obligatoires**

- Carte : vide = cachée (pas installée, déjà fini, pas élève) · chargement = « Préparation… » pendant la lecture de la liste · erreur = « Erreur réseau » ou « Place insuffisante » · succès = toast puis retrait.
- File de l'enseignant : vide = cachée · envoi = « Envoi… » · erreur = « Envoi impossible » tant qu'il reste des actions · succès = « Action envoyée ».

**Accessibilité**

- Boutons `min-h-tap` (48 px). Barre `role="progressbar"` avec ses `aria-value*`. Focus visible par défaut du design system. Ordre de tabulation : titre, état, action principale, action secondaire.
- Boutons désactivés hors ligne : `aria-disabled` et aide liée par `aria-describedby`.

## 4. Conséquences

- La carte de l'accueil est la seule entrée vers le téléchargement : pas d'invitation dans d'autres écrans.
- Toute nouvelle écriture hors ligne passe par `_pending_queue` : pas de deuxième file visible.
- Les captures de recette se font en 390 px et sur ordinateur, application installée simulée (`display-mode: standalone`).
