#!/usr/bin/env node

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const API_ROOT = "https://api.search.brave.com/res/v1";
const API_KEY = process.env.BRAVE_API_KEY;
const RAW_PROXY =
  process.env.ALL_PROXY ||
  process.env.all_proxy ||
  process.env.HTTPS_PROXY ||
  process.env.https_proxy ||
  process.env.HTTP_PROXY ||
  process.env.http_proxy ||
  "";
const execFileAsync = promisify(execFile);

if (!API_KEY) {
  console.error("Error: BRAVE_API_KEY environment variable is required");
  process.exit(1);
}

const server = new Server(
  {
    name: "cangyao/brave-lmstudio-mcp",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  },
);

const tools = [
  {
    name: "brave_web_search",
    description:
      "Brave 网页搜索。适合通用联网检索、新闻背景、网页资料汇总。支持 freshness、分页、extra_snippets、goggles，以及可选 rich data 拉取。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "搜索词" },
        count: { type: "number", description: "结果数，1-20，默认 10" },
        offset: { type: "number", description: "页偏移，0-9，默认 0" },
        country: { type: "string", description: "国家代码，如 US、CN、JP" },
        search_lang: { type: "string", description: "搜索语言，如 en、zh-hans" },
        ui_lang: { type: "string", description: "界面语言，如 en-US、zh-CN" },
        safesearch: {
          type: "string",
          description: "off、moderate、strict",
        },
        freshness: {
          type: "string",
          description: "pd、pw、pm、py，或自定义日期区间",
        },
        extra_snippets: {
          type: "boolean",
          description: "是否请求额外摘要片段",
        },
        summary: {
          type: "boolean",
          description: "是否在响应中请求 summarizer key",
        },
        include_rich_data: {
          type: "boolean",
          description: "是否自动拉取 rich callback 数据",
        },
        goggles: {
          oneOf: [
            { type: "string" },
            { type: "array", items: { type: "string" } },
          ],
          description: "单个或多个 goggles URL / inline 定义",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_news_search",
    description:
      "Brave 新闻搜索。适合近期新闻、媒体监控、时效性话题。支持 freshness、分页、extra_snippets、goggles。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "新闻搜索词" },
        count: { type: "number", description: "结果数，1-50，默认 10" },
        offset: { type: "number", description: "页偏移，0-9，默认 0" },
        country: { type: "string", description: "国家代码" },
        search_lang: { type: "string", description: "搜索语言" },
        ui_lang: { type: "string", description: "界面语言" },
        safesearch: {
          type: "string",
          description: "off、moderate、strict",
        },
        freshness: {
          type: "string",
          description: "pd、pw、pm、py，或自定义日期区间",
        },
        extra_snippets: {
          type: "boolean",
          description: "是否请求额外摘要片段",
        },
        goggles: {
          oneOf: [
            { type: "string" },
            { type: "array", items: { type: "string" } },
          ],
          description: "单个或多个 goggles URL / inline 定义",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_video_search",
    description:
      "Brave 视频搜索。适合教程、讲座、媒体片段、站点视频内容发现。支持 freshness、分页、spellcheck。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "视频搜索词" },
        count: { type: "number", description: "结果数，1-50，默认 10" },
        offset: { type: "number", description: "页偏移，0-9，默认 0" },
        country: { type: "string", description: "国家代码" },
        search_lang: { type: "string", description: "搜索语言" },
        ui_lang: { type: "string", description: "界面语言" },
        safesearch: {
          type: "string",
          description: "off、moderate、strict",
        },
        freshness: {
          type: "string",
          description: "pd、pw、pm、py，或自定义日期区间",
        },
        spellcheck: {
          type: "boolean",
          description: "是否启用拼写纠正，默认 true",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_image_search",
    description:
      "Brave 图片搜索。适合图片检索、素材发现、视觉参考。默认严格 safesearch，count 最大 200。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "图片搜索词" },
        count: { type: "number", description: "结果数，1-200，默认 20" },
        country: { type: "string", description: "国家代码，或 ALL" },
        search_lang: { type: "string", description: "搜索语言" },
        safesearch: {
          type: "string",
          description: "off 或 strict，默认 strict",
        },
        spellcheck: {
          type: "boolean",
          description: "是否启用拼写纠正，默认 true",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_spellcheck",
    description:
      "Brave 拼写纠正。适合在正式搜索前做 typo 修正或 Did you mean 提示。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "待纠正文本" },
        country: { type: "string", description: "国家代码，默认 US" },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_suggest",
    description:
      "Brave 自动补全建议。适合搜索框提示、热门补全和实体联想。支持 rich suggestions。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "输入前缀" },
        country: { type: "string", description: "国家代码，默认 US" },
        count: { type: "number", description: "建议数，默认 10" },
        rich: {
          type: "boolean",
          description: "是否请求 richer suggestion metadata",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_place_search",
    description:
      "Brave 地点搜索。适合门店、景点、POI、附近地点发现。支持坐标或 location 字符串、radius、探索模式。",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "要找什么，可省略用于 explore mode",
        },
        latitude: { type: "number", description: "纬度，需与 longitude 配套" },
        longitude: { type: "number", description: "经度，需与 latitude 配套" },
        location: {
          type: "string",
          description: "位置字符串，如 san francisco ca united states",
        },
        radius: { type: "number", description: "搜索半径，单位米" },
        count: { type: "number", description: "结果数，1-50，默认 20" },
        country: { type: "string", description: "国家代码，默认 US" },
        search_lang: { type: "string", description: "搜索语言，默认 en" },
        ui_lang: { type: "string", description: "界面语言，默认 en-US" },
        units: {
          type: "string",
          description: "metric 或 imperial，默认 metric",
        },
        safesearch: {
          type: "string",
          description: "off、moderate、strict，默认 strict",
        },
        spellcheck: {
          type: "boolean",
          description: "是否启用拼写纠正，默认 true",
        },
      },
      required: [],
    },
  },
  {
    name: "brave_place_details",
    description:
      "用 POI ids 拉取地点详情和 AI 描述。id 来自 brave_place_search 或带 location enrichments 的 web search，8 小时左右过期。",
    inputSchema: {
      type: "object",
      properties: {
        ids: {
          type: "array",
          items: { type: "string" },
          description: "最多 20 个 POI ids",
        },
        include_descriptions: {
          type: "boolean",
          description: "是否同时拉取 AI 描述，默认 true",
        },
        search_lang: { type: "string", description: "搜索语言" },
        ui_lang: { type: "string", description: "界面语言" },
        units: { type: "string", description: "metric 或 imperial" },
      },
      required: ["ids"],
    },
  },
  {
    name: "brave_local_search",
    description:
      "兼容式本地搜索入口。给一个自然语言地点查询，内部走 web location + pois + descriptions 两段式流程。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "如 pizza near central park" },
        count: { type: "number", description: "结果数，1-20，默认 5" },
        search_lang: { type: "string", description: "搜索语言，默认 en" },
        ui_lang: { type: "string", description: "界面语言" },
        units: { type: "string", description: "metric 或 imperial" },
      },
      required: ["query"],
    },
  },
  {
    name: "brave_summarizer_search",
    description:
      "Brave Summarizer 两段式摘要。直接传 query 即可自动先做 web search(summary=1) 再取摘要；也可直接传 key。该 API 已被 Brave 标记为 deprecated，且可能需要旧 Pro AI 计划。",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "要总结的问题或搜索词" },
        key: {
          type: "string",
          description: "已拿到的 summarizer key。传了它就跳过第一步 web search。",
        },
        country: { type: "string", description: "国家代码" },
        search_lang: { type: "string", description: "搜索语言" },
        ui_lang: { type: "string", description: "界面语言" },
        safesearch: { type: "string", description: "off、moderate、strict" },
        entity_info: {
          type: "boolean",
          description: "是否返回实体信息",
        },
        inline_references: {
          type: "boolean",
          description: "是否开启内联引用标记",
        },
      },
      required: [],
    },
  },
];

function clampNumber(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) {
    return fallback;
  }
  return Math.max(min, Math.min(max, n));
}

function normalizeArray(value) {
  if (value == null) {
    return [];
  }
  return Array.isArray(value) ? value : [value];
}

function buildParams(input) {
  const params = new URLSearchParams();
  for (const [key, rawValue] of Object.entries(input)) {
    if (rawValue == null || rawValue === "") {
      continue;
    }
    if (Array.isArray(rawValue)) {
      for (const item of rawValue) {
        if (item != null && item !== "") {
          params.append(key, String(item));
        }
      }
      continue;
    }
    if (typeof rawValue === "boolean") {
      params.set(key, rawValue ? "true" : "false");
      continue;
    }
    params.set(key, String(rawValue));
  }
  return params;
}

function normalizeProxyUrl(rawProxy) {
  if (!rawProxy) {
    return "";
  }
  const trimmed = String(rawProxy).trim();
  if (trimmed.startsWith("socks://")) {
    return `socks5h://${trimmed.slice("socks://".length).replace(/\/+$/, "")}`;
  }
  return trimmed.replace(/\/+$/, "");
}

async function braveGet(path, paramsInput) {
  const params = buildParams(paramsInput);
  const url = `${API_ROOT}${path}?${params.toString()}`;
  const normalizedProxy = normalizeProxyUrl(RAW_PROXY);
  const curlArgs = [
    "--ipv4",
    "--silent",
    "--show-error",
    "--location",
    "--compressed",
    "--retry",
    "2",
    "--retry-delay",
    "1",
    "--retry-all-errors",
    "--retry-connrefused",
    "--max-time",
    "20",
    "--connect-timeout",
    "8",
    "--write-out",
    "\n%{http_code}",
    "--header",
    "Accept: application/json",
    "--header",
    `X-Subscription-Token: ${API_KEY}`,
  ];

  if (normalizedProxy) {
    curlArgs.push("--proxy", normalizedProxy);
  }

  curlArgs.push(url);
  const { stdout, stderr } = await execFileAsync(
    "curl",
    curlArgs,
    {
      maxBuffer: 8 * 1024 * 1024,
      env: {
        ...process.env,
        ALL_PROXY: "",
        all_proxy: "",
        HTTPS_PROXY: "",
        https_proxy: "",
        HTTP_PROXY: "",
        http_proxy: "",
      },
    },
  ).catch((error) => {
    const detail = error?.stderr?.trim() || error?.message || String(error);
    throw new Error(`Brave API transport error via curl: ${detail}`);
  });

  const splitAt = stdout.lastIndexOf("\n");
  if (splitAt === -1) {
    throw new Error(`Brave API transport returned malformed response for ${path}`);
  }
  const text = stdout.slice(0, splitAt);
  const statusCode = Number(stdout.slice(splitAt + 1).trim());
  if (!Number.isFinite(statusCode)) {
    throw new Error(`Brave API transport returned invalid status for ${path}`);
  }

  if (statusCode < 200 || statusCode >= 300) {
    let detail = text;
    try {
      const parsed = JSON.parse(text);
      if (parsed?.error?.code || parsed?.error?.detail) {
        detail = `${parsed.error.code ?? "UNKNOWN"}: ${parsed.error.detail ?? text}`;
      }
    } catch {
      // Keep raw body when it is not valid JSON.
    }
    throw new Error(`Brave API error: ${statusCode}\n${detail}`);
  }

  if (stderr?.trim()) {
    console.error(`curl stderr (${path}): ${stderr.trim()}`);
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`Brave API returned non-JSON response from ${path}: ${text}`);
  }
}

async function webSearch(args) {
  const response = await braveGet("/web/search", {
    q: args.query,
    count: clampNumber(args.count, 1, 20, 10),
    offset: clampNumber(args.offset, 0, 9, 0),
    country: args.country,
    search_lang: args.search_lang,
    ui_lang: args.ui_lang,
    safesearch: args.safesearch,
    freshness: args.freshness,
    extra_snippets: args.extra_snippets,
    summary: args.summary ? 1 : undefined,
    enable_rich_callback: args.include_rich_data ? 1 : undefined,
    goggles: normalizeArray(args.goggles),
  });

  let richData = null;
  if (args.include_rich_data && response.rich?.hint?.callback_key) {
    richData = await braveGet("/web/rich", {
      callback_key: response.rich.hint.callback_key,
    });
  }

  return {
    endpoint: "/web/search",
    query: response.query ?? null,
    web: response.web ?? null,
    locations: response.locations ?? null,
    videos: response.videos ?? null,
    infobox: response.infobox ?? null,
    discussions: response.discussions ?? null,
    faq: response.faq ?? null,
    summarizer: response.summarizer ?? null,
    rich: response.rich ?? null,
    richData,
  };
}

async function newsSearch(args) {
  return braveGet("/news/search", {
    q: args.query,
    count: clampNumber(args.count, 1, 50, 10),
    offset: clampNumber(args.offset, 0, 9, 0),
    country: args.country,
    search_lang: args.search_lang,
    ui_lang: args.ui_lang,
    safesearch: args.safesearch,
    freshness: args.freshness,
    extra_snippets: args.extra_snippets,
    goggles: normalizeArray(args.goggles),
  });
}

async function videoSearch(args) {
  return braveGet("/videos/search", {
    q: args.query,
    count: clampNumber(args.count, 1, 50, 10),
    offset: clampNumber(args.offset, 0, 9, 0),
    country: args.country,
    search_lang: args.search_lang,
    ui_lang: args.ui_lang,
    safesearch: args.safesearch,
    freshness: args.freshness,
    spellcheck: args.spellcheck,
  });
}

async function imageSearch(args) {
  return braveGet("/images/search", {
    q: args.query,
    count: clampNumber(args.count, 1, 200, 20),
    country: args.country,
    search_lang: args.search_lang,
    safesearch: args.safesearch,
    spellcheck: args.spellcheck,
  });
}

async function spellcheck(args) {
  return braveGet("/spellcheck/search", {
    q: args.query,
    country: args.country ?? "US",
  });
}

async function suggest(args) {
  return braveGet("/suggest/search", {
    q: args.query,
    country: args.country ?? "US",
    count: clampNumber(args.count, 1, 20, 10),
    rich: args.rich,
  });
}

async function placeSearch(args) {
  if ((args.latitude == null) !== (args.longitude == null)) {
    throw new Error("latitude 和 longitude 必须成对提供");
  }
  return braveGet("/local/place_search", {
    q: args.query,
    latitude: args.latitude,
    longitude: args.longitude,
    location: args.location,
    radius: args.radius,
    count: clampNumber(args.count, 1, 50, 20),
    country: args.country,
    search_lang: args.search_lang,
    ui_lang: args.ui_lang,
    units: args.units,
    safesearch: args.safesearch,
    spellcheck: args.spellcheck,
  });
}

async function placeDetails(args) {
  const ids = normalizeArray(args.ids).slice(0, 20);
  if (ids.length === 0) {
    throw new Error("ids 不能为空");
  }

  const [pois, descriptions] = await Promise.all([
    braveGet("/local/pois", {
      ids,
      search_lang: args.search_lang,
      ui_lang: args.ui_lang,
      units: args.units,
    }),
    args.include_descriptions === false
      ? Promise.resolve(null)
      : braveGet("/local/descriptions", { ids }),
  ]);

  return {
    ids,
    pois,
    descriptions,
  };
}

async function localSearch(args) {
  const web = await braveGet("/web/search", {
    q: args.query,
    search_lang: args.search_lang ?? "en",
    ui_lang: args.ui_lang,
    result_filter: "locations",
    count: clampNumber(args.count, 1, 20, 5),
  });
  const ids = (web.locations?.results ?? [])
    .map((item) => item.id)
    .filter(Boolean)
    .slice(0, 20);

  if (ids.length === 0) {
    return {
      query: web.query ?? null,
      locations: [],
      message: "没有返回 location ids，已回退为原始 web location 结果。",
      raw: web.locations ?? null,
    };
  }

  const details = await placeDetails({
    ids,
    include_descriptions: true,
    search_lang: args.search_lang,
    ui_lang: args.ui_lang,
    units: args.units,
  });

  return {
    query: web.query ?? null,
    ids,
    summary: {
      requestedCount: clampNumber(args.count, 1, 20, 5),
      returnedLocations: ids.length,
    },
    seedLocations: web.locations ?? null,
    details,
  };
}

async function summarizerSearch(args) {
  let key = args.key;
  let webSeed = null;

  if (!key) {
    if (!args.query) {
      throw new Error("必须提供 query 或 key 之一");
    }
    webSeed = await braveGet("/web/search", {
      q: args.query,
      summary: 1,
      country: args.country,
      search_lang: args.search_lang,
      ui_lang: args.ui_lang,
      safesearch: args.safesearch,
    });
    key = webSeed.summarizer?.key;
    if (!key) {
      throw new Error("当前查询没有返回 summarizer key。可能是该查询不支持摘要，或你的 Brave plan 不包含此能力。");
    }
  }

  const summary = await braveGet("/summarizer/search", {
    key,
    entity_info: args.entity_info ? 1 : undefined,
    inline_references: args.inline_references ? "true" : undefined,
  });

  return {
    note: "Brave 文档已将 Summarizer Search 标记为 deprecated，建议后续优先看 Answers API。",
    key,
    webSeed,
    summary,
  };
}

async function callTool(name, args) {
  switch (name) {
    case "brave_web_search":
      return webSearch(args);
    case "brave_news_search":
      return newsSearch(args);
    case "brave_video_search":
      return videoSearch(args);
    case "brave_image_search":
      return imageSearch(args);
    case "brave_spellcheck":
      return spellcheck(args);
    case "brave_suggest":
      return suggest(args);
    case "brave_place_search":
      return placeSearch(args);
    case "brave_place_details":
      return placeDetails(args);
    case "brave_local_search":
      return localSearch(args);
    case "brave_summarizer_search":
      return summarizerSearch(args);
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    const { name, arguments: args } = request.params;
    const result = await callTool(name, args ?? {});
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
      isError: false,
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Brave LM Studio MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error running Brave LM Studio MCP Server:", error);
  process.exit(1);
});
