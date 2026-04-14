---
name: csharp
description: .NET and C# development conventions, patterns, and common pitfalls
---

# C# / .NET Conventions

## Build and Test
- Build: `dotnet build <solution>.sln`
- Test: `dotnet test <solution>.sln`
- Single test: `dotnet test --filter "FullyQualifiedName~ClassName.MethodName"`
- Category filter: `dotnet test --filter "Category=Unit"`
- Format: `dotnet format`

## Patterns
- DI registration typically in `Setup.cs`, entry point in `Program.cs`.
- `IOptions<T>` pattern for config binding from `appsettings.json`.
- SQS handlers implement `IMessageHandler<T>` (AWS.Messaging library).
- HTTP clients use Polly retry (exponential backoff, jitter) for resilience.
- Test categories via xUnit `[Trait("Category", "Unit|Isolated|Smoke")]`.
- Testcontainers for integration tests (ES, LocalStack, Kafka).

## Style
- `.editorconfig` is authoritative — read it, don't guess.
- Husky hooks: pre-commit runs `dotnet format`, pre-push runs unit tests.

## Common Pitfalls
- `System.Text.Json` is case-sensitive by default. Cross-language data uses PascalCase.
- Internal NuGet packages (NetDocuments.*) come from CodeArtifact. Run `aws-login.sh` if restore fails.
- ES client is `Elastic.Clients.Elasticsearch` 8.x (not NEST).
