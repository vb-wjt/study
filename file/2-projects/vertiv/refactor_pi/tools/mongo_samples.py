"""Print sample documents and field summaries for selected key collections."""
import json
from pathlib import Path

REPORT = Path("docs/legacy-analysis/mongo_report.json")

KEY_COLLECTIONS = [
    "tenants", "users", "roles", "permissions", "apikey",
    "applications", "plugins", "pluginclassifications",
    "monitoringdefinitions", "monitoringspecifications", "monitoredobjects",
    "productmonitoringmappings", "metadatadefinitions",
    "resourcetemplates", "resourcestatusrules", "assetclassifications", "categoryexts",
    "discovery", "discoveryconstraints", "discoveredobjects", "devicemgms", "devicemodule",
    "alarms", "alarmactionconfigs", "alarmactionnodes", "alarmactionjobs",
    "notificationconfigs", "notificationjobs", "smsproviders",
    "events", "eventlogs", "audittrailgridmappings",
    "jobs", "scheduledjobs", "detectiontasks", "actionspersisted",
    "queues", "queuelisteners", "topics", "topiclisteners", "wstopiclisteners",
    "tsd.datapoints", "tsddata", "electricdatas", "electricrateconfigs",
    "transformationrules", "exporttransformations", "exportdatamappings",
    "filemanager", "fs.files", "fs.chunks",
    "trapconstraints", "trapdestinations", "trellisagent",
    "licensedstructures", "licensedfeatures", "licensedproducts", "internallicensedfeatures",
    "trustcertificates", "systemsettings", "defaultconfig",
    "commands", "functions", "registry", "baseobjects", "coreschemas",
    "relationships", "dictionaryterms", "localizedstrings",
    "servermgms", "protocolconfigurations",
    "filemanager",
]


def main() -> None:
    data = json.loads(REPORT.read_text(encoding="utf-8-sig"))
    by_name = {c["name"]: c for c in data["collections"]}
    seen = set()
    for name in KEY_COLLECTIONS:
        if name in seen or name not in by_name:
            continue
        seen.add(name)
        c = by_name[name]
        print("=" * 80)
        print(f"# {name}    docs={c.get('count', 0)}  avg={int(c.get('avg_obj_size') or 0)}B")
        print("indexes:")
        for i in c.get("indexes", []):
            print(f"  - {i['name']}  key={i['key']}")
        print("fields:")
        fields = c.get("fields") or {}
        for fname in sorted(fields.keys()):
            print(f"  - {fname}: {fields[fname]}")
        print("sample:")
        sample = c.get("sample")
        if sample is not None:
            print(json.dumps(sample, indent=2, default=str, ensure_ascii=False)[:4000])
        print()


if __name__ == "__main__":
    main()
