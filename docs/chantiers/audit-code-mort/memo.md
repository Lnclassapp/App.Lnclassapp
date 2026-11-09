# Memo — Audit code mort (M-001 à M-004)

| | |
|---|---|
| **Type de cycle** | refactoring |
| **Statut** | livré (PR vers `Develop`) |
| **Ouvert le** | 2026-11-08 |
| **Branche** | `fix/audit-code-mort` |

## Motif

L'[audit du 2026-11-08](../../audits/2026-11-08-bugs-code-mort.md) relève du code jamais appelé. Coût payé : `NumericAnswer` porte une tolérance fixe qui contredit `questions.numeric_tolerance` (piège si on le branche) ; les autres brouillent la lecture et la menace écrite.

## Périmètre gelé

- Suppression, avec leur test : `Entities::Catalog::NumericAnswer` (M-001), `Policies::Catalog::ManageContentImagesPolicy` (M-002), `UseCases::Assessment::UploadQuestionImage` (M-003).
- Suppression de 10 clés I18n `fr` (M-004), preuve ci-dessous : `catalog.courses.show.{content_title,prepare_intro,due_today}`, `catalog.courses.sheets.{choice_true,choice_false}`, `classroom.classroom_courses.show.{prepare_intro,due_today}`, `teams.answer_keys.show.accepted_alternative`, `identity.profiles.information.edit_materials_label`, `errors.codes.rate_limited_daily`.
- Deux entrées devenues orphelines de l'allowlist de `test/i18n/locale_files_test.rb` (`…show.prepare_intro`).

## Hors périmètre

Aucun changement de comportement observable. M-005 (routes) : non touché, il faut d'abord les journaux d'accès.

## Preuves

- M-001/M-002 : aucune référence hors fichier et test (`grep` sur `app config lib db test script`). `menace.md` d'`images-dans-les-cours` cite encore la policy : ce chantier est livré, la menace est un instantané, non réécrite (note dans son `journal.md`).
- M-003 : aucun chantier ne l'attend. `images-dans-les-cours` (livré) le planifiait au Lot C mais la livraison n'a ni contrôleur d'envoi ni route ; les autres chantiers qui parlent d'images de question sont livrés ou en « preuve » (correctifs de stabilité).
- M-004 : pour chaque clé, usage direct, relatif (`t(".k")`) et dynamique cherchés dans `app config lib` ; les 10 clés ci-dessus n'ont ni l'un ni l'autre (les motifs `#{…}` des vues voisines — `sheets.#{kind}_title`, `errors.codes.#{result.code}` limité à `Result::ERROR_CODES` — ne peuvent pas les produire).
