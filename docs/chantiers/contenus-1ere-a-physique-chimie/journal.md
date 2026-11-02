# Journal — Leçons de Physique-Chimie de 1ère A

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-11-02 | Une leçon écrite une fois, déclinée en A1 et A2 par `series_name`. | Pas de série « A » en 1ère dans le référentiel. | Non |
| 2026-11-02 | Aucune sorte nouvelle de figure. | Les situations s'y ramènent. | Non |
| 2026-11-02 | La section « Modèles et sobriété » citée dans la demande est absente de `prompt-vague.md` sur Develop : règles de CLAUDE.md appliquées (Sonnet pour rédiger, Opus pour relire). | Section introuvable | Non |

## À faire valider par un enseignant

Voir les lignes P4 du [journal du programme](../contenus-v3-tous-niveaux/journal.md).

## Relecture indépendante

- Leçons 1 et 6 : 1 phrase corrigée chacune ; calculs justes.
- Leçons 2 et 3 : 4 défauts (HCl, 70 kg au lieu de 700 kg, espaces dans les équations, « l'hexène ») ; calculs justes.
- Leçons 4 et 7 : 3 formulations (pile de jouet, « une demi-seconde », étymologie de stator) ; calculs justes.
- Leçons 5 et 8 : butane −1 °C corrigé en −0,5 °C ; 7 autres défauts (explication fausse sur Cu et l'acide, catalyseur du vapocraquage, barème, mise en forme) ; calculs justes.
- Leçons 9 et 10 : la 10 supposait W = ±F×d sans cosinus alors que la 9 enseigne cos α : 10 chaînes alignées sur la 9.

## Ce qui a dérapé

- Ruby 3.3.6 sur la machine alors que `valider.rb` utilise `it` (Ruby 3.4) : validation faite avec 3.4.9. `valider.rb` ne contrôle toujours pas `practice`.
- La section « Modèles et sobriété » du prompt-vague citée dans la demande est absente de Develop.

## Dette laissée derrière

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Challenger empirique (import en brouillon) non fait | Aucun écran modifié | Avant publication |
