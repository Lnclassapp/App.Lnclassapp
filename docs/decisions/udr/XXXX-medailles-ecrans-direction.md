# UDR-XXXX : Médailles — les écrans de la direction
<!-- index
titre: Médailles dans les écrans de la direction
statut: Accepté
adr-lie: [0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md)
problematique: La direction lit encore moyennes, scores moyens et taux de rendu en pourcentage.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-08) |
| **Date** | 2026-11-09 |
| **Chantier** | [`docs/chantiers/medailles-direction`](../../chantiers/medailles-direction/memo.md) |
| **ADR lié** | [ADR-0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Applique l'UDR « Médailles remplacent notes et moyennes » aux écrans `/school-admin`.

## 3. Consigne d'exécution

| Écran (direction) | Avant | Après |
|---|---|---|
| Carte de classe d'un niveau | « Taux de rendu : 71 % », « Moyenne : 62 % » | « 5 devoirs rendus sur 6 » ; « 8 Bronze · 6 Argent · 3 Or » (« Pas encore » sans médaille) |
| Page d'une classe : tuiles | Taux de rendu %, Moyenne % | « Devoirs rendus : N sur M » ; « Médailles » : la répartition de la classe |
| Page d'une classe : élèves | « Score moyen » | « Médailles » de l'élève, par palier |
| Anciens élèves | « Score moyen » | « Médailles » gagnées dans l'établissement |
| Pastille et légende de participation | « 70 % et plus », « moins de 40 % » | « régulière », « à encourager », « à relancer » (couleur jamais seule) |
| Alerte de l'accueil | « moins de 40 % des devoirs » | « classes avec peu d'activité » |
| Fiches à revoir | « moins de 10/20 » | « pas encore levées », viser l'Or |

Règle de classe : par exercice. La répartition additionne les médailles gagnées par les élèves présents pour des sessions des devoirs de la classe (ADR-0097 §4.5) ; jamais de moyenne, jamais de classement, pas de seuil d'effectif. Les infobulles disent les quatre médailles en mots.
