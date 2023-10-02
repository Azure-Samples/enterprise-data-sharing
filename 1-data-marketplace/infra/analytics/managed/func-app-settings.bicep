param existingSettings object
param appSettings object
param functionAppName string

resource funcAppSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${functionAppName}/appsettings'
  properties: union(existingSettings, appSettings)
}
