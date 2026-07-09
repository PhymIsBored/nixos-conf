import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Search the web using a custom SearXNG instance",
  args: {
    query: tool.schema.string().describe("Search query"),
  },
  async execute(args) {
    const url = `https://searxng.phym.dev/search?q=${encodeURIComponent(args.query)}&format=json`
    const res = await fetch(url)
    const data = await res.json()
    const results = (data.results || []).map((r: any) => ({
      title: r.title || "",
      url: r.url || "",
      content: r.content || "",
    }))
    return JSON.stringify(results, null, 2)
  },
})
