namespace MeterReadings.Api;

/// <summary>One reading sent by a smart meter.</summary>
public record MeterReading(string MeterId, DateTimeOffset Timestamp, double Kwh)
{
    public bool IsValid() =>
        !string.IsNullOrWhiteSpace(MeterId)
        && Kwh >= 0
        && Timestamp <= DateTimeOffset.UtcNow.AddMinutes(5);

    /// <summary>Readings are grouped per meter: {meterId}/{timestamp}.json</summary>
    public string BlobName() => $"{MeterId}/{Timestamp.UtcDateTime:yyyyMMdd'T'HHmmss'Z'}.json";
}
