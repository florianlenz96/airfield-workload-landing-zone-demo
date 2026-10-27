using MeterReadings.Api;
using Xunit;

public class MeterReadingTests
{
    [Fact]
    public void Negative_consumption_is_rejected() =>
        Assert.False(new MeterReading("meter-1", DateTimeOffset.UtcNow, -1).IsValid());

    [Fact]
    public void Readings_from_the_future_are_rejected() =>
        Assert.False(new MeterReading("meter-1", DateTimeOffset.UtcNow.AddHours(1), 1.5).IsValid());

    [Fact]
    public void Blobs_are_grouped_per_meter() =>
        Assert.StartsWith("meter-1/", new MeterReading("meter-1", DateTimeOffset.UtcNow, 1.5).BlobName());
}
