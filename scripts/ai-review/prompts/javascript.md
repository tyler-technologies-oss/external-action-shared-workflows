## JavaScript Review Criteria
This is a GitHub Action runtime (Node 20), not a web server. Focus on what the action does with inputs, environment, filesystem, and network.
- Shell injection via exec: Note child_process.exec/execSync with template strings containing inputs. RISKY: exec(`git clone ${core.getInput('repo')}`)  SAFER: execFile('git', ['clone', repo])
- Env-to-network flow: Note code reading process.env (esp. GITHUB_TOKEN, *_KEY, *_SECRET) and passing it to fetch/http/https/dns/net. RISKY: fetch(url, {body: JSON.stringify(process.env)})  SAFER: env read only for documented action config
- Dynamic code execution: Note eval, new Function, vm.runInContext, or require(variable). RISKY: eval(Buffer.from(s,'base64').toString())  SAFER: no dynamic execution at all
- New network capability: Note newly added imports of http, https, net, dns, or new fetch calls to domains not previously present. RISKY: new require('https') in a formerly offline action  SAFER: same endpoints as before
- Secret logging: Note removal of core.setSecret(...) masking, or secrets/tokens passed to core.info, console.log, or error messages. RISKY: console.log('token:', token)  SAFER: core.setSecret(token) before any use
- Input-driven file paths: Note file writes/reads built from inputs without normalization, allowing ../ escape from the workspace. RISKY: fs.writeFileSync(core.getInput('out'), data)  SAFER: resolve and verify path stays under GITHUB_WORKSPACE
- package.json lifecycle and sources: Note added preinstall/postinstall/prepare scripts, git/URL dependencies, or changed registry config. RISKY: "postinstall": "node fetch-tools.js"  SAFER: registry deps only, no lifecycle scripts
- Obfuscation proxies: Note added lines >500 chars, hex/\x escape strings, or arrays of char codes joined into identifiers, outside dist/. RISKY: String.fromCharCode(104,116,116,112,...)  SAFER: plain readable strings (flag presence; do not decode)
