# Journal — Catalogue complet : pages publiques Niveau, Matière et Série

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-16 | Cadrage écrit sur les recommandations de l'agent, en attente des réponses du porteur aux questions 1 à 12 | Le porteur a demandé de lancer V2 à V6 ; le cadrage doit être validé avant le code | ADR-0099, UDR-0113 à 0115, toutes « Proposé » |
| 2026-10-16 | Pas de lot pour CA-01, CA-02, CA-03, AS-01 | L'inventaire du code les montre livrées (`politique-cache`, `interface-enseignant-organisation`, `catalogue-niveau-eleve`, `cours-eleve`) ou couverte sous sa forme corrigée (page d'une fiche) | Non : constat d'inventaire, écrit dans le memo |
| 2026-10-16 | Une requête par page publique, sur un socle commun `PublicCourses` | Quatre lots parallèles ne peuvent pas partager un fichier de requête | Oui, ADR-0099 §4.2 |

## Ce qui a dérapé

- La feuille de route appelle CA-17, CA-21 et CA-23 « pages publiques » alors que l'inventaire de l'ancienne application les décrit « tout connecté » (CA-17, CA-21) et « `team` » (CA-23). L'écart n'avait jamais été posé au porteur : c'est la question 1.

## Ce qu'on a appris sur la codebase

- Le catalogue connecté n'a plus de dette de V4 : filtres dans l'adresse pour tous les rôles sauf l'élève, pagination par frame différé, brouillons filtrés en SQL hors équipe.
- `ReadPublishedPolicy` refuse un acteur `nil` : toute lecture anonyme du catalogue doit passer par une requête qui filtre le publié elle-même.
- Le blog a posé tout l'outillage du référencement (`canonical_url`, `_head`, plan du site, `X-Robots-Tag` hors production) ; le catalogue le reprend sans le modifier.
- La bande « Matières » de la homepage est une liste écrite en dur dans la vue, sans lien.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Sommaire public d'un cours | Question 3 : vitrine limitée aux titres | À ouvrir si le porteur le demande |
| Cache HTML des pages publiques (gabarit sans session) | ADR-0076 ; trafic non mesuré | À rouvrir sur mesure du trafic |
| Liste « Tous les exercices » pour l'équipe | Question 9 : AS-01 fermée sous sa forme corrigée | À ouvrir si le besoin se confirme |
| Q9, matrice des sous-rôles | Hors de ce chantier | `sous-roles-equipe` |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | ADR-0099 (Proposé) |
| **UDR produits** | UDR-0113, UDR-0114, UDR-0115 (Proposé) |
