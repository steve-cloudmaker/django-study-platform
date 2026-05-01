#!/usr/bin/env python3
"""
Async load generator + Textual TUI for the Study Platform API.

Writes: POST /api/studies/ then POST .../submissions/ (body = survey JSON, ≤2k).
Reads: GET /api/studies/, GET /api/studies/{id}/, GET .../submissions/{sid}/ using IDs from successful writes.

Note: API DRF throttling (API_RATE_LIMIT) caps per-IP QPS; raise limits for heavy tests.
"""
from __future__ import annotations

import argparse
import asyncio
import threading
import time
import uuid
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import httpx
from textual.app import App, ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Footer, Header, Static


def load_survey_cache(data_dir: Path) -> list[str]:
    paths = sorted(data_dir.glob("survey-*.json"))
    if len(paths) < 100:
        raise SystemExit(
            f"Expected 100 surveys in {data_dir}, found {len(paths)}. Run: python generate_surveys.py"
        )
    bodies: list[str] = []
    for p in paths:
        text = p.read_text(encoding="utf-8").strip()
        if len(text) > 2000:
            raise SystemExit(f"{p.name} exceeds 2000 chars ({len(text)})")
        bodies.append(text)
    return bodies


@dataclass
class Stats:
    lock: threading.Lock = field(default_factory=threading.Lock)
    writes_ok: int = 0
    writes_err: int = 0
    reads_ok: int = 0
    reads_err: int = 0
    write_lat_ms: deque[float] = field(default_factory=lambda: deque(maxlen=8000))
    read_lat_ms: deque[float] = field(default_factory=lambda: deque(maxlen=8000))
    last_error: str = ""
    pool: list[tuple[str, str]] = field(default_factory=list)

    def add_pool(self, study_id: str, submission_id: str) -> None:
        with self.lock:
            self.pool.append((study_id, submission_id))
            if len(self.pool) > 5000:
                del self.pool[:-2500]

    def record_write(self, ok: bool, ms: float, err: str = "") -> None:
        with self.lock:
            if ok:
                self.writes_ok += 1
                self.write_lat_ms.append(ms)
            else:
                self.writes_err += 1
                if err:
                    self.last_error = err[:500]

    def record_read(self, ok: bool, ms: float, err: str = "") -> None:
        with self.lock:
            if ok:
                self.reads_ok += 1
                self.read_lat_ms.append(ms)
            else:
                self.reads_err += 1
                if err:
                    self.last_error = err[:500]

    def snapshot(self) -> dict[str, Any]:
        with self.lock:
            wl = list(self.write_lat_ms)
            rl = list(self.read_lat_ms)
            pool_n = len(self.pool)
            return {
                "writes_ok": self.writes_ok,
                "writes_err": self.writes_err,
                "reads_ok": self.reads_ok,
                "reads_err": self.reads_err,
                "pool": pool_n,
                "last_error": self.last_error,
                "write_p95_ms": _pctl(wl, 95),
                "read_p95_ms": _pctl(rl, 95),
                "write_p50_ms": _pctl(wl, 50),
                "read_p50_ms": _pctl(rl, 50),
            }


def _pctl(samples: list[float], p: int) -> float:
    if not samples:
        return 0.0
    samples = sorted(samples)
    k = max(0, min(len(samples) - 1, int(round((p / 100.0) * (len(samples) - 1)))))
    return samples[k]


class LoadRunner:
    def __init__(
        self,
        *,
        base_url: str,
        read_qps: float,
        write_qps: float,
        surveys: list[str],
        stats: Stats,
        insecure: bool,
    ) -> None:
        self.base = base_url.rstrip("/")
        self.read_qps = read_qps
        self.write_qps = write_qps
        self.surveys = surveys
        self.stats = stats
        self.client = httpx.AsyncClient(
            base_url=self.base,
            timeout=httpx.Timeout(30.0),
            verify=not insecure,
            headers={"User-Agent": "study-platform-loadtest/1.0"},
        )

    async def close(self) -> None:
        await self.client.aclose()

    async def write_once(self) -> None:
        t0 = time.perf_counter()
        name = f"LT-{uuid.uuid4()}"[:250]
        try:
            r1 = await self.client.post("/api/studies/", json={"name": name})
            if r1.status_code != 201:
                ms = (time.perf_counter() - t0) * 1000
                self.stats.record_write(False, ms, f"study {r1.status_code}: {r1.text[:200]}")
                return
            study_id = r1.json()["id"]
            body = self.surveys[uuid.uuid4().int % len(self.surveys)]
            r2 = await self.client.post(
                f"/api/studies/{study_id}/submissions/",
                json={"content": body},
            )
            ms = (time.perf_counter() - t0) * 1000
            if r2.status_code != 202:
                self.stats.record_write(False, ms, f"sub {r2.status_code}: {r2.text[:200]}")
                return
            js = r2.json()
            self.stats.add_pool(str(js["study_id"]), str(js["submission_id"]))
            self.stats.record_write(True, ms)
        except Exception as exc:  # noqa: BLE001
            ms = (time.perf_counter() - t0) * 1000
            self.stats.record_write(False, ms, repr(exc))

    async def read_once(self) -> None:
        t0 = time.perf_counter()
        try:
            with self.stats.lock:
                pool = list(self.stats.pool)
            if not pool:
                r = await self.client.get("/api/studies/", params={"limit": "10"})
                ms = (time.perf_counter() - t0) * 1000
                self.stats.record_read(r.status_code == 200, ms, f"{r.status_code}" if r.status_code != 200 else "")
                return
            roll = uuid.uuid4().int % 100
            if roll < 45:
                r = await self.client.get("/api/studies/", params={"limit": "10"})
            elif roll < 75:
                sid, _ = pool[uuid.uuid4().int % len(pool)]
                r = await self.client.get(f"/api/studies/{sid}/")
            else:
                sid, sub = pool[uuid.uuid4().int % len(pool)]
                r = await self.client.get(f"/api/studies/{sid}/submissions/{sub}/")
            ms = (time.perf_counter() - t0) * 1000
            self.stats.record_read(r.status_code == 200, ms, f"{r.status_code}" if r.status_code != 200 else "")
        except Exception as exc:  # noqa: BLE001
            ms = (time.perf_counter() - t0) * 1000
            self.stats.record_read(False, ms, repr(exc))

    async def write_loop(self, stop: asyncio.Event) -> None:
        if self.write_qps <= 0:
            return
        delay = 1.0 / self.write_qps
        while not stop.is_set():
            await self.write_once()
            try:
                await asyncio.wait_for(stop.wait(), timeout=delay)
            except TimeoutError:
                pass

    async def read_loop(self, stop: asyncio.Event) -> None:
        if self.read_qps <= 0:
            return
        delay = 1.0 / self.read_qps
        while not stop.is_set():
            await self.read_once()
            try:
                await asyncio.wait_for(stop.wait(), timeout=delay)
            except TimeoutError:
                pass


class LoadTestApp(App):
    BINDINGS = [("q", "quit", "Quit")]

    def __init__(self, args: argparse.Namespace) -> None:
        super().__init__()
        self.args = args
        data_dir = Path(__file__).resolve().parent / "data" / "surveys"
        self.surveys = load_survey_cache(data_dir)
        self.stats = Stats()
        self.runner = LoadRunner(
            base_url=args.base_url,
            read_qps=args.read_qps,
            write_qps=args.write_qps,
            surveys=self.surveys,
            stats=self.stats,
            insecure=args.insecure,
        )
        self._stop = asyncio.Event()
        self._tasks: list[asyncio.Task[Any]] = []

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield Container(
            Vertical(
                Static(id="metrics", expand=True),
                Static(id="hint", markup=True),
            ),
            id="main",
        )
        yield Footer()

    async def on_mount(self) -> None:
        self._t0 = time.perf_counter()
        self.query_one("#hint", Static).update(
            "[bold]q[/bold] quit  |  "
            f"base=[cyan]{self.args.base_url}[/cyan]  "
            f"read_qps={self.args.read_qps} write_qps={self.args.write_qps}  "
            f"surveys_cached={len(self.surveys)}"
        )
        self._tasks = [
            asyncio.create_task(self.runner.write_loop(self._stop)),
            asyncio.create_task(self.runner.read_loop(self._stop)),
        ]
        self.set_interval(0.2, self._refresh)

    async def on_unmount(self) -> None:
        self._stop.set()
        for t in self._tasks:
            t.cancel()
            try:
                await t
            except asyncio.CancelledError:
                pass
        await self.runner.close()

    def _refresh(self) -> None:
        s = self.stats.snapshot()
        elapsed = time.perf_counter() - self._t0
        text = (
            f"[bold]Load test[/bold]  elapsed={elapsed:.1f}s\n\n"
            f"Writes: ok={s['writes_ok']} err={s['writes_err']}  "
            f"p50={s['write_p50_ms']:.1f}ms p95={s['write_p95_ms']:.1f}ms\n"
            f"Reads:  ok={s['reads_ok']} err={s['reads_err']}  "
            f"p50={s['read_p50_ms']:.1f}ms p95={s['read_p95_ms']:.1f}ms\n"
            f"ID pool (for reads): {s['pool']}\n\n"
            f"[dim]Last error:[/dim]\n{s['last_error'] or '(none)'}"
        )
        self.query_one("#metrics", Static).update(text)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Study Platform API load test + TUI")
    p.add_argument("--base-url", default="https://api.charliesystems.ai", help="API base URL")
    p.add_argument("--read-qps", type=float, default=2.0, help="Target read requests per second (0=off)")
    p.add_argument("--write-qps", type=float, default=0.5, help="Target write pairs per second (0=off)")
    p.add_argument(
        "--insecure",
        action="store_true",
        help="Disable TLS certificate verification",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    if args.read_qps < 0 or args.write_qps < 0:
        raise SystemExit("QPS must be >= 0")
    if args.read_qps == 0 and args.write_qps == 0:
        raise SystemExit("Set at least one of --read-qps or --write-qps to a value > 0")
    LoadTestApp(args).run()


if __name__ == "__main__":
    main()
