#!/usr/bin/env bash
set -euo pipefail

# ─── Colour Palette ───────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'  # No Colour

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_DIR
readonly STATE_FILE="${SCRIPT_DIR}/.room-state"
readonly KIND_CONFIG="${SCRIPT_DIR}/kind/cluster-config.yaml"
readonly CILIUM_MANIFEST="${SCRIPT_DIR}/kind/cni/cilium.yaml"
readonly KIND_KUBECONFIG="${SCRIPT_DIR}/kind/.kube/config"
readonly SCENARIOS_DIR="${SCRIPT_DIR}/scenarios"
readonly CLUSTER_NAME="escape-room"
readonly VALID_LEVELS="level-01 level-02 level-03 level-04"

# ─── State helpers ────────────────────────────────────────────────────────────

init_state() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    cat > "${STATE_FILE}" <<'EOF'
CURRENT_LEVEL=
HINT_LEVEL=0
COMPLETED_LEVELS=
EOF
  fi
}

read_state() {
  local key="$1"
  # Pure bash: parse key=value without jq/python
  grep "^${key}=" "${STATE_FILE}" 2>/dev/null | cut -d'=' -f2- || true
}

write_state() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "${STATE_FILE}" 2>/dev/null; then
    # Replace existing key (portable sed -i for macOS & Linux)
    sed -i.bak "s|^${key}=.*|${key}=${value}|" "${STATE_FILE}"
    rm -f "${STATE_FILE}.bak"
  else
    echo "${key}=${value}" >> "${STATE_FILE}"
  fi
}

# ─── Banner helpers ───────────────────────────────────────────────────────────

print_header() {
  echo ""
  echo -e "${RED}${BOLD}"
  cat <<'EOF'
  ██╗  ██╗ █████╗ ███████╗    ███████╗███████╗ ██████╗ █████╗ ██████╗ ███████╗
  ██║ ██╔╝██╔══██╗██╔════╝    ██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝
  █████╔╝ ╚█████╔╝███████╗    █████╗  ███████╗██║     ███████║██████╔╝█████╗  
  ██╔═██╗ ██╔══██╗╚════██║    ██╔══╝  ╚════██║██║     ██╔══██║██╔═══╝ ██╔══╝  
  ██║  ██╗╚█████╔╝███████║    ███████╗███████║╚██████╗██║  ██║██║     ███████╗
  ╚═╝  ╚═╝ ╚════╝ ╚══════╝    ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝
                    ██████╗  ██████╗  ██████╗ ███╗   ███╗
                    ██╔══██╗██╔═══██╗██╔═══██╗████╗ ████║
                    ██████╔╝██║   ██║██║   ██║██╔████╔██║
                    ██╔══██╗██║   ██║██║   ██║██║╚██╔╝██║
                    ██║  ██║╚██████╔╝╚██████╔╝██║ ╚═╝ ██║
                    ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝
EOF
  echo -e "${NC}"
  echo -e "  ${BOLD}Kubernetes Escape Room — CLI Harness${NC}"
  echo -e "  Can you debug your way out with AI as your copilot?"
  echo ""
}

print_banner() {
  local colour="$1"
  local text="$2"
  echo ""
  echo -e "${colour}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${colour}${BOLD}  ${text}${NC}"
  echo -e "${colour}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

print_success_banner() {
  echo ""
  echo -e "${GREEN}${BOLD}"
  cat <<'EOF'
  ███████╗███████╗ ██████╗ █████╗ ██████╗ ███████╗██████╗ ██╗
  ██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗██║
  █████╗  ███████╗██║     ███████║██████╔╝█████╗  ██║  ██║██║
  ██╔══╝  ╚════██║██║     ██╔══██║██╔═══╝ ██╔══╝  ██║  ██║╚═╝
  ███████╗███████║╚██████╗██║  ██║██║     ███████╗██████╔╝██╗
  ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═════╝ ╚═╝
EOF
  echo -e "${NC}"
  echo -e "${GREEN}${BOLD}  🎉  You escaped the room!  🎉${NC}"
  echo ""
}

unmark_completed() {
  local level="$1"
  local completed kept="" item
  completed="$(read_state COMPLETED_LEVELS)"
  local IFS=','
  for item in ${completed}; do
    if [[ "${item}" != "${level}" ]]; then
      kept="${kept:+${kept},}${item}"
    fi
  done
  write_state "COMPLETED_LEVELS" "${kept}"
}

# Prints the next available level after "$1" (empty if none has a scenario yet)
next_level() {
  local current="$1" found=0 candidate d
  for candidate in ${VALID_LEVELS}; do
    if [[ "${found}" -eq 1 ]]; then
      for d in "${SCENARIOS_DIR}/${candidate}-"*/; do
        if [[ -d "${d}" ]]; then
          echo "${candidate}"
          return 0
        fi
      done
    fi
    [[ "${candidate}" == "${current}" ]] && found=1
  done
  return 0
}

print_next_steps() {
  local level="$1" next
  next="$(next_level "${level}")"
  echo -e "${BOLD}What's next?${NC}"
  if [[ -n "${next}" ]]; then
    echo -e "  Continue:   ${BOLD}make start LEVEL=${next}${NC}"
  else
    echo -e "  ${GREEN}No further levels are available yet.${NC}"
  fi
  echo -e "  Retry:      ${BOLD}make reset${NC}"
  echo -e "  Tear down:  ${BOLD}make cleanup${NC}"
  echo ""
}

# ─── Prerequisite checks ──────────────────────────────────────────────────────

install_hint() {
  case "$1" in
    docker)  echo "https://docs.docker.com/get-docker/  (macOS: 'brew install --cask docker')" ;;
    kind)    echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation  (macOS: 'brew install kind')" ;;
  esac
}

check_prereqs() {
  local missing=0
  for cmd in docker kind kubectl; do
    if ! command -v "${cmd}" > /dev/null 2>&1; then
      echo -e "${RED}✗ Missing required tool: ${cmd}${NC}"
      local hint
      hint="$(install_hint "${cmd}")"
      if [[ -n "${hint}" ]]; then
        echo -e "  ${YELLOW}💡 Install it: ${hint}${NC}"
      fi
      missing=1
    fi
  done
  if [[ "${missing}" -eq 1 ]]; then
    echo -e "${RED}Install missing tools and retry.${NC}"
    exit 1
  fi
}

cluster_exists() {
  kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"
}

require_cluster() {
  if ! cluster_exists; then
    echo -e "${RED}✗ Kind cluster '${CLUSTER_NAME}' does not exist.${NC}"
    echo -e "  Run ${BOLD}make setup${NC} first."
    exit 1
  fi
  if ! grep -q "kind-${CLUSTER_NAME}" "${KIND_KUBECONFIG}" 2>/dev/null; then
    echo -e "${RED}✗ Kubeconfig ${KIND_KUBECONFIG#"${SCRIPT_DIR}/"} is missing.${NC}"
    echo -e "  Run ${BOLD}make setup${NC} to regenerate it."
    exit 1
  fi
  export KUBECONFIG="${KIND_KUBECONFIG}"
}

require_state() {
  local level
  level="$(read_state CURRENT_LEVEL)"
  if [[ -z "${level}" ]]; then
    echo -e "${RED}✗ No active level.${NC}"
    echo -e "  Run ${BOLD}make start LEVEL=<level>${NC} first."
    exit 1
  fi
}

validate_level() {
  local level="$1"
  local valid
  for valid in ${VALID_LEVELS}; do
    if [[ "${level}" == "${valid}" ]]; then
      return 0
    fi
  done
  echo -e "${RED}✗ Unknown level: '${level}'.${NC}"
  echo -e "  Valid levels: ${VALID_LEVELS}"
  exit 1
}

# ─── Command: setup ───────────────────────────────────────────────────────────

# Exits 1 when the cluster was created with kindnet (no NetworkPolicy support).
# Cilium cannot be layered on top of kindnet, so the user must recreate it.
check_not_kindnet() {
  if kubectl get daemonset kindnet -n kube-system > /dev/null 2>&1; then
    echo -e "${RED}✗ Cluster '${CLUSTER_NAME}' was created with kindnet, which does not enforce NetworkPolicy.${NC}"
    echo -e "  Run ${BOLD}make cleanup${NC} followed by ${BOLD}make setup${NC}."
    exit 1
  fi
}

# Writes a repo-local kubeconfig holding only the kind cluster, so every harness
# kubectl call is pinned to it whatever the user's current context is. kind also
# keeps updating the default ~/.kube/config as usual.
export_kubeconfig() {
  mkdir -p "${KIND_KUBECONFIG%/*}"
  chmod 700 "${KIND_KUBECONFIG%/*}"
  if ! kind export kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KIND_KUBECONFIG}" > /dev/null; then
    echo -e "${RED}✗ Could not write ${KIND_KUBECONFIG#"${SCRIPT_DIR}/"}.${NC}"
    exit 1
  fi
  chmod 600 "${KIND_KUBECONFIG}"
  export KUBECONFIG="${KIND_KUBECONFIG}"
}

# Installs the pinned Cilium CNI (kind/cni/cilium.yaml) with Hubble, then waits
# for every component and all nodes to be Ready. Re-applying is idempotent.
install_cilium() {
  echo -e "${CYAN}→ Installing Cilium CNI (pinned 1.20.2)...${NC}"
  kubectl apply --server-side --force-conflicts -f "${CILIUM_MANIFEST}" > /dev/null
  kubectl rollout status daemonset/cilium -n kube-system --timeout=300s > /dev/null
  kubectl rollout status deployment/cilium-operator -n kube-system --timeout=300s > /dev/null
  kubectl rollout status deployment/hubble-relay -n kube-system --timeout=300s > /dev/null
  kubectl rollout status deployment/hubble-ui -n kube-system --timeout=300s > /dev/null
  echo -e "${CYAN}→ Waiting for all nodes to be Ready...${NC}"
  kubectl wait --for=condition=Ready nodes --all --timeout=300s > /dev/null
  echo -e "${GREEN}✓ Cilium is ready and all nodes are Ready.${NC}"
}

cmd_setup() {
  print_banner "${CYAN}" "🚀  Setting up Escape Room Cluster"

  check_prereqs

  echo -e "${CYAN}→ Checking Docker...${NC}"
  if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running. Please start Docker and retry.${NC}"
    echo -e "  ${YELLOW}💡 Start Docker Desktop. Not installed? $(install_hint docker)${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Docker is running.${NC}"

  if cluster_exists; then
    echo -e "${YELLOW}⚠ Cluster '${CLUSTER_NAME}' already exists — skipping creation.${NC}"
  else
    echo -e "${CYAN}→ Creating Kind cluster '${CLUSTER_NAME}'...${NC}"
    kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}"
    echo -e "${GREEN}✓ Cluster created.${NC}"
  fi

  echo -e "${CYAN}→ Writing repo kubeconfig (kind/.kube/config)...${NC}"
  export_kubeconfig
  echo -e "${GREEN}✓ Kubeconfig written.${NC}"

  echo -e "${CYAN}→ Verifying kubectl connectivity...${NC}"
  kubectl cluster-info > /dev/null
  echo -e "${GREEN}✓ kubectl is connected to the cluster.${NC}"

  check_not_kindnet
  install_cilium

  init_state

  print_banner "${GREEN}" "✅  Setup complete — cluster is ready"
  echo -e "  Run ${BOLD}make start LEVEL=level-01${NC} to begin."
  echo ""
}

# Builds scenarios/<level>-*/app/ (if present) and loads it into the kind
# cluster, so no external registry is needed. Image: escape-room/<level>-app:1.0.0
build_app_image() {
  local level="$1" dir="$2"
  local app_dir="${dir}app"
  [[ -f "${app_dir}/Dockerfile" ]] || return 0

  local image="escape-room/${level}-app:1.0.0"
  echo -e "${CYAN}→ Building application image '${image}'...${NC}"
  docker build -q -t "${image}" "${app_dir}" > /dev/null
  kind load docker-image "${image}" --name "${CLUSTER_NAME}" > /dev/null
  echo -e "${GREEN}✓ Image loaded into the cluster.${NC}"
}

# Blocks until each deployment in "$@" rolls out (Ready pods), or exits 1 after 120s
wait_for_deployments() {
  local namespace="$1"
  shift
  local deployment
  echo -e "${CYAN}→ Waiting for ${*} to be ready...${NC}"
  for deployment in "$@"; do
    if ! kubectl rollout status "deployment/${deployment}" -n "${namespace}" --timeout=120s > /dev/null 2>&1; then
      echo -e "${RED}✗ Deployment '${deployment}' is not ready after 120s.${NC}"
      echo -e "  Check: kubectl get pods -n ${namespace}"
      exit 1
    fi
    echo -e "${GREEN}✓ ${deployment} is ready.${NC}"
  done
}

# Waits for the Deployments of levels whose broken state still rolls out Ready.
# Level 01 must stay broken (ImagePullBackOff), so it is intentionally skipped.
wait_for_level_rollout() {
  local level="$1" namespace="$2"
  case "${level}" in
    level-03) wait_for_deployments "${namespace}" backend frontend ;;
    level-04) wait_for_deployments "${namespace}" payment cart gateway ;;
  esac
}

# Deletes the namespaces of every level except "$1" so old workloads cannot interfere
remove_other_levels() {
  local keep="$1" other
  for other in ${VALID_LEVELS}; do
    [[ "${other}" == "${keep}" ]] && continue
    if kubectl get namespace "escape-${other}" > /dev/null 2>&1; then
      echo -e "${CYAN}→ Removing previous level namespace 'escape-${other}'...${NC}"
      kubectl delete namespace "escape-${other}" --ignore-not-found=true --wait=true
    fi
  done
}

# ─── Command: start <level> ───────────────────────────────────────────────────

cmd_start() {
  local level="${1:-}"
  if [[ -z "${level}" ]]; then
    echo -e "${RED}✗ Usage: make start LEVEL=<level>${NC}"
    echo -e "  Valid levels: ${VALID_LEVELS}"
    exit 1
  fi

  validate_level "${level}"
  require_cluster

  # Expand glob manually without failing on no-match
  local dir=""
  for d in "${SCENARIOS_DIR}/${level}-"*/; do
    dir="${d}"
    break
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    echo -e "${RED}✗ Scenario directory for '${level}' not found under ${SCENARIOS_DIR}/${NC}"
    exit 1
  fi

  local broken_dir="${dir}broken"
  if [[ ! -d "${broken_dir}" ]]; then
    echo -e "${RED}✗ No 'broken/' directory found in ${dir}${NC}"
    exit 1
  fi

  local namespace="escape-${level}"

  print_banner "${YELLOW}" "🔥  Starting ${level}"

  build_app_image "${level}" "${dir}"

  remove_other_levels "${level}"

  echo -e "${CYAN}→ Resetting namespace '${namespace}'...${NC}"
  kubectl delete namespace "${namespace}" --ignore-not-found=true --wait=true
  kubectl create namespace "${namespace}"
  echo -e "${GREEN}✓ Namespace ready.${NC}"

  echo -e "${CYAN}→ Applying broken manifests...${NC}"
  kubectl apply -f "${broken_dir}/" -n "${namespace}"
  echo -e "${GREEN}✓ Broken state injected.${NC}"

  wait_for_level_rollout "${level}" "${namespace}"

  # Update state
  init_state
  write_state "CURRENT_LEVEL" "${level}"
  write_state "HINT_LEVEL" "0"
  unmark_completed "${level}"

  # Show incident alert
  local incident_file="${dir}incident.md"
  if [[ -f "${incident_file}" ]]; then
    echo ""
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}  🚨  INCIDENT ALERT — READ CAREFULLY${NC}"
    echo -e "${RED}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    cat "${incident_file}"
    echo ""
  fi

  echo -e "${BOLD}Useful commands:${NC}"
  echo -e "  ${CYAN}make status${NC}   — see pod states"
  echo -e "  ${CYAN}make hint${NC}     — get your first hint"
  echo -e "  ${CYAN}make ai-assist${NC} — tips for using an AI copilot on this level"
  echo -e "  ${CYAN}make verify${NC}   — check if you've fixed it"
  echo ""
}

# ─── Command: status ─────────────────────────────────────────────────────────

cmd_status() {
  require_cluster
  require_state

  local level
  level="$(read_state CURRENT_LEVEL)"
  local hint_level
  hint_level="$(read_state HINT_LEVEL)"
  local completed
  completed="$(read_state COMPLETED_LEVELS)"
  local namespace="escape-${level}"

  print_banner "${CYAN}" "📊  Status — ${level}"

  echo -e "${BOLD}Active level:${NC}     ${CYAN}${level}${NC}"
  echo -e "${BOLD}Namespace:${NC}        ${namespace}"
  echo -e "${BOLD}Hints used:${NC}       ${hint_level}/3"
  if [[ -n "${completed}" ]]; then
    echo -e "${BOLD}Completed:${NC}        ${GREEN}${completed}${NC}"
  fi
  echo ""

  echo -e "${BOLD}Pod status:${NC}"
  kubectl get pods -n "${namespace}" 2>/dev/null || echo "  (no pods yet)"
  echo ""

  echo -e "${BOLD}Service status:${NC}"
  kubectl get svc -n "${namespace}" 2>/dev/null || echo "  (no services yet)"
  echo ""

  echo -e "${BOLD}Troubleshooting commands:${NC}"
  echo -e "  kubectl get pods -n ${namespace}"
  echo -e "  kubectl describe pod -n ${namespace} -l app=<name>"
  echo -e "  kubectl logs -n ${namespace} -l app=<name> --previous"
  echo -e "  kubectl get events -n ${namespace} --sort-by='.lastTimestamp'"
  echo ""
}

# ─── Command: hint ────────────────────────────────────────────────────────────

cmd_hint() {
  require_state

  local level
  level="$(read_state CURRENT_LEVEL)"
  local hint_level
  hint_level="$(read_state HINT_LEVEL)"

  local dir=""
   for d in "${SCENARIOS_DIR}/${level}-"*/; do
    dir="${d}"
    break
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    echo -e "${RED}✗ Scenario directory not found for '${level}'.${NC}"
    exit 1
  fi

  local hints_file="${dir}hints.md"
  if [[ ! -f "${hints_file}" ]]; then
    echo -e "${RED}✗ No hints file found for '${level}'.${NC}"
    exit 1
  fi

  if [[ "${hint_level}" -ge 3 ]]; then
    echo -e "${YELLOW}⚠  You've already used all 3 hints.${NC}"
    echo -e "  Use ${BOLD}make solve${NC} if you're truly stuck (instructor only)."
    return
  fi

  local next_hint=$(( hint_level + 1 ))
  write_state "HINT_LEVEL" "${next_hint}"

  echo ""
  echo -e "${YELLOW}${BOLD}💡  Hint ${next_hint} of 3 — ${level}${NC}"
  echo ""

  # Extract the Nth hint block from hints.md using pure bash + awk
  # Hints are delimited by "## Hint N" headings
  extract_hint "${hints_file}" "${next_hint}"
  echo ""
}

extract_hint() {
  local file="$1"
  local n="$2"
  awk -v hint="Hint ${n}" '
    /^## / { 
      if (found) exit
      if (index($0, hint) > 0) found=1
      next
    }
    found { print }
  ' "${file}"
}

# ─── Command: ai-assist ───────────────────────────────────────────────────────

# Prints the level's AI tip. Independent of the hint counter (HINT_LEVEL).
cmd_ai_assist() {
  require_state

  local level
  level="$(read_state CURRENT_LEVEL)"

  local dir=""
  for d in "${SCENARIOS_DIR}/${level}-"*/; do
    dir="${d}"
    break
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    echo -e "${RED}✗ Scenario directory not found for '${level}'.${NC}"
    exit 1
  fi

  local tip_file="${dir}ai-assist.md"
  if [[ ! -f "${tip_file}" ]]; then
    echo -e "${RED}✗ No AI tip file found for '${level}'.${NC}"
    exit 1
  fi

  echo ""
  echo -e "${CYAN}${BOLD}🤖  AI assist — ${level}${NC}"
  echo ""
  cat "${tip_file}"
  echo ""
}

# ─── Command: verify ─────────────────────────────────────────────────────────

cmd_verify() {
  require_cluster
  require_state

  local level
  level="$(read_state CURRENT_LEVEL)"

  local dir=""
   for d in "${SCENARIOS_DIR}/${level}-"*/; do
    dir="${d}"
    break
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    echo -e "${RED}✗ Scenario directory not found for '${level}'.${NC}"
    exit 1
  fi

  local verify_script="${dir}verify.sh"
  if [[ ! -f "${verify_script}" ]]; then
    echo -e "${RED}✗ No verify.sh found for '${level}'.${NC}"
    exit 1
  fi

  print_banner "${CYAN}" "🔍  Verifying ${level}"

  if bash "${verify_script}"; then
    # Mark level as completed
    local completed
    completed="$(read_state COMPLETED_LEVELS)"
    if [[ ",${completed}," != *",${level},"* ]]; then
      if [[ -z "${completed}" ]]; then
        write_state "COMPLETED_LEVELS" "${level}"
      else
        write_state "COMPLETED_LEVELS" "${completed},${level}"
      fi
    fi
    print_success_banner
    print_next_steps "${level}"
  else
    echo ""
    echo -e "${YELLOW}⚠  Not fixed yet. Run ${BOLD}make hint${NC}${YELLOW} for your next clue.${NC}"
    exit 1
  fi
}

# ─── Command: solve ───────────────────────────────────────────────────────────

cmd_solve() {
  require_cluster
  require_state

  local level
  level="$(read_state CURRENT_LEVEL)"

  local dir=""
   for d in "${SCENARIOS_DIR}/${level}-"*/; do
    dir="${d}"
    break
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    echo -e "${RED}✗ Scenario directory not found for '${level}'.${NC}"
    exit 1
  fi

  local solution_dir="${dir}solution"
  if [[ ! -d "${solution_dir}" ]]; then
    echo -e "${RED}✗ No solution/ directory found for '${level}'.${NC}"
    exit 1
  fi

  local namespace="escape-${level}"

  print_banner "${YELLOW}" "🔓  Applying Reference Solution — ${level}"
  echo -e "${YELLOW}${BOLD}⚠  Instructor/Emergency use only!${NC}"
  echo ""

  kubectl apply -f "${solution_dir}/" -n "${namespace}"

  echo ""
  echo -e "${GREEN}✓ Solution applied. Waiting for pods to stabilise...${NC}"
  if ! kubectl rollout status deployment -n "${namespace}" --timeout=120s > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠  Deployments are not ready after 120s. Check: kubectl get pods -n ${namespace}${NC}"
  fi
  echo ""
  echo -e "Run ${BOLD}make verify${NC} to confirm the level is complete."
}

# ─── Command: reset ───────────────────────────────────────────────────────────

cmd_reset() {
  require_cluster
  require_state

  local level
  level="$(read_state CURRENT_LEVEL)"

  print_banner "${YELLOW}" "♻️   Resetting broken state — ${level}"

  local dir=""
   for d in "${SCENARIOS_DIR}/${level}-"*/; do
    dir="${d}"
    break
  done

  if [[ -z "${dir}" || ! -d "${dir}" ]]; then
    echo -e "${RED}✗ Scenario directory not found for '${level}'.${NC}"
    exit 1
  fi

  local broken_dir="${dir}broken"
  if [[ ! -d "${broken_dir}" ]]; then
    echo -e "${RED}✗ No broken/ directory found for '${level}'.${NC}"
    exit 1
  fi

  local namespace="escape-${level}"

  echo -e "${CYAN}→ Deleting namespace '${namespace}'...${NC}"
  kubectl delete namespace "${namespace}" --ignore-not-found=true --wait=true
  kubectl create namespace "${namespace}"

  echo -e "${CYAN}→ Re-injecting broken manifests...${NC}"
  kubectl apply -f "${broken_dir}/" -n "${namespace}"

  wait_for_level_rollout "${level}" "${namespace}"

  write_state "HINT_LEVEL" "0"
  unmark_completed "${level}"

  echo -e "${GREEN}✓ Broken state restored.${NC}"
  echo ""
}

# ─── Command: cleanup ─────────────────────────────────────────────────────────

cmd_cleanup() {
  print_banner "${RED}" "🧹  Tearing Down Escape Room Cluster"

  if ! cluster_exists; then
    echo -e "${YELLOW}⚠  Cluster '${CLUSTER_NAME}' does not exist — nothing to do.${NC}"
  else
    echo -e "${CYAN}→ Deleting kind cluster '${CLUSTER_NAME}'...${NC}"
    kind delete cluster --name "${CLUSTER_NAME}"
    echo -e "${GREEN}✓ Cluster deleted.${NC}"
  fi

  # Repo kubeconfig holds client credentials
  if [[ -d "${KIND_KUBECONFIG%/*}" ]]; then
    rm -rf "${KIND_KUBECONFIG%/*}"
    echo -e "${GREEN}✓ Repo kubeconfig removed.${NC}"
  fi

  # Clear state
  if [[ -f "${STATE_FILE}" ]]; then
    rm -f "${STATE_FILE}"
    echo -e "${GREEN}✓ State file cleared.${NC}"
  fi

  echo ""
  echo -e "Run ${BOLD}make setup${NC} to create a fresh cluster."
  echo ""
}

# ─── Usage ────────────────────────────────────────────────────────────────────

cmd_usage() {
  print_header
  echo -e "${BOLD}Usage:${NC}  make <command> [LEVEL=<level>]"
  echo ""
  echo -e "${BOLD}Commands:${NC}"
  echo -e "  ${CYAN}setup${NC}              Check prerequisites and create the Kind cluster"
  echo -e "  ${CYAN}start LEVEL=<level>${NC} Begin a level (e.g. level-01, level-02, level-03, level-04)"
  echo -e "  ${CYAN}status${NC}             Show active scenario, pod statuses, troubleshooting tips"
  echo -e "  ${CYAN}hint${NC}               Display the next progressive hint (1 → 2 → 3)"
  echo -e "  ${CYAN}ai-assist${NC}          Show an AI copilot tip for the current level (does not use a hint)"
  echo -e "  ${CYAN}verify${NC}             Run the scenario verification probe"
  echo -e "  ${CYAN}solve${NC}              Apply the reference solution (instructor/emergency only)"
  echo -e "  ${CYAN}reset${NC}              Re-inject the current level's broken state"
  echo -e "  ${CYAN}cleanup${NC}            Tear down the Kind cluster"
  echo ""
  echo -e "${BOLD}Valid levels:${NC}  ${VALID_LEVELS}"
  echo ""
}

# ─── Entrypoint ───────────────────────────────────────────────────────────────

main() {
  local command="${1:-}"
  case "${command}" in
    setup)   cmd_setup ;;
    start)   cmd_start "${2:-}" ;;
    status)  cmd_status ;;
    hint)    cmd_hint ;;
    ai-assist) cmd_ai_assist ;;
    verify)  cmd_verify ;;
    solve)   cmd_solve ;;
    reset)   cmd_reset ;;
    cleanup) cmd_cleanup ;;
    ""|help|--help|-h) cmd_usage ;;
    *)
      echo -e "${RED}✗ Unknown command: '${command}'${NC}"
      cmd_usage
      exit 1
      ;;
  esac
}

main "$@"
