"""Print a human-readable summary table from mongo_report.json."""
import json
from pathlib import Path

REPORT = Path("docs/legacy-analysis/mongo_report.json")


def fmt_bytes(n: int) -> str:
    for unit in ["B", "KB", "MB", "GB"]:
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}TB"


def main() -> None:
    data = json.loads(REPORT.read_text(encoding="utf-8-sig"))
    rows = sorted(data["collections"], key=lambda c: -(c.get("count") or 0))

    print(f"MongoDB {data['server_version']}  db={data['database']}  collections={data['collection_count']}")
    print()
    print(f"{'collection':38} {'docs':>10} {'avgSz':>9} {'storage':>10} {'idx':>4}")
    print("-" * 78)
    total_docs = 0
    total_storage = 0
    for r in rows:
        if "error" in r:
            print(f"{r['name']:38} ERROR: {r['error']}")
            continue
        c = r.get("count") or 0
        total_docs += c
        total_storage += r.get("storage_bytes") or 0
        print(
            f"{r['name']:38} {c:>10} "
            f"{fmt_bytes(int(r.get('avg_obj_size') or 0)):>9} "
            f"{fmt_bytes(int(r.get('storage_bytes') or 0)):>10} "
            f"{len(r.get('indexes', [])):>4}"
        )
    print("-" * 78)
    print(f"TOTAL                                  {total_docs:>10} "
          f"{'':>9} {fmt_bytes(total_storage):>10}")


if __name__ == "__main__":
    main()
