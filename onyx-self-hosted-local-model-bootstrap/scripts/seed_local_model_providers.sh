#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-onyx-relational_db-1}"

docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres <<'SQL'
BEGIN;

INSERT INTO llm_provider (name, api_base, provider, is_public, is_auto_mode, is_default_provider, default_model_name, is_default_vision_provider, default_vision_model)
VALUES
  ('Ollama', 'http://host.docker.internal:11434', 'ollama_chat', true, false, true, 'qwen3.5:4b', true, 'qwen3-vl:latest'),
  ('LM Studio', 'http://host.docker.internal:1234', 'lm_studio', true, false, false, NULL, false, NULL)
ON CONFLICT (name) DO UPDATE SET
  api_base = EXCLUDED.api_base,
  provider = EXCLUDED.provider,
  is_public = EXCLUDED.is_public,
  is_auto_mode = EXCLUDED.is_auto_mode,
  is_default_provider = EXCLUDED.is_default_provider,
  default_model_name = EXCLUDED.default_model_name,
  is_default_vision_provider = EXCLUDED.is_default_vision_provider,
  default_vision_model = EXCLUDED.default_vision_model;

WITH ollama_provider AS (
  SELECT id FROM llm_provider WHERE name = 'Ollama'
), lmstudio_provider AS (
  SELECT id FROM llm_provider WHERE name = 'LM Studio'
)
INSERT INTO model_configuration (llm_provider_id, name, is_visible, max_input_tokens, supports_image_input, display_name)
VALUES
  ((SELECT id FROM ollama_provider), 'glm-4.7-flash:latest', true, 202752, false, 'Glm 4.7 Flash'),
  ((SELECT id FROM ollama_provider), 'gpt-oss:20b', true, 131072, false, 'Gpt Oss 20B'),
  ((SELECT id FROM ollama_provider), 'huihui_ai/hy-mt1.5-abliterated:1.8b', true, 262144, false, 'Huihui Ai Hy Mt1.5 Abliterated 1.8B'),
  ((SELECT id FROM ollama_provider), 'qwen3-vl:latest', true, 262144, true, 'Qwen 3 Vl'),
  ((SELECT id FROM ollama_provider), 'qwen3.5:4b', true, 262144, false, 'Qwen 3.5 4B'),
  ((SELECT id FROM lmstudio_provider), 'qwen3.5-4b-uncensored-hauhaucs-aggressive@q4_k_m', true, 262144, true, 'Qwen3.5 4B Uncensored HauhauCS Aggressive'),
  ((SELECT id FROM lmstudio_provider), 'qwen3.6-35b-a3b-claude-4.6-opus-reasoning-distilled', true, 262144, false, 'Qwen3.6 35B A3B Claude 4.6 Opus Reasoning Distilled'),
  ((SELECT id FROM lmstudio_provider), 'qwen/qwen3.6-35b-a3b', true, 262144, true, 'Qwen3.6 35B A3B'),
  ((SELECT id FROM lmstudio_provider), 'unsloth/glm-4.7-flash', true, 202752, false, 'GLM 4.7 Flash'),
  ((SELECT id FROM lmstudio_provider), 'google/gemma-4-31b', true, 262144, true, 'Gemma 4 31B'),
  ((SELECT id FROM lmstudio_provider), 'unsloth/qwen3.5-9b', true, 262144, true, 'Qwen3.5 9B'),
  ((SELECT id FROM lmstudio_provider), 'openai/gpt-oss-120b', true, 131072, false, 'GPT-OSS 120B'),
  ((SELECT id FROM lmstudio_provider), 'qwen/qwen3-vl-8b', true, 262144, true, 'Qwen3 VL 8B'),
  ((SELECT id FROM lmstudio_provider), 'google/gemma-3-4b', true, 131072, true, 'Gemma 3 4B')
ON CONFLICT (llm_provider_id, name) DO UPDATE SET
  is_visible = EXCLUDED.is_visible,
  max_input_tokens = EXCLUDED.max_input_tokens,
  supports_image_input = EXCLUDED.supports_image_input,
  display_name = EXCLUDED.display_name;

INSERT INTO llm_model_flow (llm_model_flow_type, is_default, model_configuration_id)
SELECT 'CHAT', CASE WHEN lp.name = 'Ollama' AND mc.name = 'qwen3.5:4b' THEN true ELSE false END, mc.id
FROM model_configuration mc
JOIN llm_provider lp ON lp.id = mc.llm_provider_id
ON CONFLICT (llm_model_flow_type, model_configuration_id) DO UPDATE SET is_default = EXCLUDED.is_default;

INSERT INTO llm_model_flow (llm_model_flow_type, is_default, model_configuration_id)
SELECT 'VISION', CASE WHEN lp.name = 'Ollama' AND mc.name = 'qwen3-vl:latest' THEN true ELSE false END, mc.id
FROM model_configuration mc
JOIN llm_provider lp ON lp.id = mc.llm_provider_id
WHERE mc.supports_image_input = true
ON CONFLICT (llm_model_flow_type, model_configuration_id) DO UPDATE SET is_default = EXCLUDED.is_default;

UPDATE llm_model_flow SET is_default = false WHERE llm_model_flow_type = 'CHAT' AND model_configuration_id NOT IN (
  SELECT mc.id FROM model_configuration mc JOIN llm_provider lp ON lp.id = mc.llm_provider_id WHERE lp.name = 'Ollama' AND mc.name = 'qwen3.5:4b'
);
UPDATE llm_model_flow SET is_default = false WHERE llm_model_flow_type = 'VISION' AND model_configuration_id NOT IN (
  SELECT mc.id FROM model_configuration mc JOIN llm_provider lp ON lp.id = mc.llm_provider_id WHERE lp.name = 'Ollama' AND mc.name = 'qwen3-vl:latest'
);

COMMIT;
SQL
