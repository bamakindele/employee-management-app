# Employee Management App

## Local development

Start the PostgreSQL database used by the app:

```powershell
docker compose up -d postgres
```

In PowerShell, start the backend from the project root:

```powershell
cd backend-fastapi
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8001
```

The execution-policy change applies only to the current PowerShell process and
allows the virtual environment activation script to run. If `DATABASE_URL` is
already set in that terminal, clear it before launching so the backend reads
the root `.env` instead:

```powershell
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
```

In a Bash terminal, start the frontend from the `frontend` directory:

```bash
cd frontend
npm run dev
```

Local development URLs:

- Frontend: `http://localhost:5174`
- Backend API: `http://localhost:8001`
- FastAPI docs: `http://localhost:8001/docs`

Create a sign-in account (called a user in the database) from the backend
directory in PowerShell:

```powershell
cd backend-fastapi
.\.venv\Scripts\python.exe create_user.py
```

The script prompts for a username and password. It creates a login account;
employee directory records are added separately from the signed-in frontend.

## Run with Docker

Copy `.env.example` to `.env`, set strong values for `POSTGRES_PASSWORD` and
`JWT_SECRET`, then start the application:

```powershell
docker compose up --build
```

Open the frontend at `http://localhost:5173`. The API is available at
`http://localhost:8000`, and its FastAPI docs are at
`http://localhost:8000/docs`. PostgreSQL runs on port `5432`.

Create a sign-in account while the Docker backend is running:

```powershell
docker compose exec backend python create_user.py
```

The script prompts for a username and password. Employee directory records are
added separately from the signed-in frontend.

## PostgreSQL client and server

`psql 15.19` is the PostgreSQL command-line client available in PowerShell;
it is a client program, not a database server. pgAdmin connects to the
PostgreSQL 18 server selected in its registered server connection. Docker
Compose separately runs a PostgreSQL 15 server in its `postgres` container.

The server version and data depend on the host and port configured in the
client. Because Compose publishes its PostgreSQL container on host port `5432`,
a separate local PostgreSQL service cannot use that same port at the same time.
