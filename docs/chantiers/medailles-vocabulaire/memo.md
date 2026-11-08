# Memo — Médailles : vocabulaire et garde-fous

| | |
|---|---|
| **Type de cycle** | refactoring (vocabulaire, sans changement d'écran) |
| **Statut** | en cours |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `claude/medailles-vocabulaire` |
| **Programme** | — |

## Le problème

L'interface mélange « badge », note sur 20, pourcentage et moyenne. Le porteur a tranché : la **médaille** (Bronze, Argent, Or, Diamant) remplace tout cela à l'écran. Il faut d'abord le dire dans la doc et le faire respecter par les tests, avant de toucher aux écrans.

## Décisions du porteur (2026-11-08)

- Médailles = seule mesure lue ; les chiffres restent en base.
- Mot officiel : « Médaille ». Nouvelle UDR qui amende UDR-0007.
- Classe : médaille **par exercice** ; répartition, jamais moyenne ni classement.
- Sous Bronze : « Pas encore », avec encouragement et possibilité de refaire.
- Remédiation : sous Bronze (aujourd'hui 15/20) ; doc seulement.

## Hors périmètre

Toute refonte d'écran (voir `plan.md`, chantiers suivants). Aucun renommage de code (`ExerciseBadge`, `badge_for`) ni de clé I18n.

## Livré ici

UDR médailles ; glossaire (seuils 48/68/78 %) ; `FORBIDDEN` du test I18n ; valeurs fr « badge » → « médaille » ; « Non acquis » → « Pas encore ».
