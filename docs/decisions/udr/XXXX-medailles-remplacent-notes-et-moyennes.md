# UDR-XXXX : Médailles — le mot « Médaille » remplace « badge » ; les médailles remplacent notes, pourcentages et moyennes à l'écran
<!-- index
titre: Médailles à la place des notes, pourcentages et moyennes
statut: Accepté
adr-lie: [0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md), [0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md)
problematique: L'interface dit « badge », « note sur 20 », « moyenne » et « % » pour la même chose ; le porteur veut que la médaille (Bronze, Argent, Or, Diamant) soit la seule mesure lue par l'utilisateur.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-08) |
| **Date** | 2026-11-08 |
| **Chantier** | [`docs/chantiers/medailles-vocabulaire`](../../chantiers/medailles-vocabulaire/memo.md) |
| **ADR lié** | [ADR-0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) · [ADR-0033](../adr/0033-bareme-des-badges-et-seuils-pedagogiques.md) |
| **Amende** | [UDR-0007](0007-vocabulaire-de-la-fiche-essentielle-et-de-l-evaluation.md) §2 (« badge », « Médaille » interdit) · [UDR-0131](0131-paliers-et-maitrise-lus-sur-20-dans-les-infobulles-et-la-faq.md) (paliers lus sur 20 → lus en médailles) |
| **Remplacé par** | — |

---

## 1. Contexte

L'élève et l'enseignant lisent aujourd'hui quatre mesures concurrentes : la note sur 20, le pourcentage, la moyenne, et le badge. Le badge est déjà calculé de façon unique (`Grading.badge_for`, ADR-0106). UDR-0007 interdisait « Médaille » et nommait l'objet « badge ». Le porteur tranche : la médaille est la seule mesure affichée.

## 2. Décision

1. **Le mot est « Médaille »**, jamais « badge » dans un texte lu. Le code garde `badge` (`ExerciseBadge`, `Grading.badge_for`, `BadgesHelper`) : on ne renomme pas le code. Pastille de statut ou de rôle (composant `ui_badge`) : « pastille » à l'écran.
2. **Quatre médailles** : Bronze, Argent, Or, Diamant. Seuils réels, lus sur la note affichée (ADR-0106) : Bronze dès 48 %, Argent dès 68 %, Or dès 78 %, Diamant = sans-faute. Ils s'écrivent 48/68/78 % dans la doc ; à l'écran jamais en chiffre (10, 14, 16 sur 20 compris).
3. **La médaille remplace** note sur 20, pourcentage, moyenne et score affichés. Les chiffres restent en base ; aucune migration.
4. **Côté classe, la médaille se lit par exercice.** La classe affiche une **répartition** de médailles (« 8 Bronze · 6 Argent · 3 Or »). Jamais de moyenne, jamais de classement d'élèves.
5. **Tout exercice traité donne au moins Bronze** (décision du porteur, pas de médaille de participation distincte) : Bronze couvre tout score sous Argent, y compris sous 48 %. **« Pas encore »** ne subsiste que pour « aucun exercice fait / rien à afficher » ; libellé unique (remplace « Non acquis », « Pas encore de badge »). Il n'est jamais présenté comme un échec (ni rouge, ni « raté », ni cadenas). Aujourd'hui `Grading.badge_for` et `class_badge_for` renvoient `nil` sous `PASS_THRESHOLD` : l'écart est à corriger par un chantier de code, pas ici.
6. **Remédiation** : elle se lit en médailles (Bronze en dessous duquel on revoit). Amendé le 2026-11-09 (chantier `seuil-remediation`, décision du porteur) : Bronze et Argent restent en remédiation, la fiche n'est levée qu'à l'Or ; il n'y a plus de seuil propre à la remédiation. Amendé le 2026-11-09 (chantier `ouverture-remediation`, décision du porteur) : « quand la médaille est Argent, l'élève est dans la remédiation ; seules les médailles Or et Diamant ne sont pas dans la remédiation » ; la fiche s'ouvre donc aussi à Bronze et à Argent, pas seulement sous 10/20. Une copie sans réponse (aucune médaille) n'ouvre rien.

## 3. Consigne d'exécution

| Surface | Texte |
|---|---|
| Nom de l'objet | « Médaille », pluriel « Médailles » ; « Nouvelle médaille ! » ; « Médaille Or » (aria-label) |
| Rien à afficher (aucun exercice fait) | « Pas encore » |
| Répartition de classe | « 8 Bronze · 6 Argent · 3 Or », « Élèves par médaille » |
| Interdits à l'écran | « badge », « note sur 20 », « moyenne », « % » comme mesure d'un élève ou d'une classe |

- `test/i18n/locale_files_test.rb` : `FORBIDDEN` refuse désormais `badge(s)` et `trophée` ; `médaille` est autorisé.
- Les clés I18n gardent leur nom (`badge`, `badges_label`) : seules les valeurs changent. Les écrans qui affichent encore note, % ou moyenne sont convertis par les chantiers suivants (voir `plan.md`).

## 4. Conséquences

- UDR-0007 : la ligne `ExerciseBadge` du tableau §2 est lue « Médailles Bronze, Argent, Or, Diamant » ; « Médaille » n'est plus interdit.
- Glossaire : seuils réels 48/68/78 %.
- Les infobulles « Bronze dès 10/20… » (UDR-0131) seront réécrites en mots par le chantier enseignant ; ici, seul le mot « badge » change.
