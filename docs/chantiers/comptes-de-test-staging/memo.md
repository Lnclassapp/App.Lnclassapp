# Memo — Comptes de test sur Staging

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `feature/comptes-de-test-staging` |
| **Programme** | — |

---

## Le problème

La recette connectée sur Staging est impossible : aucun compte de test n'y existe. Le jeu standard (ADR-0124) n'est semé que sur Develop, Demo et les environnements de PR. Le 2026-11-05, l'étape « recette connectée sur Staging » du train a dû être sautée (« faute de compte de test sur Staging »), et les identifiants sont redonnés à la main dans le chat (rapport sur la méthode de travail, point 7).

## Pour qui

Le porteur et les agents qui font la recette d'un train sur Staging, avant la promotion vers `main`.

## Pourquoi maintenant

Chaque train vers `main` passe par Staging : sans compte, la recette connectée y est sautée à chaque fois.

## Ce qui change

À chaque déploiement de Staging (`RAILWAY_ENVIRONMENT_NAME=Staging`), le semis ajoute ce qui manque des établissements, classes et comptes du jeu standard, comme sur Develop :

- PIN de test public `2468` pour les élèves, enseignants et directions du jeu ;
- comptes équipe seulement si `STANDARD_TEAM_PIN` est posée sur Staging, en variable **scellée**, créés sans second facteur ;
- rien n'est supprimé ni modifié ; un contact déjà pris est laissé tel quel et signalé (contact masqué) ;
- **pas d'activité simulée** (`standard/activite`) et **pas de leçons du manifeste** : Staging garde son chargement `:create_only` ;
- un échec du jeu est journalisé, jamais levé : le déploiement de Staging ne casse pas pour lui.

Tranché par le porteur le 2026-11-05 (option « comptes du jeu », sans activité simulée).

## Hors périmètre

- Production : inchangée, aucun jeu.
- Activité simulée sur Staging.
- Remise à zéro de Staging.

## Menace

Staging est un site ouvert (`app-staging.lnclass.com`). Un PIN public sur un compte équipe y donnerait l'administration à tout visiteur : d'où la variable scellée, comme sur Develop et Demo. Les comptes élève, enseignant et direction du jeu au PIN public ne voient que les trois établissements fictifs du jeu.
