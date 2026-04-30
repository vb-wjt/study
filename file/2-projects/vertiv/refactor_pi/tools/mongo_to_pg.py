"""ETL: MongoDB (mtp) -> PostgreSQL (mtp-postgresql).

Reads from the local Mongo instance described in the legacy analysis and
loads each collection into the corresponding PostgreSQL table created by
db/postgres/*.sql.

Run:
    python tools/mongo_to_pg.py

Strategy:
  * One mapper per Mongo collection. Each mapper takes a Mongo document and
    returns either a dict (single row) or a list of dicts (1->N).
  * The driver loads collections in dependency order so foreign keys hold.
  * Bulk insert via psycopg `executemany` with `Jsonb` adapters for JSONB
    columns and Python lists for TEXT[] columns.
  * After each table, prints SRC_COUNT vs DST_COUNT.
"""
from __future__ import annotations

import logging
import re
from datetime import date, datetime, timezone
from typing import Any, Callable, Iterable

import psycopg
from bson import ObjectId
from psycopg.types.json import Jsonb
from pymongo import MongoClient

# ---------------------------------------------------------------------------
# Connections
# ---------------------------------------------------------------------------
MONGO_URI = "mongodb://mtpuser:Passw0rd@localhost:27019/mtp?authSource=mtp"
PG_DSN = "host=localhost port=5432 user=postgres password=Passw0rd dbname=mtp-postgresql"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("etl")

# ---------------------------------------------------------------------------
# Generic helpers
# ---------------------------------------------------------------------------
ISO_Z_RE = re.compile(r"Z$")


def oid(v: Any) -> str | None:
    """Coerce ObjectId / str / None to 24-hex string."""
    if v is None or v == "":
        return None
    if isinstance(v, ObjectId):
        return str(v)
    s = str(v)
    if re.fullmatch(r"[0-9a-fA-F]{24}", s):
        return s.lower()
    return None


def to_ts(v: Any) -> datetime | None:
    """ISO string / epoch ms / datetime -> aware datetime."""
    if v is None or v == "":
        return None
    if isinstance(v, datetime):
        return v if v.tzinfo else v.replace(tzinfo=timezone.utc)
    if isinstance(v, (int, float)):
        # epoch ms (Mongo tsd.datapoints style)
        return datetime.fromtimestamp(v / 1000.0, tz=timezone.utc)
    if isinstance(v, str):
        s = ISO_Z_RE.sub("+00:00", v)
        try:
            dt = datetime.fromisoformat(s)
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


def to_date(v: Any) -> date | None:
    if v is None or v == "":
        return None
    if isinstance(v, date) and not isinstance(v, datetime):
        return v
    if isinstance(v, datetime):
        return v.date()
    if isinstance(v, str):
        try:
            return datetime.strptime(v[:10], "%Y-%m-%d").date()
        except ValueError:
            return None
    return None


def to_jsonb(v: Any) -> Jsonb | None:
    if v is None:
        return None
    return Jsonb(v, dumps=_jsonb_dumps)


def _jsonb_dumps(obj: Any) -> str:
    """JSON dumper that handles ObjectId, datetime, bytes."""
    import json

    def default(o: Any) -> Any:
        if isinstance(o, ObjectId):
            return str(o)
        if isinstance(o, datetime):
            return o.isoformat()
        if isinstance(o, date):
            return o.isoformat()
        if isinstance(o, bytes):
            return o.hex()
        raise TypeError(f"Unserializable type {type(o).__name__}")

    return json.dumps(obj, default=default, ensure_ascii=False)


def arr(v: Any) -> list | None:
    if v is None:
        return None
    if isinstance(v, list):
        return v
    return [v]


def base_audit(doc: dict, *, with_modified: bool = False) -> dict:
    """Extract the standard `_createdBy/_createdDateTime/...` fields."""
    out = {
        "type": doc.get("_type"),
        "hierarchy": doc.get("_hierarchy") or [],
        "created_by": doc.get("_createdBy") or "",
        "created_at": to_ts(doc.get("_createdDateTime")) or datetime.now(timezone.utc),
    }
    if with_modified:
        out["modified_by"] = doc.get("_modifiedBy")
        out["modified_at"] = to_ts(doc.get("_modifiedDateTime"))
    return out


def parse_decimal(v: Any) -> float | None:
    if v is None:
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# Mapper definitions: Mongo collection -> (PG schema.table, mapper fn)
# Each mapper returns a dict whose keys are column names of the target table.
# ---------------------------------------------------------------------------
def map_tenants(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "tenant_name": d.get("tenantName"),
        "description": d.get("description"),
        "contact": d.get("contact"),
        "parent_id": d.get("parentId"),
        "descendant_access": bool(d.get("descendantAccess", False)),
        **base_audit(d),
    }


def map_users(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "username": d.get("username"),
        "programmatic_name": d.get("programmaticName"),
        "password_hash": d.get("password"),
        "email": d.get("email"),
        "temporary_password": bool(d.get("temporaryPassword", False)),
        "provider_type": d.get("providerType"),
        "category": d.get("category"),
        "tenant_id": oid(d.get("_tenant")),
        **base_audit(d, with_modified=True),
    }


def map_roles(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "programmatic_name": d.get("programmaticName"),
        "description": d.get("description"),
        "category": d.get("category"),
        **base_audit(d),
    }


def map_permissions(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "programmatic_name": d.get("programmaticName"),
        "category": d.get("category"),
        **base_audit(d),
    }


def map_relationships(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "source_id": oid(d.get("sourceId") or d.get("_sourceId")),
        "target_id": oid(d.get("targetId") or d.get("_targetId")),
        "context": d.get("context"),
        "type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or ["AbstractRelationship"],
        "parent_ids": d.get("parentIds"),
        "priority": d.get("priority"),
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


def map_apikey(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "api_key_hash": d.get("apiKeyHash") or d.get("hash") or "",
        "owner_user_id": oid(d.get("ownerUserId")),
        "enabled": bool(d.get("enabled", True)),
        "expires_at": to_ts(d.get("expiresAt")),
        **base_audit(d, with_modified=True),
        "properties": to_jsonb({k: v for k, v in d.items() if k not in {"_id", "_type", "_hierarchy", "_createdBy", "_createdDateTime", "_modifiedBy", "_modifiedDateTime", "name", "apiKeyHash", "hash", "ownerUserId", "enabled", "expiresAt"}}),
    }


def map_trustcerts(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "cert_type": d.get("certType"),
        "size": d.get("size") or 0,
        "category": d.get("category"),
        "file_data": bytes(d.get("fileData") or b""),
        "details": to_jsonb(d.get("details") or {}),
        **base_audit(d),
    }


# --- metamodel -------------------------------------------------------------
def map_coreschemas(d: dict) -> dict:
    return {
        "id": d["_id"],
        "schema_text": d.get("schema") or "",
        "created_at": datetime.now(timezone.utc),
    }


def map_metadatadefs(d: dict) -> dict:
    # The Mongo dump shows '$schema' as the wide-character variant '＄schema'
    # in the analysis file, but the actual key in the database is '$schema'.
    schema_dollar = d.get("$schema") or d.get("＄schema")
    return {
        "id": oid(d["_id"]),
        "schema_id": d.get("id"),
        "title": d.get("title"),
        "description": d.get("description"),
        "version": d.get("version"),
        "type": d.get("type"),
        "schema_dollar": schema_dollar,
        "definition_type": d.get("definitionType"),
        "parent": d.get("parent"),
        "path": d.get("path"),
        "model_configuration": to_jsonb(d.get("modelConfiguration")),
        "service_configuration": to_jsonb(d.get("serviceConfiguration")),
        "properties": to_jsonb(d.get("properties")),
        "required": to_jsonb(d.get("required")),
        "includes": to_jsonb(d.get("includes")),
        "definitions": to_jsonb(d.get("definitions")),
        "owner": d.get("_owner"),
        "metadata_type": d.get("_type") or "MetaDataDefinition",
        "hierarchy": d.get("_hierarchy") or ["MetaDataDefinition"],
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


_DICT_PROMOTED_KEYS = {
    "_id", "_type", "_hierarchy", "_createdBy", "_createdDateTime",
    "programmaticName", "classification", "providedByPlugin",
    "access", "valueType", "constraintType", "precision",
    "baseUomProgrammaticName", "preferredUomProgrammaticName",
    "datapointSource", "datapointCategoryProgrammaticNames",
    "isAlarmEvent", "isThresholdEvent", "activeOrClear",
    "eventClassification", "defaultSeverityProgrammaticName",
    "effectiveSeverityProgrammaticName", "showAsAvailableHoverSetting",
}


def map_dictterms(d: dict) -> dict:
    payload = {k: v for k, v in d.items() if k not in _DICT_PROMOTED_KEYS}
    return {
        "id": oid(d["_id"]),
        "programmatic_name": d.get("programmaticName"),
        "classification": d.get("classification"),
        "type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or [],
        "provided_by_plugin": d.get("providedByPlugin") or "",
        "access": d.get("access"),
        "value_type": d.get("valueType"),
        "constraint_type": d.get("constraintType"),
        "precision": d.get("precision"),
        "base_uom_programmatic_name": d.get("baseUomProgrammaticName"),
        "preferred_uom_programmatic_name": d.get("preferredUomProgrammaticName"),
        "datapoint_source": d.get("datapointSource"),
        "datapoint_category_names": d.get("datapointCategoryProgrammaticNames"),
        "is_alarm_event": d.get("isAlarmEvent"),
        "is_threshold_event": d.get("isThresholdEvent"),
        "active_or_clear": d.get("activeOrClear"),
        "event_classification": d.get("eventClassification"),
        "default_severity_programmatic_name": d.get("defaultSeverityProgrammaticName"),
        "effective_severity_programmatic_name": d.get("effectiveSeverityProgrammaticName"),
        "show_as_available_hover_setting": d.get("showAsAvailableHoverSetting"),
        "payload": to_jsonb(payload),
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


def map_localizedstrings(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "key": d.get("key"),
        "message": to_jsonb(d.get("message") or {}),
        **base_audit(d),
    }


def map_categoryexts(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "category_name": d.get("categoryName"),
        "extension_name": d.get("extensionName"),
        **base_audit(d),
    }


# --- platform --------------------------------------------------------------
def map_applications(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "app_identifier": d.get("appIdentifier"),
        "display_name": d.get("displayName"),
        "description": d.get("description"),
        "version": d.get("version"),
        "product_version": d.get("productVersion"),
        "platform_version": d.get("platformVersion"),
        "vendor": d.get("vendor"),
        "default_locale": d.get("defaultLocale"),
        "license_agreement": d.get("licenseAgreement"),
        "configuration_class": d.get("configurationClass"),
        "dependencies": to_jsonb(d.get("dependencies") or []),
        **base_audit(d),
    }


def map_pluginclassifications(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "classification_name": d.get("classificationName"),
        "allow_delete": bool(d.get("allowDelete", False)),
        "allow_disable": bool(d.get("allowDisable", False)),
        "allow_stop": bool(d.get("allowStop", False)),
        "allow_multiple_plugins": bool(d.get("allowMultiplePlugins", False)),
        "delete_after_add": bool(d.get("deleteAfterAdd", False)),
        "delete_zip_after_add": bool(d.get("deleteZipAfterAdd", False)),
        "classification_properties_schema_id": d.get("classificationPropertiesSchemaId"),
        "static_resource_mappings": to_jsonb(d.get("staticResourceMappings")),
        **base_audit(d),
    }


def map_plugins(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "version": d.get("version"),
        "platform_version": d.get("platformVersion"),
        "vendor": d.get("vendor"),
        "description": d.get("description"),
        "classification": d.get("classification"),
        "configuration_class": d.get("configurationClass"),
        "administration_state": d.get("administrationState"),
        "installation_state": d.get("installationState"),
        "installation_originator": d.get("installationOriginator"),
        "autoupgrade": to_jsonb(d.get("autoupgrade")),
        "dependencies": to_jsonb(d.get("dependencies")),
        "handlers": to_jsonb(d.get("handlers")),
        "topics": to_jsonb(d.get("topics")),
        "topic_listeners": to_jsonb(d.get("topicListeners")),
        "queues": to_jsonb(d.get("queues")),
        "queue_listeners": to_jsonb(d.get("queueListeners")),
        "commands": to_jsonb(d.get("commands")),
        **base_audit(d, with_modified=True),
    }


def map_commands(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "programmatic_name": d.get("programmaticName"),
        "owner": d.get("owner"),
        "version": d.get("version"),
        "description": d.get("description"),
        "help": d.get("help"),
        "parameter_schema_id": d.get("parameterSchemaId"),
        "return_schema_id": d.get("returnSchemaId"),
        "on_execute_command": to_jsonb(d.get("onExecuteCommand") or {}),
        "cluster_selector": to_jsonb(d.get("clusterSelector") or {}),
        "execution_timeout_seconds": d.get("executionTimeout") or 0,
        "expected_completion_seconds": d.get("expectedCompletionTime") or 0,
        "top_tenant_execution_only": bool(d.get("topTenantExecutionOnly", False)),
        **base_audit(d),
    }


def map_functions(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "programmatic_name": d.get("programmaticName"),
        "description": d.get("description"),
        "parameters": to_jsonb(d.get("parameters") or {}),
        "expressions": to_jsonb(d.get("expressions") or []),
        **base_audit(d),
    }


def map_topics(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "owner": d.get("owner"),
        "topic_item_schema_id": d.get("topicItemSchemaId"),
        **base_audit(d),
    }


def map_topiclisteners(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "topic_name": d.get("topicName"),
        "owner": d.get("owner"),
        "local": bool(d.get("local", False)),
        "on_topic_message": to_jsonb(d.get("onTopicMessage") or {}),
        **base_audit(d),
    }


def map_wstopiclisteners(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "ws_session_id": d.get("wsSessionId"),
        "topic_name": d.get("topicName"),
        **base_audit(d),
    }


def map_queues(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "owner": d.get("owner"),
        "queue_item_schema_id": d.get("queueItemSchemaId"),
        "timeout_seconds": d.get("timeout") or 0,
        "max_size": d.get("maxSize") or 0,
        "backup_count": d.get("backupCount") or 0,
        "async_backup_count": d.get("asyncBackupCount") or 0,
        "empty_queue_ttl_seconds": d.get("emptyQueueTtl") or -1,
        **base_audit(d),
    }


def map_queuelisteners(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "queue_name": d.get("queueName"),
        "owner": d.get("owner"),
        "local": bool(d.get("local", False)),
        "on_queue_entry_added": to_jsonb(d.get("onQueueEntryAdded") or {}),
        **base_audit(d),
    }


def map_registry(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "category": d.get("category"),
        "key": d.get("key"),
        "entry_type": d.get("entryType"),
        "entry_value": d.get("entryValue"),
        "encrypted": bool(d.get("encrypted", False)),
        **base_audit(d),
    }


def map_systemsettings(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "system_version": d.get("systemVersion"),
        "db_state": d.get("dbState"),
        "upgrade_report": to_jsonb(d.get("upgradeReport") or {}),
        "licensing_configuration": to_jsonb(d.get("licensingConfiguration") or {}),
        "singleton": True,
    }


def map_defaultconfig(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "config_key": d.get("key") or d.get("configKey") or str(d.get("_id")),
        "payload": to_jsonb({k: v for k, v in d.items() if k != "_id"}),
        **base_audit(d),
    }


def map_exporttransformations(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "service_name": d.get("serviceName"),
        "banned_projections": d.get("bannedProjections") or [],
        "transformations": to_jsonb(d.get("transformations") or {}),
        **base_audit(d),
    }


def map_exportdatamappings(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "mapping_name": d.get("mappingName"),
        "column_name_to_source_mapping": to_jsonb(d.get("columnNameToSourceMapping") or []),
        **base_audit(d),
    }


# --- device ----------------------------------------------------------------
def map_assetclassifications(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "programmatic_name": d.get("programmaticName"),
        **base_audit(d),
    }


def map_protocolconfigs(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "protocol_programmatic_name": d.get("protocolProgrammaticName"),
        "enable_discovery_use": bool(d.get("enableDiscoveryUse", False)),
        "communication_properties": to_jsonb(d.get("communicationProperties") or {}),
        "snmp": to_jsonb(d.get("snmp")),
        "discovery": to_jsonb(d.get("discovery")),
        **base_audit(d, with_modified=True),
    }


_BASEOBJECT_PROMOTED = {
    "_id", "_type", "_hierarchy", "_createdBy", "_createdDateTime",
    "_modifiedBy", "_modifiedDateTime",
    "name", "primaryCategoryProgrammaticName", "obwiUrl", "categories",
    "product", "images", "specificProperties", "agentIdentifications",
    "monitoringConfiguration", "signalTemplate", "userDefinedProperties",
    "status", "identification", "communicationProperties",
    "platformIdentification", "platformCommunicationProperties",
    "operationalState", "engineTypeProgrammaticName",
    "customStatusUpdates", "requestsRegistrationRetries",
}


def map_baseobjects(d: dict) -> dict:
    extra = {k: v for k, v in d.items() if k not in _BASEOBJECT_PROMOTED}
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or [],
        "primary_category_programmatic_name": d.get("primaryCategoryProgrammaticName"),
        "obwi_url": d.get("obwiUrl"),
        "categories": d.get("categories"),
        "product": to_jsonb(d.get("product")),
        "images": to_jsonb(d.get("images")),
        "specific_properties": to_jsonb(d.get("specificProperties")),
        "agent_identifications": to_jsonb(d.get("agentIdentifications")),
        "monitoring_configuration": to_jsonb(d.get("monitoringConfiguration")),
        "signal_template": to_jsonb(d.get("signalTemplate")),
        "user_defined_properties": to_jsonb(d.get("userDefinedProperties")),
        "status": to_jsonb(d.get("status")),
        "identification": to_jsonb(d.get("identification")),
        "communication_properties": to_jsonb(d.get("communicationProperties")),
        "platform_identification": to_jsonb(d.get("platformIdentification")),
        "platform_communication_properties": to_jsonb(d.get("platformCommunicationProperties")),
        "operational_state": to_jsonb(d.get("operationalState")),
        "engine_type_programmatic_name": d.get("engineTypeProgrammaticName"),
        "custom_status_updates": d.get("customStatusUpdates"),
        "requests_registration_retries": d.get("requestsRegistrationRetries"),
        "extra": to_jsonb(extra) if extra else to_jsonb({}),
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
        "modified_by": d.get("_modifiedBy"),
        "modified_at": to_ts(d.get("_modifiedDateTime")),
    }


def map_monitoredobjects(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "object_id": oid(d.get("objectId")),
        "object_classification_programmatic_name": d.get("objectClassificationProgrammaticName"),
        "object_name": d.get("objectName"),
        "request_time": to_ts(d.get("requestTime")) or datetime.now(timezone.utc),
        "distribution_status": d.get("distributionStatus"),
        "waiting_for_engine": bool(d.get("waitingForEngine", False)),
        "retry_count": d.get("retryCount") or 0,
        "engine_id": oid(d.get("engineId")),
        "dependencies": to_jsonb(d.get("dependencies") or {}),
        "monitoring_configuration": to_jsonb(d.get("monitoringConfiguration") or {}),
        "agent": to_jsonb(d.get("agent") or {}),
        "components": to_jsonb(d.get("components") or []),
        **base_audit(d, with_modified=True),
    }


def map_detectiontasks(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "detection_type": d.get("detectionType"),
        "command_programmatic_name": d.get("commandProgrammaticName"),
        "assigning_classification_programmatic_name": d.get("assigningClassificationProgrammaticName"),
        "configuration_programmatic_name": d.get("configurationProgrammaticName"),
        "adding_properties": to_jsonb(d.get("addingProperties")),
        "detection_rules": to_jsonb(d.get("detectionRules")),
        **base_audit(d),
    }


# --- monitoring ------------------------------------------------------------
def map_monitoringdefs(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "programmatic_name": d.get("programmaticName"),
        "custom": bool(d.get("custom", False)),
        "override": bool(d.get("override", False)),
        "protocol_identifier": d.get("protocolIdentifier"),
        "version": d.get("version"),
        "components": to_jsonb(d.get("components") or []),
        **base_audit(d),
    }


def map_monitoringspecs(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "programmatic_name": d.get("programmaticName"),
        "description": d.get("description"),
        "category": d.get("category"),
        "protocol_identifier": d.get("protocolIdentifier"),
        "product_references": d.get("productReferences") or [],
        "monitoring_properties": to_jsonb(d.get("monitoringProperties") or {}),
        "components": to_jsonb(d.get("components") or []),
        "custom": bool(d.get("custom", False)),
        "override": bool(d.get("override", False)),
        "sharable": bool(d.get("sharable", True)),
        "product_monitoring_mapping_independent": bool(d.get("productMonitoringMappingIndependent", False)),
        **base_audit(d),
    }


def map_pmm(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "product_programmatic_name": d.get("productProgrammaticName"),
        "type_identifier_tag": d.get("typeIdentifierTag"),
        "management_module": d.get("managementModule"),
        "version": d.get("version"),
        "protocol_identifier": d.get("protocolIdentifier"),
        "monitoring_definition_references": d.get("monitoringDefinitionReferences") or [],
        "custom": bool(d.get("custom", False)),
        "override": bool(d.get("override", False)),
        "object_type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or [],
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


def map_resourcetemplates(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "version": d.get("version"),
        "classifier": d.get("classifier"),
        "product": to_jsonb(d.get("product") or {}),
        "commands": to_jsonb(d.get("commands") or []),
        **base_audit(d),
    }


def map_resourcestatusrules(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "alarm_mapping": to_jsonb(d.get("alarmMapping") or {}),
        "target_resource": to_jsonb(d.get("targetResource") or {}),
        **base_audit(d),
    }


# --- evt -------------------------------------------------------------------
def map_events(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "type": d.get("type"),
        "category": d.get("category"),
        "severity_programmatic_name": d.get("severityProgrammaticName"),
        "timestamp": to_ts(d.get("timestamp")) or datetime.now(timezone.utc),
        "origin_id": d.get("originId") or "",
        "resource_id": oid(d.get("resourceId")),
        "resource_name": d.get("resourceName"),
        "component_identifier": d.get("componentIdentifier"),
        "message": d.get("message") or "",
        "parameters": to_jsonb(d.get("parameters")),
        "data": to_jsonb(d.get("data")),
        "object_type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or [],
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


def map_eventlogs(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "event_type": d.get("eventType"),
        "event_name": d.get("eventName"),
        "source_name": d.get("sourceName"),
        "plugin_id": d.get("pluginId"),
        "timestamp": to_ts(d.get("timestamp")) or datetime.now(timezone.utc),
        "detail_data": to_jsonb(d.get("detailData")),
        "detail_data_keys": d.get("detailDataKeys"),
        **base_audit(d),
    }


def map_audittrailgridmappings(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "type": d.get("type"),
        "path": d.get("path"),
        "object_type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or [],
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


def map_transformationrules(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "description": d.get("description"),
        "type": d.get("type"),
        "source_path": d.get("sourcePath"),
        "target": to_jsonb(d.get("target") or {}),
        "object_type": d.get("_type"),
        "hierarchy": d.get("_hierarchy") or [],
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
    }


# --- alarm (mostly empty) --------------------------------------------------
def map_smsproviders(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "service_path": d.get("servicePath"),
        "enabled": bool(d.get("enabled", True)),
        "settings": to_jsonb({k: v for k, v in d.items() if k not in {"_id", "_type", "_hierarchy", "_createdBy", "_createdDateTime", "servicePath", "enabled"}}),
        **base_audit(d),
    }


# --- job -------------------------------------------------------------------
def map_jobs(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "command_programmatic_name": d.get("commandProgrammaticName"),
        "scheduled_job_id": oid(d.get("scheduledJobId")),
        "run_mode": d.get("runMode"),
        "state": d.get("state"),
        "status": d.get("status"),
        "active": bool(d.get("active", False)),
        "run_on_create": bool(d.get("runOnCreate", False)),
        "priority": d.get("priority") or 4,
        "time_to_live_hours": d.get("timeToLive") or 0,
        "parent_jobs": d.get("parentJobs") or [],
        "run_as_execution_context": to_jsonb(d.get("runAsExecutionContext") or {}),
        "results": to_jsonb(d.get("results")),
        "parameter_data": to_jsonb(d.get("parameterData")),
        "start_time": to_ts(d.get("startTime")),
        "end_time": to_ts(d.get("endTime")),
        **base_audit(d, with_modified=True),
    }


def map_scheduledjobs(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "command_programmatic_name": d.get("commandProgrammaticName"),
        "schedule": to_jsonb(d.get("schedule") or {}),
        "type": d.get("_type") or "Scheduler",
        "schedule_type": d.get("type") or "system",
        "active": bool(d.get("active", True)),
        "state": d.get("state") or "enabled",
        "execution_history": bool(d.get("executionHistory", False)),
        "execution_context": to_jsonb(d.get("executionContext") or {}),
        "parameter_data": to_jsonb(d.get("parameterData")),
        "last_execution_id": oid(d.get("lastExecutionId")),
        "hierarchy": d.get("_hierarchy") or ["Scheduler"],
        "created_by": d.get("_createdBy") or "",
        "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
        "modified_by": d.get("_modifiedBy"),
        "modified_at": to_ts(d.get("_modifiedDateTime")),
    }


def map_locks(d: dict) -> dict:
    return {
        "id": str(d.get("_id")),
        "locked_by": d.get("lockedBy") or d.get("owner"),
        "locked_at": to_ts(d.get("lockedAt")) or datetime.now(timezone.utc),
        "expires_at": to_ts(d.get("expiresAt")),
    }


# --- telemetry -------------------------------------------------------------
def map_tsd_datapoints(d: dict) -> list[dict]:
    """Mongo: tsd.datapoints -> telemetry.datapoints (1:1).

    Each Mongo doc has name/timestamp(ms)/value/tags{sensorId}.
    PG composite PK is (sensor_id, metric_name, ts) so we deduplicate on the
    fly inside one batch (rare, but possible if the source has duplicates).
    """
    tags = d.get("tags") or {}
    sensor_id = tags.get("sensorId") or ""
    return [{
        "sensor_id": sensor_id,
        "metric_name": d.get("name") or "",
        "ts": to_ts(d.get("timestamp")) or datetime.now(timezone.utc),
        "value_num": parse_decimal(d.get("value")),
        "value_text": str(d["value"]) if d.get("value") is not None else None,
        "tags": to_jsonb(tags),
    }]


def map_electricdatas(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "device_id": oid(d.get("deviceId")),
        "day": to_date(d.get("time")),
        "hour": int(d.get("hour") or 0),
        "origin_value": parse_decimal(d.get("originValue")) or 0,
        "consumption": parse_decimal(d.get("consumption")) or 0,
        **base_audit(d),
    }


# --- file ------------------------------------------------------------------
def map_filemanager(d: dict) -> dict:
    loc = d.get("location") or {}
    addr = loc.get("address")
    # Address is sometimes printed as 'BsonObjectId{value=...}' string in dumps;
    # in the live DB it is a real ObjectId. Normalize to plain string.
    if isinstance(addr, ObjectId):
        addr = str(addr)
    elif isinstance(addr, str) and addr.startswith("BsonObjectId{value="):
        addr = addr[len("BsonObjectId{value="):-1]
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "file_path": d.get("filePath"),
        "full_name": d.get("fullName"),
        "file_type": d.get("fileType"),
        "content_type": d.get("contentType"),
        "size_bytes": d.get("size") or 0,
        "location_type": loc.get("type") or "db",
        "location_address": str(addr) if addr is not None else "",
        **base_audit(d, with_modified=True),
    }


def map_fsfiles(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "filename": d.get("filename"),
        "length": d.get("length") or 0,
        "chunk_size": d.get("chunkSize") or 0,
        "upload_date": to_ts(d.get("uploadDate")) or datetime.now(timezone.utc),
        "metadata": to_jsonb(d.get("metadata") or {}),
    }


def map_fschunks(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "files_id": oid(d.get("files_id")),
        "n": d.get("n") or 0,
        "data": bytes(d.get("data") or b""),
    }


# --- licensing -------------------------------------------------------------
def map_licensedstructures(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "feature_type": d.get("featureType"),
        "model": d.get("model"),
        "operation": d.get("operation"),
        "action_name": d.get("actionName"),
        **base_audit(d),
    }


def map_internallicensedfeatures(d: dict) -> dict:
    return {
        "id": oid(d["_id"]),
        "name": d.get("name"),
        "feature_version": d.get("featureVersion"),
        "quota_count": d.get("count") or 0,
        **base_audit(d),
    }


# --- generic placeholder for empty skeleton tables -------------------------
def make_placeholder_mapper(extra_cols: dict[str, Callable[[dict], Any]] | None = None) -> Callable[[dict], dict]:
    extra_cols = extra_cols or {}

    def fn(d: dict) -> dict:
        out = {
            "id": oid(d["_id"]),
            "payload": to_jsonb({k: v for k, v in d.items() if k != "_id"}),
            "type": d.get("_type"),
            "hierarchy": d.get("_hierarchy") or [],
            "created_at": to_ts(d.get("_createdDateTime")) or datetime.now(timezone.utc),
        }
        if "created_by" not in extra_cols:
            out["created_by"] = d.get("_createdBy") or ""
        for k, getter in extra_cols.items():
            out[k] = getter(d)
        return out

    return fn


# ---------------------------------------------------------------------------
# Registry: ordered list of (mongo_collection, pg_table, mapper, options)
# Order matters for FK satisfaction.
# ---------------------------------------------------------------------------
PIPELINE: list[tuple[str, str, Callable[[dict], Any], dict]] = [
    # -- iam (tenants must precede users; users precede api_keys)
    ("tenants",                 "iam.tenants",                       map_tenants, {}),
    ("users",                   "iam.users",                         map_users, {}),
    ("roles",                   "iam.roles",                         map_roles, {}),
    ("permissions",             "iam.permissions",                   map_permissions, {}),
    ("relationships",           "iam.relationships",                 map_relationships, {}),
    ("apikey",                  "iam.api_keys",                      map_apikey, {}),
    ("trustcertificates",       "iam.trust_certificates",            map_trustcerts, {}),

    # -- metamodel
    ("coreschemas",             "metamodel.core_schemas",            map_coreschemas, {}),
    ("metadatadefinitions",     "metamodel.metadata_definitions",    map_metadatadefs, {}),
    ("dictionaryterms",         "metamodel.dictionary_terms",        map_dictterms, {}),
    ("localizedstrings",        "metamodel.localized_strings",       map_localizedstrings, {}),
    ("categoryexts",            "metamodel.category_extensions",     map_categoryexts, {}),

    # -- platform (plugin_classifications precedes plugins)
    ("applications",            "platform.applications",             map_applications, {}),
    ("pluginclassifications",   "platform.plugin_classifications",   map_pluginclassifications, {}),
    ("plugins",                 "platform.plugins",                  map_plugins, {}),
    ("commands",                "platform.commands",                 map_commands, {}),
    ("functions",               "platform.functions",                map_functions, {}),
    ("topics",                  "platform.topics",                   map_topics, {}),
    ("topiclisteners",          "platform.topic_listeners",          map_topiclisteners, {}),
    ("wstopiclisteners",        "platform.ws_topic_listeners",       map_wstopiclisteners, {}),
    ("queues",                  "platform.queues",                   map_queues, {}),
    ("queuelisteners",          "platform.queue_listeners",          map_queuelisteners, {}),
    ("registry",                "platform.registry",                 map_registry, {}),
    ("systemsettings",          "platform.system_settings",          map_systemsettings, {}),
    ("defaultconfig",           "platform.default_config",           map_defaultconfig, {}),
    ("exporttransformations",   "platform.export_transformations",   map_exporttransformations, {}),
    ("exportdatamappings",      "platform.export_data_mappings",     map_exportdatamappings, {}),

    # -- device (base_objects precedes monitored_objects + electric_data)
    ("assetclassifications",    "device.asset_classifications",      map_assetclassifications, {}),
    ("protocolconfigurations",  "device.protocol_configurations",    map_protocolconfigs, {}),
    ("baseobjects",             "device.base_objects",               map_baseobjects, {}),
    ("monitoredobjects",        "device.monitored_objects",          map_monitoredobjects, {}),
    ("detectiontasks",          "device.detection_tasks",            map_detectiontasks, {}),
    ("discovery",               "device.discoveries",                make_placeholder_mapper(), {}),
    ("discoveryconstraints",    "device.discovery_constraints",      make_placeholder_mapper({"name": lambda d: d.get("name")}), {}),
    ("discoveredobjects",       "device.discovered_objects",         make_placeholder_mapper({
        "identification_address": lambda d: (d.get("identification") or {}).get("address"),
        "mac_address":            lambda d: d.get("macAddress"),
    }), {}),
    ("devicemgms",              "device.device_managements",         make_placeholder_mapper(), {}),
    ("devicemodule",            "device.device_modules",             make_placeholder_mapper(), {}),
    ("servermgms",              "device.server_managements",         make_placeholder_mapper(), {}),
    ("trellisagent",            "device.trellis_agents",             make_placeholder_mapper(), {}),

    # -- monitoring
    ("monitoringdefinitions",   "monitoring.monitoring_definitions", map_monitoringdefs, {}),
    ("monitoringspecifications","monitoring.monitoring_specifications", map_monitoringspecs, {}),
    ("productmonitoringmappings","monitoring.product_monitoring_mappings", map_pmm, {}),
    ("resourcetemplates",       "monitoring.resource_templates",     map_resourcetemplates, {}),
    ("resourcestatusrules",     "monitoring.resource_status_rules",  map_resourcestatusrules, {}),

    # -- evt
    ("events",                  "evt.events",                        map_events, {}),
    ("eventlogs",               "evt.event_logs",                    map_eventlogs, {}),
    ("audittrailgridmappings",  "evt.audit_trail_grid_mappings",     map_audittrailgridmappings, {}),
    ("transformationrules",     "evt.transformation_rules",          map_transformationrules, {}),

    # -- alarm (almost all empty)
    ("alarms",                  "alarm.alarms",                      make_placeholder_mapper(), {}),
    ("alarmactionconfigs",      "alarm.alarm_action_configs",        make_placeholder_mapper({"name": lambda d: d.get("name")}), {}),
    ("alarmactionnodes",        "alarm.alarm_action_nodes",          make_placeholder_mapper({
        "node_id":   lambda d: d.get("nodeId") or "",
        "config_id": lambda d: oid(d.get("configId")),
    }), {}),
    ("alarmactionjobs",         "alarm.alarm_action_jobs",           make_placeholder_mapper({
        "alarm_id_list": lambda d: d.get("alarmIdList") or [],
        "state":         lambda d: d.get("state"),
    }), {}),
    ("actionspersisted",        "alarm.actions_persisted",           make_placeholder_mapper(), {}),
    ("notificationconfigs",     "alarm.notification_configs",        make_placeholder_mapper({
        "name":    lambda d: d.get("name"),
        "enabled": lambda d: bool(d.get("enabled", True)),
    }), {}),
    ("notificationjobs",        "alarm.notification_jobs",           make_placeholder_mapper({
        "alarm_id":     lambda d: oid(d.get("alarmId")),
        "trigger_time": lambda d: to_ts(d.get("triggerTime")),
        "state":        lambda d: d.get("state"),
    }), {}),
    ("smsproviders",            "alarm.sms_providers",               map_smsproviders, {}),
    ("trapconstraints",         "alarm.trap_constraints",            make_placeholder_mapper({"name": lambda d: d.get("name")}), {}),
    ("trapdestinations",        "alarm.trap_destinations",           make_placeholder_mapper({
        "destination_ipv4_address": lambda d: d.get("destinationIpv4Address"),
        "destination_ipv6_address": lambda d: d.get("destinationIpv6Address"),
    }), {}),

    # -- job
    ("jobs",                    "job.jobs",                          map_jobs, {}),
    ("scheduledjobs",           "job.scheduled_jobs",                map_scheduledjobs, {}),
    ("locks",                   "job.locks",                         map_locks, {}),

    # -- telemetry (depends on base_objects via electric_data.device_id)
    ("tsd.datapoints",          "telemetry.datapoints",              map_tsd_datapoints, {"explodes": True}),
    ("tsddata",                 "telemetry.tsd_data",                make_placeholder_mapper(), {}),
    ("electricdatas",           "telemetry.electric_data",           map_electricdatas, {}),
    ("electricrateconfigs",     "telemetry.electric_rate_configs",   make_placeholder_mapper({
        "name": lambda d: d.get("name"),
        "rate": lambda d: parse_decimal(d.get("rate")),
    }), {}),

    # -- file (fs_files precedes fs_chunks)
    ("filemanager",             "file.file_metadata",                map_filemanager, {}),
    ("fs.files",                "file.fs_files",                     map_fsfiles, {}),
    ("fs.chunks",               "file.fs_chunks",                    map_fschunks, {}),

    # -- licensing
    ("licensedstructures",      "licensing.licensed_structures",     map_licensedstructures, {}),
    ("internallicensedfeatures","licensing.internal_licensed_features", map_internallicensedfeatures, {}),
    ("licensedfeatures",        "licensing.licensed_features",       make_placeholder_mapper({
        "name":            lambda d: d.get("name"),
        "feature_version": lambda d: d.get("featureVersion"),
        "quantity":        lambda d: d.get("quantity"),
        "expires_at":      lambda d: to_ts(d.get("expiresAt")),
    }), {}),
    ("licensedproducts",        "licensing.licensed_products",       make_placeholder_mapper({
        "product_name": lambda d: d.get("productName") or d.get("name"),
        "activated":    lambda d: bool(d.get("activated", False)),
    }), {}),
]


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def insert_batch(cur: psycopg.Cursor, table: str, rows: list[dict]) -> int:
    if not rows:
        return 0
    cols = list(rows[0].keys())
    col_list = ", ".join(f'"{c}"' for c in cols)
    placeholders = ", ".join(["%s"] * len(cols))
    sql = f'INSERT INTO {table} ({col_list}) VALUES ({placeholders}) ON CONFLICT DO NOTHING'
    data = [tuple(r.get(c) for c in cols) for r in rows]
    cur.executemany(sql, data)
    return cur.rowcount


def run_pipeline(mongo: MongoClient, pg: psycopg.Connection) -> list[dict]:
    db = mongo["mtp"]
    report = []
    for coll_name, table, mapper, opts in PIPELINE:
        explodes = opts.get("explodes", False)
        try:
            coll = db[coll_name]
            src_count = coll.count_documents({})
            rows: list[dict] = []
            for doc in coll.find():
                try:
                    res = mapper(doc)
                except Exception as ex:
                    log.error("[%s] mapper failed for _id=%s: %s", coll_name, doc.get("_id"), ex)
                    raise
                if res is None:
                    continue
                if explodes:
                    rows.extend(res)
                elif isinstance(res, list):
                    rows.extend(res)
                else:
                    rows.append(res)
            with pg.cursor() as cur:
                inserted = insert_batch(cur, table, rows)
                pg.commit()
                cur.execute(f"SELECT count(*) FROM {table}")
                dst_count = cur.fetchone()[0]
            status = "ok" if dst_count == src_count else ("loss" if dst_count < src_count else "gain")
            log.info("%-26s -> %-44s  src=%5d  dst=%5d  inserted=%5d  [%s]",
                     coll_name, table, src_count, dst_count, inserted, status)
            report.append({"coll": coll_name, "table": table, "src": src_count, "dst": dst_count, "status": status})
        except Exception as ex:
            pg.rollback()
            log.error("FAILED %s -> %s: %s", coll_name, table, ex)
            report.append({"coll": coll_name, "table": table, "src": -1, "dst": -1, "status": f"FAIL: {ex}"})
            raise
    return report


def main() -> None:
    mongo = MongoClient(MONGO_URI, serverSelectionTimeoutMS=10000)
    with psycopg.connect(PG_DSN) as pg:
        report = run_pipeline(mongo, pg)
    print()
    print("=" * 100)
    print(f"{'collection':28} {'table':46} {'src':>6} {'dst':>6}  status")
    print("-" * 100)
    for r in report:
        print(f"{r['coll']:28} {r['table']:46} {r['src']:>6} {r['dst']:>6}  {r['status']}")


if __name__ == "__main__":
    main()
