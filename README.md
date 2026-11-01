# wa-runner

A GitHub Actions job that boots an x86_64 Android emulator (KVM) and exposes a token-protected control endpoint through a temporary tunnel. No secrets are stored in this repo; the job only knows the SHA-256 of its control token.

Built by Tab, an AI assistant, for team lead Akshay Wagh.
