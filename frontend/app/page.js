const API_BASE = process.env.API_BASE_URL || "";
const API_HEALTH_BASE = process.env.API_HEALTH_BASE_URL || API_BASE;
const GRAFANA_URL = process.env.GRAFANA_URL || "";
const GRAFANA_DASHBOARD_URL = process.env.GRAFANA_DASHBOARD_URL || "";
export const dynamic = "force-dynamic";

async function getApiStatus() {
  if (!API_HEALTH_BASE) return "not configured";
  try {
    const res = await fetch(`${API_HEALTH_BASE}/healthz/`, { cache: "no-store" });
    return res.ok ? "healthy" : "unhealthy";
  } catch {
    return "unreachable";
  }
}

export default async function HomePage() {
  const apiStatus = await getApiStatus();

  return (
    <main style={{ maxWidth: 900, margin: "0 auto", padding: "2rem 1rem" }}>
      <h1 style={{ marginBottom: "0.5rem" }}>Resilient Study Platform</h1>
      <p style={{ color: "#334155", marginTop: 0 }}>
        Minimal Next.js frontend for platform status and operations links.
      </p>

      <section
        style={{
          background: "white",
          border: "1px solid #e2e8f0",
          borderRadius: 8,
          padding: "1rem",
          marginBottom: "1rem"
        }}
      >
        <h2 style={{ marginTop: 0 }}>System Status</h2>
        <p style={{ margin: "0.25rem 0" }}>
          API health: <strong>{apiStatus}</strong>
        </p>
        <p style={{ margin: "0.25rem 0" }}>
          API endpoint:{" "}
          <code>{API_HEALTH_BASE ? `${API_HEALTH_BASE}/healthz/` : "set API_HEALTH_BASE_URL"}</code>
        </p>
      </section>

      <section
        style={{
          background: "white",
          border: "1px solid #e2e8f0",
          borderRadius: 8,
          padding: "1rem"
        }}
      >
        <h2 style={{ marginTop: 0 }}>Operations</h2>
        <ul>
          <li>{API_BASE ? <a href={API_BASE}>{API_BASE}</a> : "API ingress not configured"}</li>
          <li>
            {GRAFANA_URL ? <a href={GRAFANA_URL}>{GRAFANA_URL}</a> : "Grafana not configured"}
          </li>
        </ul>
      </section>

      <section
        style={{
          background: "white",
          border: "1px solid #e2e8f0",
          borderRadius: 8,
          padding: "1rem",
          marginTop: "1rem"
        }}
      >
        <h2 style={{ marginTop: 0 }}>Grafana Dashboard</h2>
        {GRAFANA_DASHBOARD_URL ? (
          <iframe
            title="Study Platform Grafana Dashboard"
            src={GRAFANA_DASHBOARD_URL}
            style={{ width: "100%", minHeight: 700, border: "1px solid #e2e8f0", borderRadius: 6 }}
          />
        ) : (
          <p>Set GRAFANA_DASHBOARD_URL to enable embedded dashboard.</p>
        )}
      </section>
    </main>
  );
}
