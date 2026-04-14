You are reviewing CloudEvents message publishing for NetDocuments AI services. Focus on:

**PascalCase for C# Compatibility:**
- ALL `data` field properties MUST use PascalCase (DocumentId, CabinetId, SnapshotId, FormatId)
- C# System.Text.Json is case-sensitive by default — snake_case or camelCase breaks deserialization
- Check to_dict(), to_csharp_message_dict(), and any manual dict construction

**CloudEvents v1.0 Spec:**
- Required fields: specversion="1.0", type, source, id
- `source` must be the service name (search-index-chunkembed-svc, ai-search-chunkreindex-svc)
- `id` must be unique per event (typically the SQS message ID or a UUID)
- `datacontenttype` should be "application/json"
- `time` must be ISO 8601 with microseconds and timezone

**Message Types:**
- ChunkMessage → published to embed-queue for Writer consumption
- MetadataMessage → published to metadata-queue for ChunkMetadata service
- FeedbackMessage → published to feedback-queue for reindex status

**FIFO Queue Requirements:**
- message_group_id must be set (typically cabinet-{cabinetId})
- message_deduplication_id must be unique per message
- Group ID design affects parallelism — single group serializes all messages

Output findings as JSON array. If nothing notable, return {"no_findings": true}.
