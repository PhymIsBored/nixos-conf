import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Search the web using a custom SearXNG instance",
  args: {
    query: tool.schema.string().describe("Search query"),
  },
  async execute(args) {
    const url = `https://searxng.phym.dev/search?q=${encodeURIComponent(args.query)}&format=json`
    
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 15000)
    
    let res: Response
    try {
      res = await fetch(url, { signal: controller.signal })
    } finally {
      clearTimeout(timeout)
    }
    
    if (!res.ok) {
      return `SearXNG search failed with status ${res.status}: ${res.statusText}`
    }
    
    const data: any = await res.json()
    
    // Check for SearXNG API errors
    if (data.error) {
      return `SearXNG error: ${typeof data.error === "string" ? data.error : JSON.stringify(data.error)}`
    }
    
    const results = (data.results || []).map((r: any) => ({
      title: r.title || "",
      url: r.url || "",
      content: r.content || "",
    }))
    
    // Include infoboxes (direct answers/knowledge graph data)
    const infoboxes = (data.infoboxes || [])
      .map((ib: any) => ib.content || ib.text || "")
      .filter(Boolean)
    
    // Include suggestions for follow-up
    const suggestions = data.suggestions || []
    
    let output = JSON.stringify(results, null, 2)
    
    if (infoboxes.length > 0) {
      output += `\n\n## Direct Answers / Knowledge:\n${infoboxes.join("\n\n")}`
    }
    
    if (suggestions.length > 0) {
      output += `\n\n## Related searches: ${suggestions.join(", ")}`
    }
    
    if (data.unresponsive_engines && data.unresponsive_engines.length > 0) {
      output += `\n\n⚠ Unresponsive engines: ${data.unresponsive_engines.join(", ")}`
    }
    
    return output
  },
})
