# UDR-0106 : Le bloc « Code d'établissement » de la fiche dit quand le code a changé pour la dernière fois
<!-- index
titre: Le bloc « Code d'établissement » de la fiche dit quand le code a changé pour la dernière fois
statut: Accepté
adr-lie: [0096](../adr/0096-regeneration-des-codes-d-etablissement-en-masse-par-un-job.md)
problematique: Ligne « Changé le 16 octobre 2026 » sous le code, depuis `school_code_rotated_at` (unitaire ou en masse), absente si le code n'a jamais changé ; re-rendue avec l'en-tête après une régénération unitaire.
-->

| | |
|---|---|
| **Statut** | Accepté *(porteur, 2026-10-16 : chantier gardé et élargi aux liens des classes)* |
| **Date** | 2026-10-16 |
| **Chantier** | [`docs/chantiers/regeneration-codes-en-masse`](../../chantiers/regeneration-codes-en-masse/prd.md) — RM-13 |
| **ADR lié** | ADR-0096 |
| **Remplacé par** | — |

---

## 1. Contexte

Après une régénération de masse, personne n'est prévenu (memo, Q3). Quand une direction appelle l'équipe parce que « le code ne marche pas », l'équipe ouvre la fiche : elle voit le code actuel, mais rien ne lui dit que celui de la direction est périmé. La date existe déjà en base (`schools.school_code_rotated_at`, ADR-0057) et n'est affichée nulle part.

## 2. Décision

- Une ligne discrète **sous le code** donne la date du dernier changement, quelle qu'en soit l'origine (fiche ou masse). Elle ne dit pas l'origine : le journal d'audit la garde.
- Un code jamais changé n'affiche **rien** (pas de « Jamais changé ») : c'est le cas de la plupart des établissements, et la ligne n'a de sens que pour expliquer un code périmé.

## 3. Règles d'implémentation

> Cette section est un **contrat d'exécution**. Un agent l'applique littéralement.

**Structure**

- Fichier : `app/views/teams/schools/_header.html.erb`, bloc `#school_code`, dans la colonne de gauche, **après** `#school_code_value` et **avant** le paragraphe `school_code_hint`.
- Élément : `<p id="school_code_rotated_at" class="mt-1 text-xs text-mute">` contenant `t(".school_code_rotated_at", date: l(school.school_code_rotated_at.to_date, format: :long))` → « Changé le 16 octobre 2026 ».
- Rendu seulement si `school.school_code_rotated_at` est présent.
- Données : `Queries::School::SchoolDetailQuery::Detail` et `Queries::School::SchoolsQuery::Row` gagnent `school_code_rotated_at` (Lot 0) : l'en-tête est rendu par la fiche (`show`) et re-rendu par les streams `school_codes/update`, `schools/update` et `schools/deactivate`, qui lisent `SchoolsQuery#find`.

**Tokens**

- `text-xs text-mute` ; aucune icône, aucun badge.

**Comportement**

- Après « Régénérer le code » sur la fiche, l'en-tête re-rendu montre la date du jour (aucun changement au stream : la query la porte).
- Après une régénération de masse, la fiche ouverte ensuite montre la date ; une fiche déjà ouverte ne se met pas à jour seule.

**États obligatoires**

- Code jamais changé : rien. Code changé : la ligne. Pas d'état de chargement ni d'erreur propre.

**Accessibilité**

- Texte lu dans l'ordre du bloc : libellé, code, date, aide. Contraste de `text-mute` sur fond blanc déjà conforme (tokens existants).
- Téléphone (390 px) : la ligne passe sous le code, sans troncature.

## 4. Conséquences

- La date ne distingue pas un changement unitaire d'un changement de masse : pour le savoir, l'équipe lit le journal d'audit (`report_public_id` présent pour la masse).
- Quand `inscription-direction-sans-code` retirera le code, cette ligne part avec le bloc.
- **Amendement du 2026-10-16 (liens des classes)** : la date du dernier changement d'un lien de classe (`classrooms.link_token_rotated_at`) est enregistrée mais **n'est affichée nulle part** ; le bloc « Lien de la classe » (UDR-0081 §3.6) ne change pas. L'afficher demanderait une UDR sur la page de la classe.
