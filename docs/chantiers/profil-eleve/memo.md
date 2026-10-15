# Memo — Profil de l'élève aux couleurs Wave et Djamo

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | cadrage |
| **Ouvert le** | 2026-10-15 |
| **Branche** | `Develop` (cadrage, docs seules) ; le code passera par une PR |
| **Programme** | — |

---

## Le problème

La page « Mon profil » de l'élève (`identity/profiles#show` et ses fenêtres) fonctionne, mais elle ne ressemble pas encore aux écrans élève redessinés aux couleurs de Wave et de Djamo (`accueil-eleve`, `cours-eleve`, `ma-classe-eleve`, `exercice-eleve`).

## Pour qui

L'élève (Student), le plus souvent sur un téléphone Android d'entrée de gamme.

## Hors périmètre

- Le profil de l'enseignant, de la direction et de l'équipe (second facteur, codes de récupération).
- Les règles d'identité : code secret à 4 chiffres, numéro ivoirien à 10 chiffres, photo de 1 Mo et 1024 px au plus, blocage après trop d'essais.

## Point de départ : la page actuelle

Relevée dans le code le 2026-10-15 (UDR-0041, UDR-0047, UDR-0051, UDR-0080) : « Mon profil » avec « Accueil » ; « Mes informations » (photo, nom, numéro, classe, date d'inscription) ; « Mon code secret » ; « Apparence » au téléphone ; fenêtres pour le nom, la photo (aperçu recadré, retirer), le code secret (actuel, nouveau, confirmation, œil) et le numéro (code secret actuel, nouveau numéro, confirmation) ; « Code secret incorrect. » en bandeau ; « Se déconnecter » seulement dans le menu du compte.

## Maquettes

Toile : https://claude.ai/artifact/BCpNowiWxjrCx53kCTTr9g (téléphone d'abord).

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Quelle page après la révision (mise en pause) ? | Le profil (porteur, 2026-10-15). | Même en-tête et même menu de l'avatar ; carte bleue avec la photo, le nom et la classe ; lignes entières à toucher ; fenêtres par le bas au téléphone. |

| Ajoute-t-on « Se déconnecter » en bas du profil ? | Oui (porteur, 2026-10-15). | Un bouton « Se déconnecter » en bas du profil ; il reste aussi dans le menu du compte. |
| Affiche-t-on l'établissement dans « Mes informations » ? | Oui (porteur, 2026-10-15). | Une ligne « Établissement » en lecture seule après « Classe » ; la carte bleue dit seulement « Élève en 3e B ». |

## Tablette

- Verticale (820 px) : une seule colonne centrée ; les fenêtres s'ouvrent au milieu de l'écran.
- Horizontale (1180 px) : le menu de gauche revient ; « Mes informations » à gauche, le code secret et « Se déconnecter » à droite ; le mode sombre passe par la lune de l'en-tête.
