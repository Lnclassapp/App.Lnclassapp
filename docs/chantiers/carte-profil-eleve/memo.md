# Memo — Carte de profil de l'élève dans la barre latérale

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | livré |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/carte-profil-eleve` |
| **Programme** | — |

---

## Le problème

Sur ordinateur, la barre latérale de l'élève commence directement par la navigation : rien ne dit qui est connecté ni dans quelle classe. L'enseignant, lui, a en tête une carte avec sa photo, son nom, ses matières et son établissement. Le porteur veut la même carte pour l'élève : « avatar, nom complet, puis classe », « en respectant les sections des enseignants ».

## Pour qui

L'élève connecté sur ordinateur, sur toutes les pages de son espace.

## Pourquoi maintenant

Demande directe du porteur, qui renverse la règle « l'élève n'a pas de carte de profil » de l'accueil élève.

## Hors périmètre

- Le téléphone : il n'a pas de barre latérale, rien n'y change.
- Enseignant, direction, équipe : leur carte ne change pas.
- Parent : il n'a pas d'espace connecté aujourd'hui.
- Rendre la carte cliquable (« Mon compte » s'ouvre depuis l'avatar de la barre du haut).
- Afficher plusieurs classes ou plusieurs établissements.

## Ce que le grill a révélé

> Grill joué par l'orchestrateur sur la demande écrite du porteur et le code (pas de porteur joignable en direct pendant la session) ; chaque réponse vient de la demande ou d'une règle déjà écrite.

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Que voient les autres acteurs (enseignant, direction, équipe, parent) ? | Rien ne change pour eux ; le parent n'a pas d'espace. | Écrit dans `Hors périmètre` ; un test garde la carte des adultes. |
| Un élève rattaché à plusieurs classes : laquelle ? | La classe principale active, celle que l'en-tête et l'aide nomment déjà. | Aucune nouvelle lecture : on reprend celle du shell. |
| L'enseignant montre « matières · sigle ». L'élève : nom de l'établissement ou sigle ? | Le sigle (le nom à défaut), comme l'enseignant et comme la carte de l'accueil (« 3ÈME B · LMC »). Le nom entier passait sur deux lignes et rendait la carte plus haute que celle de l'enseignant (vu en capture). | Le sigle est lu avec la classe, dans la même requête ; la carte garde la hauteur de celle de l'enseignant. |
| Un élève sans classe, ou dont la classe est archivée ? | « Pas encore de classe », jamais une ligne vide. | Un texte d'état vide et son test. |
| Un nom très long ? | Une seule ligne, coupée par des points de suspension, sans élargir la barre. | Test de vue et mesure dans le test système. |
| La couleur des initiales : par le nom (enseignant) ou par l'identifiant (en-tête élève) ? | Par l'identifiant public, sinon l'élève verrait deux couleurs différentes pour lui-même. | La teinte suit celle de l'avatar de la barre du haut. |
| Contexte borné ? | `identity` (qui est connecté) ; aucune règle métier nouvelle. | Pas d'ADR. |

## Cas limites identifiés

- Élève sans classe active (jamais rattaché, ou classe archivée) → « Pas encore de classe ».
- Établissement sans sigle → son nom.
- Nom très long → une ligne tronquée.
- Élève sans photo → initiales, teinte de l'en-tête.

## Questions encore ouvertes

- Aucune.
