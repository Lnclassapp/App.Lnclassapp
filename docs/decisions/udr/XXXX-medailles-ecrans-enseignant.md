# UDR-XXXX : Médailles — les écrans de l'enseignant
<!-- index
titre: Médailles dans les écrans de l'enseignant
statut: Accepté
adr-lie: [0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md)
problematique: L'enseignant lit encore moyenne sur 20, dernier score en %, notes par copie et classement des élèves à côté des médailles.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-09) |
| **Date** | 2026-11-09 |
| **Chantier** | [`docs/chantiers/medailles-enseignant`](../../chantiers/medailles-enseignant/memo.md) |
| **ADR lié** | [ADR-0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Applique l'UDR « Médailles remplacent notes et moyennes » aux écrans de l'enseignant. Règle de classe **par exercice** : la classe affiche une répartition de médailles par exercice, jamais de moyenne ni de classement (décision du porteur).

## 3. Consigne d'exécution

| Écran (enseignant) | Avant | Après |
|---|---|---|
| Page de classe, ligne d'élève | « Moyenne 15/20 · Or », « Fait seul (7 j) », « Dernier score 80 % », « Voir le résultat » | « 9 faits sur 18 · 1 en retard » + médaille seule ; « Pas encore » sans exercice fait |
| Page de classe, fiches à revoir | « moins de 10/20 » | « n'ont pas encore de médaille Bronze » |
| Fiche élève, résumé | « Moyenne 14/20 · Or » | Médailles obtenues, nommées et comptées |
| Fiche élève, exercice et « fait seul » | « 14/20 », « 78 % » | Médaille de l'exercice ; médaille de la session |
| Suivi d'un devoir | « Copies rendues : 1re copie 8/20, meilleure note 15/20 » ; élèves classés par score ; « 🏆 16/20 » | Section supprimée ; élèves par ordre alphabétique ; pastille = médaille seule |
| Suivi d'un devoir, relance | « N élèves n'ont pas encore de médaille » | « N élèves n'ont pas encore l'Argent » (Pas encore + Bronze) |
| Résultat d'une copie (enseignant, équipe) | tuiles Note, Score %, Maîtrise | médaille et « x sur y justes » |
| Accueil, historique | moyenne de la classe « 17/20 » | répartition de médailles du devoir (« Or 3 · Argent 5 ») |

- Les chiffres restent en base et dans les DTO des queries ; seules les vues changent.
- Les médailles de classe se lisent par classe (`Queries::Assessment::Medals`, ADR-0097 §4.5), pour les élèves présents.
- Interdits à l'écran enseignant : « Moyenne », « /20 », « % » comme mesure d'un élève, classement d'élèves par score.
