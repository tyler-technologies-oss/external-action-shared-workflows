## Docker Review Criteria
- Unpinned base image: Note FROM without a tag, with :latest, or with a tag but no @sha256: digest; also a base image switched to an unfamiliar registry or org. RISKY: FROM node:latest  SAFER: FROM node:20.11-alpine@sha256:<digest>
- ADD from URL: Note ADD https://... (fetches at build time). RISKY: ADD https://example.dev/tool /usr/bin/tool  SAFER: COPY of an in-repo file, or curl + sha256sum -c in RUN
- Download-and-run in RUN: Note RUN curl ... | sh and equivalents. RISKY: RUN wget -qO- https://x.sh | sh  SAFER: pinned package-manager installs (apk add pkg=1.2.3)
- Root execution: Note removal of a USER directive or a switch back to root for the final stage. RISKY: final stage has no USER  SAFER: USER nonroot (or numeric UID) before ENTRYPOINT
- Secrets in layers: Note credentials in ENV, ARG defaults, or files copied then "deleted" in a later layer (still present in history). RISKY: ENV NPM_TOKEN=abc123  SAFER: BuildKit --mount=type=secret, or no build-time secrets
- Entrypoint indirection: Note ENTRYPOINT/CMD changed to a wrapper script that fetches or decodes content at container start. RISKY: ENTRYPOINT ["sh","-c","curl x.sh | sh"]  SAFER: entrypoint runs committed, reviewed code
- Permission loosening: Note chmod 777, setuid/setgid bits, or writes to system paths added in RUN. RISKY: RUN chmod u+s /usr/bin/tool  SAFER: default permissions
