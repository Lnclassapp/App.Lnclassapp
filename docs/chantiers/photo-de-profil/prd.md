# PRD — Photo de profil

> Les specs sont figées ici. Toute évolution après la phase 3 se fait par modification explicite de ce fichier, pas par improvisation dans le code.

## 1. Contexte

Chaque compte n'est représenté que par ses initiales. Chaque utilisateur doit pouvoir ajouter, changer et retirer sa photo depuis « Mon profil » ; la photo remplace alors ses initiales partout où son avatar est affiché. Le public est sur téléphone d'entrée de gamme et réseau lent : l'image est recadrée et allégée **dans le navigateur** avant l'envoi, et le serveur ne fait que la vérifier. La photo d'un élève n'est visible que de lui, de ses enseignants et de l'équipe ([memo](memo.md), [ADR-0060](../../decisions/adr/0060-photo-de-profil-stockee-privee-recadree-par-le-navigateur.md), [UDR-0047](../../decisions/udr/0047-photo-de-profil.md)).

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Élève | ajouter, changer, retirer **sa** photo ; la voir dans son menu et son profil | voir la photo d'un autre élève ; changer celle d'un autre |
| Enseignant | idem pour la sienne ; voir la photo des élèves présents dans une classe qu'il enseigne (liste de la classe) | voir la photo d'un élève d'une classe qu'il n'enseigne pas, ou d'un autre enseignant |
| Équipe | idem pour la sienne ; voir la photo de tout compte (compte retrouvé au déblocage) | changer la photo d'un autre compte |
| school_admin (en attente) | idem pour la sienne | voir la photo d'un autre compte |
| Visiteur | — | rien : l'image exige une session |

Règles d'autorisation : écrire = `Identity::UpdateSelfPolicy` (soi seulement) ; lire = `Identity::ReadUserPolicy` (soi, l'équipe, l'enseignant pour un élève qu'il enseigne), avec « enseigne » = l'élève est présent dans une classe, active ou archivée, que l'enseignant a déclarée.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur « Mon profil », la carte « Mes informations » a une ligne « Photo » et un bouton « Ajouter une photo » (ou « Changer ma photo »).
2. Le bouton ouvre une modale : l'avatar actuel en grand, un champ « Photo » (le téléphone propose l'appareil photo ou la galerie) et « Enregistrer ».
3. À la sélection, le navigateur recadre l'image au centre en carré de 512 px au plus, la compresse (WebP, sinon JPEG, qualité 80 %) et montre l'aperçu à la place de l'avatar.
4. « Enregistrer » envoie l'image allégée ; la modale se ferme, un toast « Votre photo est enregistrée. » s'affiche, et la page se rafraîchit sans rechargement complet : la photo remplace les initiales dans la carte, le menu du compte et la barre latérale.
5. **Retirer** : dans la même modale, « Retirer ma photo » (présent seulement s'il y a une photo) efface la photo ; toast « Votre photo est retirée. » ; les initiales reviennent partout.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Aucun fichier choisi | 422 dans la modale, « Choisissez une photo. » |
| Fichier qui n'est pas une image JPEG, PNG ou WebP (PDF, texte, image renommée) | 422, « Choisissez une photo JPEG, PNG ou WebP. » ; rien n'est stocké |
| Image de plus de 1 Mo (navigateur qui n'a pas pu la réduire) | 422, « La photo pèse 1 Mo au plus. » |
| Image incomplète ou mal formée, envoyée sans recadrage (JPEG sans EOI ou avec un octet égaré, PNG sans IEND ou au CRC faux, WebP plus court que sa longueur RIFF) | 422, « Choisissez une photo JPEG, PNG ou WebP. » ; rien n'est stocké *(amendé le 2026-09-28, contre-épreuve de la PR #50)* |
| Image qui se décode en rien dans le navigateur (0 × 0, aucun pixel visible) | refusée avant l'envoi : « Cette image est illisible ou abîmée. Choisissez-en une autre. », le champ est vidé *(idem)* |
| Image de plus de 1024 px de côté | 422, « La photo mesure 1024 pixels de côté au plus. » |
| Image qui porte des métadonnées de prise de vue (Exif, XMP, IPTC, textes PNG) | acceptée si elle respecte le reste ; ses métadonnées sont **retirées** avant le stockage *(amendé le 2026-09-28, voir le journal)* |
| Retirer sans photo | succès silencieux, aucune trace d'audit |
| Requête sans Turbo | repli HTML : redirection 303 vers « Mon profil » avec le toast |
| Adresse de l'image demandée par un autre élève, un enseignant qui n'enseigne pas l'élève | 403 ; visiteur : redirection vers la connexion ; compte sans photo ou inconnu : 404 |

## 4. Critères d'acceptation

```gherkin
Scénario: [PH-01] Ajouter sa photo depuis « Mon profil » et la voir dans le menu du compte
  Étant donné un élève connecté sans photo
  Quand il ouvre « Mon profil », choisit « Ajouter une photo » et une image JPEG
  Alors l'aperçu recadré s'affiche avant l'envoi
  Et après « Enregistrer », un toast « Votre photo est enregistrée. » s'affiche sans rechargement de page
  Et sa photo remplace ses initiales dans la carte « Mes informations » et dans le menu du compte
  Et le journal d'audit contient « profile.photo_changed » avec le format, le poids et les dimensions, jamais l'image

Scénario: [PH-02] Le navigateur allège la photo avant l'envoi
  Étant donné une image PNG de 700 × 700 px qui pèse plus de 1 Mo
  Quand l'élève la choisit et enregistre
  Alors l'image stockée est carrée, de 512 px de côté, pèse moins de 1 Mo et ne porte aucune métadonnée

Scénario: [PH-03] Changer puis retirer sa photo
  Étant donné un élève qui a une photo
  Quand il en choisit une autre et enregistre
  Alors l'ancienne est effacée du stockage et la nouvelle s'affiche
  Quand il choisit « Retirer ma photo »
  Alors un toast « Votre photo est retirée. » s'affiche, ses initiales reviennent partout, le fichier est effacé
  Et le journal d'audit contient « profile.photo_removed »

Scénario: [PH-04] Le serveur refuse ce qui n'est pas une petite image propre
  Quand un fichier PDF, une image de plus de 1 Mo ou une image de plus de 1024 px arrive
  Alors la modale est re-rendue en 422 avec le message du cas, sous le champ
  Et rien n'est stocké ni tracé
  Mais une petite image qui porte des métadonnées Exif est stockée sans elles

Scénario: [PH-05] La photo d'un élève n'est visible que de lui, de ses enseignants et de l'équipe
  Étant donné un élève avec une photo, dans la classe d'un enseignant
  Alors l'élève, cet enseignant (liste de la classe) et l'équipe (compte retrouvé) reçoivent l'image
  Et un autre élève et un enseignant qui n'enseigne pas la classe reçoivent 403
  Et un visiteur est renvoyé à la connexion
  Et l'image est servie avec « Cache-Control: private », jamais par une adresse publique du stockage

Scénario: [PH-06] Personne ne change la photo d'un autre
  Alors les actions d'ajout et de retrait ne prennent aucun identifiant : toujours le compte de la session
  Et un visiteur non connecté est renvoyé à la connexion

Scénario: [PH-07] Au téléphone
  Étant donné un écran de 390 px de large
  Quand l'élève ajoute sa photo
  Alors la modale tient dans l'écran, sans défilement horizontal, avec des cibles de 48 px
```

## 5. Hors périmètre

Voir le [memo](memo.md#hors-périmètre). En particulier : aucun redimensionnement serveur, aucune retouche manuelle, aucune photo dans la liste des enseignants d'un établissement.
