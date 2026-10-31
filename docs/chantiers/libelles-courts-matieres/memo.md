# Memo — Les libellés courts des matières

| | |
|---|---|
| **Type de cycle** | feature (une vue change) |
| **Statut** | livré, clos |
| **Ouvert le** | 2026-10-30 |
| **Branche** | `feature/libelles-courts-matieres` |
| **Programme** | — |

---

## Problème

Le porteur veut des libellés courts dans la section « Matières » : « Mathématiques » → « Maths », « Histoire-Géographie » → « HG », « Physique-Chimie » → « PC ».

## Grill

- **Quels écrans ?** Cinq affichent des matières : (1) la grille « Mes matières » de l'accueil élève, (2) la bande « Les matières du programme » de la homepage, (3) les pastilles « Matières » des leçons dans le catalogue élève sur ordinateur (`#lesson_materials`), (4) les titres par matière du catalogue public, (5) le profil enseignant et le référentiel de l'équipe. Réponse du porteur : **seul l'écran 3 change** ; puis, en cours de lot : « sur téléphone aussi » — la vue téléphone du même écran (les titres de groupe par matière de Cours) s'abrège aussi.
- **Et ailleurs ?** Le nom complet reste partout : titres de page, h1 de la vue d'une matière, fil d'Ariane, `title`, `aria-label`.
- **Philo ?** La table `shared.subjects.short` porte déjà « Philo » : il suit aussi.
- **La donnée ?** Inchangée : nom en base, slugs, imports. Le libellé court vient de l'I18n existant (`shared.subjects.short`, par slug figé), déjà lu par le menu « Mon compte » de l'enseignant. La colonne `shortname` des matières n'est pas lue.
- **Accessibilité** : le court seul visible et muet ; le nom entier lu (sr-only) et en `title`, comme `ui_subject_bubble short_label:` (UDR-0084 §3.5).

## Hors périmètre

Les écrans 1, 2, 4 et 5 ; toute autre abréviation que celles de `shared.subjects.short`.
