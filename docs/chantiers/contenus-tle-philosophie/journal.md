# Journal — Les 10 premières leçons de Philosophie de Tle

> Rempli **pendant** le chantier.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-31 | Prompt de matière : ligne Philosophie dans « Selon la matière » et section « Auteurs, doctrines et textes » de `prompt-redaction.md` | La consigne ne couvrait pas la Philosophie ; reprise du modèle Français 3ème (questions rédigées avec corrigé modèle, barème, critères ; ≥ 50 % corrigées automatiquement) | Non |
| 2026-10-31 | Textes longs : auteurs de langue française du domaine public ou textes écrits pour Lnclass ; auteurs étrangers en paraphrase | Une traduction récente peut être protégée | Non |

## Ce qui a dérapé

- **Aucune leçon n'était livrable au premier jet** : les 10 relectures indépendantes ont trouvé 0 défaut bloquant mais 2 à 7 défauts à corriger par leçon : thèses déformées (Rousseau et l'état de nature, Descartes au service d'une thèse qu'il ne soutient pas, arbitraire du signe de Saussure), dates de préface (Kant 1787), barèmes incohérents avec leurs critères, réponses justes refusées par un `fill_blank`, textes supports absents des questions qui les citent. Le script ne voit rien de cela.
- **Vocabulaire de méthode divergent entre leçons** (problème ou problématique, ordre de l'introduction) : L1 a servi de référence, L2 et L10 ont été réalignées.
- **Corrections qui désignent une proposition par son rang** (« la première proposition ») : la relecture de la leçon 6 a montré que l'application mélange les propositions, ce qui rend ces renvois faux (et 4 étaient faux même dans l'ordre du fichier). 8 cas trouvés dans L4 et L6, corrigés ; règle ajoutée à `prompt-redaction.md` et au brief des rédacteurs. Le contrôle ne le détecte pas.

## À faire valider par un enseignant de philosophie

| Leçon | Point à valider |
|---|---|
| L1 Dissertation | Terminologie des plans (dialectique thèse/antithèse/dépassement ou synthèse ; analytique/progressif) et lien forme du sujet → plan présenté comme tendance ; structure de l'introduction (amorce, sujet, problème/problématique, annonce du plan) ; paragraphe idée-argument-exemple-bilan avec référence d'auteur facultative |
| L2 Commentaire | Explication en 5 gestes (situer, définir, reformuler/justifier, illustrer, relier) ; place de l'évaluation de l'intérêt (dernier moment du développement) ; 4 temps de l'introduction ; connecteurs (certes… mais, sans doute… mais, ainsi) ; textes supports tous écrits pour Lnclass ; Usage de « problème » (la difficulté) et « problématique » (la question) dans le commentaire, aligné sur L1 |
| L3 Connaissance de l'homme | Périmètre de la notion « sciences humaines » (Durkheim, 1895, « considérer les faits sociaux comme des choses ») face aux leçons 4 et 10 ; dates de 1re publication Freud (« L'Interprétation des rêves » datée 1900, « Psychopathologie de la vie quotidienne » 1901, « Une difficulté de la psychanalyse » 1917) ; inconscient présenté comme hypothèse |
| L4 Vie en société | Aristote, « Politique » (IVe s. av. J.-C.), animal politique et langage ; Hobbes, « Léviathan », 1651 (guerre de chacun contre chacun, paraphrase) ; Rousseau, « Du contrat social », 1762, citation « L'homme est né libre, et partout il est dans les fers » ; Kant, « insociable sociabilité » (1784) ; Montesquieu, « De l'esprit des lois », 1748 ; travail et échanges non traités ; Kant, « insociable sociabilité » tiré d'un texte sur l'histoire (proximité avec L6) ; état de nature de Hobbes présenté comme hypothèse ; justice traitée sans auteur |
| L5 Dieu et la religion | Durkheim, « Les formes élémentaires de la vie religieuse », 1912 ; étymologie de « religion » (relier / recueillir) présentée comme discutée ; Descartes, 3e Méditation (idée d'infini) ; pari de Pascal (« Pensées », 1670) comme raison d'agir ; Kant, 1781 (ni prouver ni réfuter) ; Feuerbach 1841 ; Freud, « L'Avenir d'une illusion », 1927 (sens d'illusion) ; Marx 1844, « l'opium du peuple » ; Locke 1689 et Voltaire 1763 sur la tolérance ; laïcité de l'État ivoirien (Constitution, aucun article cité) ; neutralité d'ensemble ; Kant, « faire place à la croyance » : préface de la 2e édition (1787) ; titre de Marx 1844 ; article de la Constitution ivoirienne sur la laïcité non cité |
| L6 Histoire et humanité | Rousseau, perfectibilité (1755) ; Hegel, « Leçons sur la philosophie de l'histoire » (publication posthume, 1837), raison dans l'histoire et « ruse de la raison » ; Marx et Engels 1848 ; Marx, « Le 18 Brumaire de Louis Bonaparte », 1852 ; Pascal, petite cause imprévue ; objection de la contingence sans auteur ; indépendance de la Côte d'Ivoire le 7 août 1960 ; Pascal rangé dans la réponse « hasard » ; conclusion « le sens de l'histoire se construit » |
| L7 Valeur de la philosophie | Platon, « Théétète », et Aristote, « Métaphysique » : l'étonnement (paraphrase) ; Descartes, lettre-préface des « Principes de la philosophie », 1647 (arbre, yeux fermés) ; Russell, « Problèmes de philosophie », 1912, chap. XV ; Tempels, « La philosophie bantoue », 1945 (Présence africaine 1949), force vitale ; Hountondji, 1976, ethnophilosophie ; Towa, 1971 ; Kagame, « La philosophie bantu-rwandaise de l'être », 1956 (paraphrase) ; équilibre des positions dans le débat sur la philosophie africaine ; la notion « philosophie, sciences et religion » face à la leçon 10 |
| L8 Progrès et bonheur | Condorcet, 1795, perfectibilité indéfinie (fill_blank « perfectibilité ») ; Descartes, « maîtres et possesseurs de la nature », 1637, VIe partie ; Rousseau, 1750 ; Épicure, « Lettre à Ménécée », classement des désirs ; Épictète, « Manuel », ce qui dépend de nous ; Kant, 1785, bonheur concept indéterminé ; Formule « ni naturels ni nécessaires » attribuée à la « Lettre à Ménécée » (plutôt Maxime capitale XXIX) ; « Discours sur les sciences et les arts » daté 1750 (diffusé 1751) |
| L9 Langage et vérité | Descartes, lettre au marquis de Newcastle, 1646 (paraphrase) ; Benveniste, abeilles (article de 1952, recueil « Problèmes de linguistique générale », 1966) ; Saussure, 1916 ; Bergson, « Le Rire », 1900, mots-étiquettes ; Platon, « Gorgias » ; Aristote, vérité-adéquation ; cohérence sans auteur ; définitions de sophisme, mensonge, erreur |
| L10 Connaissance scientifique | Bachelard, 1938, obstacle épistémologique et rupture ; Claude Bernard, 1865 ; Popper, 1934, réfutabilité (cygne noir) ; Copernic, 1543 ; Rabelais, « Pantagruel », 1532, « Science sans conscience n'est que ruine de l'âme » ; faits : anophèle femelle, Aedes de jour, Jenner 1796, éradication de la variole 1980 (OMS) |
| Toutes | Méthode de l'introduction et du paragraphe argumenté (alignée sur L1) ; barèmes des questions rédigées |

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Relecture par un enseignant de philosophie (table ci-dessus) | Aucun enseignant dans le chantier ; les leçons restent en brouillon | Programme `contenus-v3-tous-niveaux` |
| `valider.rb` ne détecte pas une correction qui désigne une proposition par son rang | Hors périmètre (aucun code dans cette vague) | À ouvrir avec la dette « astérisques » de `contenus-3e-francais` |
| Challenger empirique (import en brouillon, captures 390 px et ordinateur) | Pas de base ni de navigateur sur la session de rédaction ; aucune vue modifiée | Avant publication, par l'équipe |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-31 |
| **PR** | #426 (test `rich_text_sanitizer_test.rb:33` rouge : décision attendue) |
