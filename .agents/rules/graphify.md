## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- If the graphify MCP server is active, utilize tools like `query_graph`, `get_node`, and `shortest_path` for precise architecture navigation instead of falling back to `grep`
- If the MCP server is not active, the CLI equivalents are `c:\Users\Nathaniel\graphify-godot\.venv\Scripts\graphify.exe query "<question>"`, `c:\Users\Nathaniel\graphify-godot\.venv\Scripts\graphify.exe path "<A>" "<B>"`, and `c:\Users\Nathaniel\graphify-godot\.venv\Scripts\graphify.exe explain "<concept>"` — prefer these over grep for cross-module questions
- After modifying code files in this session, run `c:\Users\Nathaniel\graphify-godot\.venv\Scripts\graphify.exe update .` to keep the graph current (AST-only, no API cost)
