FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/MeterReadings.Api/MeterReadings.Api.csproj --configuration Release --output /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
WORKDIR /app
COPY --from=build /app .
# The .NET images listen on 8080 and run as a non-root user by default.
EXPOSE 8080
ENTRYPOINT ["dotnet", "MeterReadings.Api.dll"]
