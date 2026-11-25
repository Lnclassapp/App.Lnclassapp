# UDR-0184 : La note sur 20 revient dans les listes de l'élève, la médaille devient une récompense
<!-- index
titre: Note sur 20 et médaille-récompense dans les listes de l'élève
statut: Accepté
adr-lie: [0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md)
problematique: l'élève ne voyait plus que la médaille ; le porteur veut aussi la note sur 20, la médaille étant montrée comme une récompense
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-24) |
| **Date** | 2026-11-25 |
| **Chantier** | [`docs/chantiers/ecrans-wave-ma-classe-historique`](../../chantiers/ecrans-wave-ma-classe-historique/journal.md) |
| **ADR lié** | [ADR-0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) |
| **Amende** | [UDR-0167](0167-medailles-remplacent-notes-et-moyennes.md) §2.3 et §3 (« note sur 20 » interdite à l'écran) |
| **Remplacé par** | — |

---

## 1. Contexte

UDR-0167 faisait de la médaille la seule mesure affichée. En refaisant « Ma classe » et « Mon historique » (PR #707), le porteur demande : « remettre les notes, puis rendre les médailles comme une récompense ».

## 2. Décision

1. **Trois listes de l'élève** affichent la note sur 20 (« 14/20 ») de chaque exercice traité : « Exercices traités » de Ma classe, « Mes exercices terminés » de Mon historique, l'historique de l'accueil.
2. **La médaille est une récompense** : sous la note, une pastille teintée à sa couleur, le trophée sur un rond blanc (`medal_reward_tag`, `grade_and_medal`).
3. **Copie vide** : « Pas encore » seul, jamais « 0/20 ».
4. **Rien d'autre ne change** : ni pourcentage, ni moyenne, ni compte « réussis » ou « répondu/total » ; écrans enseignant et direction toujours en médailles (UDR-0167 s'y applique entière).

Réversible : remplacer `grade_and_medal` par `medal_reward_tag`.

## 3. Consigne d'exécution

| Surface | Texte |
|---|---|
| Exercice traité (élève, trois listes) | « 14/20 » puis la pastille « Argent » |
| Copie vide | « Pas encore » |
| Interdits inchangés | « % », « moyenne », comptes de réussite |
