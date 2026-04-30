"""Analyze the legacy MTP MongoDB database (read-only).

Outputs a JSON report covering:
  - collection size, count, average document size
  - inferred top-level field types (sampling)
  - indexes
  - one anonymized sample document (truncated)

Usage:
  python tools/mongo_analyze.py > docs/legacy-analysis/mongo_report.json
"""
from __future__ import annotations

import json
from collections import Counter
from typing import Any

from bson import ObjectId
from pymongo import MongoClient

URI = "mongodb://mtpuser:Passw0rd@localhost:27019/mtp?authSource=mtp"
DB_NAME = "mtp"
SAMPLE_SIZE = 50


def bson_type(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "double"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    if isinstance(value, ObjectId):
        return "objectId"
    return type(value).__name__


def truncate(value: Any, depth: int = 0) -> Any:
    if depth > 3:
        return "..."
    if isinstance(value, dict):
        return {k: truncate(v, depth + 1) for k, v in list(value.items())[:20]}
    if isinstance(value, list):
        return [truncate(v, depth + 1) for v in value[:3]]
    if isinstance(value, str) and len(value) > 200:
        return value[:200] + "...(truncated)"
    if isinstance(value, ObjectId):
        return f"ObjectId({str(value)})"
    if isinstance(value, bytes):
        return f"<bytes len={len(value)}>"
    return value


def analyze_collection(db, name: str) -> dict:
    coll = db[name]
    stats = db.command("collStats", name)
    doc_count = stats.get("count", 0)
    size = stats.get("size", 0)
    storage = stats.get("storageSize", 0)
    avg_obj = stats.get("avgObjSize", 0)
    indexes = list(coll.list_indexes())
    index_info = [{"name": i["name"], "key": dict(i["key"])} for i in indexes]

    # Field profile from sample
    field_types: dict[str, Counter] = {}
    sample_doc = None
    if doc_count > 0:
        try:
            cursor = coll.aggregate([{"$sample": {"size": min(SAMPLE_SIZE, doc_count)}}])
        except Exception:
            cursor = coll.find().limit(SAMPLE_SIZE)
        for i, doc in enumerate(cursor):
            if i == 0:
                sample_doc = truncate(doc)
            for k, v in doc.items():
                field_types.setdefault(k, Counter())[bson_type(v)] += 1

    fields = {
        k: {t: c for t, c in cnt.most_common()} for k, cnt in field_types.items()
    }

    return {
        "name": name,
        "count": doc_count,
        "size_bytes": size,
        "storage_bytes": storage,
        "avg_obj_size": avg_obj,
        "indexes": index_info,
        "fields": fields,
        "sample": sample_doc,
    }


def main() -> None:
    client = MongoClient(URI, serverSelectionTimeoutMS=10000)
    info = client.server_info()
    db = client[DB_NAME]
    coll_names = sorted(db.list_collection_names())

    report = {
        "server_version": info.get("version"),
        "database": DB_NAME,
        "collection_count": len(coll_names),
        "collections": [],
    }
    for name in coll_names:
        try:
            report["collections"].append(analyze_collection(db, name))
        except Exception as ex:
            report["collections"].append({"name": name, "error": str(ex)})

    print(json.dumps(report, default=str, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
