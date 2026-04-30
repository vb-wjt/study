"""Side-by-side verification: Mongo collection counts vs. PostgreSQL row counts."""
from __future__ import annotations

import json
from pathlib import Path

import psycopg
from pymongo import MongoClient

MONGO_URI = "mongodb://mtpuser:Passw0rd@localhost:27019/mtp?authSource=mtp"
PG_DSN = "host=localhost port=5432 user=postgres password=Passw0rd dbname=mtp-postgresql"

PAIRS = [
    ("tenants",                  "iam.tenants"),
    ("users",                    "iam.users"),
    ("roles",                    "iam.roles"),
    ("permissions",              "iam.permissions"),
    ("relationships",            "iam.relationships"),
    ("apikey",                   "iam.api_keys"),
    ("trustcertificates",        "iam.trust_certificates"),
    ("coreschemas",              "metamodel.core_schemas"),
    ("metadatadefinitions",      "metamodel.metadata_definitions"),
    ("dictionaryterms",          "metamodel.dictionary_terms"),
    ("localizedstrings",         "metamodel.localized_strings"),
    ("categoryexts",             "metamodel.category_extensions"),
    ("applications",             "platform.applications"),
    ("pluginclassifications",    "platform.plugin_classifications"),
    ("plugins",                  "platform.plugins"),
    ("commands",                 "platform.commands"),
    ("functions",                "platform.functions"),
    ("topics",                   "platform.topics"),
    ("topiclisteners",           "platform.topic_listeners"),
    ("wstopiclisteners",         "platform.ws_topic_listeners"),
    ("queues",                   "platform.queues"),
    ("queuelisteners",           "platform.queue_listeners"),
    ("registry",                 "platform.registry"),
    ("systemsettings",           "platform.system_settings"),
    ("defaultconfig",            "platform.default_config"),
    ("exporttransformations",    "platform.export_transformations"),
    ("exportdatamappings",       "platform.export_data_mappings"),
    ("assetclassifications",     "device.asset_classifications"),
    ("protocolconfigurations",   "device.protocol_configurations"),
    ("baseobjects",              "device.base_objects"),
    ("monitoredobjects",         "device.monitored_objects"),
    ("detectiontasks",           "device.detection_tasks"),
    ("discovery",                "device.discoveries"),
    ("discoveryconstraints",     "device.discovery_constraints"),
    ("discoveredobjects",        "device.discovered_objects"),
    ("devicemgms",               "device.device_managements"),
    ("devicemodule",             "device.device_modules"),
    ("servermgms",               "device.server_managements"),
    ("trellisagent",             "device.trellis_agents"),
    ("monitoringdefinitions",    "monitoring.monitoring_definitions"),
    ("monitoringspecifications", "monitoring.monitoring_specifications"),
    ("productmonitoringmappings","monitoring.product_monitoring_mappings"),
    ("resourcetemplates",        "monitoring.resource_templates"),
    ("resourcestatusrules",      "monitoring.resource_status_rules"),
    ("events",                   "evt.events"),
    ("eventlogs",                "evt.event_logs"),
    ("audittrailgridmappings",   "evt.audit_trail_grid_mappings"),
    ("transformationrules",      "evt.transformation_rules"),
    ("alarms",                   "alarm.alarms"),
    ("alarmactionconfigs",       "alarm.alarm_action_configs"),
    ("alarmactionnodes",         "alarm.alarm_action_nodes"),
    ("alarmactionjobs",          "alarm.alarm_action_jobs"),
    ("actionspersisted",         "alarm.actions_persisted"),
    ("notificationconfigs",      "alarm.notification_configs"),
    ("notificationjobs",         "alarm.notification_jobs"),
    ("smsproviders",             "alarm.sms_providers"),
    ("trapconstraints",          "alarm.trap_constraints"),
    ("trapdestinations",         "alarm.trap_destinations"),
    ("jobs",                     "job.jobs"),
    ("scheduledjobs",            "job.scheduled_jobs"),
    ("locks",                    "job.locks"),
    ("tsd.datapoints",           "telemetry.datapoints"),
    ("tsddata",                  "telemetry.tsd_data"),
    ("electricdatas",            "telemetry.electric_data"),
    ("electricrateconfigs",      "telemetry.electric_rate_configs"),
    ("filemanager",              "file.file_metadata"),
    ("fs.files",                 "file.fs_files"),
    ("fs.chunks",                "file.fs_chunks"),
    ("licensedstructures",       "licensing.licensed_structures"),
    ("internallicensedfeatures", "licensing.internal_licensed_features"),
    ("licensedfeatures",         "licensing.licensed_features"),
    ("licensedproducts",         "licensing.licensed_products"),
]


def main() -> None:
    mongo = MongoClient(MONGO_URI, serverSelectionTimeoutMS=10000)["mtp"]
    rows = []
    with psycopg.connect(PG_DSN) as pg, pg.cursor() as cur:
        for coll, table in PAIRS:
            src = mongo[coll].count_documents({})
            cur.execute(f"SELECT count(*) FROM {table}")
            dst = cur.fetchone()[0]
            delta = dst - src
            status = "ok" if delta == 0 else ("more" if delta > 0 else "less")
            rows.append({"coll": coll, "table": table, "src": src, "dst": dst, "delta": delta, "status": status})

    total_src = sum(r["src"] for r in rows)
    total_dst = sum(r["dst"] for r in rows)
    print()
    print(f"{'collection':28} {'table':46} {'src':>6} {'dst':>6} {'delta':>6}  status")
    print("-" * 102)
    for r in rows:
        print(f"{r['coll']:28} {r['table']:46} {r['src']:>6} {r['dst']:>6} {r['delta']:>6}  {r['status']}")
    print("-" * 102)
    print(f"{'TOTAL':28} {'':46} {total_src:>6} {total_dst:>6} {total_dst-total_src:>6}")
    losses = [r for r in rows if r["status"] == "less"]
    print()
    if losses:
        print(f"NOTE: {len(losses)} table(s) with row loss:")
        for r in losses:
            print(f"  - {r['coll']} -> {r['table']} : -{-r['delta']}")
    else:
        print("All collections imported with full row parity.")

    Path("docs/migration").mkdir(parents=True, exist_ok=True)
    Path("docs/migration/etl_report.json").write_text(
        json.dumps({"rows": rows, "total_src": total_src, "total_dst": total_dst}, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
