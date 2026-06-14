const supervisorStatus = document.querySelector("#supervisor-status");
const logState = document.querySelector("#log-state");
const logOutput = document.querySelector("#log-output");

async function updateSupervisorStatus() {
  try {
    const response = await fetch("/supervisor-api/supervisor/ping", {
      cache: "no-store",
    });
    supervisorStatus.textContent = response.ok
      ? "Supervisor responding"
      : "Supervisor starting";
  } catch (_) {
    supervisorStatus.textContent = "Waiting for Supervisor";
  }
}

async function updateLogs() {
  try {
    const response = await fetch("/observer/logs", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const text = await response.text();
    const lines = text.trim().split("\n").slice(-28);
    logOutput.textContent = lines.join("\n") || "Observer is running; no log lines yet.";
    logState.textContent = "Live";
  } catch (_) {
    logOutput.textContent = "Observer logs are not available yet. Startup is still in progress.";
    logState.textContent = "Waiting";
  }
}

function refresh() {
  updateSupervisorStatus();
  updateLogs();
}

refresh();
setInterval(refresh, 5000);
