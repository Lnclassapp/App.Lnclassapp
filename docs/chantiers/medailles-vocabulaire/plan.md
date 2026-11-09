# Plan — Médailles : vocabulaire et garde-fous

## Lot A — Doc et garde-fous (ce chantier, un commit)

UDR médailles, UDR-0007, glossaire, remédiation dans la doc, regex `FORBIDDEN`, valeurs I18n fr, tests alignés. Preuve : `bin/ci-quiet` dans la PR.

## Chantiers suivants (écrans), cadrés dans `docs/audits/2026-11-08-optimisations-ux-wording.md` § « Passage aux médailles »

1. **`medailles-eleve`** (en premier) : résultat de copie (médaille seule + prochaine à viser), accueil (« À revoir », historique, Refaire), Ma classe, mon historique, page exercice (« Ta médaille »), copie en cours (retirer barème et points), FAQ `/aide`, fiches et feuilles du catalogue (« Réussi » = médaille obtenue).
2. **`medailles-enseignant`** : liste de classe et fiche élève (médaille, plus de « Moyenne 15/20 » ni « Dernier score »), rapport d'exercice (répartition, tri alphabétique, plus de « Copies rendues » notées), accueil « Historique », infobulles en mots.
3. **`medailles-direction`** : carte de classe, tuiles « Moyenne » et « Score moyen », anciens élèves, bulles « Niveaux », alerte rendu sans pourcentage, « Fiches à revoir ».
4. **`medailles-equipe`** : pilotage « Réussite moyenne » → médailles décernées, corrigé sans points, « Barème des classes » renommé « Plan des classes ».

Chaque chantier : captures à 390 px et sur ordinateur, UDR propre, test d'absence de note/% dans ses vues.

## Écart code à traiter

Décision du porteur : tout exercice traité donne au moins Bronze. Aujourd'hui `Grading.badge_for` et `Grading.class_badge_for` renvoient `nil` sous `PASS_THRESHOLD` (et la clôture n'écrit pas de médaille). Un chantier de code précède `medailles-eleve` : Bronze pour tout exercice traité, « Pas encore » seulement sans exercice fait.

## Décisions ouvertes

Voir `journal.md` § À trancher.
