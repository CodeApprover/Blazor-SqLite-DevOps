#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
WORKDIR /src
COPY ["Blazor-SqLite-Golf-Club.csproj", "."]
RUN dotnet restore "./development/Blazor-SqLite-Golf-Club/Blazor-SqLite-Golf-Club.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "./development/Blazor-SqLite-Golf-Club/Blazor-SqLite-Golf-Club.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "./development/Blazor-SqLite-Golf-Club/Blazor-SqLite-Golf-Club.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Blazor-SqLite-Golf-Club.dll"]
