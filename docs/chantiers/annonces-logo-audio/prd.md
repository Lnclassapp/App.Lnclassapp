# PRD — Annonces : le logo officiel, un audio de 10 secondes téléchargeable, plus de « Toutes les annonces »

## 1. Contexte

Voir le [memo](memo.md). Les annonces de l'équipe se signent du logo officiel ; l'audio d'une annonce dure 10 secondes au plus, vérifié dans le navigateur et au serveur, et chaque lecteur peut le télécharger ; le lien « Toutes les annonces » quitte les accueils des adultes.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Équipe, direction, enseignant (auteurs) | joindre un audio MP3 ou M4A de 10 s et 1 Mo au plus | joindre un audio plus long, plus lourd, ou dont la durée ne se lit pas |
| Tout lecteur d'une annonce | écouter et télécharger son audio | télécharger l'audio d'une annonce qu'il ne peut pas lire (404) |

Règle d'autorisation : inchangée, `ReadFilePolicy` (lecture d'un fichier d'annonce, ADR-0078 §4.4).

## 3. Parcours utilisateur

### Chemin nominal

1. L'auteur choisit un audio de 8 s dans « Audio (facultatif) » ; rien ne s'affiche ; il publie.
2. La carte montre ▶ et, dessous, « Télécharger ». Une annonce de l'équipe est signée du logo officiel et de « Lnclass ».
3. Le lecteur appuie sur « Télécharger » : le navigateur enregistre `annonce-<identifiant>.mp3`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| L'auteur choisit un audio de 14 s | Le navigateur dit sous le champ « Cet audio dure 14 s : 10 secondes au plus. Raccourcissez l'enregistrement. » et bloque l'envoi |
| Le contrôle du navigateur est contourné | Le serveur répond 422 avec le même message sous le champ ; rien n'est enregistré |
| La durée ne se lit pas (fichier tronqué, octets inconnus, M4A fragmenté) | 422 « La durée de cet audio ne se lit pas. Exportez l'enregistrement en MP3 ou M4A. » |
| Audio de plus d'1 Mo | 422 « Ce fichier est trop lourd (1 Mo au plus). », sans lecture |
| Lecteur sans droit sur l'annonce | 404 au téléchargement comme à l'écoute |

## 4. Critères d'acceptation

```gherkin
# LA-1 — logo
Étant donné une annonce publiée par l'équipe
Quand un lecteur voit sa carte
Alors la signature montre le logo officiel de Lnclass et « Lnclass »

# LA-2 — durée bornée, serveur
Étant donné un auteur qui joint un audio de plus de 10 secondes (tolérance 0,3 s)
Quand il publie
Alors la réponse est 422, le message donne la durée lue et la borne, et rien n'est enregistré

# LA-3 — durée illisible
Étant donné un audio MP3 dont des octets inconnus séparent deux trames, ou un M4A sans durée lisible
Quand il est joint
Alors la réponse est 422 « La durée de cet audio ne se lit pas »

# LA-4 — audio court accepté
Étant donné un audio MP3 ou M4A de 10 secondes au plus
Quand il est joint
Alors l'annonce est publiée avec son audio

# LA-5 — poids
Étant donné un audio de plus d'1 Mo
Quand il est joint
Alors la réponse est 422 « 1 Mo au plus », sans lecture de sa durée

# LA-6 — contrôle dans le navigateur
Étant donné un auteur qui choisit un audio de plus de 10 secondes
Quand le navigateur en lit la durée
Alors le message s'affiche sous le champ, le champ est invalide et l'envoi est bloqué
Et en choisissant ensuite un audio court, le message disparaît

# LA-7 — téléchargement
Étant donné une annonce lisible avec un audio
Quand le lecteur suit « Télécharger »
Alors la réponse est le fichier en pièce jointe, nommé annonce-<identifiant>.<mp3|m4a>
Et un acteur qui ne peut pas lire l'annonce reçoit 404

# LA-8 — plus de « Toutes les annonces »
Étant donné l'accueil d'un enseignant ou d'une direction avec au moins une annonce
Quand il s'affiche
Alors aucun lien « Toutes les annonces » n'apparaît sous la bande
Et l'onglet « Reçues » reste servi à son adresse
```

## 5. Modélisation préliminaire

| Couche | Éléments prévus |
|---|---|
| Domaine | mesure de la durée d'un audio (Ruby pur, sur les octets) ; bornes de l'annonce (10 s, 0,3 s, 1 Mo) ; validation de la saisie |
| Infrastructure | aucune |
| Delivery | le contrôleur des fichiers d'annonce sert la pièce jointe sur demande |
| UI | signature de la carte, lien « Télécharger », contrôle de durée du formulaire (Stimulus), carrousel sans lien |

## 6. Décisions rattachées

- ADR-XXXX-annonces-audio-dix-secondes — borne de durée, mesure sans bibliothèque, plafond d'1 Mo, téléchargement, menace.
- UDR-0071 — amendement du 2026-10-30 (§3.2 signature, §3.4 téléchargement, §3.5 et §3.7 sans « Toutes les annonces », §3.8 formulaire).
- Aucun port, aucune table : la mesure est une fonction du domaine sur les octets déjà lus par la saisie.
