# Reprise du chantier sur Claude Code on the web

> Écrit le 2026-09-26 vers 14 h par l'orchestrateur local, au moment où le porteur déplace la suite sur claude.ai/code.
> À lire en entier avant de lancer une session web. Le plan (`../plan.md`) et le PRD (`../prd.md`) restent la référence.

## 1. Où en est le chantier

Branche du chantier : **`feature/boucle-pedagogique`**. Elle part de `Develop` et reçoit chaque lot par fusion. PR brouillon vers `Develop` : #16.

**Lots fusionnés dans le chantier** : 0a, 0b, 0d, 0e, R1, R2, R3, S1, S2, S3, B1, B2, B3, B4, B5, B7, B8, A1, A2, A3, A4, C1, C2, C3, D1, D2, D3, D4, D5, I1, I2, I3.

**Lot commencé, sur sa propre branche, NON fusionné** :

| Lot | Branche | État | Ce qui reste |
|---|---|---|---|
| B6 — Accueil équipe | `feature/boucle-pedagogique-lot-b6` | Fini : 4 commits, 22 tests verts, UDR-0018 | **Ne pas fusionner avant le correctif CSP (§3).** Avec le vrai `Teams::HomesController`, `test/system/teams/essential_management_test.rb` échoue (1 échec, 1 erreur). |

**Lots pas encore commencés** : D6, D7, D8, puis le **Lot E** (preuve de bout en bout, en dernier).

- D6 et D7 dépendent de D5, déjà fusionné. Ils réutilisent la bascule d'assignation de D5 (`classroom/assignments/_toggle`, contrat dans `docs/decisions/udr/0028-*.md` §3) sans la modifier.
- D8 ne dépend que du socle.
- D6, D7 et D8 touchent des fichiers disjoints : ils peuvent tourner en parallèle.

## 2. Comment lancer un lot sur le web

Une session web = un lot. Dans claude.ai/code, choisir le dépôt `Lnclassapp/App.Lnclassapp`, puis coller :

```
Tu travailles sur le dépôt Lnclassapp/App.Lnclassapp, branche de départ feature/boucle-pedagogique.
Crée (ou reprends si elle existe déjà sur GitHub) la branche feature/boucle-pedagogique-lot-<xx>.
Lis docs/chantiers/boucle-pedagogique/reprise/README.md, puis exécute à la lettre
docs/chantiers/boucle-pedagogique/reprise/brief-lot.md en remplaçant <LOT> par <XX>.
Consigne propre au lot : voir le §4 du README de reprise.
```

La session livre une **PR de sa branche vers `feature/boucle-pedagogique`** (jamais vers `Develop`). Quand la CI de cette PR est verte, on la fusionne dans le chantier. Seule la PR #16 (chantier → `Develop`) va vers `Develop`.

**Règles qui ne changent pas** : jamais de commit direct sur `Develop`, `Staging` ou `main` ; jamais `SKIP_HOOKS` ni `--no-verify` ; aucune action Railway sans le porteur ; la clé maître n'est jamais committée ; un refus d'accès ne se contourne pas.

## 3. Première tâche : le correctif CSP (socle, avant B6)

**Le bogue.** Le nonce CSP est aléatoire à chaque requête (`config/initializers/content_security_policy.rb`, ADR-0049). Une navigation Turbo Drive garde le document, donc la CSP de la première page, mais Turbo remplace `meta[name=csp-nonce]` par celui de la nouvelle page. Trix lit ce meta pour ses `<style>` en ligne : ils sont refusés (`style-src-elem`), l'éditeur perd son habillage et son champ de lien caché intercepte les clics. Parcours cassé : se connecter → accueil équipe → « Nouveau cours ».

**Pourquoi on ne l'a pas vu plus tôt.** Le stand-in de `Teams::HomesController` rendait sans `formats: :html`, ce qui forçait un rechargement complet et donnait un nonce neuf.

**Recommandation de l'orchestrateur, à faire valider par le porteur (amendement de l'ADR-0049)** :
1. Nonce stable par session : `config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }` (forme standard de Rails avec Turbo).
2. Rechargement complet après la connexion et le second facteur, parce que la session est renouvelée à la connexion et change donc le nonce.
3. Un test système : connexion → accueil équipe → « Nouveau cours » → la barre de Trix est habillée et le texte se saisit.

Branche conseillée : `fix/boucle-pedagogique-csp-turbo`, PR vers `feature/boucle-pedagogique`. B6 se fusionne ensuite.

## 4. Consignes propres aux lots restants

- **B6** : le lien « Inviter un membre » (Lot B7) n'apparaît qu'aux admins (via `Policies::Identity::InviteTeamPolicy`). Les tests système qui remplaçaient `Teams::HomesController` doivent rester verts avec le vrai.
- **A3** (fait) : l'élève voit le code de sa classe, jamais la liste nominative des autres élèves.
- **D6, D7** : réutiliser `classroom/assignments/_toggle` tel quel (locals stricts : `classroom_public_id:`, `assignable_type:`, `assignable_key:`, `assignable_name:`, `assignment_public_id:`).
- **D8** : pas de consigne en plus du plan.
- **D4 (fait) et B8 (fait)** : le bouton « code de récupération » de la page de classe poste vers `account_pin_recovery_codes_path(<public_id de l'élève>)`, contrat dans l'UDR-0020 §4 ; le vérifier au Lot E.
- **Lot E** : c'est l'orchestrateur qui le mène, une fois tous les lots fusionnés et la CI verte.

## 5. Après les lots

1. **Chantier `/optimize` des imports de contenu.** I1 (≈ 100-120 s), I2 (133-163 s) et I3 (200 s) dépassent le budget de 120 s de l'ADR-0039. Deux tiers du temps d'écriture partent dans la construction Ruby du SQL de `ContentTreeWriter#insert_all!`, surtout les horodatages `TimeWithZone`. Pistes : horodatages posés en SQL, insert brut ou `COPY` par tranches, validateur de schéma plus rapide, mesure avec YJIT, module commun des nœuds de contenu I1/I2/I3, clé de doublon des exercices (`normalize` ou `compact`).
2. **Index des UDR.** Les UDR 0009 à 0040 sont « Proposé » et absentes de l'index `docs/decisions/udr/README.md` : les indexer à leur acceptation par le porteur.
3. **Preuve de la V1** (Lot E), mise à jour du corps de la PR #16, fusion vers `Develop`.

## 6. Questions ouvertes pour le porteur

Elles sont toutes dans [`notes-orchestrateur.md`](notes-orchestrateur.md), avec la recommandation appliquée en attendant. Les plus structurantes :

- Seuil de résolution d'une lacune : 50 % (ADR-0043, ce que fait le code) ou 70 % (PRD AS-11).
- Correctif CSP (§3) : amendement de l'ADR-0049.
- Acceptation des UDR proposées pendant le chantier.
