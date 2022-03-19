FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src
COPY ["OneDiscoveryDemoApi.csproj", "."]
RUN dotnet restore "OneDiscoveryDemoApi.csproj"
COPY . .
WORKDIR "/src/"
RUN dotnet build "OneDiscoveryDemoApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "OneDiscoveryDemoApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "OneDiscoveryDemoApi.dll"]
