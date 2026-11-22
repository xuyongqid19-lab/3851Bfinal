# Global Village team handoff — 10 November 2026

## Open the shared site

https://global-village-haozhe.malaysiawest.cloudapp.azure.com/

The site runs on the team's Azure virtual machine in Malaysia West. Teammates can use the same URL from different networks; they do not need to run Docker locally to use the deployed site. The web page and the Auth, Chat, Community, and Family health endpoints were checked after deployment.

## Work with the source

This archive contains the Flutter source, API source, Docker Compose files, and the built web client. Use the existing README and database setup guides for local development. The Azure deployment uses `docker-compose.azure.yml`, `public-gateway/nginx.azure.conf`, and `public-gateway/Caddyfile.azure`.

The Azure host's passwords, SSH keys, SMTP authorization code, database backups, and live `.env` files are intentionally excluded. The team should not commit or share those files. The Azure databases were restored from the existing local project databases on 10 November 2026; this archive is source code, not a database snapshot.

The Azure VM must remain running and the Azure for Students credit must remain active for the site to stay available.
