# ADR-XXXX : Les assistants IA passent par un seul port de modèle de langage, servi par OpenRouter, en tâche de fond, sans conservation des données
<!-- index
titre: Accès aux modèles IA par OpenRouter
statut: Proposé
problematique: comment appeler des modèles de langage externes depuis le domaine sans couplage, sans fuite non maîtrisée de données de mineurs et sans bloquer le serveur
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-11-04 |
| **Chantier** | `docs/chantiers/crm-ecoles` |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Le chantier livre quatre assistants (memo, réponse 8) : briefing avant appel, brouillon de relance WhatsApp, rapport pour la direction, compte rendu dicté. L'accès aux modèles se fait par OpenRouter, qui route vers plusieurs fournisseurs (Gemini, DeepSeek, Kimi…). Le porteur accepte que des données d'élèves partent chez le fournisseur pour le rapport pour la direction (réponse 9) : ce sont des mineurs.

Le code n'a aujourd'hui aucun client HTTP sortant, aucun port de service externe, et aucune trace d'appel externe.

**À vérifier à l'exécution** (la documentation d'OpenRouter n'était pas joignable depuis la session de cadrage : domaine bloqué par le réseau de l'environnement) : le nom exact des réglages de routage qui interdisent la conservation et l'entraînement, la forme d'une entrée audio et ses formats acceptés, les codes d'erreur (quota, crédit). Le lot qui écrit l'adaptateur les lit dans la documentation officielle et les reporte ici, en §4.3, avant de coder.

## 2. Moteurs de décision

1. Aucune donnée de mineur chez un fournisseur qui la garde ou s'en sert pour entraîner.
2. Chaque assistant n'envoie que ce dont il a besoin.
3. Le domaine ne connaît ni HTTP ni OpenRouter : on doit pouvoir changer de fournisseur.
4. Une réponse lente du modèle (plusieurs dizaines de secondes) ne bloque pas un fil Puma.
5. Coût maîtrisé : budget mensuel et quota par personne.
6. Zéro nouvelle gem si la bibliothèque standard suffit.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Appel synchrone dans le contrôleur | Simple | Bloque un fil Puma jusqu'à 60 s ; une fois le délai dépassé, l'erreur est opaque |
| B — Tâche de fond et diffusion Turbo Stream par Action Cable | Temps réel | Ajoute un canal et une souscription à sécuriser ; la page de prévisualisation PR tourne en `async` |
| C — Tâche de fond, résultat stocké, page qui interroge toutes les 2 s (retenue) | Robuste, sans canal, testable ; marche hors ligne et revient | Quelques requêtes d'interrogation |
| D — Gem cliente (`ruby-openai`, `faraday`) | Moins de code | Une dépendance pour un seul point d'appel ; `Net::HTTP` suffit |
| E — Appel direct aux API de chaque fournisseur | Pas d'intermédiaire | Un adaptateur par fournisseur, en 8 jours |

## 4. Décision

> **Nous ajoutons un port `Ports::School::LanguageModelPort` (texte, et audio pour la dictée), servi par un adaptateur `Net::HTTP` vers OpenRouter qui force le routage vers des fournisseurs sans conservation ni entraînement. Chaque appel est une ligne `ai_requests`, exécutée par une tâche de fond et lue par interrogation. Chaque assistant construit son propre contexte minimal ; seul le rapport pour la direction contient des noms d'élèves. Toute sortie est un brouillon que l'humain valide.**

### 4.1 Port

```ruby
# app/domain/ports/school/language_model_port.rb
# complete(purpose:, system:, messages:, audio: nil, json: false) → Shared::Result
#   success(value: { text:, provider:, model:, input_tokens:, output_tokens: })
#   failure(:unavailable | :timeout | :refused | :budget_exhausted)
```

`audio:` vaut `{ bytes:, format: :mp3 | :m4a }`, pour la dictée seulement. `purpose:` vaut `briefing`, `whatsapp_draft`, `director_report` ou `dictation`.

### 4.2 Trace et exécution

Table `ai_requests` : `public_id`, `actor_id`, `school_id`, `purpose`, `status` (`pending`·`succeeded`·`failed`), `error_code`, `provider`, `model`, `input_tokens`, `output_tokens`, `output` (text, chiffrée par `encrypts`), `created_at`, `finished_at`. Le texte envoyé n'est pas gardé.

1. Le contrôleur appelle le use case (`RequestBriefing`…), qui vérifie la policy, le quota (40 par acteur et par jour) et le budget du mois. Il crée la ligne `pending` et met `School::AiRequestJob` en file.
2. La tâche construit le contexte, appelle le port (délai 60 s) et écrit `succeeded` ou `failed`.
3. La page interroge `GET /teams/ai_requests/:public_id` toutes les 2 s, au plus 45 fois. Seul l'acteur auteur de la demande la lit (sinon 404).
4. Purge : `output` est vidé au bout de 7 jours (tâche quotidienne). Le rapport téléchargé est gardé à part, dans le journal de l'école (ADR-XXXX-rapport-direction-en-pdf).

Budget : `LNCLASS_AI_MONTHLY_TOKEN_BUDGET` (somme `input_tokens + output_tokens` du mois). Sans clé `OPENROUTER_API_KEY`, le port répond `:unavailable` et les panneaux le disent.

### 4.3 Requête au fournisseur

- `POST https://openrouter.ai/api/v1/chat/completions`, `Authorization: Bearer`, `timeout` 60 s (ouverture 5 s).
- Routage : **réglage de non-conservation et de non-entraînement toujours posé** (nom exact à reporter ici, voir §1). Si aucun fournisseur ne le respecte pour le modèle demandé, l'appel échoue (`:refused`) : jamais de repli sur un fournisseur qui conserve.
- Modèles : `LNCLASS_AI_TEXT_MODEL` et `LNCLASS_AI_AUDIO_MODEL` (variables d'environnement, choisis par le porteur).

### 4.4 Données envoyées, par assistant

| Assistant | Envoyé | Jamais envoyé |
|---|---|---|
| Briefing | Nom de l'école, DRENA, étape, 20 derniers échanges (type, date, interlocuteur adulte, résultat, note), relances ouvertes, chiffres agrégés (comptes, classes, devoirs et taux de rendu sur 30 j) | Nom d'élève, de parent, note individuelle, numéro de téléphone |
| Brouillon WhatsApp | Nom de l'école, interlocuteur, 5 derniers échanges, motif de la relance, chiffres agrégés | Idem |
| Rapport pour la direction | Chiffres par classe, et **prénom, nom et taux de rendu des élèves à suivre** (rendu < 50 % sur la période, 10 par classe au plus) | Numéro, identifiant, date de naissance, note d'une question |
| Dictée | Le fichier son, et la liste des types, résultats et motifs permis | Toute donnée de l'école |

Les numéros de téléphone sont retirés des notes libres avant l'envoi (`Entities::School::PromptRedactor`, motif `+?\d[\d \-.]{7,}\d`).

### 4.5 Sortie

Le briefing s'affiche seulement. Le brouillon WhatsApp se copie. Le rapport est un brouillon modifiable. La dictée renvoie un JSON validé par le domaine (types et valeurs permis) et ne fait que pré-remplir le formulaire d'échange. Rien n'est écrit dans le journal ni envoyé sans geste humain.

## 5. Conséquences

### 🟢 Positives

- Changer de fournisseur ou de modèle touche un adaptateur ou une variable, pas le domaine.
- Chaque appel est traçable : qui, quelle école, quel usage, quel fournisseur, combien.
- Un fournisseur en panne n'empêche pas le suivi de fonctionner.

### 🔴 Coûts consentis

- Des données de mineurs (noms et taux de rendu) quittent l'infrastructure pour le rapport. La parade est contractuelle (fournisseurs sans conservation) et ne se vérifie qu'à la requête, pas chez le fournisseur. Le cadre légal reste à confirmer par le porteur avant la mise en production (memo, questions ouvertes).
- L'interrogation toutes les 2 s coûte jusqu'à 45 requêtes par appel IA.
- Le port vit dans `school`, son seul client. Un second contexte qui en aura besoin le déplacera.
- Les réglages exacts d'OpenRouter ne sont pas vérifiés au cadrage (§1).

## 6. Notes d'implémentation

```ruby
# app/infrastructure/school/open_router_language_model.rb (lot IA)
# Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 60)
# Le corps porte toujours le réglage de non-conservation (§4.3) ; un test d'adaptateur échoue s'il manque.
```

## 7. Comment vérifier que la décision est respectée

- `test/infrastructure/school/open_router_language_model_test.rb` (sans gem : `Net::HTTP` remplacé par un double dans le test) : le corps de chaque requête porte le réglage de non-conservation ; 429, 402, 5xx et délai donnent la bonne erreur.
- `test/domain/use_cases/school/request_briefing_test.rb` : le contexte envoyé au port simulé ne contient aucun nom d'élève de l'école d'essai.
- `test/domain/use_cases/school/*_quota_test.rb` : le 41e appel du jour et le budget dépassé n'appellent pas le port.
- `test/controllers/teams/ai_requests_controller_test.rb` : un autre acteur reçoit 404.
- `test/domain/domain_purity_test.rb` : `Net::HTTP` n'apparaît pas sous `app/domain/`.
