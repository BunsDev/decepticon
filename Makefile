# Decepticon — Development & Operations
#
# Dev workflow:    make dev   (build + hot-reload via docker compose watch)
# Production:     make start (build + start, same as open-source user experience)
# Interactive CLI: make cli   (in a separate terminal)
#
# Both dev and prod run identical Docker containers.
# The only difference: `watch` syncs local source changes into containers.

COMPOSE := docker compose
COMPOSE_CLI := $(COMPOSE) --profile cli

.PHONY: dev start cli stop status logs build test lint clean

# ── Development ──────────────────────────────────────────────────

## Build images and start with hot-reload (source changes auto-sync)
dev:
	$(COMPOSE) watch

## Run interactive CLI (use in a separate terminal while `make dev` is running)
cli:
	$(COMPOSE_CLI) run --rm cli

# ── Production-like ──────────────────────────────────────────────

## Build and start all services in background (same as open-source user)
start:
	$(COMPOSE) up -d --build

## Stop all services
stop:
	$(COMPOSE) --profile cli --profile victims down

## Show service status
status:
	$(COMPOSE) ps

## Follow service logs (usage: make logs or make logs SVC=langgraph)
logs:
	$(COMPOSE) logs -f $(or $(SVC),langgraph)

# ── Build ────────────────────────────────────────────────────────

## Build all Docker images without starting
build:
	$(COMPOSE_CLI) build

## Build a specific service (usage: make build-svc SVC=langgraph)
build-svc:
	$(COMPOSE) build $(SVC)

# ── Testing & Quality ────────────────────────────────────────────

## Run pytest inside langgraph container
test:
	$(COMPOSE) exec langgraph python -m pytest $(ARGS)

## Run tests locally (requires uv sync --dev)
test-local:
	pytest $(ARGS)

## Lint and typecheck locally
lint:
	ruff check .
	ruff format --check .
	basedpyright

## Auto-fix lint issues
lint-fix:
	ruff check --fix .
	ruff format .

# ── Victim Targets (demo/testing) ───────────────────────────────

## Start vulnerable test targets
victims:
	$(COMPOSE) --profile victims up -d

## Run guided demo (Metasploitable 2)
demo:
	$(COMPOSE) --profile victims up -d
	@echo "Waiting for services..."
	@until curl -sf http://localhost:$${LANGGRAPH_PORT:-2024}/ok >/dev/null 2>&1; do sleep 2; done
	$(COMPOSE_CLI) run --rm -e DECEPTICON_INITIAL_MESSAGE="Resume the demo engagement and execute all objectives." cli

# ── Cleanup ──────────────────────────────────────────────────────

## Stop services and remove volumes
clean:
	$(COMPOSE) --profile cli --profile victims down --volumes --remove-orphans

# ── Help ─────────────────────────────────────────────────────────

## Show this help
help:
	@echo "Decepticon — Development & Operations"
	@echo ""
	@echo "Development:"
	@echo "  make dev        Build + start with hot-reload (docker compose watch)"
	@echo "  make cli        Run interactive CLI (separate terminal)"
	@echo ""
	@echo "Production-like:"
	@echo "  make start      Build + start in background"
	@echo "  make stop       Stop all services"
	@echo "  make status     Show service status"
	@echo "  make logs       Follow logs (SVC=langgraph)"
	@echo ""
	@echo "Quality:"
	@echo "  make test       Run pytest in container"
	@echo "  make test-local Run pytest locally"
	@echo "  make lint       Lint + typecheck"
	@echo "  make lint-fix   Auto-fix lint issues"
	@echo ""
	@echo "Other:"
	@echo "  make build      Build all Docker images"
	@echo "  make victims    Start vulnerable targets"
	@echo "  make demo       Run guided demo"
	@echo "  make clean      Stop + remove volumes"
