# UDR-0047 : Photo de profil — ligne « Photo » du profil, modale d'ajout avec aperçu recadré, photo à la place des initiales

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-28 |
| **Chantier** | [`docs/chantiers/photo-de-profil`](../../chantiers/photo-de-profil/prd.md) — critères PH-01 à PH-07 |
| **ADR lié** | [ADR-0060](../adr/0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md) · [UDR-0041](0041-page-profil.md) · [UDR-0005](0005-design-system-fondateur.md) · [UDR-0006](0006-shell-applicatif-par-role.md) |
| **Remplacé par** | — |

> Numérotation : plus haut numéro existant au 2026-09-28 (0043) **+ 4**, pour éviter les collisions avec les chantiers ouverts en parallèle.

---

## 1. Contexte

Un avatar n'affiche que des initiales. Un enseignant ne distingue pas deux « A K » de sa classe ; l'équipe qui débloque un compte ne voit pas à qui elle parle. Le public prend sa photo au téléphone, sur un réseau lent.

## 2. Décision

La photo s'ajoute depuis « Mon profil », dans une modale (règle CRUD Hotwire de l'UDR-0006, comme le nom en UDR-0041), avec un aperçu du recadrage **avant** l'envoi : l'utilisateur voit exactement ce qui sera montré. Après l'enregistrement, la page se rafraîchit par Turbo (morphing) : un seul mécanisme met à jour la carte, l'en-tête et la barre latérale, sans rechargement complet. Pas de bouton séparé « Prendre une photo » : le sélecteur du téléphone propose déjà l'appareil photo et la galerie, et forcer la caméra retirerait la galerie sur Android.

## 3. Règles d'implémentation

- **Composant** : `ui_avatar(name, src:, size:)` ; `src` est `account_photo_src(public_id, photo_version)` (nil sans photo → initiales). L'image est ronde (`rounded-full object-cover`), `alt` = le nom, `loading="lazy"`, `decoding="async"`. Nouvelle taille `xl` (`size-28 text-3xl`, 112 px) pour la modale.
- **Où la photo remplace les initiales** : menu du compte (déclencheur de l'en-tête), barre latérale, carte `#profile_information`, liste de la classe (`classroom/classrooms/_roster`), compte retrouvé par l'équipe (`teams/account_lookups/_result`). Ailleurs, rien ne change.
- **Carte `#profile_information`** (UDR-0041) : première ligne de la `dl`, avant « Nom » :
  - `dt` « Photo », `dd` « Votre photo remplace vos initiales. » ou, sans photo, « Aucune photo : vos initiales s'affichent. » ;
  - bouton `ui_button` `secondary`, `sm`, icône `camera`, `data-turbo-frame="modal"`, vers `edit_profile_photo_path` : « Changer ma photo » ou « Ajouter une photo ».
- **Modale « Ma photo »** (`ui_modal` dans `turbo_frame_tag "modal"`, `id="profile-photo-modal"`, taille `sm`) :
  - en haut, centré : l'avatar actuel en `xl` (cible `current`), et une `<img>` d'aperçu `hidden`, même taille, `rounded-full object-cover`, `alt` « Aperçu de votre nouvelle photo » (cible `preview`) ;
  - formulaire `profile-photo-form`, `multipart`, `PATCH profile_photo_path`, contrôleur Stimulus `identity--photo-picker` : champ fichier `profile_photo[photo]`, `accept="image/jpeg,image/png,image/webp,image/*"`, **sans** `capture`, libellé visible « Photo », aide `id="profile_photo_photo_hint"` « JPEG, PNG ou WebP. Elle est recadrée en carré et allégée sur votre téléphone avant l'envoi. », style du champ fichier des imports (`file:min-h-tap`) ;
  - pied : « Annuler » (`secondary`, `modal#close`) et « Enregistrer » (`primary`, icône `check`, `form="profile-photo-form"`) ;
  - s'il y a une photo, sous le formulaire, séparé par `border-t border-line` : `button_to` « Retirer ma photo » (`DELETE profile_photo_path`, `ui_button` `ghost`, `sm`, icône `trash`, texte `text-error`).
- **Comportement du contrôleur Stimulus** : à la sélection, décode l'image (`Image` + `URL.createObjectURL`), recadre au centre en carré de `min(512, petit côté)` px, encode en WebP 0,8 (JPEG 0,8 si le navigateur ne sait pas), remplace le fichier du champ (`DataTransfer`) et montre l'aperçu à la place de l'avatar. Un envoi pendant le traitement attend sa fin. Si le décodage échoue, le fichier part tel quel et le serveur tranche.
- **États** :
  - Vide : sans photo, l'avatar actuel montre les initiales ; pas de « Retirer ma photo ».
  - Chargement : `aria-busy` sur le formulaire pendant le recadrage ; bouton de soumission en `loading` pendant l'envoi.
  - Erreur : 422 dans la modale ; message sous le champ (`id="profile_photo_photo_error"`, relié par `aria-describedby`, `aria-invalid`), champ en bord `border-error`. Messages : « Choisissez une photo. », « Choisissez une photo JPEG, PNG ou WebP. », « La photo pèse 1 Mo au plus. », « La photo mesure 1024 pixels de côté au plus. », « Cette image contient des informations cachées (lieu, appareil). Choisissez-la depuis cette page pour qu'elles soient retirées. ».
  - Succès : Turbo Stream = toast (`success`) « Votre photo est enregistrée. » ou « Votre photo est retirée. », `update "modal"` vide, `refresh` (morphing de la page). Repli HTML : 303 vers `profile_path` avec le même toast.
- **Téléphone (390 px)** : la modale est la feuille basse existante ; l'avatar `xl` et le champ tiennent sans défilement horizontal ; cibles ≥ 48 px (`min-h-tap`).
- **Accessibilité** : libellé visible sur le champ ; l'aperçu a un `alt` ; le toast passe par la région `aria-live` existante. Aucune couleur en dur : tokens et composants `ui_*`.
- **Vocabulaire** : « photo », « Ma photo », « Retirer ma photo » ; jamais « avatar » ni « image de profil » dans l'interface.

## 4. Conséquences

- `ui_avatar` gagne la taille `xl` ; la page du design system la montre.
- Les avatars photographiés chargent une image de 512 px même à 32 px d'affichage (ADR-0060, coût consenti).
