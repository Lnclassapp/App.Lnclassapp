# Journal — Annonces : le logo officiel, un audio de 10 secondes, plus de « Toutes les annonces »

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 | Le logo signe toute annonce de l'équipe ; il n'est pas joint comme image aux 3 annonces de `Develop` | Design system §10 ; joint, il prendrait la place de l'illustration et se lirait deux fois | UDR-0071, amendement du 2026-10-30 |
| 2026-10-30 | Le lien « Télécharger » et le mode pièce jointe de la route sont retirés (LA-7, M9, M10, ADR-0118 §4.3) | Le porteur : « quand j'ai dit rends-le téléchargeable, c'était pour l'avoir en local et non via l'app » ; il voulait les fichiers, pas un lien | UDR-0071 et ADR-0118 amendés |
| 2026-10-30 | Plafond de l'audio ramené de 10 Mo à 1 Mo | 10 s à 320 kbit/s = 400 Ko ; le serveur ne lit jamais plus d'1 Mo | Oui, ADR-0118 §4.1 |
| 2026-10-30 | Fin d'un MP3 : ID3v1 de 128 octets exactement, APEv2 dont la taille va jusqu'à la fin ; M4A : `stts` doit couvrir tous les échantillons de `stsz` | Revues sécurité et échecs silencieux : une fausse étiquette `TAG` cachait 36 s de trames derrière 0,1 s mesurée | Oui, ADR §4.2 et §4.4 |
| 2026-10-30 | Le contrôle du navigateur écrit le message sous le champ et rend le champ invalide, sans bulle `reportValidity` | La bulle redisait le message (« dire chaque chose une seule fois ») ; vu sur la capture à 390 px | Non (UDR déjà conforme) |

## Ce qui a dérapé

- La première fin de MP3 admise (`TAG` ou `APETAGEX` au début du reste) contournait la menace M2 : la menace était écrite, mais la parade trop large. Les revues l'ont trouvée ; corrigé au Lot R.
- Les tests de `AudioDuration` du Lot A ont été écrits après le code (jamais vus rouges) ; ceux du Lot R l'ont été avant.
- Les worktrees des lots n'avaient pas d'assets compilés : `yarn build` et `yarn build:css` à lancer avant les tests de vue et système.

## Ce qu'on a appris sur la codebase

- Les anciens tests fabriquaient des MP3/M4A factices (en-tête puis zéros) : ils ne sont plus mesurables ; les fixtures réelles de `test/fixtures/files/audio/` les remplacent.
- La signature de l'équipe utilisait `lnclass/icon.svg`, pas le logo officiel `logo/lnclass.jpeg` (`BrandHelper::LOGOS`).

## Dette laissée derrière

### Correctif après la revue du train (2026-10-30)

La revue de sécurité du train vers `main` a relevé deux constats de gravité basse dans `AudioDuration`, reproduits :

- `APETAGEX` suivi de 2 à 7 octets après des trames valides : lecture hors de la chaîne, 500 au lieu de 422. Garde de 32 octets en tête de `ape_to_end?` (ADR-0118 M10).
- Piste M4A sans `mdhd`, ou `stbl` hors de `mdia/minf` : seule la durée déclarée était crue (5 s devant 60 s). Chaque `trak` exige `mdhd` et `mdia/minf/stbl/stts` (ADR-0118 M9).

### Carte sobre (2026-10-30, après la fusion de la PR #391)

Demande du porteur : sans « Modifiée », texte de 10 mots ou 2 lignes, logo du lecteur (bleu pour l'élève, orange — le « jaune » du porteur — pour l'enseignant). Règle d'affichage seulement : la saisie garde ses 140 caractères. UDR-0071, amendement du 2026-10-30 (second).

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Les audios joints avant ce chantier ne sont pas relus | Hors périmètre (memo) | — |
| M4A fragmenté (`dash`) refusé | Durée dans les fragments, coût de lecture | — |
| Vérification iOS Safari du contrôle de durée (`player.load()` ajouté, non vu sur appareil) | Pas d'appareil dans le conteneur | — |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-30 (en revue) |
| **PR** | voir la PR vers `Develop` |
| **ADR produits** | ADR-0118 |
| **UDR produits** | UDR-0071 amendée (2026-10-30) |
