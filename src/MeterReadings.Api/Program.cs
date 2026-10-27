using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using MeterReadings.Api;

var builder = WebApplication.CreateBuilder(args);

// No connection strings. Locally this is your az login / Visual Studio account,
// in Azure it is the user-assigned managed identity (Terraform sets AZURE_CLIENT_ID).
var credential = new DefaultAzureCredential();

var blobEndpoint = builder.Configuration["Storage:BlobEndpoint"]
    ?? throw new InvalidOperationException("Set Storage:BlobEndpoint (or Storage__BlobEndpoint).");

builder.Services.AddSingleton(
    new BlobServiceClient(new Uri(blobEndpoint), credential).GetBlobContainerClient("readings"));

var app = builder.Build();

// The pipeline's smoke test waits until this version shows up.
var version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "dev";

app.MapGet("/health", () => Results.Ok(new { status = "ok", version }));

app.MapPost("/readings", async (MeterReading reading, BlobContainerClient container) =>
{
    if (!reading.IsValid())
    {
        return Results.BadRequest("A reading needs a meter ID, a non-negative kWh value and a timestamp that isn't in the future.");
    }

    await container.UploadBlobAsync(reading.BlobName(), BinaryData.FromObjectAsJson(reading));
    return Results.Created($"/readings/{reading.MeterId}", reading);
});

app.MapGet("/readings/{meterId}", async (string meterId, BlobContainerClient container) =>
{
    var readings = new List<MeterReading>();
    await foreach (var blob in container.GetBlobsAsync(
        traits: BlobTraits.None,
        states: BlobStates.None,
        prefix: $"{meterId}/",
        cancellationToken: CancellationToken.None))
    {
        var download = await container.GetBlobClient(blob.Name).DownloadContentAsync();
        readings.Add(download.Value.Content.ToObjectFromJson<MeterReading>()!);
    }

    return Results.Ok(readings);
});

app.Run();
